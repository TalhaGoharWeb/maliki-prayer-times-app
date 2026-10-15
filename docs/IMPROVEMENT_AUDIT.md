# Improvement Audit — Maliki Prayer Times

- **Repo:** `~/workspace/maliki-prayer-times-app` (local `master`)
- **Audit date:** 2026-10-16
- **Audited commit:** `f983678` ("Release v1.1.1+3")
- **Baseline at audit start:** `flutter analyze` clean (0 issues); `flutter test` 144/144 passing at `830bd31`;
  one test red at `f983678` (I-01, fixed in `9b96f1a`)
- **Toolchain:** Flutter 3.47.5 · Dart 3.13.4
- **Method:** three parallel read-only audits (calculation+fiqh, reliability+architecture+privacy+performance,
  UI+i18n+a11y+docs). Full reports: `~/workspace/maliki-audit/` (calc-fiqh-findings.md,
  reliability-findings.md, ui-i18n-a11y-findings.md). Numeric claims marked **[N]** were verified with
  scratch engine scripts; **[R]** = verified by code reading; **[H]** = hypothesis.

**Binding constraints for all fixes:** no "PROPOSED — pending scholarly review" (or variants) in app UI or
README; light mode only; keep the Stitch design system (#003527 / #E5FFF6 / gold; Amiri + Nafees Nastaleeq +
Source Serif 4 + Manrope); commits on local master only (no pushes without user approval); no bare
`dart format`; no paid APIs; no new network dependencies on the critical path; license-check every new
dependency (permissive only) and record in ATTRIBUTION.md; never invent citations, quotations, or scholarly
endorsements.

---

## P0 — release-blocking

| ID | Category | Issue | Evidence | User impact | Root cause | Recommended fix | Verification | Status |
|---|---|---|---|---|---|---|---|---|
| E-01 | Calculation | **Polar-night chimera:** at ~67.4°–84.6°N in deep winter the app shows Fajr *after* "sunrise" and Isha *before* Maghrib [N] | `lib/engine/prayer_times.dart:283-347`; trace 80°N 21-Dec-2026: fajr 08:03 > sunrise 05:58, isha 15:24 < maghrib 17:59 | User could pray at wrong times; timetable is incoherent | Fallback applied per-event: real twilight crossings (sun max altitude in −18°..−0.833°) mixed with synthetic `noon±6` sunrise/sunset | When sunrise/sunset is null, force the whole day onto the coherent estimate path (treat Fajr/Isha as fallback too) | Engine tests at 70°N/80°N on 21 Dec asserting ordering + `highLatitudeFallback==true` | Open |
| I-01 | Tests | `locale_test.dart` asserted version `'1.1.0'` after the v1.1.1 bump — suite red at HEAD [R] | `test/locale_test.dart:567` vs `lib/utils/app_info.dart:4` | Blocks any green-build claim | Version bump commit didn't update the test | Assert against `kAppVersion` const | `flutter test test/locale_test.dart` | **Fixed in `9b96f1a`** |

## P1 — major reliability / correctness / accessibility

