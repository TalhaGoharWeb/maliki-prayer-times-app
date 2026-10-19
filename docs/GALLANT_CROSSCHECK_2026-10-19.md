# Gallant Manual Cross-Check — 2026-10-19

Cross-check of two user-supplied knowledge-base sections against the app's
existing logic. **No code was changed on the basis of this report.**

Source for both sections: Mathieu Gallant, *Students' Guide to Maliki
Fiqh* — a contemporary English manual, **not** a primary classical Arabic
text. It is treated here as a secondary source; none of its content is
presented as a verified classical ruling, and the D7 scholarly review
remains outstanding throughout.

- Section 2: Prayer Times (Ch. 2, last update 2024-04-19)
- Section 25: Joining Prayers (Ch. 2, last update 2024-06-16)

Related work (same date): §§14 and 24 of the same manual were used to
engineering-verify rules QH-101, QH-102, QH-108, QH-109 in
`lib/fiqh/qada_rules.dart` (secondary-source status recorded per rule).

---

## 1. §2 (Prayer Times) vs `docs/MALIKI_RULES.md`

### Agreements

| # | Manual (§2) | App registry | Verdict |
|---|---|---|---|
| 1 | Every one of the five prayers has a first (mukhtaar) and a second (daruurii) time | All five prayers carry ikhtiyari + daruri boundaries | AGREE |
| 2 | Zuhr's first time ends / Asr's begins at the **first mithl**: shadow = object height, noon shadow excluded | R-DHUHR-02: first mithl, «بغير ظل الزوال» | AGREE |
| 3 | Maghrib's first time lasts only the time to perform it after fulfilling its conditions (adhaan + iqaamah); cited shaykhs quantify ~15–25 min | R-MAGHRIB-02: narrow ~15–20 min band, labeled "not a matn value" | AGREE |
| 4 | Isha's first time begins at the disappearance of the **red** (and yellow) twilight; whiteness does not count | R-ISHA-01: red twilight, «الشفق الأحمر» | AGREE |
| 5 | Isha's first time ends at the end of the **first third of the night** | R-ISHA-02: «الثلث الأول» | AGREE |
| 6 | Maghrib and Isha daruri times end at true dawn | R-MAGHRIB-03 / R-ISHA-03 | AGREE |
| 7 | Subh begins at **true dawn** (broad white band on the eastern horizon; false dawn excluded) | R-SUBH-01: الفجر الصادق | AGREE |
| 8 | Subh's first time ends at **isfar** (stars masked, faces distinguishable) — informational, no clock time | R-SUBH-02: isfar as informational band, "no fiqh source gives isfar as a clock offset" | AGREE |
| 9 | Subh's daruri time ends at sunrise | R-SUBH-03 | AGREE |
| 10 | A prayer counts as adaa' if one rak'ah is completed before the time exits (first or second time) | QH-001 («والكل أداء», primary-text verified) | AGREE |
| 11 | Asr's first time ends at **isfirar** (yellowing of sunlight) | R-ASR-01: isfirar informational band | AGREE |
| 12 | The 10 valid reasons for second-time prayer without sin / the 8 that also lift the makeup obligation (menses, lochia, insanity, coma/fainting, childhood, non-sinful intoxication, no water/earth, disbelief) | QH-002 (daruri excuses, matn-verified) and QH-101 exceptions (the 8-item list) | AGREE |

### Observations (not discrepancies)

- **O1 — High-latitude Isha.** §2 (Shaykh Mahmoud, fn. 27) gives a specific
  rule for places where the redness never disappears: borrow the
  sunset→redness-disappearance interval from the nearest place where it
  does disappear. The app instead offers a user-chosen fallback method
  (R-HIGHLAT-01). These are different conventions; the app's approach is
  explicitly a user-chosen convention, so this is a difference of
  convention, not a contradiction of a ruling.
- **O2 — Isha qada' at Subh.** §2 (Shaykhs al-Maghiilii and Zohir): where
  Isha's time is disputed, do qada' of Isha at Subh time — "better to
  perform a prayer whose validity is agreed upon." Not currently among the
  app's fallback options; recorded here as a reference for the scholarly
  review, not as a required change.
- **O3 — Night definition for the third.** §2 measures the night from
  center-disk sunset to true dawn; the app measures from its raw solar
  sunset event (−0.833°). The difference is a few minutes. Noted, not
  flagged as a discrepancy: the manual is secondary and the app's
  definition is its documented spec (§3.7, anchor E-05).
