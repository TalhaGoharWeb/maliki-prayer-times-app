# Privacy

What the Maliki Prayer Times app collects, stores, transmits, and never
touches. This document describes the code as shipped; anything not listed
here does not happen.

## Location

- **One-shot fixes only.** The app calls `Geolocator.getCurrentPosition`
  (medium accuracy) when the user taps the device-location button or
  refreshes a device location. There is no background tracking, no
  continuous watch, and no location access at startup.
- **Declared permissions (Android):** `ACCESS_FINE_LOCATION` and
  `ACCESS_COARSE_LOCATION`. The permission flow is check → request;
  `denied` and `deniedForever` outcomes are handled with a manual-entry
  fallback and, for permanent denial, a deep link to system settings.
  **iOS:** `NSLocationWhenInUseUsageDescription` only — no background
  location modes.
- The coarse-vs-fine choice is a product decision left open: city-level
  (coarse) accuracy changes prayer times by seconds at most.

## Local-only persistence

Everything the app remembers lives in on-device `SharedPreferences`
and is never transmitted anywhere by the app:

- the chosen location (`saved_location`: name, latitude, longitude,
  device-vs-manual flag, cached place name),
- calculation profile, ihtiyat toggle, per-prayer minute adjustments,
  notification toggles, reminder offset, UI language,
- the notification schedule's inputs (last coordinates, profile id,
  timezone name/offset) and any pending sun-alignment reminder,
- a flag recording that the notification permission prompt was shown.

No account, no login, no server-side profile.

## Network touches (two, both non-critical)

1. **Update check — user-tapped only.** Tapping "check for updates" in
   Settings fetches `https://api.github.com/repos/TalhaGoharWeb/maliki-prayer-times-app/releases/latest`
   (`INTERNET` permission exists solely for this). Per-stage ~8 s
   timeouts plus a 2 s outer bound; any failure yields "unknown", never
   an error screen. Nothing is checked at startup, in the background,
   or on a timer.
2. **OS reverse-geocoder — on GPS fix only.** After a successful device
   fix, coordinates are sent to the platform geocoder to obtain a human
   place name (city/locality). Bounded by a 10 s timeout; any failure
   or hang falls back to the generic "Device location" label. The name
   is cached alongside the coordinates so offline reloads keep the last
   good one.

Prayer computation itself is pure Dart and fully offline.

## What the app does not do

- **No analytics, ads, crash-reporting, or telemetry.** Dependencies are
  `geolocator`, `shared_preferences`, `flutter_local_notifications`,
  `timezone`, `sensors_plus`, `geocoding`, `package_info_plus`,
  `url_launcher` (+ Flutter SDK packages) — none exfiltrate data.
- **No secrets.** No API keys, tokens, or credentials anywhere in the
  source or the repository.
- **No coordinate logging.** `lib/` contains no `print`/`debugPrint`/
  `developer.log` calls (the only `log` reference is `dart:math`'s in
  the qibla math). Precise coordinates are never written to logs.
- **Notifications are local.** `POST_NOTIFICATIONS` (Android 13+
  runtime), `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` exist so prayer
  reminders can fire at exact times; all scheduling is on-device via
  `flutter_local_notifications`, using absolute UTC instants. No push
  service, no notification content leaves the phone.

## Permissions summary

| Permission | Why |
|---|---|
| `INTERNET` | GitHub releases API for the manual update check |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | One-shot device-location fix |
| `POST_NOTIFICATIONS` | Prayer-time and reminder notifications (runtime prompt) |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | Exact-time alarms when the user grants them; otherwise inexact with an honest "may arrive late" note |
