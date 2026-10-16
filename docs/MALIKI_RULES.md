# Maliki Rules — Scholarly Evidence Registry

Evidence registry for the Maliki positions implemented (or intentionally not
implemented) in this app. Source references are recorded **exactly as found
in the repo's research deliverables** (`~/workspace/goals/
maliki-prayer-times-app-for-android-and-ios/files/`, documents 01–13) —
they are secondhand via the quoting sites those documents cite and have not
been independently verified against print editions of the classical works.

Review status: none of the rules below has been reviewed by a qualified
Maliki scholar. The `Review status` column records this factually per row.

The calculation angles (18°/17°, 19.5°/17.5°, 12°/12°) are astronomical
conventions estimating observable legal signs (true dawn, red-twilight
disappearance) — they are not fiqh rulings themselves. See
`docs/CALCULATION_METHODS.md` for how the engine computes times.

## Boundary rules

| Rule ID | Boundary | Arabic term | Selected Maliki position | Recognized alternatives (not defaults) | Source as recorded in research docs (secondhand) | Code location | Status | Review status |
|---|---|---|---|---|---|---|---|---|
| R-SUBH-01 | Subh begins | الفجر الصادق | True dawn; estimated by 18° solar depression (MWL 1986) | 19.5° Egyptian, 12° UOIF (implemented as named profiles) | MWL Islamic Fiqh Council 9th session 1986 (French translation, "verified live 2026-10-15" per doc 07:24); al-hamdoulillah.com Nouakchott timetable (MWL 18/17 stated) | `prayer_profile.dart`; `prayer_times.dart` Fajr event | implemented | unreviewed |
| R-SUBH-02 | Subh ikhtiyari end | الإسفار | Isfar — informational band, no clock time ("no fiqh source gives isfar as a clock offset", doc 07:91) | Minority view (al-Shinqiti noted): Subh has no daruri at all (doc 07:103) | al-Dardir, *Aqrab al-Masalik* «للاسفار البين» (via malikifiqhqa.com, "verified live" per doc 07:30); al-Shinqiti, *Adwa' al-Bayan* ("مشهور مذهب مالك", via majles.alukah.net) | `maliki_rules.dart` Subh band | implemented (text only) | unreviewed |
| R-SUBH-03 | Subh daruri end | — | Sunrise | — | *Risala* (via doc 07:103: isfar = ikhtiyari, sunrise = daruri) | `maliki_rules.dart` Subh daruri; `prayer_times.dart` sunrise | implemented | unreviewed |
| R-DHUHR-01 | Dhuhr begins | الزوال | Solar transit; +1 min ihtiyat as a user-toggleable operational convention, not part of the definition (spec §4.2) | — | *Risala* 8.2a; Khalil «من زوال الشمس» (doc 03:111-113) | `prayer_times.dart` dhuhrUtc; `settings_service.dart` ihtiyat toggle | implemented | unreviewed |
| R-DHUHR-02 | Dhuhr ikhtiyari end / Asr begins | المثل الأول | First mithl: shadow = object length + noon shadow, noon shadow excluded «بغير ظل الزوال» | Hanafi factor 2 — explicitly excluded as non-Maliki (doc 03:35) | Khalil «لآخر القامة بغير ظل الزوال» (doc 03:29-33); *Risala* 8.2e | `prayer_times.dart` Asr altitude; profile `asrShadowFactor: 1.0` | implemented | unreviewed |
| R-ASR-01 | Asr ikhtiyari end | الاصفرار | Isfirar (yellowing of the sun) — informational band | — | *Risala* (Ibn al-Qasim transmission, doc 03:143) | `maliki_rules.dart` Asr band (text only) | implemented (text only) | unreviewed |
| R-MAGHRIB-01 | Maghrib begins | غروب الشمس | Complete disk disappearance; −0.833° depression + optional 1 min ihtiyat | — | *Risala* 8.4; Khalil/Aqrab «والمغرب لغروب الشمس»; MWL 1986 (50′) | `prayer_times.dart` sunset/maghribUtc | implemented | unreviewed |
| R-MAGHRIB-02 | Maghrib mukhtar end | بقدر فعلها بعد شروطها | Narrow ~15–20 min band (practical quantification from malikifiqhqa.com, "not a matn value" — spec §3.5); displayed as raw sunset + 20 min | **al-Baji** and many of the School: mukhtar extends to red-twilight disappearance (*Muwatta'*, Muslim — doc 07 §3.5) — not implemented | *Risala* 8.4b commentary; malikifiqhqa.com (15–20 min, "verified live") | `prayer_times.dart` maghribPreferredEnd; `maliki_rules.dart` Maghrib band | implemented (mashhur only); al-Baji alternative not implemented | unreviewed |
| R-MAGHRIB-03 | Maghrib daruri end | — | True dawn (Khalil/Aqrab «وللفجر في العشاءين», spec §3.5) | — | Rule matrix 04:131 | `maliki_rules.dart` Maghrib daruri (informational) | implemented (text only) | unreviewed |
| R-ISHA-01 | Isha begins | الشفق الأحمر | Disappearance of the **red** twilight; whiteness does not count | — | *Aqrab* «من غروب الشفق الأحمر»; *Risala* 8.5b (hadith "The twilight is the redness"); MWL 1986 (17°) | profile `ishaAngle`; `prayer_times.dart` Isha event | implemented | unreviewed |
| R-ISHA-02 | Isha ikhtiyari end | الثلث الأول | First third of the night, night = sunset→true dawn (spec §3.7) | **Ibn Habib**: to midnight (Muslim 612; *Risala* 8.5c commentary) — implemented as a labeled alternative | *Aqrab* «للثلث الأول»; malikifiqhqa ("one third of the time between sunset and true dawn", doc 04:95) | `prayer_times.dart` ishaPreferredEnd; variant ishaMidnightVariant; `maliki_rules.dart` Isha band | implemented (both) | unreviewed |
| R-ISHA-03 | Isha/Maghrib daruri end | — | True dawn; final four rak'as = shared Maghrib+Isha window (*Risala* 8.6) | — | Rule matrix 04:132; doc 03:166 | `maliki_rules.dart` (informational) | implemented (text only) | unreviewed |
| R-HIGHLAT-01 | High-latitude rule | — | user-chosen fallback method (default middle-of-night; one-seventh / angle-based / nearest-day per D5 §3.7 math) estimates Fajr/Isha from the night frame when twilight angles are unreachable; when the sun never reaches the horizon (polar day/night) the engine returns a typed no-solution (honest empty state, never fabricated times) unless the user explicitly chose nearest-day borrowing; the active method is named in the UI | MWL 1983 three-category logic; `seventhOfTheNight` above 48° (doc 07:32 — the latitude-gated MWL variant is not implemented; one-seventh is offered as a user-chosen convention instead) | MWL council 3rd session 1983 opinion (French translation "verified live"; Ould 'Adud signatory — doc 07:32) | `prayer_times.dart` fallback block | implemented (partial) | unreviewed |

## Notes

- **Secondhand sources:** all matn quotations above rest on the research
  docs' quoting sites (doc 07:14), not on printed editions consulted in
  person. No page numbers are claimed because the research docs provide none.
- **Anchor rule (E-05):** the fiqh night interval is measured from the raw
  solar sunset, never from the ihtiyat-shifted displayed Maghrib — fiqh
  boundaries must not move when the user toggles the operational ihtiyat
  convention.
- **Gaps recorded (not defects):** Moonsighting Committee 18°/18° profile and
  user custom angles (doc 07 §3.3/§3.5); al-Baji extended-Maghrib view;
  `seventhOfTheNight` above 48°.
- Doc 07 §6 lists 14 open review questions (including Q14 on the
  high-latitude default) — unanswered, as expected before scholarly review.