| ID | Category | Issue | Evidence | User impact | Root cause | Recommended fix | Verification | Status |
|---|---|---|---|---|---|---|---|---|
| E-02 | Calculation | Monthly grid, tomorrow's times, and notifications use **today's** UTC offset — 1h off across DST transitions [R] | `main.dart:335` → `monthly_screen.dart:63-66`; `home_screen.dart:138-141`; `notification_service.dart:522,541` | Wrong displayed/scheduled times on DST-transition days | Fixed `DateTime.now().timeZoneOffset` passed for all dates | Per-date offset: `DateTime(y,m,d).timeZoneOffset` | Test with fake per-date offset fn; check October grid in DST zone | Open |
| F-01 | Fiqh docs | README "headline Maliki rules" table misfiles every prayer's tier and misstates Maghrib's daruri end as red-twilight disappearance (al-Baji) — matrix+spec+code say daruri = true dawn [R] | `README.md:29-37` vs rule matrix `04:126-132`, spec §3.5 | User-facing docs contradict the app's own researched positions | Table written from the wrong columns | Rewrite with Beginning / Ikhtiyari end / Daruri end columns per the matrix | Row-by-row diff vs matrix | Open |
| E-03 | UI honesty | Home screen shows no high-latitude estimate notice (engine contract `prayer_times.dart:280-281` honored only on Monthly) [R] | `home_screen.dart` has no `highLatitudeFallback` reference; monthly does (`monthly_screen.dart:167-169`) | Misleading times shown with no warning on the main screen | Notice never wired into home | Reuse the monthly notice pattern on home when `times.highLatitudeFallback` | Widget test with forced fallback day | Open |
| REL-01 | Reliability | Monthly grid + day sheet ignore per-prayer adjustments — two timetables for the same day [R] | `monthly_screen.dart:62-70`; zero `adjustedTime` references in file | User's mosque adjustments silently missing on Monthly tab | `_loadMonth` stores raw engine output | Apply `SettingsService.adjustedTime` per prayer when building `_days` | Test: +15 Fajr adjustment reflected in cell + sheet | Open |
| REL-02 | Reliability | Monthly goes stale when profile/ihtiyat change while open — no `didUpdateWidget` [R] | `monthly_screen.dart` (grep: no `didUpdateWidget` in lib/) | Wrong profile's times displayed | `_days` computed only in initState/_shiftMonth | Override `didUpdateWidget`, compare profile/offset, reload | Widget test: parent rebuild with new profile | Open |
| REL-03 | Notifications | **No reboot rescheduling** — no `RECEIVE_BOOT_COMPLETED`/receiver; all notifications lost on restart until next app open [R] | `AndroidManifest.xml:1-7`; grep BOOT_COMPLETED empty | Phone restarted overnight → Fajr missed silently | Schedules don't survive reboot | Add permission + native `BroadcastReceiver` re-running `rescheduleAll` from persisted prefs | Device reboot test; unit-test input reconstruction | Open |
| REL-04 | Location | GPS fix has **no timeout** — indefinite spinner, no cancel path [R] | `location_service.dart:74-84` (`getCurrentPosition`, no `timeLimit`); `location_screen.dart:114-122` | Indoors: permanent spinner, can't fall back to manual entry | Missing `timeLimit` | `timeLimit: 20–30s` → existing `positionUnknown` path | Never-completing GpsReader → completes with `positionUnknown` | Open |
| I-02 | Accessibility | High-latitude estimate marker contrast **2.06:1** — fails WCAG AA [R] | `monthly_screen.dart:503-508` (`#CEAC63` on `#E5FFF6`) | The honesty flag is invisible to low-vision users | Too-light gold on mint | Darker marker (e.g. `#5B4301`) | Recomputed ratio ≥4.5:1 | Open |
| I-04 | Tests | Contrast test group tests the **wrong color scheme** (`fromSeed(Colors.teal)`, hardcoded dial colors) — passes vacuously; how I-02 slipped through [R] | `test/accessibility_test.dart:520-563`; `fonts.dart:140-141` | False confidence in contrast coverage | Test doesn't use `AppFonts.lightScheme` | Rebuild test on the real scheme + real painter colors | Test fails on I-02 until fixed | Open |

## P2 — important usability / maintainability

| ID | Category | Issue | Evidence | Status |
|---|---|---|---|---|
| F-02 | Fiqh docs | README attributes Ould ʿAdud's signatory role to the 1986 decision; research docs say 1983 opinion [R] | `README.md:42` vs research doc 07:32,45 | Open |
| E-04 | Calculation | Maghrib preferred-band end is sunset+21 min; text says "15–20 minutes after sunset" [R+N] | `prayer_times.dart:306,376`; `maliki_rules.dart:111-114` | Open |
| E-05 | Calculation | Inconsistent ihtiyat anchors: `ishaPreferredEnd` uses maghribUtc (+1 min), `ishaMidnightVariant` uses raw sunsetUtc; Dhuhr/Asr daruri "sunset" displayed as sunset+1 [R] | `prayer_times.dart:349,370-373`; `maliki_rules.dart:89-94` | Open |
| E-06 | Fiqh text | Asr band text claims isfirar "shown approximately"; no estimate is shown anywhere [R] | ARB `asrPreferredInfo`; `maliki_rules.dart:97-99` | Open |
| REL-05 | Reliability | Reverse-geocode has no timeout and **blocks persisting** the GPS fix [R] | `location_service.dart:93-111,296-301` | Open |
| REL-06 | Notifications | Sun-reminder "Remind me" after today's alignment passed schedules a past instant → fires immediately [R] | `qibla_screen.dart:608-647`; `notification_service.dart:356-384` | Open |
| REL-07 | Reliability | `useManualLocation` doesn't reset `errorKind` → stale error banner after successful save [R] | `location_service.dart:312-318` | Open |
| REL-08 | Performance | Qibla screen `setState`s on every raw sensor event (up to ~100Hz) with heavy build [R] | `qibla_screen.dart:62-65,86-100,278` | Open |
| REL-09 | Limitation | Device-timezone frame for far-away manual locations: shifted wall labels, device civil-day boundary, DST effects. Internally consistent; documented in code. No fix within constraints (needs offline IANA lookup — product decision) [R] | `main.dart:~330`; `home_screen.dart:50-55` | Documented; no fix |
| I-05 | Docs | README stale: version badge `1.1.0+2` (pubspec `1.1.1+3`), test counts 141 vs 144 (actual 144) [R] | `README.md:13-15,104,116` | Open |
| I-06 | Docs | README "Screenshots" section has zero images [R] | `README.md:85-91` | Open |
| I-07 | i18n | Arabic-Indic digit inconsistency in `ar`: band texts embed Western digits; monthly sheet Hijri not digit-localized while home is [R] | `band_texts.dart:15-16`; `monthly_screen.dart:162` | Open |
| I-08 | i18n honesty | Day-detail sheet shows Hijri date without the approximation qualifier [R] | `monthly_screen.dart:160-166` | Open |
| I-09 | UI honesty | `Icons.verified` + "Standard Maliki calculation applied" chip risks implying scholarly verification [R] | `monthly_screen.dart:414-441` | Open |

