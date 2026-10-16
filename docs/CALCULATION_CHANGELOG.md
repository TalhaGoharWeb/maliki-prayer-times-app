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
