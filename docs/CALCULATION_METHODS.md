# Calculation Methods

How the prayer-time engine (`lib/engine/prayer_times.dart`) actually computes
one day of times. This document describes the code as implemented — it is not
a design proposal.

## Pipeline order (actual)

1. **Raw solar events** — `_solarEvents()` computes, for each of yesterday /
   today / tomorrow, the solar declination and the UTC hour of each event on
   that date's own timeline. A null event means the sun never reaches that
   altitude on that date (high latitude; exactly ±90° latitude always yields
   null).
2. **Fallback estimates** — when a twilight event (Fajr/Isha) has no
   solution but a real night frame exists (persistent twilight), the
   user-chosen [HighLatitudeFallback] method estimates them and the
   `highLatitudeFallback` flag is set. When the sun never reaches the
   horizon at all (polar day/night), the result is a typed no-solution
   (see below) — never fabricated times.
3. **Ihtiyat** — `dhuhrIhtiyatMinutes` is added to solar noon and
   `maghribIhtiyatMinutes` to sunset (default profile: +1 minute each; both
   become 0 when the user disables ihtiyat in settings).
4. **Fiqh markers** — `ishaPreferredEnd` (first third of the night),
   `ishaMidnightVariant` (Ibn Habib midnight), `maghribPreferredEnd`
   (sunset + 20 minutes) are computed from the UTC-hour values. The fiqh
   night interval is anchored on the **raw solar sunset**, never on the
   ihtiyat-shifted Maghrib, so these boundaries do not move when the user
   toggles the operational ihtiyat convention.
5. **Offset + rounding** — each UTC instant gets `timeZoneOffset` added and
   is rounded to the nearest minute (`wall()`).
6. **Manual adjustments** — ±60-minute per-prayer adjustments
   (`SettingsService.adjustedTime`) are applied in the UI layer after
   rounding. They are whole minutes, for which `round(t) + n == round(t + n)`
   exactly, so this is mathematically identical to applying them before
   rounding.

## Solar model

Standard low-precision formulation (Meeus, Astronomical Algorithms, as
formulated by the adhan libraries — see ATTRIBUTION.md), with Julian date
taken at 0h UTC of the date:

- mean anomaly `g = 357.529 + 0.98560028·d`
- mean longitude `q = 280.459 + 0.98564736·d`
- ecliptic longitude `l = q + 1.915·sin(g) + 0.020·sin(2g)`
- obliquity `e = 23.439 − 0.00000036·d`
- right ascension from `atan2(cos(e)·sin(l), cos(l))`, normalised to [0, 360)
- declination `δ = asin(sin(e)·sin(l))`
- equation of time `eqt = q/15 − raHours`, normalised to (−12, 12] hours
- solar noon `noon = (12 − eqt − longitude/15)` normalised to [0, 24)

One event per altitude (event altitudes below):

- Fajr: morning crossing of `−fajrAngle` (default 18°)
- sunrise: morning crossing of `−(solarDepression + dip)` (0.833° + elevation dip)
- Dhuhr: solar noon (+ ihtiyat)
- Asr: afternoon crossing of the shadow-rule altitude (see below)
- Maghrib: evening crossing of `−(solarDepression + dip)` (0.833° + elevation dip) (+ ihtiyat)
- Isha: evening crossing of `−ishaAngle` (default 17°)

### Horizon dip (observer elevation)

`dip = 0.0293 × √h` degrees, with `h` the observer elevation in meters
(standard astronomical dip-of-horizon formula, mean refraction included).
It is added to the profile's `solarDepression` for the sunrise/sunset
horizon events only — the visible horizon drops for a higher observer, so
sunrise comes earlier and sunset later. Twilight (Fajr/Isha) angles and the
Asr shadow rule reference the sun's depression below the geometric horizon
and are unaffected. Elevation is an optional per-location input (meters,
persisted with the location); unset/0 = sea-level horizon. Negative input
is clamped to 0. Like the 0.833° itself, the dip is a software/astronomical
convention — never a Maliki ruling.

### Time-zone frame

All engine times are UTC instants; the wall-clock frame is applied by adding
a UTC offset per civil date. Since Phase 2 the offset comes from the
*location's* IANA zone (bundled `package:timezone` latest_all database —
full IANA coverage, 598 zones, tzdata 2026e — offline-first) — the stored
zone id for manual locations, the device zone for GPS-derived locations —
resolved per date so DST transitions are correct per date, not just "today".
Previously (≤ v1.2.0+5) the device timezone was used for every location,
which mis-rendered far-away manual locations; see
docs/CALCULATION_CHANGELOG.md.

`eventUtc(altitude, morning)`: `cosH = (sin(alt) − sinLat·sinDecl) /
(cosLat·cosDecl)`; returns null when `|cosH| > 1 + 1e-9` (a small epsilon
keeps grazing events computable) or when `cosLat·cosDecl == 0`. Hour angle
`H = acos(cosH)/15`, morning side `noon − H`, evening side `noon + H`.

