# Calculation changelog

A versioned record of what changed in the prayer-time engine and profiles.
Whenever a release changes a computed time — or the frame a time is shown
in — it gets an entry here, so a time that moves between versions is
explainable from inside this file.

The in-app mirror of this file is rendered by
`lib/screens/calculation_changelog_screen.dart` from hardcoded Dart data.
Keep both in sync: `test/calculation_changelog_test.dart` asserts the
screen names the same versions and parameters as this file.

**Integrity rule (program Part A §2.3 / Part B rule 2):** angles and other
operational parameters are institutional or software conventions — they are
never presented as Maliki rulings. The status column marks every row
`fiqh-derived` (a Maliki legal rule with attested textual basis) or
`convention` (an institutional/software convention approximating a legal
sign or keeping computation deterministic).

## v1.2.0+5 (2026-10-16)

Baseline entry: the first recorded method state, measured from
`docs/CALCULATION_METHODS.md` and the engine as implemented. Every later
change is measured against this entry.

| parameter | value | status | changed-since |
|---|---|---|---|
| Fajr angle | 18° solar depression (MWL Islamic Fiqh Council, 1986) | convention | v1.2.0+5 (baseline) |
| Isha angle | 17° solar depression (red twilight; MWL 1986) | convention | v1.2.0+5 (baseline) |
| Asr shadow factor | 1 — first mithl, zawal shadow excluded (Maliki mashhur; Mukhtasar Khalil) | fiqh-derived | v1.2.0+5 (baseline) |
| Sunrise/sunset horizon | −0.833° solar depression (upper limb + refraction) | convention | v1.2.0+5 (baseline) |
| Ihtiyat policy | +1 min on Dhuhr, +1 min on Maghrib; user-toggleable in Settings; fiqh night boundaries stay anchored on the raw solar sunset | convention | v1.2.0+5 (baseline) |
| Rounding | every solar instant rounded to the nearest minute after the timezone offset is applied; manual adjustments are whole minutes applied after rounding | convention | v1.2.0+5 (baseline) |
| High-latitude fallback | middle-of-night estimates when a solar event has no solution (polar coherence: whole day on the estimate path when the sun never reaches the horizon); flagged in the UI | convention | v1.2.0+5 (baseline) |
| Time-zone frame | all displayed times use the device timezone; manual far-away locations are approximate (documented limitation) | convention | v1.2.0+5 (baseline) |

## v1.3.0+6 (2026-10-16)

Released: Trust & Global Usefulness Improvement Program, Phases 2–5 —
location exactness, profiles & regions, teaching section, high-latitude
honesty (Phase 1 foundations shipped earlier in the program and are recorded
through the methodology/review screens, not this engine table).

| parameter | value | status | changed-since |
|---|---|---|---|
| Time-zone frame | displayed times render in the location's IANA zone: the stored zone for manual locations (chosen in the zone picker, defaulting to the device zone), the device zone for GPS-derived locations; offsets resolved per date so DST transitions are correct per date; bundled tz database latest_all (full IANA coverage, 598 zones, tzdata 2026e), offline-first | convention | v1.3.0+6 |
| Sunrise/sunset horizon | −0.833° solar depression (upper limb + refraction) plus the elevation dip correction 0.0293×√h (h in meters) when a per-location elevation is set; optional input, unset = sea-level horizon | convention | v1.3.0+6 |
| Calculation profiles | new "Maliki — Morocco Habous" preset added (Fajr 19°, Isha 17°): institutional preset, NOT a fiqh ruling; methodology unpublished (D1). No engine math changed | convention | v1.3.0+6 |
| Profile evidence badges | every profile shows per-parameter evidence status (D9): MWL West Africa 18/17 = provisional convention (default); Habous 19/17 and Egyptian 19.5/17.5 = institutional preset; UOIF 12/12 = disputed (12° vs claimed 15°); Asr factor 1 = fiqh-derived on all profiles | convention | v1.3.0+6 |
| Regional auto-adapt | "Recommended settings": a one-time, dismissible dialog suggests the regional preset matching the detected location (Maghreb → Habous; West Africa → MWL West Africa; Egypt → Egyptian; France → UOIF with its disputed badge); the user confirms — nothing switches silently | convention | v1.3.0+6 |
| High-latitude fallback | user-chosen method (default: middle-of-night, per adhan `recommended()`): middle-of-night / one-seventh / angle-based estimates from the night frame (D5 §3.7 math), or nearest-day borrowing with the source date shown; no night frame (polar day/night) → typed NoSolution with an honest empty state, never fabricated times; the old noon±6 synthetic-horizon path is deleted; the active method is named wherever fallback times appear, with a change affordance | convention | v1.3.0+6 |
