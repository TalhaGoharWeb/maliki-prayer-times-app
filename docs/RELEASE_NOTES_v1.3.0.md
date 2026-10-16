# Release notes — v1.3.0+6 (2026-10-16)

The Trust & Global Usefulness Improvement Program, phases 1–7. This release
is what the user needs to trust the app: exact times for the user's exact
location, every number traceable to a source, every limit stated honestly.

**Distribution.** This build is cut locally and signed with the production
key. It has **not** been published to GitHub Releases, so the in-app updater
(which checks GitHub releases) will not offer it until a release is
published by the user. No claim here implies publication.

## What's new

- **Trust foundations (Phase 1):** Methodology screen — the full method
  table, every row badged *institutional/software convention* vs
  *fiqh-derived rule*. Review-status data model
  (`proposed`/`reviewed`/`endorsed` + reviewer + date) and an in-app review
  record screen. Exportable scholarly-review packet (the 18-question
  checklist + 8 pass-2 items, Arabic/English/French) for the user's scholar
  outreach. In-app calculation changelog (Settings → Calculation changelog),
  mirroring `docs/CALCULATION_CHANGELOG.md`.
- **Location exactness (Phase 2):** bundled IANA time-zone database; times
  render in the *location's* zone with per-date DST resolution (closes the
  old device-timezone-frame limitation for far-away manual locations).
  Optional per-location elevation input; GPS quality indicator
  (accuracy + updated timestamp); saved places; manual-coordinate range
  validation.
- **Profiles & regions (Phase 3):** new "Maliki — Morocco Habous" profile
  (Fajr 19°, Isha 17°) with per-parameter evidence badges on every profile.
  "Recommended settings" auto-adapt: a one-time dismissible dialog suggests
  the regional preset for the detected location — the user confirms; nothing
  switches silently.
- **Teaching section (Phase 4):** the Learn section — Maliki definitions of
  the five prayers with classical Arabic passages, the 18° classical
  pedigree, dawn-observation studies summary, FAQ, glossary — in all four
  locales, full RTL.
- **High-latitude honesty (Phase 5):** user-chosen fallback method
  (default: middle-of-night, per adhan `recommended()`), each labeled a
  convention, never a Maliki ruling. Polar day/night → typed `NoSolution`
  with an honest empty state; the app never fabricates plausible times. The
  old noon±6 synthetic-horizon path is deleted.
- **Verification hardening (Phase 6):** golden test vectors from the
  calculation spec (Nouakchott, Fez equinox/solstices, Tromsø
  polar-day/persistent-twilight), cross-validation against `adhan_dart` in
  CI, and fiqh regression tests for every verified rule.

## Calculation changes — disclosed honestly

| Change | What it does | Status |
|---|---|---|
| IANA tz database bundled (`package:timezone` **latest_all**: 598 zones, tzdata 2026e, offline-first) | Displayed times now render in the location's IANA zone (stored zone for manual locations, device zone for GPS); offsets resolved per date so DST is correct per date. ≤ v1.2.0+5 used the device timezone for every location. | convention — deviates from the plan's first draft (`latest_10y`, a 345-zone subset), because that subset drops real zones including `Africa/Nouakchott`, one of the app's own preset cities; ~1 MB in a ~73 MB APK |
| "Maliki — Morocco Habous" profile added | Fajr 19°, Isha 17°; the closest Maliki-majority institutional preset (methodology unpublished — D1). **Not a fiqh ruling.** No engine math changed. | institutional convention |
| Fallback chooser + `NoSolution` | User-chosen high-latitude fallback; no night frame (polar day/night) → honest empty state, never fabricated times; noon±6 synthetic path deleted | software convention |
| Elevation dip correction | `0.0293 × √h` added to the −0.833° sunrise/sunset horizon when a per-location elevation is set; unset = sea-level horizon. Twilight angles and the Asr shadow rule are unaffected (they reference the geometric horizon). | astronomical convention |
| Adjustment chips | Every ihtiyat minute, rounding step, and manual per-prayer adjustment now appears as an explicit chip on the affected time. Nothing is silently adjusted. | transparency, no math change |

### What did not change (Maliki fiqh)

Asr factor 1 (first mithl, zawal shadow excluded); Maghrib narrow preferred
window with the true-dawn daruri end; Isha tied to the red shafaq with 17°
as the operational convention; the +1 min Dhuhr / +1 min Maghrib ihtiyat
policy; informational (non-computed) Isfar/Isfirar bands.

## Limits — stated, not hidden

- **No qualified scholarly review yet.** This is the single biggest
  remaining trust gap: nothing in this release is scholarly-reviewed,
  endorsed, or approved. The app shows method, sources, and provisional
  status — never "verified/endorsed/approved" wording.
- GPS-derived locations use the device zone: the app does not do
  lat/lon → time-zone reverse-geocoding (only manual locations get an
  explicit zone picker).
- Time-zone data is frozen at tzdata 2026e: future zone-law changes need a
  data update; DST history far outside 2026e's coverage is not guaranteed.
- Hijri dates remain approximate and are labeled as such.

## Integrity notes (program rules, binding on this release)

- Angles and operational parameters (18°/17°, −0.833°, fallback methods)
  are never presented as Maliki rulings — in code comments, UI strings, or
  these notes.
- No new fiqh was invented in code; unresolved questions stay in the
  scholarly review register (D7).
- Light mode only; the approved Stitch design system; Urdu-first
  (Nafees Nastaleeq display, Naskh inputs, full RTL).
- Free-first: no paid APIs; every dependency license-checked
  (`adhan_dart` 2.0.1 MIT, recorded in `ATTRIBUTION.md`).
