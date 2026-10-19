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

## Notification sound: Tunisian adhan recording (user-supplied)

- **File:** `android/app/src/main/res/raw/tunisi_adhan.mp3` (3.9 MB, MP3,
  64 kbps, 44.1 kHz stereo, ~122 s) — played for the at-time notifications
  of the five prayers via the Android `prayer_times` notification channel
  (`RawResourceAndroidNotificationSound('tunisi_adhan')`). Pre-prayer
  reminders, the sun–qibla reminder, and qada reminders use a separate
  `prayer_times_reminders` channel with the default sound.
- **Provenance:** supplied directly by the app owner (Muhammad Talha Bin
  Farid) on 2026-10-19 with the instruction to use it as the notification
  sound for each salat timing. The original recording artist, source, and
  license are not known to the project — the file is used solely on the
  owner's direction and responsibility. Re-verify redistribution rights
  before any public release that bundles this file.
- **iOS:** the platform caps notification sounds at 30 s, so a 29 s excerpt
  (`ios/Runner/adhan/tunisi_adhan_30s.mp3`, opening takbirs with a 2 s
  fade-out, wired into the Xcode project's Resources build phase) plays for
  the at-time prayer notifications via `DarwinNotificationDetails(sound:)`.
  Chosen by the owner 2026-10-19 ("trim a 30-second excerpt for iPhone").

## Qada tracker: encrypted storage for sensitive records

- **flutter_secure_storage** — BSD-3-Clause — 11.2.0 —
  mogol/flutter_secure_storage
  (https://github.com/mogol/flutter_secure_storage) — used ONLY for the
  Hayd/Nifas bleeding records (the sensitive subset of the Qada tracker).
  Android: keys in the Android Keystore, values in EncryptedSharedPreferences
  (AES-256-GCM); iOS: Keychain. License verified 2026-10-19 by reading the
  LICENSE file in the pub cache
  (`~/.pub-cache/hosted/pub.dev/flutter_secure_storage-11.2.0/LICENSE`):
  full BSD-3-Clause text, "Copyright 2017 German Saprykin". Passed the
  license gate (permissive, no copyleft). All other Qada data (balances,
  ledger, planner) stays in shared_preferences like the rest of the app.

## Phase 2: timezone tz-data variant (location exactness)

- **timezone** — BSD-3-Clause — 0.11.2 — srawlins/timezone
  (https://github.com/srawlins/timezone) — the app now uses the
  **latest_all** tz-data variant (`package:timezone/data/latest_all.dart`,
  full IANA coverage: 598 zones, tzdata version 2026e) via
  `lib/services/timezone_service.dart` to render times in the
  *location's* IANA zone (stored zone for manual locations, device zone
  for GPS-derived ones). Offline-first: the database is bundled, no
  connectivity needed. The notification path
  (`lib/services/notification_service.dart`) was already on `latest_all`
  and now shares the single `TimezoneService` initialization.
- **Why not latest_10y:** the first draft named `latest_10y` (~85 KB), but
  verification showed it is a curated 345-zone SUBSET, not a time-window
  trim — it drops real zones including `Africa/Nouakchott`, one of this
  app's own preset cities. A zone picker that cannot represent Nouakchott
  breaks Phase 2's purpose, so the full variant is used; the size cost
  (~1 MB in a ~73 MB APK) is immaterial next to correctness.
- License re-verified 2026-10-16 by reading the LICENSE file in the pub
  cache (`~/.pub-cache/hosted/pub.dev/timezone-0.11.2/LICENSE`): full
  BSD-3-Clause text, "Copyright (c) 2014, timezone project authors".
  Passed the license gate (permissive, no copyleft). Release blocker:
  cleared.

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

## Phase 6: adhan_dart (test-only cross-validation dependency)

- **Package:** adhan_dart 2.0.1 —
  https://github.com/prayer-timetable/adhan_dart
  (https://pub.dev/packages/adhan_dart)
- **License: VERIFIED MIT — release blocker CLEARED.** Verified 2026-10-16 by
  reading the LICENSE file in the pub cache at the pinned version
  (`~/.pub-cache/hosted/pub.dev/adhan_dart-2.0.1/LICENSE`): full MIT text,
  "Copyright (c) 2020 prayer-timetable <https://github.com/prayer-timetable>".
  Passed the license gate (permissive, no copyleft). pubspec.lock pins
  sha256 `b1a280975b73052eb3b213430adf481f241bfc1cd839b2b0f4368bfe1a1b7ee5`.
- **Use:** `dev_dependency` ONLY. Imported solely by
  `test/adhan_cross_validation_test.dart` to cross-validate the app's own
  engine against an independent Meeus-family implementation (MWL 18/17,
  Asr t=1 mapped via Madhab.shafi, ihtiyat disabled on both sides — see the
  parameter-mapping comment in the test). It is NEVER imported by `lib/`
  and never ships in the app's runtime path. Agreement is a math-consistency
  signal, never fiqh proof (D6 §8.2).

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
