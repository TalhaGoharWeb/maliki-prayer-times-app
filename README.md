<p align="center">
  <img src="assets/branding/logo_full_text.jpg" width="220" alt="Maliki Prayer Times logo" />
</p>

<h1 align="center">Maliki Prayer Times</h1>

<p align="center">
  A prayer-times app for Android and iOS that implements <b>Maliki fiqh</b> — not a generic preset relabelled.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter" alt="Flutter 3.47.5" />
  <img src="https://img.shields.io/badge/tests-141%2F141-brightgreen" alt="141/141 tests" />
  <img src="https://img.shields.io/badge/version-1.1.0+2-blue" alt="v1.1.0+2" />
  <img src="https://img.shields.io/badge/offline-first-success" alt="offline-first" />
  <img src="https://img.shields.io/badge/license-see%20ATTRIBUTION.md-lightgrey" alt="licenses" />
</p>

---

## Why this app exists

Most prayer-time apps compute generic astronomical times and slap a madhhab label on a settings preset.
This app was built the other way round: first a full evidence-based research blueprint of **Maliki prayer-time
rules** — classical texts, then Mauritanian scholarship, then the wider Maliki world — and only then an engine,
a validated calculation profile, and an app around it.

The headline Maliki rules the engine implements:

| Prayer | Ikhtiyari (preferred) | Daruri (necessity) |
|---|---|---|
| Fajr | True dawn | Until isfar (clear light) → sunrise |
| Dhuhr | Just after transit | Until first mithl (shadow = 1×) |
| Asr | **First mithl** — the mashhur Maliki start | Until sunset |
| Maghrib | Sunset, narrow window (~15–20 min) | Until red-twilight disappearance (al-Baji's view noted as internal disagreement) |
| Isha | Disappearance of the **red** shafaq | Until first third of night (Ibn Habib: midnight) → dawn |

Every prayer therefore shows **two times** in the app — the preferred window and the necessity window —
instead of a single line. Combining (jamʿ) follows the Maliki taqdim-only basis via al-Qarafi's
"two shared times" from *al-Dhakhira*.

## Calculation profiles

| Profile | Fajr | Isha | Asr | Basis |
|---|---|---|---|---|
| **Maliki — MWL West Africa** (default) | 18° | 17° (red twilight) | factor 1 | 1986 MWL Fiqh Council decision (signatory: Mauritanian scholar Ould ʿAdud) |
| Maliki — Egyptian (19.5/17.5) | 19.5° | 17.5° | factor 1 | Egyptian General Authority of Survey convention |
| Maliki — UOIF (12/12) | 12° | 12° | factor 1 | UOIF (France) convention |

Angles are astronomical conventions, not fiqh rulings.

## Features

- **Two-tier timetable** — ikhtiyari and daruri bands for every prayer, with plain-language explanations
- **Live Qibla compass** — sensor-driven dial (accelerometer + magnetometer) with distance, rhumb-line bearing,
  true-north offset, 16-wind compass point, and a computed sun-alignment time with reminder
- **Smart location** — device GPS with reverse-geocoded place names, manual coordinates, and one-tap
  historic Maliki cities (Fez, Cairo, Kairouan, Cordoba, Nouakchott)
- **Monthly timetable** — full-month grid with Hijri dates and a per-day detail sheet
- **4 languages, full RTL** — اردو (Nafees Nastaleeq), العربية (Amiri), English & Français (Source Serif 4 + Manrope)
- **Notifications** — per-prayer reminders, rescheduled automatically on any settings/location change
- **Per-prayer adjustments** (±60 min) and ihtiyat toggles to match your local mosque
- **Profile comparison** — side-by-side times across calculation profiles
- **In-app updates** — checks GitHub releases for newer builds
- **Honest by design** — no invented figures (no magnetic declination without a geomagnetic model, no
  unverified quote attributions), approximate Hijri clearly labelled, best-effort delivery notes

## Screenshots

| Home (Urdu) | Monthly | Qibla |
|---|---|---|
| Two-tier bands, Hijri date on the hero card | Full-month grid, Hijri subtitles | Live compass, distance & bearing |

*(Screenshots from the 1.1.0 test builds.)*

## Tech

- **Flutter 3.47.5** (Dart), Android + iOS from one codebase
- **Pure-Dart calculation engine** (`lib/engine/`) — fiqh rules (`lib/fiqh/`) kept strictly separate from astronomy
- **Offline-first** — zero network calls for core features; free-first, no paid APIs anywhere
- **State** — SharedPreferences persistence; notifications via `flutter_local_notifications`
- Fonts & plugins are license-checked before adoption — see [ATTRIBUTION.md](ATTRIBUTION.md)

### Project structure

```
lib/
├── engine/        # pure-Dart astronomy (solar position, prayer angles)
├── fiqh/          # Maliki rule mapping (two-tier bands, combining basis)
├── l10n/          # ARB sources: en / ur / ar / fr
├── models/        # SavedLocation, calculation profiles
├── screens/       # home, monthly, qibla, profiles, location, settings, splash
├── services/      # location, notifications, compass, update check, settings
└── utils/         # Hijri dates, qibla math, solar scan, fonts, digits
test/              # 141 widget + unit tests
```

## Getting started

```bash
# prerequisites: Flutter SDK 3.47.5, Java 21
flutter pub get
flutter gen-l10n
flutter analyze        # must be clean
flutter test           # 141/141 green

# Android
flutter build apk --release

# iOS
flutter build ipa --release
```

> **Build-env notes (sandbox):** `JAVA_HOME` must point at a full JDK 21 (not a JRE);
> `GRADLE_USER_HOME` and `-Djava.net.preferIPv4Stack=true` are set for proxied egress.
> Never run two `flutter test` in this repo concurrently, and never run bare `dart format`
> (the repo keeps a hand style — read-only check: `dart format --output=none --set-exit-if-changed`).

## Research basis

The app's rules come from a two-pass research program: classical Maliki texts (*Mukhtasar Khalil*,
*Risala*, *Aqrab al-Masalik*, commentaries of Dardir/Dasuqi/Hattab — verified against printed editions),
then Mauritanian scholarship (al-Shinqiti's *Adwa' al-Bayan*, bin Bayyah, Ould ʿAdud and the 1986 MWL
decision). Gaps are declared, not filled: no invented citations, no merged incompatible opinions, no
regional practice presented as universal. The full blueprint (12 deliverables) is maintained alongside
the project.

## Roadmap

- [ ] Adhan audio for notifications
- [ ] Scholarly review of the calculation profiles (the 18-question checklist)
- [ ] iOS release build & TestFlight
- [ ] Travel mode / multiple saved locations
- [ ] Mosque-timetable verification helper
- [ ] Google Play release

## Credits

Developed by **Muhammad Talha Bin Farid Al Maliki** — **Maliki Fiqh Subcontinent**.

Fonts: Nafees Nastaleeq (CRULP), Amiri / Source Serif 4 / Manrope (OFL) — notices ship with the app.
Full third-party attributions in [ATTRIBUTION.md](ATTRIBUTION.md).

---

*The calculation profiles document their source conventions. For religious practice, consult
qualified Maliki scholars in your region.*
