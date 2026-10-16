# Architecture

How the Maliki Prayer Times app is put together: what each subsystem owns,
how data flows between them, and the conventions new code must follow.

## Layering

```
engine/  (pure Dart — no Flutter, no plugins, no I/O)
  ↓  PrayerTimes: UTC-kind DateTimes whose fields are wall-clock values
fiqh/    (maps engine events onto Maliki prayer bands)
  ↓  band starts/ends, preferred vs daruri windows
services/ (ChangeNotifier state + persistence + platform seams)
  ↓  constructor-passed into screens; listeners, no provider package
screens/ + widgets/
```

Data flows one way: the engine never calls up into services, and services
never import screens. Screens read service state and call engine functions
directly for display.

## Engine (`lib/engine/`)

- `prayer_times.dart` — `calculatePrayerTimes({coordinates, date, timeZoneOffset, profile, elevationMeters})`
  computes solar events (Fajr, sunrise, sunset, Dhuhr, Asr, Maghrib, Isha) as UTC
  instants, adds `timeZoneOffset`, rounds to the nearest minute, and returns
  them as UTC-kind `DateTime`s whose **fields are wall-clock values** in the
  offset's frame. `elevationMeters` (default 0) applies the horizon dip
  correction to sunrise/sunset only. Differences and orderings between returned times are exact;
  to recover true UTC instants, subtract the offset. Only the civil
  year/month/day of `date` is used. Times may fall on the adjacent civil
  date (e.g. an Isha after midnight belongs to the night that began at
  Maghrib). High-latitude fallback (`HighLatitudeRule.middleOfNight`)
  estimates Fajr/Isha from night portions when twilight never reaches the
  configured depression, and sets `PrayerTimes.highLatitudeFallback`.
- `prayer_profile.dart` — `PrayerProfile` value objects (Fajr/Isha angles,
  Asr shadow factor, solar depression, ihtiyat minutes) plus the
  `PrayerProfiles` registry (e.g. `malikiMwlWestAfrica`,
  `defaultProfile`). Angles are astronomical conventions, not fiqh rulings.
- `coordinates.dart` — validated latitude/longitude value type.
- `lib/utils/solar.dart`, `qibla.dart`, `hijri.dart` — pure helpers
  (solar math, qibla bearing/distance, Hijri date).

The engine has no dependencies on Flutter, plugins, or the network, and is
covered by unit tests that run without a device.

## Fiqh mapping (`lib/fiqh/maliki_rules.dart`)

Maps each engine event onto the Maliki prayer band it belongs to: band
start/end, the preferred (ikhtiyari) window, and the daruri (last-resort)
window, with the explanatory texts the UI shows. It consumes engine output;
it never performs I/O and never changes a computed instant.

## Services (`lib/services/`)

All services are constructed with their dependencies injected and expose
test fakes; widget tests never touch platform channels. `SettingsService`
and `LocationService` are `ChangeNotifier`s passed down through widget
constructors; screens add/remove listeners symmetrically.

- **SettingsService** — active calculation profile, ihtiyat on/off,
  per-prayer minute adjustments (±60, clamped), notification toggles,
  reminder offset (allow-listed 0/5/10/15), UI language. `adjustedTime`
  applies the stored per-prayer adjustment. Persists defensively:
  corrupt/missing values fall back to defaults, never throw.
- **LocationService** — the chosen `SavedLocation`, permission/service
  state (`LocationPermissionState`), and machine-readable failure kinds
  (`LocationErrorKind`) with an English `errorMessage` fallback; the UI
  renders localized text from `errorKind`. Flows:
  - `useDeviceLocation()` — service check → check/request permission →
    one GPS fix (25 s `timeLimit`) → persist fix **first**, then resolve
    the cosmetic place name (10 s timeout) and update/persist again if one
    arrives. Never throws; every failure records state and leaves `current`
    untouched so an existing manual location is never wiped.
  - `useManualLocation()` — persists the entry, sets `current`, clears
    all error state.
  - `refreshDeviceLocation()` — re-reads the fix for device locations.
  - Seams: `GpsReader` (`GeolocatorGpsReader` / fake),
    `LocationPermissionGateway` (`GeolocatorPermissionGateway` / fake),
    `PlaceNamer` (`GeocodingPlaceNamer` / fake).
- **NotificationService** — schedules prayer at-time notifications
  (id = `Prayer.index`) and pre-prayer reminders (id = `1000 + index`)
  from the same `adjustedTime` values the UI shows, plus the one-time
  sun–qibla alignment reminder (id `950`). `rescheduleAll` cancels
  everything first, then schedules the next upcoming occurrence per
  enabled prayer (today's when still future, else tomorrow's); past
  times are skipped so nothing fires immediately. Each target date is
  computed in its own UTC-offset frame (`timeZoneOffsetForDate`,
  defaulting to the device zone's offset for that date) so DST
  transitions are honored per date. Scheduling uses absolute UTC
  instants. Seam: `NotificationScheduler`
  (`PluginNotificationScheduler` / `FakeNotificationScheduler`).
  Timezone renames trigger a reschedule from the persisted
  location/profile via `_syncTimeZone`.
- **CompassService** — `SensorCompassService` fuses accelerometer +
  magnetometer into tilt-compensated headings on a broadcast stream;
  emits `null` when no usable reading arrives within 4 s; `dispose()`
  cancels the timer, both subscriptions, and the controller.
- **AppUpdateService** — compares the installed build number against the
  latest GitHub release tag. Only ever runs on an explicit user tap in
  Settings; per-stage ~8 s timeouts, never throws (`unknown` on failure).
  Seam: `ReleaseFetcher` (`GithubReleaseFetcher` / fake).

## Screens (`lib/screens/`)

Five tabs under the root `MalikiPrayerTimesApp` shell (top bar +
bottom nav live in `main.dart`; tabs render body content only):

0. **Home** — today's timetable, next-prayer countdown (1 s timer scoped
   to the Home subtree), Hijri date.