## P3 — polish / hardening

| ID | Category | Issue | Evidence | Status |
|---|---|---|---|---|
| E-07 | Validation | `"NaN"` passes manual coordinate validation; engine silently collapses all times to solar noon [R+N] | `location_screen.dart:157-176` | Open |
| REL-10 | Performance | Root rebuilds entire MaterialApp on settings/location change — negligible today | `main.dart:117-119` | Open (optional) |
| REL-11 | Privacy | `ACCESS_FINE_LOCATION` exceeds need; coarse changes times by seconds — **product decision** | `AndroidManifest.xml:1-2` | Awaiting user call |
| REL-12 | Persistence | No schema-version key in persisted blobs — safe while evolution is additive | `saved_location.dart`, `settings_service.dart` | Open |
| REL-13 | Reliability | Startup service load unguarded — splash could hang on platform-channel failure **[H]** | `main.dart:37-40` | Open |
| REL-14 | Release | `USE_EXACT_ALARM` needs Play Console declaration with justification | `AndroidManifest.xml:5-6` | Open (release) |
| REL-15 | Reliability | Theoretical reschedule-before-init in `_NotificationBootstrap` **[H]** — no production path | `main.dart:470-481` | Open |
| REL-16 | Notifications | Sun-reminder card forgets persisted reminder across restarts; no cancel affordance [R] | `qibla_screen.dart:606` | Open |
| I-10 | Accessibility | Top-bar location chip tap target ~32px < 48px guideline [R] | `main.dart:417` | Open |
| I-11 | i18n | `'Geodesic Hub'` hardcoded English title — **needs user call** (branding vs localizable) | `location_screen.dart:222` | Awaiting user call |
| I-12 | i18n | Qibla cardinal letters hardcoded Latin in all locales | `qibla_screen.dart:772` | Open |
| I-13 | i18n | Static-fallback dial semantics not digit-localized in `ar` | `qibla_screen.dart:343` | Open |
| I-14 | i18n | `fr` keeps `.` decimal separator (French uses `,`) | `qibla_screen.dart:119-132` | Open |
| I-15 | Accessibility | `badgeLabel` 0.08em letter-spacing breaks Arabic-script joining in ur/ar badges | `fonts.dart:127-131` | Open |
| I-16 | Maintainability | Magic-number color duplications of scheme values | `home_screen.dart:478` etc. | Open |
| I-17 | i18n | Raw Western digits in `ar`: stepper value, reminder-offset picker | `settings_screen.dart:447-451` etc. | Open |
| I-18 | Accessibility | `.toUpperCase()` without locale on ~15 localized eyebrows | various | Open |
| I-19 | RTL | Non-directional `Alignment.centerLeft/Right` spots don't mirror in RTL | `qibla_screen.dart:143` etc. | Open |

## Research-documented gaps (not defects)

- **G-01:** Moonsighting Committee 18°/18° profile and user custom angles (research doc 07 §3.3/§3.5) — not implemented.
- **G-02:** al-Baji extended-Maghrib view (doc 07 §3.5) — not implemented; default remains the mashhur narrow band.
- **G-03:** `seventhOfTheNight` above 48° (doc 07:32) — `HighLatitudeRule` has only `middleOfNight`.

## Needs the user's decision (not for agents to decide unilaterally)

1. **ATTRIBUTION.md "Status" section** still contains the verbatim removed phrase "PROPOSED — pending scholarly review"
   (removal commits touched UI/README only). Reword or remove?
2. **`'Geodesic Hub'`** hardcoded title — intentional branding or should it be localized?
3. **Coarse-only location** (drop `ACCESS_FINE_LOCATION`) — accept the smaller privacy ask?
4. **Screenshots for README** — capture real ones from the 1.1.1 build or drop the section?

## Verification log

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | 0 issues (at `830bd31`; re-run after waves) |
| Unit + widget tests | `flutter test` | 144/144 at `830bd31`; 1 red at `f983678` (I-01) → fixed in `9b96f1a` |
| Release build | `flutter build apk --release` | Last built at `830bd31` (60.2MB); rebuild after waves |
| iOS build | — | Unavailable in this Linux environment — documented, not claimed |