- **O4 — Zawaal definition.** §2 warns against apps using astronomical
  (center-disk) zawaal for Zuhr's beginning; shar'ii zawaal is when the
  entire disk has passed. The app's +1 min ihtiyat convention moves in
  this direction; no change proposed.

### Supporting items for the FAQ record (secondary attributions)

- **F1 — Astronomical calculations.** §2: "It is also permissible to rely
  on … astronomical calculations when they yield certainty." Supports the
  app's existing FAQ position on calculated times (recorded as the
  manual's statement, secondary source).
- **F2 — 18° for Subh.** §2, fn. 34 (attributed to Shaykh Zohir): "It is
  valid to pray Subh when the sun reaches 18 degrees below the horizon —
  even in a place where there is too much light pollution to distinguish
  when dawn actually rises." Supports the app's 18° Fajr convention
  (recorded as a secondary attribution to a named contemporary shaykh,
  not as a classical text).

---

## 2. §25 (Joining Prayers) vs the app's Travel mode

The app's Travel mode guidance (Settings → travel card, `travelJamNote`
in all 4 locales) currently reads, in Urdu:

> جمع: مالکی مذہب میں صرف پہلے وقت میں جمع کرنا جائز ہے (جمع تقدیم) — بارش، بیماری یا سفر کے لیے۔
> ("Jam': in the Maliki madhhab only joining in the first time is
> permitted (jam' taqdim) — for rain, illness or travel.")

### Agreements

- **A1 — Travel jam' is permissible.** §25: travel jam' is "permissible
  but suboptimal" (mashhur). The app permits jam' for travel. AGREE in
  the permission itself.
- **A2 — Rain jam'.** §25: recommended, Maghrib + Isha, mosque +
  congregation. The app lists rain among the jam' causes. AGREE in brief
  (the app does not claim the mosque/congregation conditions).
- **A3 — Illness jam'.** §25: permissible (fear of fainting / severe
  fever / vertigo; jam' suri for the sick). The app lists illness.
  AGREE in brief.
- **A4 — Distance note.** The app's "four barid, approx. 80 km, an
  approximation" matches §24's 48 shar'ii miles (~74.64 km / ~80 km).
  (Checked via §24, same manual.)

### Discrepancies / omissions

- **D1 — Jam' taqdim ONLY vs. jam' ta'khir.** The app's note says
  *only* joining in the first time (jam' taqdim) is permitted. §25
  explicitly permits joining in the **second** prayer's time for the
  traveler: "one may join Zuhr and 'Asr upon halting or arriving, during
  'Asr's first or second time" (and likewise Maghrib + Isha during
  'Isha's time). **This is a genuine discrepancy** between the app's
  one-line note and the manual. Note: the app's note reflects the
  earlier research position (al-Qarafi's "two shared times", taqdim
  only). The manual's ta'khir allowance is the mashhur travel-jam'
  doctrine as this manual presents it.
- **D2 — Travel jam' conditions unstated.** §25 conditions travel jam'
  on: (1) a permissible journey (even under 48 miles), (2) travel **on
  land** (not at sea), (3) being **in a hurry** (mashhur; the manual
  notes Dardir, Dusuuqi and Saawi hold the no-rush-needed view as the
  relied-upon one). The app's note states none of these conditions.
- **D3 — "Suboptimal" status unstated.** §25 grades travel jam' as
  permissible *but suboptimal*; rain jam' as *recommended*. The app's
  note flattens all three causes to bare permissibility.

### Recommendation

**Do not change the Travel guidance unilaterally.** D1 is the kind of
genuine madhhab-detail conflict (earlier research: taqdim-only;
Gallant §25: ta'khir allowed for travel) that the scholarly-review
process exists to resolve. Recommended: add D1–D3 to the review-packet
question set as a flagged item (data-model / review-packet level, never
as in-app "pending review" wording per the user's standing order), and
leave the app's current note untouched until a qualified scholar
answers. If the reviewer confirms the manual's position, the note
should be expanded to: travel jam' is permissible but suboptimal
(taqdim or ta'khir), on land, when in a hurry; rain jam' is recommended
for the mosque congregation (Maghrib + Isha).

---

## Method note

Both sections were read in full from the user-supplied PDFs on
2026-10-19. Where the PDF's OCR was garbled, claims were paraphrased
from the readable portions only; nothing was reconstructed by guesswork.
The manual's own cited shaykhs (Mahmoud, Zohir, al-Maghiilii) are
recorded as the manual's attributions, not as independently verified
statements.