1. **Monthly** — 31-day grid; each cell computed once per month load.
2. **Qibla** — compass dial, qibla bearing/distance, sun-alignment card.
3. **Profiles** — calculation-profile picker.
4. **Settings** — ihtiyat, adjustments, notification toggles, reminder
   offset, language, update check.

Plus `LocationScreen` (device fix / manual entry / presets, pushed from
the top-bar chip or the choose-location prompt) and `SplashScreen`.

Screens guard every post-await `setState` with `mounted` and dispose
their controllers/listeners.

## Startup sequence

1. `main()` draws `SplashScreen` immediately.
2. `SettingsService.load()` and `LocationService.load()` run **in
   parallel** (`.wait`) — never sequential awaits on the launch path.
3. `NotificationService` is constructed (plugin init is deferred).
4. The splash is kept for a **700 ms floor** measured from launch, never
   longer than init actually takes, then the real app is run with the
   loaded services passed into constructors.
5. `_NotificationBootstrap` (post-frame): `init()` (plugin +
   `TimezoneService.ensureInitialized()` + timezone-change sync), then
   `rescheduleAll`. It also listens to settings/location and
   re-runs `rescheduleAll` on profile, ihtiyat, adjustments, toggles,
   reminder offset, or location changes.
6. Notification permission is requested **once ever** (persisted flag),
   right after the splash closes.

## Notification ID strategy and reschedule triggers

- Stable, disjoint IDs: at-time `Prayer.index` (0–5), reminders
  `1000 + index`, sun reminder `950`. A re-run converges instead of
  duplicating.
- Every `rescheduleAll` starts with `cancelAll()`.
- Triggers: app start (post-frame), and any change to location,
  calculation profile, ihtiyat, per-prayer adjustments, notification
  toggles, or reminder offset — via the `_NotificationBootstrap`
  listeners, plus direct calls from the notification settings UI.
- The persisted sun-reminder record is restored by `rescheduleAll`
  while its fire time is still in the future; stale records are pruned.
- Exact vs inexact Android scheduling follows
  `canScheduleExactAlarms()`; the settings UI states the grant
  honestly ("may arrive late" when denied).
- Known limitation: schedules do not survive a device reboot (no
  `RECEIVE_BOOT_COMPLETED` receiver yet); they are rebuilt on the next
  app start.

## Persistence

All state lives in `SharedPreferences` (local only, never transmitted):

| Owner | Key | Contents |
|---|---|---|
| Location | `saved_location` | `SavedLocation` JSON: name, lat/lon, `isDevice`, `placeName` |
| Settings | `active_profile_id` | calculation profile id |
| Settings | `adjustments` | per-prayer minute offsets |
| Settings | `ihtiyat_enabled` | bool |
| Settings | `language_code` | UI language, allow-listed |
| Settings | `notification_toggles` | per-prayer bools |
| Settings | `reminder_offset_minutes` | 0/5/10/15 |
| Notifications | `notifications_last_tz_name` | last seen `timeZoneName` |
| Notifications | `notifications_last_lat` / `_lon` | coords used for the schedule |
| Notifications | `notifications_last_profile_id` | profile id used for the schedule |
| Notifications | `notifications_last_offset_minutes` | offset used for the schedule |
| Notifications | `sun_reminder_utc` / `_title` / `_body` | one-time sun reminder |
| App shell | `notif_permission_asked_v1` | permission prompt shown once |

**Additive-evolution policy:** persisted blobs have no schema-version key.
New fields must be optional with safe defaults so legacy JSON still
deserializes (e.g. `SavedLocation.fromJson` defaults `isDevice: false`,
`placeName: null`). The first breaking schema change must introduce a
version key.

## Test seam pattern

Every external dependency sits behind a small abstract class with a
production implementation and a fake, injected through the constructor:

- `NotificationScheduler` → `FakeNotificationScheduler` (records
  scheduled/cancelled; controllable permission and exact-alarm answers)
- `GpsReader` → `FakeGpsReader` (scripted position; timeout-mirroring
  variants for hang tests)
- `LocationPermissionGateway` → `FakePermissionGateway` (scripted
  outcomes)
- `PlaceNamer` → `FakePlaceNamer` (scripted name / throws / hangs)
- `ReleaseFetcher` → fake (scripted release JSON / failure)
- `CompassService` → fake headings stream

Pure functions take injectable clocks instead of calling `DateTime.now`
(`rescheduleAll({now, timeZoneOffsetForDate})`,
`_syncTimeZone` via `syncTimeZoneForTest`). Timeouts use
`FakeAsync`-compatible `Timer`/`Future.timeout` so hang tests elapse
fake time instead of sleeping. The never-throw contracts are tested by
driving every failure path through the fakes.