Asr altitude: `atan(1 / (t + tan(|latitude − declination|)))` with
`t = profile.asrShadowFactor` (1.0 = Maliki first mithl). The computed Asr
is accepted only if it falls strictly between Dhuhr and Maghrib; otherwise
the midpoint `(dhuhr + maghrib) / 2` is used and the fallback flag is set.

## Fallback chooser — definition and triggers (Phase 5)

The user selects one of four fallback methods in Settings (persisted;
default [HighLatitudeFallback.middleOfNight], per adhan `recommended()`).
Every method is an institutional/software convention — never a Maliki
ruling — and the UI names the method in effect wherever fallback times
are shown, with a change affordance.

All values below are UTC hours on one absolute timeline measured from 00:00
UTC of the requested date; yesterday's events shift by −24 and tomorrow's
by +24. Each twilight event uses the solar night it belongs to (D5 §3.7):
`N_fajr = sunrise − prevSunsetAbs` (yesterday's sunset shifted −24, or
`sunrise − 12` when yesterday's sunset is also null) and
`N_isha = tomorrowSunriseAbs − sunset` (tomorrow's sunrise shifted +24, or
`sunset + 12` when tomorrow's sunrise is null); either night is replaced
by 12 when it is ≤ 0 or NaN.

- **Middle of night** — `fajr = sunrise − N_fajr/2`,
  `isha = sunset + N_isha/2` (D5 §3.7).
- **One-seventh of night** — `fajr = sunrise − N_fajr/7`,
  `isha = sunset + N_isha/7` (D5 §3.7).
- **Angle-based** — `fajr = sunrise − (fajrAngle/60)·N_fajr`,
  `isha = sunset + (ishaAngle/60)·N_isha` (D5 §3.7; the profile's own
  twilight angles).
- **Nearest day** — the whole day is borrowed from the nearest civil date
  within ±183 days on which every event has a solution (past preferred on
  equidistant ties); the source date is recorded on
  `PrayerTimes.nearestDaySourceDate` and the UI shows it next to the
  borrowed times. Borrowed times render in the displayed date's offset
  frame — a documented engineering convention. When no solvable day is
  found within ±183 days (the poles), the middle-of-night convention
  stands in, still named honestly as the method in effect.

A method engages only when its twilight event actually lacks a solution;
a solvable Fajr/Isha is always kept. `PrayerTimes.fallbackMethod` names
the method in effect (null on a fully computed day); the Asr-midpoint
fallback (`asr = (dhuhr + maghrib) / 2` when the shadow rule is rejected)
is a separate software convention and does not change the named method.

## No-solution days (Phase 5 — replaces the old polar coherence)

When the sun never reaches the horizon (polar day/night: sunrise or
sunset null), no fallback can be constructed from a nonexistent
sunset/sunrise, and the engine returns `PrayerTimesNoSolution` with the
reason (`polarDay` — transit altitude above the horizon; `polarNight` —
below it). The old noon±6 synthetic-horizon estimate path (E-01 "polar
coherence") is deleted: a calculation failure never produces a
plausible-but-unsupported time. The UI renders an honest empty state
("Prayer times cannot be computed for this date and location") with the
fallback chooser one tap away.

The single exception is an explicit user choice of the nearest-day
method: with no night frame and `fallback == nearestDay`, the borrowed
day is shown — labeled with its source date — because the user asked for
that convention. Polar-night twilight Fajr/Isha that are mathematically
solvable are still suppressed under the default: showing them alongside
a frameless Dhuhr/Asr is the legal-policy question D5 §5 E5 leaves to
scholarly review, and suppress-and-flag is the honest default.

## DST / time-zone offset handling

The engine takes a fixed `Duration timeZoneOffset` and is offset-agnostic:
it adds the offset to every UTC instant and returns wall-clock DateTimes in
that frame. Choosing the right offset per date (e.g. across a DST
transition) is the CALLER's responsibility — currently all callers pass
today's offset for every computed date (known issue E-02, not fixed here).

## Markers (informational, never adhan times)

- `ishaPreferredEnd = sunset + (tomorrowFajr − sunset) / 3` — first third of
  the night, Maliki ikhtiyari end of Isha.
- `ishaMidnightVariant = sunset + (tomorrowSunrise − sunset) / 2` — Ibn Habib
  midnight alternative (spec §3.8); `sunset + 6` if tomorrow's sunrise is
  null.
- `maghribPreferredEnd = sunset + 20 min` — the narrow ~15–20 minute
  preferred band, measured from the raw sunset so the displayed end matches
  the band text.

## Validation limits

- The engine performs no coordinate validation; `Coordinates` documents
  −90..90 / −180..180 but enforces nothing. Known issue E-07 (not fixed
  here): a NaN latitude passes manual-entry validation and collapses all
  events to solar noon (`(double.nan).clamp(-1, 1)` returns 1.0 in this SDK),
  silently producing six identical times.
- Fallback times are always finite by construction (the `night ≤ 0 || NaN →
  12` guards), and the universal ordering invariant
  `fajr < sunrise < dhuhr < asr < maghrib < isha < ishaPreferredEnd`
  (`test/engine_test.dart: expectOrdering`) is asserted across vectors
  including persistent-twilight fallback days. Polar days are typed
  no-solutions by construction — no ordering to assert.
