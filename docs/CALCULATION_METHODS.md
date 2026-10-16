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
2. **Fallback estimates** — null or rejected events are replaced by
   middle-of-night estimates (`HighLatitudeRule.middleOfNight`), and the
   `highLatitudeFallback` flag is set. If sunrise or sunset is null, the
   whole day is forced onto the estimate path (polar coherence — see below).
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
- sunrise: morning crossing of `−solarDepression` (0.833°)
- Dhuhr: solar noon (+ ihtiyat)
- Asr: afternoon crossing of the shadow-rule altitude (see below)
- Maghrib: evening crossing of `−solarDepression` (0.833°) (+ ihtiyat)
- Isha: evening crossing of `−ishaAngle` (default 17°)

`eventUtc(altitude, morning)`: `cosH = (sin(alt) − sinLat·sinDecl) /
(cosLat·cosDecl)`; returns null when `|cosH| > 1 + 1e-9` (a small epsilon
keeps grazing events computable) or when `cosLat·cosDecl == 0`. Hour angle
`H = acos(cosH)/15`, morning side `noon − H`, evening side `noon + H`.

Asr altitude: `atan(1 / (t + tan(|latitude − declination|)))` with
`t = profile.asrShadowFactor` (1.0 = Maliki first mithl). The computed Asr
is accepted only if it falls strictly between Dhuhr and Maghrib; otherwise
the midpoint `(dhuhr + maghrib) / 2` is used and the fallback flag is set.

## Fallback (middleOfNight) — definition and triggers

All values below are UTC hours on one absolute timeline measured from 00:00
UTC of the requested date; yesterday's events shift by −24 and tomorrow's
by +24.

- **Sunrise/sunset null** → `sunrise = noon − 6`, `sunset = noon + 6`,
  fallback flagged.
- **Fajr null** → `fajr = sunrise − night/2`, where `night = sunrise −
  prevSunsetAbs` (`prevSunsetAbs` = yesterday's sunset shifted −24, or
  `sunrise − 12` if yesterday's sunset is also null); if `night ≤ 0` or NaN,
  `night = 12`. Fallback flagged.
- **Isha null** → `isha = sunset + night/2`, where `night = tomorrowFajr −
  sunset` (tomorrow's Fajr shifted +24, itself fallback-estimated if null);
  if `night ≤ 0` or NaN, `night = 12`. Fallback flagged. If the estimated
  Isha lands at/after the third-of-night marker, the marker is pushed to
  `isha + 30 min` (clamped to the midpoint toward tomorrow's Fajr if needed)
  so ordering stays sane.
- **Asr rejected** → `asr = (dhuhr + maghrib) / 2`. Fallback flagged.

`highLatitudeFallback` is true if ANY of the above triggered on the day.

## Polar coherence (E-01 fix)

When either horizon event is null (polar day/night), the whole day is
forced onto the coherent estimate path: Fajr, Isha, AND Asr take their
fallback estimates even if a real twilight crossing or a shadow-rule value
exists for them. Previously, real twilight crossings (possible while the
sun's maximum altitude lies between −18°/−17° and −0.833°) were mixed with
synthetic `noon±6` horizon times, producing an incoherent day (verified:
80°N on 21 Dec 2026 showed Fajr 08:03 after "sunrise" 05:58 and Isha 15:24
before Maghrib 17:59). A shadow-based Asr is likewise undefined when the
sun never rises, so it takes the midpoint estimate on this path.

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
  including 70°N/80°N polar-night cases.
