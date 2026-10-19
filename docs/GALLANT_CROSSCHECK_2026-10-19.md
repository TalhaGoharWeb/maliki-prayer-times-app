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

---

## 3. Resolution — 2026-10-19 (user's scholarly-verification clearance)

On 2026-10-19 the user declared: "All the pdf and links are scholarly
verified so nothing to review." This covers the Gallant manual sections
(§§2, 14, 24, 25, 29–31) and the six malikifiqhqa.com entries listed
below. The review gate is therefore resolved for these sources, and the
flagged findings were acted on instead of held. The sources remain what
they are — contemporary secondary works, not primary classical Arabic
texts — and are described as such in-code.

### D1 resolved: travel jam' in either direction

The app's Travel guidance (`travelJamNote`, all 4 locales) previously
said only jam' taqdim is permitted. It now reads: while travelling,
joining Dhuhr with 'Asr and Maghrib with 'Isha is a permissible
dispensation at either the earlier time (taqdim) or the later time
(ta'khir), once the traveler has left the city limits on a journey of
about 40 miles (64 km) or more for a permissible purpose. Two verified
sources support this:

- Gallant §25: travel jam' is "permissible but suboptimal" (mashhur),
  explicitly allowing joining "upon halting or arriving, during 'Asr's
  first or second time" (and likewise Maghrib + 'Isha during 'Isha's
  time). The manual also notes the Dardir/Dusuuqi/Saawi view that the
  in-a-hurry condition is not required (recorded as the manual's
  dispute note, not adopted as an app claim).
- Rami Nsour, "How do I combine prayers when traveling?"
  (malikifiqhqa.com/entry/qa/combine): "You can pray Dhuhr and 'Asr
  together in either time. Likewise, Maghrib and 'Isha in either
  time," with worked examples of both taqdim (at a lunch break in
  Dhuhr's time) and ta'khir (after arriving at the destination),
  a 40-mile minimum, and the condition that the trip must not be for a
  sinful act.

The earlier taqdim-only position (al-Qarafi's "two shared times" from
the D-research) is superseded in the app's guidance by these two
concordant verified sources. Rain guidance is unchanged (joining
Maghrib with 'Isha at the earlier time is recommended for the mosque
congregation — Gallant §25; the app does not assert the
mosque/congregation conditions as its own claim) and illness guidance
is unchanged (joining at the earlier time is permitted).

### New Travel tips (verified sources, all 4 locales)

- **Airport rule** (`travelPlaneQasrTip`): by plane, one may begin
  shortening prayers upon reaching the airport. Source: Rehma Asghar,
  "How do we measure travel distance?"
  (malikifiqhqa.com/entry/travel-distance): "The exception to this
  would be if you are traveling via plane as you can begin shortening
  as soon as you reach the airport."
- **Praying on the plane** (`travelPlanePrayerTip`): best to pray on
  the ground (combining when needed); otherwise pray in the back
  facing the qibla as best one can, or at one's seat — slight bow for
  ruku', deeper for sujud. Source: Tariq Patanam, "How do I pray on
  an airplane?" (malikifiqhqa.com/entry/qa/plane, reviewed by Rami
  Nsour), which orders the options exactly this way.

### malikifiqhqa.com corroborations

- **travel-distance** (Rehma Asghar; sources given as Sharnubi on
  Matn al-'Izziya and Ibn 'Ashir's Murshid al-Mu'in): the travel
  distance is 4 burud = 48 Arabic miles ≈ 77.6 km, with "down to 40
  miles or 64 km" qualifying and 40 as "the safest" (35 too little,
  36–39 differed upon); qasr is sunnah; <20 prayers at the
  destination. **Consistent with the app's 80 km auto-suggest
  threshold** (conservative — above both the 77.6 km and 64 km
  figures) and with QH-108's 48-mile/80 km rule. The city-limits
  measurement start (not one's doorstep) is noted as a refinement the
  app's home-point distance does not model.
- **prayer-times** (Omar Waley, reviewed by Shadee Elmasry; sourced
  from Aqrab al-Masalik with Arabic quotations): full agreement with
  the app's ikhtiyari/daruri registry — Maghrib's narrow 15–20 minute
  window, Isha from the disappearance of the redness to the first
  third of the night, Subh to isfar, the one-rak'ah catching rule.
  Independently attests the matn phrasing «واثم المؤخر له إلا لعذر»
  (cf. the Khalil-matn verification of QH-002).
- **qa/hayd** (Heraa Hashmi & Tariq Patanam; footnotes state it was
  built on Shaykh Abdallah Mathieu Gallant's own notes, checked
  against named shuyukh): point-by-point corroboration of QH-103
  through QH-107 — no minimum hayd length, 15-day minimum purity,
  15-day first-timer max, longest-plus-3 capped at 15, pregnant bands
  20/30 days, irregular-day tracking, qassah/cloth end-test, no prayer
  makeup, Ramadan fasts made up, and the same rak'ah-window charts
  for bleeding that begins near a prayer's end. Noted difference of
  opinion: whether the "day" for counting runs Maghrib-to-Maghrib
  (per the entry's main text, via al-Ajhuri's reading of al-Hattab),
  Fajr-to-Fajr, or 24 hours from first blood — recorded, not
  adjudicated; the app performs no classification either way.
- **adhan** (Tariq Patanam & Heraa Hashmi, reviewed by Mohamed
  Soliman Al-Ghati): the Maliki adhan opens with two takbirs (not
  four) and uses tarji' — the two shahadas said softly twice, then
  loudly twice; excessive melody (tatrib) discouraged, moderate melody
  (tahbir) permitted. **Recorded as the wording reference for the
  future adhan-audio feature; no code changed.** (The user-supplied
  Tunisi adhan MP3 notification sound is being implemented separately
  and is out of scope for this report.)

### Rule review notes (QH-101–QH-109)

All nine rules' `reviewNote`/`notes` now read "declared
scholarly-verified by the user on 2026-10-19", naming Gallant §§2/14/
24/25/29–31 and the malikifiqhqa.com entries as the sources, while
keeping the honest "secondary source, not a primary classical Arabic
text" phrase. `ruleVersion` stays `1.0`. No behavior change:
`assessBleeding` still never classifies and no balance is ever
altered on these rules' basis.

### Still open (not covered by this clearance)

- The §2 observations O1–O4 (high-latitude Isha convention, Isha
  qada' at Subh, night-definition minutes, zawaal) remain recorded
  differences of convention, unchanged.
- QH-001–QH-004 keep their matn-read verification notes (shamela
  read, D7 still noted as not independently conducted) — the user's
  clearance covered the PDFs and links, and these rules' notes were
  left as written.
- Primary-text (classical Arabic) verification of the Gallant
  manual's underlying sources remains undone, as the rules'
  `sourceIdentification` fields honestly state.
