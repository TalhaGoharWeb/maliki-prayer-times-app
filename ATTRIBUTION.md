# Attribution — calculation engine sources

## What was used

The astronomical core of `lib/engine/` ports the standard solar-position
formulation (Jean Meeus, *Astronomical Algorithms*) as implemented by the
adhan prayer-times libraries:

- batoulapps/adhan-kotlin (Android)
- batoulapps/adhan-swift (iOS)

## License basis

- The adhan projects state in their official READMEs that
  "Adhan is available under the MIT license".
- Maven Repository metadata for the adhan artifacts lists the MIT license.
- A third-party vendoring note independently describes adhan as MIT-licensed.
- A direct fetch of the LICENSE file from batoulapps/adhan-kotlin timed out
  (transient network error, not a license problem).

**Action item: Re-verify the LICENSE file text in batoulapps/adhan-kotlin
directly before any release.**

## What was ported (astronomy, MIT-licensed formulation)

- Solar coordinates: mean anomaly, mean longitude, ecliptic longitude,
  obliquity of the ecliptic, right ascension, declination, equation of time.
- Hour-angle method for solar-altitude events (Fajr/Isha twilight depressions,
  sunrise/sunset at −0.833° for upper limb + refraction).
- Asr shadow formula: altitude = arccot(shadowFactor + tan(|latitude −
  declination|)).
- High-latitude middle-of-night fallback concept.
- The MWL 18°/17°, Egyptian 19.5°/17.5°, and UOIF 12°/12° angle values, taken
  as named institutional conventions per the research brief (not as fiqh
  rulings).

## What was reimplemented (original to this project)

- The Maliki profile layer (`PrayerProfile`, `PrayerProfiles`), including the
  per-parameter source citations from the calculation specification.
- The ikhtiyari/daruri display outputs: first-third-of-night Isha end,
  Ibn Habib midnight variant, Maghrib +20 minute informational band.
- The pure-Dart API (`PrayerTimes`, `calculatePrayerTimes`, `nextPrayer`),
  the wall-clock time frame, nearest-minute rounding, and the order in which
  ihtiyat adjustments are applied.
- The absolute-timeline night arithmetic spanning civil-date boundaries.

## What was deliberately NOT taken

- SunnahTimes, Qibla computation, adhan's madhab preset enums, any UI code.

## Status

The calculation profile is PROPOSED — pending scholarly review. Nothing in
this app is presented as scholar-reviewed.

## Milestone 2 runtime dependencies

- **geolocator** — MIT — Baseflow/flutter-geolocator
  (https://github.com/Baseflow/flutter-geolocator) — used for device GPS
  fixes. License verified 2026-10-15 via repo metadata and multiple
  independent license listings (pub.dev, Medium ecosystem survey, GitHub
  community proposals all list MIT).
- **shared_preferences** — BSD-3-Clause — flutter/packages
  (https://github.com/flutter/packages/tree/main/packages/shared_preferences/shared_preferences)
  — used for settings and location persistence. License verified 2026-10-15
  via multiple independent license listings (pub.dev metadata for
  `shared_preferences_ios`, plus independent third-party attribution files
  all listing BSD-3-Clause).

## Track A runtime dependencies (notifications)

- **flutter_local_notifications** — BSD-3-Clause — 22.3.2 —
  MaikuBui/flutter_local_notifications
  (https://github.com/MaikuBui/flutter_local_notifications) — used for
  prayer-time and pre-prayer reminder notifications (Android channel
  `prayer_times`, iOS via the plugin's permission flow). License verified
  2026-10-15 by reading the LICENSE file in the pub cache
  (`~/.pub-cache/hosted/pub.dev/flutter_local_notifications-22.3.2/LICENSE`):
  full BSD-3-Clause text, "Copyright 2018 Michael Bui".
- **timezone** — BSD-3-Clause — 0.11.2 — srawlins/timezone
  (https://github.com/srawlins/timezone) — used to initialize the tz database
  and build absolute `TZDateTime` fire times for `zonedSchedule`. License
  verified 2026-10-15 by reading the LICENSE file in the pub cache
  (`~/.pub-cache/hosted/pub.dev/timezone-0.11.2/LICENSE`): full
  BSD-3-Clause text, "Copyright (c) 2014, timezone project authors".

Both passed the license gate (permissive: MIT/Apache-2.0/BSD — no
copyleft, no proprietary terms, LICENSE files present and read).
