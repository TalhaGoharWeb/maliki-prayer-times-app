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

## Bundled font: Nafees Nastaleeq (CRULP — redistribution permitted)

- **File:** `assets/fonts/NafeesNastaleeq.ttf` (396,948 bytes), declared as family
  `Nafees Nastaleeq` in pubspec.yaml, used for Urdu (`ur`) locale text.
- **License: VERIFIED permissive.** The Nafees Nastaleeq License Agreement
  (Copyright (c) 2004 by Center for Research in Urdu Language Processing
  (CRULP), National University of Computer and Emerging Sciences, Lahore,
  Pakistan) grants, free of charge, the rights to "reproduce and distribute
  the Font Software, including without limitation the rights to use, copy,
  merge, publish, distribute, and/or sell copies", subject to: (1) including
  the copyright/trademark/permission notices in all copies, (2) renaming the
  font if modified, (3) voiding of the license for modified versions
  distributed under the Nafees/CRULP names, (4) no sale of the font by itself.
  License text confirmed 2026-10-15 via the font's metadata on multiple font
  registries and the Debian packaging record.
- **Source of this binary:** Ubuntu package `fonts-nafees` 1.2-5.1ubuntu1
  (downloaded from the Ubuntu archive 2026-10-15); its copyright file
  (`assets/fonts/NafeesNastaleeq-Debian-copyright.txt`) notes the font was
  obtained from CRULP/CLE and additionally records GPL-2 terms per the Debian
  maintainer. Either way, redistribution in this app is permitted.
- **Attribution condition satisfied:** the copyright/trademark notice travels
  with the font in `assets/fonts/NafeesNastaleeq-Debian-copyright.txt` and is
  recorded here.
- **History:** Jameel Noori Nastaleeq was briefly bundled on 2026-10-15 at the
  user's explicit direction, then REMOVED the same day when the user said "if
  you are not satisfied use nafees nastaleeq for now" — no Jameel Noori files
  remain in this repo. The earlier finding stands: no redistribution license
  for Jameel Noori could be verified (font sites list it as personal-use-only;
  no official license document exists).

## Amiri (Arabic typeface)
- **Files:** `assets/fonts/Amiri-Regular.ttf`, `assets/fonts/Amiri-Bold.ttf`
  (font family "Amiri").
- **License:** SIL Open Font License 1.1 (OFL). License text in
  `assets/fonts/OFL-Amiri.txt`.
- **Source:** google/fonts repository (github.com/google/fonts), verified
  2026-10-15. Designed by Khaled Hosny.
- **Use:** Arabic-script UI text (ar locale and Arabic names/labels across
  locales).

## Source Serif 4 (Latin/French headlines)
- **Files:** `assets/fonts/SourceSerif4-Variable.ttf` (font family
  "Source Serif 4", variable weight; used at w400/w600/w700).
- **License:** SIL Open Font License 1.1 (OFL). License text in
  `assets/fonts/OFL-SourceSerif4.txt`.
- **Source:** google/fonts repository (github.com/google/fonts), verified
  2026-10-15. Designed by Frank Grießhammer.
- **Use:** Headlines and HH:MM time readouts for en/fr locales.

## Manrope (Latin/French body)
- **Files:** `assets/fonts/Manrope-Variable.ttf` (font family "Manrope",
  variable weight).
- **License:** SIL Open Font License 1.1 (OFL). License text in
  `assets/fonts/OFL-Manrope.txt`.
- **Source:** google/fonts repository (github.com/google/fonts), verified
  2026-10-15. Designed by Michael Sharanda.
- **Use:** Body text, labels, and UI chrome for en/fr locales.

## sensors_plus (live compass)

- **Package:** sensors_plus 7.1.1 (plus_platform_interface 2.0.2) —
  https://github.com/fluttercommunity/plus_plugins
- **License:** BSD-3-Clause ("Copyright 2017 The Chromium Authors").
  Verified 2026-10-15 by reading the LICENSE file in the pub cache
  (`~/.pub-cache/hosted/pub.dev/sensors_plus-7.1.1/LICENSE`): full
  BSD-3-Clause text. Passed the license gate (permissive, no copyleft).
- **Use:** accelerometer + magnetometer streams for the live Qibla compass
  heading. Abstracted behind `CompassService` so widget tests never touch
  platform channels.

## geocoding (reverse geocoding for device location)

- **Package:** geocoding 5.0.0 (geocoding_android 5.1.0, geocoding_darwin
  1.0.3, geocoding_platform_interface 5.0.0) —
  https://github.com/Baseflow/flutter-geocoding
- **License:** MIT ("Copyright (c) 2018 Baseflow"). Verified 2026-10-15 by
  reading the LICENSE file in the pub cache
  (`~/.pub-cache/hosted/pub.dev/geocoding-5.0.0/LICENSE`): full MIT text.
  Passed the license gate (permissive, no copyleft).
- **Use:** reverse-geocodes a GPS fix to a human place name (city/locality)
  shown in the home location header and Location screen. Abstracted behind
  `PlaceNamer` so widget tests never touch platform channels; never throws
  (failure falls back to the localized "Device location" label).

## package_info_plus (installed version for the update check)

- **Package:** package_info_plus 10.2.2 —
  https://github.com/fluttercommunity/plus_plugins
- **License:** BSD-3-Clause ("Copyright 2017 The Chromium Authors").
  Verified 2026-10-15 by reading the LICENSE file in the pub cache
  (`~/.pub-cache/hosted/pub.dev/package_info_plus-10.2.2/LICENSE`): full
  BSD-3-Clause text. Passed the license gate (permissive, no copyleft).
- **Use:** reads the installed build number so the in-app update check can
  compare it against the latest GitHub release tag.

## url_launcher (open the release download URL)

- **Package:** url_launcher 6.3.1 — https://github.com/flutter/packages
- **License:** BSD-3-Clause ("Copyright 2013 The Flutter Authors"). Verified
  2026-10-15 by reading the LICENSE file in the pub cache
  (`~/.pub-cache/hosted/pub.dev/url_launcher-6.3.1/LICENSE`): full
  BSD-3-Clause text. Passed the license gate (permissive, no copyleft).
- **Use:** opens the update download URL (release APK asset or release page)
  in the external browser from Settings → Check for updates.

## share_plus (monthly timetable sharing)

- **Package:** share_plus 13.3.1 —
  https://github.com/fluttercommunity/plus_plugins
- **License:** BSD-3-Clause ("Copyright 2017, the Flutter project authors").
  Verified 2026-10-16 by reading the LICENSE file in the pub cache
  (`~/.pub-cache/hosted/pub.dev/share_plus-13.3.1/LICENSE`): full
  BSD-3-Clause text. Passed the license gate (permissive, no copyleft).
- **Use:** opens the platform share sheet to share the monthly timetable
  image rendered from the Monthly screen. Sharing is wrapped in an
  injectable function so widget tests never touch platform channels.
