library;

import 'package:malikiprayertimes/models/review_status.dart';

/// Localized content for the Learn screen (Phase 4 — the "Enseignement"
/// teaching section, per the Tawqit pattern).
///
/// Sourcing rule (binding): every claim here comes from the research
/// deliverables — D1 (English scholarly report), D2 (Urdu report), D4
/// (evidence database), or the Tawqit Instagram profile review. Arabic
/// passages are copied VERBATIM from D4/D1, never reconstructed from
/// memory. Nothing here invents fiqh, scholars, quotations, or angles.
///
/// Every [LearnBlock] carries at least one evidence reference (rendered
/// as e.g. "D1 §2.3 · D4 A3.1"), and every section's blocks together
/// reference both D1 and D4. Blocks about modern conventions (the 18°
/// section, the FAQ on ihtiyat) carry the convention disclaimer in the
/// body: conventions are NEVER presented as Maliki rulings.
///
/// The integrity line at the screen's head says what this section is
/// NOT: no "verified/endorsed/approved" language anywhere — nothing here
/// has been reviewed by a qualified Maliki scholar.
///
/// Content keys: locale code ('en'/'ur'/'ar'/'fr') -> section id ->
/// [LearnContent]. Unknown locales and unknown section ids fall back to
/// English. Digits stay Western 0-9 in every locale (Urdu-first rule).

/// One Learn section: the five prayers' definitions, the 18° question,
/// dawn studies, the FAQ, or the glossary.
class LearnSection {
  /// Stable identifier used as the content-map key.
  final String id;

  const LearnSection(this.id);
}

/// The five teaching sections in display order.
const List<LearnSection> learnSections = [
  LearnSection('definitions'),
  LearnSection('eighteen'),
  LearnSection('dawn'),
  LearnSection('faq'),
  LearnSection('glossary'),
];

/// One teaching block: a definition, an FAQ entry, or a glossary term.
class LearnBlock {
  /// Block heading: a prayer name, a question, or a term.
  final String title;

  /// Verbatim classical Arabic passage, copied from D4/D1. Empty when the
  /// block has no quotation.
  final String arabic;

  /// The teaching body: plain text, claims all tied to [refs].
  final String body;

  /// Evidence references, e.g. "D1 §2.3 · D4 A3.1". Never empty.
  final String refs;

  /// Exact classical book the [arabic] passage is quoted from, e.g.
  /// «الرسالة» or «مختصر خليل» — traced through the D4 evidence
  /// references in [refs]. Empty when the source book could not be
  /// determined from the research evidence (never guessed).
  final String source;

  /// Scholarly-review status of this block's claims. Data only — never
  /// rendered as a label (the user directive of 2026-10-15 forbids
  /// review-status banners in the UI); the screen's integrity note carries
  /// the honesty requirement instead. Defaults to
  /// [ReviewStatus.proposed]: nothing in this section has been reviewed
  /// by a qualified Maliki scholar.
  final ReviewStatus reviewStatus;

  const LearnBlock(
    this.title,
    this.arabic,
    this.body,
    this.refs, {
    this.source = '',
    this.reviewStatus = ReviewStatus.proposed,
  });
}

/// The localized content of one Learn section.
class LearnContent {
  /// Section heading, e.g. "Why 18°?".
  final String title;

  /// One-line framing of the section.
  final String intro;

  /// The section's blocks in display order.
  final List<LearnBlock> blocks;

  const LearnContent(this.title, this.intro, this.blocks);
}

/// Screen chrome strings (title and the integrity note).
class LearnStrings {
  /// Screen title, also used for the settings entry and the home card.
  final String title;

  /// The unmistakable integrity note: teaching, not rulings; nothing here
  /// is a scholarly endorsement.
  final String integrityNote;

  const LearnStrings({required this.title, required this.integrityNote});
}

/// Chrome strings per locale; unknown locales fall back to English.
const Map<String, LearnStrings> _chrome = {
  'en': LearnStrings(
    title: 'Learn',
    integrityNote:
        'Teaching material drawn from the research evidence — not fiqh '
        'rulings. Every quotation names the book it comes from, and every '
        'modern convention is labeled a convention. Nothing here has been '
        'reviewed by a qualified Maliki scholar.',
  ),
  'ur': LearnStrings(
    title: 'سیکھیں',
    integrityNote:
        'تحقیقی شواہد سے ماخوذ تعلیمی مواد — فقہی احکام نہیں۔ ہر اقتباس اس '
        'کتاب کا نام دیتا ہے جس سے لیا گیا ہے، اور ہر جدید کنونشن کو کنونشن '
        'ہی کہا گیا ہے۔ یہاں کی کسی بات کی اہل مالکی عالم نے نظرثانی نہیں کی۔',
  ),
  'ar': LearnStrings(
    title: 'التعليم',
    integrityNote:
        'مواد تعليمي مستمد من أدلة البحث — وليس أحكاماً فقهية. كل اقتباس '
        'يذكر الكتاب الذي أُخذ منه، وكل عرف حديث مسمّى عرفاً. لم يراجع أيَّ '
        'شيء هنا عالمٌ مالكي مؤهل.',
  ),
  'fr': LearnStrings(
    title: 'Enseignement',
    integrityNote:
        'Matériel pédagogique tiré des preuves de recherche — pas des règles '
        'de fiqh. Chaque citation nomme le livre dont elle est tirée, et chaque '
        'convention moderne est étiquetée comme telle. Rien ici n’a été '
        'révisé par un savant malikite qualifié.',
  ),
};

/// Chrome strings for [languageCode] ('en' fallback).
LearnStrings learnStrings(String languageCode) =>
    _chrome[languageCode] ?? _chrome['en']!;

/// Localized section content: locale -> section id -> content. English is
/// the fallback for missing locales and missing sections.
const Map<String, Map<String, LearnContent>> _content = {
  'en': {
    'definitions': LearnContent(
      'The five prayers — Maliki definitions',
      'The classical Maliki texts define the prayer times as observable '
          'signs: the spreading dawn, the lengthening shadow, the gone sun, '
          'the fading redness. The passages below are quoted verbatim from '
          'the research evidence.',
      [
        LearnBlock(
          'Subh — from the true dawn to isfar',
          '«أول وقتها انصداع الفجر المعترض بالضياء في أقصى المشرق ذاهبا من '
              'القبلة إلى دبر القبلة حتى يرتفع فيعم الأفق»',
          'Subh begins at the true dawn (fajr sadiq) — light spreading '
              'horizontally across the far east until it covers the horizon — '
              'and its preferred time ends at the clear isfar, when daylight '
              'has spread so that, at the end of the prayer, the sun’s edge '
              'appears. On the mashhur its necessity time (daruri) continues '
              'to sunrise; a minority holds Subh has no daruri at all.',
          'D1 §2.3 · D4 A3.1',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'Dhuhr — from zawal to the first mithl',
          '«الْوَقْتُ الْمُخْتَارُ لِلظُّهْرِ: مِنْ زَوَالِ الشَّمْسِ لِآخِرِ '
              'القامة بغير ظل الزوال»',
          'Dhuhr begins at the sun’s decline past the meridian (zawal), and '
              'its preferred time ends when an object’s shadow equals its own '
              'length — the shadow present at noon (zill al-zawal) is always '
              'excluded from the count. Its necessity time continues to '
              'sunset. The Khalil passage above is the school’s compressed '
              'definition, verified verbatim from the printed matn.',
          'D1 §2.4 · D4 A4.1 · A2.1',
          source: '«مختصر خليل»',
        ),
        LearnBlock(
          'Asr — the first mithl, to the yellowing',
          '«وهو أول وقت العصر للإصفرار»',
          'Asr begins where Dhuhr ends: at the first mithl — one object-'
              'length of shadow beyond the noon shadow. Its preferred time '
              'lasts while the sun is still white and pure; the preferred end '
              'is the sun’s yellowing (isfirar), judged on the ground and the '
              'walls, not in the sun’s disk. The necessity time continues to '
              'sunset. This is the one place where the software rule (shadow '
              'factor 1) coincides exactly with the text-established rule.',
          'D1 §2.5 · D4 A4.1 · A6.5',
          source: '«مختصر خليل»',
        ),
        LearnBlock(
          'Maghrib — sunset, one narrow time (mashhur)',
          '«ليس لها إلا وقت واحد لا تؤخر عنه»',
          'Maghrib begins at sunset — the disappearance of the entire solar '
              'disk. On the mashhur it has but one narrow time, about the '
              'time needed to perform it after its conditions are met; it is '
              'not delayed beyond it. A recognized second qawl (Ashhab, '
              'al-Baji’s choice) extends it to the disappearance of the red '
              'twilight — noted here as an alternative, not the default.',
          'D1 §2.6 · D4 A3.4 · A6.7',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'Isha — the red twilight, to the first third of the night',
          '«غيبوبة الشفق والشفق الحمرة الباقية في المغرب من بقايا شعاع الشمس… '
              'ولا ينظر إلى البياض في المغرب»',
          'Isha begins at the disappearance of the red twilight (shafaq) — '
              'the remaining whiteness does not count, against the Hanafi '
              'white-twilight reading. Its preferred time ends at the first '
              'third of the night, measured from raw sunset to the true dawn '
              '(Ibn Habib’s qawl: to midnight). The necessity time continues '
              'to dawn, and Maghrib and Isha share the final four rak‘as.',
          'D1 §2.7 · D4 A3.5 · A2.4',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'The two tiers: mukhtar and daruri',
          '«والضروري بعد المختار للطلوع في الصبح وللغروب في الظهرين وللفجر '
              'في العشاءين» — «وَأَثِمَ إلَّا لِعُذْرٍ»',
          'The preferred (mukhtar) time is the time of choice; the necessity '
              '(daruri) time that follows it is for those with an excuse. '
              'Khalil: one who delays into it without excuse is sinful '
              '(wa-athim illa li-‘udhr). A prayer is still caught in it with '
              'one rak‘a, and all of it counts as on-time (ada’). The '
              'mukhtar/daruri pair is Khalil’s systematization — the '
              'Mudawwana era used earlier vocabulary such as "first/last of '
              'the time" and "no harm".',
          'D1 §2.2 · §2.8 · D4 A4.1 · A2.6',
          source: '«مختصر خليل»',
        ),
      ],
    ),
    'eighteen': LearnContent(
      'Why 18°?',
      'The 18° figure has a classical astronomical pedigree — but no '
          'classical Maliki text fixes the dawn at a degree angle. Both '
          'truths belong in this section.',
      [
        LearnBlock(
          'Habach al-Hasib al-Marwazi (d. ~227H)',
          '«قد علم بالتجربة أن انحطاط الشمس عن الأفق في أول الصبح الكاذب '
              'وفي آخر الشفق ثماني عشرة درجة»',
          'The earliest established mention of the 18° value: in one of his '
              'zij (astronomical tables), the Baghdad astronomer Habach '
              'al-Hasib gives a procedure using sin(18°) to determine '
              'dawn-rise and twilight-disappearance — the manuscript is held '
              'in Berlin. Al-Baha’ al-Din al-‘Amili records the same 18° as '
              'known "by repeated observation". An astronomer’s observational '
              'parameter — not a Maliki ruling.',
          'D1 §4.1 · D4 D3.4',
          source: '«تشريح الأفلاك»',
        ),
        LearnBlock(
          'Ibn al-Samh al-Mahri (d. 426H)',
          '',
          'In his book on the use of the astrolabe, chapter 74, the '
              'Andalusian muhandis Ibn al-Samh instructs: to know the hour '
              'when twilight disappears and dawn rises, place the nadir of '
              'the sun’s position on the 18th almacantarat — "and according '
              'to Habach (d. 250H), on the 16th almacantarat". The degree '
              'figure was a working instrument setting among the early '
              'Muslim astronomers.',
          'D1 §4.1 · D4 D3.4',
        ),
        LearnBlock(
          'The medieval 16°–20° range',
          '',
          'The medieval astronomers worked with a family of parameters, not '
              'one fixed value: Ibn Yunus 20°/16°, the Egyptian astronomers '
              '19°/17°, and 18°/18° widespread (King/Ilyas, secondary '
              'summary). Qadi Zadah notes that below about 72° latitude the '
              'twilight joins the false dawn at the summer solstice — the '
              'classical statement of the high-latitude twilight problem.',
          'D1 §4.1 · D4 D3.3',
        ),
        LearnBlock(
          'The honest boundary: no angle in the fiqh',
          '',
          'No classical Maliki text fixes the true dawn at a solar-'
              'depression angle — the description is purely visual: the '
              'splitting of the transverse dawn until it fills the horizon. '
              'The 18°/17° figures of the MWL 1986 convention, and every '
              'institutional preset, are modern operational estimates of the '
              'legal signs — a software convention, never a Maliki ruling.',
          'D1 §4.1 · D4 NEG-1 · C7.1',
        ),
      ],
    ),
    'dawn': LearnContent(
      'Dawn-observation studies',
      'Modern measurements of the true dawn’s solar depression. Science '
          'informs the conventions — it is not fiqh.',
      [
        LearnBlock(
          'UKM, Malaysia (2018)',
          '',
          'Kassim Bahali et al., Jurnal Sains Malaysiana 47(11) 2018: a '
              'DSLR-camera measurement of the fajr sadiq depression — '
              '-14.5° to -18.5°, mean -16.67°, with a proposed working value '
              'of -17.0°. Every commonly used Fajr angle lies inside or near '
              'this observed range.',
          'D1 §4.1 · D4 D3.1',
        ),
        LearnBlock(
          'UIN Jakarta (2018)',
          '',
          'An SQM-photometer study detected the true dawn only at 15°–18°. '
              'Indonesia’s official 20° standard showed no detectable dawn '
              'there — it runs 8–20 minutes early. A warning against '
              'hard-coding a single high angle.',
          'D1 §4.1 · D4 D3.2',
        ),
        LearnBlock(
          'Why cities see the dawn later',
          '',
          'Sheikh Abdessalam al-Shuway‘ir: the true dawn is the horizontal '
              'whiteness, as opposed to the false dawn’s vertical shaft; '
              'because of artificial lighting, the true dawn cannot be seen '
              'in cities — not even near towns or on electrified farms — '
              'only where the light pollution has gone. A reason for '
              'cautious, later Fajr estimates.',
          'Tawqit Instagram review, Post 3 · D1 §4.1',
        ),
      ],
    ),
    'faq': LearnContent(
      'Common questions',
      'Answers that stay inside the research evidence — conventions are '
          'always named as conventions.',
      [
        LearnBlock(
          'May prayer times be calculated, or must they be watched for?',
          '«لا أعلم خلافا في إثبات أوقات الصلاة بالحساب في الآلات بالماء والرمل '
              'وغيرهما، وعلى ذلك أهل الأمصار في سائر الأعصار زمن الشتاء عند الأمطار '
              'والغيوم»',
          'They may be calculated — and this is not a modern shortcut. The Maliki '
              'school said it plainly seven centuries ago. Al-Qarafi (d. 684 AH) wrote in '
              'his al-Dhakhira: "I know of no disagreement about establishing prayer times '
              'by calculation, with water-clocks, sand instruments and the like — the '
              'people of the great cities have done so in every age, in winter, when rain '
              'and clouds come." He drew the line carefully in his al-Furuq: calculating '
              'prayer times is one thing; calculating the Ramadan crescent is another, and '
              'the two are not judged alike. In this app, every time is computed on your '
              'phone from the astronomical signs themselves — and the method is shown to '
              'you, never silently adjusted.',
          'D1 §4.1 · D4 (verification 2026-10-18: al-Dhakhira, Kitab al-Siyam)',
          source: '«الذخيرة»',
        ),
        LearnBlock(
          'Why should I trust a calculated timetable?',
          '«وقال البرزلي في أوائله: ظاهر المذهب عندنا قبول قول المؤذن العدل العارف '
              'مطلقا، أي في الغيم والصحو، في الصلاة والصوم، إذا كان عارفا بالأوقات بالآلات، '
              'مثل الرمليات والمنقلات وغيرها»',
          'Because the school trusts the knowledgeable timekeeper. Al-Burzuli — quoted '
              'by al-Hattab in Mawahib al-Jalil — states the apparent position of the '
              'Maliki school: the word of an upright, knowledgeable muezzin is accepted '
              'absolutely, in cloudy skies and in clear ones, for prayer and for fasting, '
              'when he knows the times by instruments — sand-glasses, astronomical clocks, '
              'and the like. Ibn Yunus and others stated this generality explicitly in the '
              'Book of Fasting. A timetable is only as good as the knowledge behind it: '
              'this app shows you the method, the angles, and the evidence for every time '
              'it displays, so you are never asked to trust a black box.',
          'D1 §4.1 · D4 (verification 2026-10-18: Mawahib al-Jalil, bab mawaqit '
              'al-salat)',
          source: '«مواهب الجليل»',
        ),
        LearnBlock(
          'Is using astronomy for prayer times the same as astrology?',
          '«وبعد فاعلم أن علم الفلك ۞ علم عزيز من أجل مسلك / أعني الذي تدرى به الأوقات '
              '۞ والفجر والقبلة والساعات // وما به تطرق للغيب ۞ فذلك الحرام دون ريب / واعلم '
              'بأن العلم بالنجوم ۞ علم شريف ليس بالمذموم»',
          'No — and the jurists drew this line long ago. Al-Akhdari (d. 953 AH) opens '
              'his astronomical poem al-Siraj with it: the science by which times, the '
              'dawn, the qibla and the hours are known is "a noble science, among the most '
              'honorable pursuits" — while anything claiming access to the unseen is '
              'forbidden "without doubt." Astronomy that finds the prayer times is a '
              'learned craft; astrology that claims hidden knowledge is another matter '
              'entirely. (The Arabic verses above are as transmitted in the Tawqit '
              'educational slides from the manuscript tradition of al-Siraj; no printed '
              'edition was accessible for word-for-word verification.)',
          'D1 §4.1 · D4 (al-Siraj attribution verified 2026-10-18; verses per '
              'manuscript tradition)',
          source: '«السراج في علم الفلك»',
        ),
        LearnBlock(
          'Why 18° for Fajr?',
          '',
          'Because generations of Muslim astronomers and timekeepers recorded it as '
              'their working estimate of the observable sign — the true dawn. Al-Biruni '
              'states the matter plainly in al-Qanun al-Mas’udi: the practitioners of the '
              'craft observed and "obtained from the laws of its time that when the sun’s '
              'depression below the horizon is eighteen degrees, that is the time of '
              'dawn-rise in the east and of the twilight’s disappearance in the west" — '
              'while adding at once that it is "not a fixed thing," since some of them saw '
              'it as seventeen degrees (Qanun 2/948–949, Hyderabad ed.). In his Tahdid he '
              'gives the report from the other side: seventeen degrees per the '
              'practitioners, eighteen per some — both "taken from experiment and repeated '
              'testing." Two honesties belong with this. First, it was never unanimous: the '
              'classical books record a 16°–20° range — 17° and 19° in serious use '
              'alongside 18°, and no classical Maliki text fixes a degree at all — the '
              'angle is a convention estimating the sign, not a ruling. Second, these were '
              'astronomers, not jurists: their authority is observational, and the fiqh '
              'judgment about the sign stays with the fuqaha’. This app’s default profile '
              '(Muslim World League, 18°/17°) follows the 1986 MWL Islamic Fiqh Council '
              'decision; the other profiles name their own conventions honestly.',
          'D1 §4.2 · Biruni Qanun 2/948-949 & Tahdid (verbatim-verified); King 1973 '
              '(Habash/Nayrizi "probably"; Battani denial); Tusi Muiniyya 18°',
        ),
        LearnBlock(
          'Why do different countries use different angles?',
          '',
          'Because the angle is a national convention for reading the same sky, not a '
              'ruling about it. Morocco’s tables run on 19°/17° (reported in secondary '
              'sources — the Habous ministry’s own methodology is unpublished); Egypt on '
              '19.5°/17.5°; Saudi Arabia on 18.5° for Fajr with a 90-minute interval for '
              'Isha; Malaysia and Indonesia on 20°/18°; and much of West Africa, including '
              'Mauritania, on the Muslim World League’s 18°/17°. None of these numbers is '
              'the fiqh — the fiqh speaks of the true dawn and the red twilight’s '
              'disappearance, which observers have always read slightly differently by '
              'place and season. This app offers the main conventions as named profiles '
              'with their provenance, so you always know which convention you are praying '
              'by. (One caution: the Tawqit map’s tagline — "the stronger a state’s '
              'scholarly tradition, the closer it stays to 18°" — is the publisher’s own '
              'rhetoric, not a scholarly finding.)',
          'D1 §4.2 · D4 (Morocco secondary-only per pass-2 C) · Tawqit angles map',
        ),
        LearnBlock(
          'Why do times differ between apps?',
          '',
          'Look past the labels and you will usually find the same fiqh with '
              'different software conventions: one app opens Fajr at 18°, another at '
              '20°; one adds precautionary minutes, another adds none; each handles '
              'high latitudes in its own way. Two things deserve care. Preset labels '
              'are not always what they claim — the UOIF 12°/12° label, for example, is '
              'disputed against a claimed 15°/15° reality. And where the method itself '
              'is unpublished, as with Muslim Pro and IslamicFinder, their timetables '
              'cannot be used to judge anyone else’s.',
          'D1 §4.6–4.7 · D4 NEG-5 · C3.2',
        ),
        LearnBlock(
          'What if I live where Isha or Fajr never occurs?',
          '',
          'In the far north in summer, the red twilight may never disappear before dawn '
              '— so when is Isha, and when does the fast begin? The timekeeper of Fez, '
              'al-’Alami, put exactly this question to the city’s shaykh al-jama’a, Ibn '
              'al-Khayyat al-Zukari (d. 1343 AH/1924 CE). His answer chose a "third '
              'opinion": the night is split at its middle — its first half belongs to the '
              'twilight, its second half to the dawn; Isha becomes due when the sun’s '
              'light-effect passes from the west side to the east; Fajr is then prayed '
              'after Isha, keeping the required order; and the fast is held by the local '
              'day, "complete the fast until night" (Qur’an 2:187), however long it is. The '
              'question itself had quoted an older report — al-Qarafi transmitting from '
              'Imam al-Haramayn (al-Juwayni) in al-Qarafi’s al-Yawaqit: Isha is not prayed '
              'until the twilight is gone, and it is not qaḍa’ since its time remains; the '
              'dawn prayer follows the nearest country’s dawn. This is one mufti’s reasoned '
              'fatwa from the Fez timekeeping tradition — not the school’s mashhur '
              'doctrine. This app’s answer to the same problem is its high-latitude '
              'fallback chooser: when the twilight angles are unreachable, it estimates '
              'from the night itself (middle of the night, and other named conventions) and '
              'tells you plainly which one is active — the midnight-split at the fatwa’s '
              'heart is close kin to the "middle of the night" convention.',
          'D1 §4.5 · Tawqit Fez fatwa series (identities & al-Yawaqit correction per '
              'strand B 2026-10-18)',
        ),
        LearnBlock(
          'Why can the "preferred until" marker fall before Isha in summer?',
          '',
          'At high latitudes — France, for instance — the twilight that opens Isha '
              'sometimes lingers past the first third of the night. The preferred '
              'period still ends at that third, so its calculated end can land before '
              'Isha itself begins. On 17 May in Paris, for example: Maghrib at 21:31, '
              'the first third ending at 23:30, Isha only at 23:51, Fajr at 03:30. The '
              'four schools agree on waiting for the genuine Isha time even when it '
              'falls past midnight; as Imam Ibn Hajar put it, a substitute sign is '
              'considered only when the real sign is absent, never when it is present.',
          'Tawqit Instagram review, Post 1 · D1 §2.7',
        ),
        LearnBlock(
          'Why does Isha come after midnight in summer?',
          '',
          'For two thoroughly unreligious reasons: time zones and daylight saving. '
              'France, for example, lives a full hour ahead of its solar time — a wartime '
              'German imposition from 1940 that was never undone — and then adds another '
              'hour every summer for daylight saving (since 1976). So by the clock, Isha '
              'can land at 1 a.m. while the sun is only just past where midnight used to '
              'be. The religious signs have not moved; the clock has. Do not mistake a '
              'late-looking timetable for a late religion: the four schools agree that one '
              'waits for the genuine Isha time even when it falls past midnight.',
          'D1 §4.5 · Tawqit summer-midnight slide (history: general record)',
        ),
        LearnBlock(
          'Prayer times are very late in summer — what should I do?',
          '',
          'The Tawqit slides propose four graduated steps for coping with very late '
              'summer times — pastoral guidance, not a fatwa of this app. (1) Pray at the '
              'start of the time whenever you can — "the prayer at the beginning of its '
              'time" (hadith of Umm Farwa, Sunan Abi Dawud #426; its chain is graded weak, '
              'though its meaning is established by Ibn Mas’ud’s hadith in the two Sahihs). '
              '(2) If you cannot, delay Fajr toward the brightening (isfar) — the mashhur '
              'end of Subh’s preferred time itself. The slides word it as Ibn Habib, '
              'reported by Ibn Abi Zayd in al-Nawadir from Mu’adh: "when summer comes, '
              'brighten the Subh, for the night is short and people sleep; do not delay '
              'Isha, for the night is short, and do not pray it before the twilight is '
              'gone" — a wording we could not verify against a printed edition, so take the '
              'step for its substance, which the school’s own rule supports. (3) If even '
              'that fails, delay Isha to just before Fajr — for "neglect of prayer is only '
              'to delay it until the time of the next one" (the saying of Abu Hurayra; as '
              'the Prophet’s ﷺ own words it comes via Abu Qatada in Sahih Muslim). (4) As a '
              'last resort, combine Maghrib and Isha: Ashhab permitted combining two '
              'prayers without a specific cause — a real, recognized internal disagreement, '
              'reported by al-Baji and Ibn Rushd via Khalil’s al-Tawdih (as al-Hattab '
              'records it) — on the hadith of Ibn ’Abbas that the Prophet ﷺ combined Dhuhr '
              'with ’Asr and Maghrib with ’Isha "without fear, travel, or rain." Be '
              'clear-eyed about step 4: it is the minority view, not the mashhur — the '
              'well-known Maliki position permits combining only by advancing (taqdim), for '
              'rain or illness.',
          'D1 §2.9 · Tawqit summer-management slide (attribution corrections per strand '
              'B 2026-10-18)',
        ),
        LearnBlock(
          'What does daruri (necessity time) mean?',
          '',
          'When the preferred time closes, the door does not shut for the excused — '
              'a necessity window opens after it. Khalil’s formulation: the daruri '
              'follows the mukhtar — to sunrise for Subh, to sunset for Dhuhr and Asr, '
              'to dawn for Maghrib and Isha. Stepping into it without excuse is sinful, '
              'but one rak‘a caught inside it still counts as prayer performed on time '
              '(ada’). On the mashhur, Subh keeps this tier as well; a minority holds '
              'that it has none.',
          'D1 §2.8 · D4 A4.1 · A7.2',
        ),
        LearnBlock(
          'What is ihtiyat?',
          '',
          'A small precautionary shift added on top of the computed times — +1 '
              'minute on Dhuhr and Maghrib, say. It belongs to caution, not to fiqh: '
              'move the ihtiyat switch in this app and none of the legal boundaries '
              'move with it. The idea has classical company — the older tradition '
              'already kept the legal noon (the sun’s disk crossing the meridian) '
              'separate from the astronomical noon (its center crossing it), by about '
              'half a degree, roughly two minutes.',
          'D1 §4.4 · D4 A6.2',
        ),
      ],
    ),
    'glossary': LearnContent(
      'Glossary',
      'The terms used in this app, in Maliki vocabulary. A caution from the '
          'research: the formal pair "waqt al-fadila / waqt al-jawaz" is '
          'Shafi‘i vocabulary, not Maliki.',
      [
        LearnBlock(
          'Mukhtar (الوقت المختار)',
          '',
          'The preferred or chosen time — the time of choice, in which '
              'praying is best. Also called the ikhtiyari time.',
          'D1 §2.2 · D4 A4.2',
        ),
        LearnBlock(
          'Daruri (الوقت الضروري)',
          '',
          'The necessity time that follows the mukhtar, for those with an '
              'excuse; delaying into it without excuse is sinful. For the '
              'excused, it still counts as on-time.',
          'D1 §2.8 · D4 A4.1',
        ),
        LearnBlock(
          'Fajr sadiq / fajr kadhib (الفجر الصادق / الكاذب)',
          '',
          'The true dawn: light spreading horizontally until it fills the '
              'horizon — this opens Subh. The false dawn: a vertical column '
              'of light with no horizontal spread — it counts for nothing.',
          'D1 §2.3 · D4 A3.1 · B2.2',
        ),
        LearnBlock(
          'Shafaq (الشفق)',
          '',
          'The twilight. In Maliki law it is the redness remaining in the '
              'west after sunset — and Isha begins at its disappearance. The '
              'whiteness that remains after it is disregarded.',
          'D1 §2.7 · D4 A3.5',
        ),
        LearnBlock(
          'Zill al-zawal (ظل الزوال)',
          '',
          'The shadow present at solar noon. It is excluded from all later '
              'shadow measurements — the qama is counted only after it. It '
              'vanishes in the tropics and varies with season and latitude.',
          'D1 §2.4 · D4 A2.1 · A6.1',
        ),
        LearnBlock(
          'Isfar (الإسفار)',
          '',
          'The clear brightening before sunrise; the end of Subh’s preferred '
              'time. An observed visual sign — no fiqh source gives it as a '
              'clock offset, so it is shown as an informational band, never '
              'as a computed time.',
          'D1 §2.3 · D4 A2.5',
        ),
        LearnBlock(
          'Isfirar (الإصفرار)',
          '',
          'The yellowing of the sun; the end of Asr’s preferred time. '
              'Judged on the ground and the walls, not in the sun’s disk — '
              'an observed visual sign, never a clock offset.',
          'D1 §2.5 · D4 A6.5',
        ),
        LearnBlock(
          'Ghalas (الغلس)',
          '',
          'The pre-dawn darkness; praying Subh in ghalas is sunna. The '
              'Mudawwana school says Subh is prayed in ghalas and its time '
              'ends at isfar.',
          'D1 §2.3 · D4 A2.5',
        ),
        LearnBlock(
          'Ihtiyat (احتياط)',
          '',
          'A precautionary minute-offset added to computed times (for '
              'example +1 min on Dhuhr/Maghrib) — a convention, not fiqh.',
          'D1 §4.4 · D4 A6.2',
        ),
        LearnBlock(
          'Mashhur (مشهور)',
          '',
          'The well-established position of the school — the position the '
              'app uses as default wherever recognized disagreements exist.',
          'D1 §2.10 · D4 A6.7',
        ),
      ],
    ),
  },

  'ur': {
    'definitions': LearnContent(
      'پانچ نمازوں کی مالکی تعریفیں',
      'کلاسیکی مالکی نصوص نمازوں کے اوقات قابل مشاہدہ علامات سے بیان کرتی '
          'ہیں: پھیلی ہوئی فجر، بڑھتا ہوا سایہ، غائب سورج، مٹتی ہوئی سرخی۔ '
          'ذیل کی عبارتیں تحقیقی شواہد سے لفظ بہ لفظ نقل شدہ ہیں۔',
      [
        LearnBlock(
          'صبح — فجر صادق سے اسفار تک',
          '«أول وقتها انصداع الفجر المعترض بالضياء في أقصى المشرق ذاهبا من '
              'القبلة إلى دبر القبلة حتى يرتفع فيعم الأفق»',
          'صبح فجر صادق سے شروع ہوتی ہے — یعنی وہ روشنی جو مشرق کے انتہائی '
              'کنارے پر افقی پھیل کر بلند ہو یہاں تک کہ افق کو گھیر لے — اور '
              'اس کا وقتِ اختیار واضح اسفار پر ختم ہوتا ہے، یعنی جب روشنی '
              'اتنی پھیل جائے کہ نماز کے ختم پر سورج کا کنارہ نظر آنے لگے۔ '
              'مشہور پر اس کا وقتِ ضرورت طلوع آفتاب تک رہتا ہے؛ اقلیتی قول '
              'کے مطابق صبح کا کوئی وقتِ ضرورت نہیں۔',
          'D1 §2.3 · D4 A3.1',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'ظہر — زوال سے مثل اول تک',
          '«الْوَقْتُ الْمُخْتَارُ لِلظُّهْرِ: مِنْ زَوَالِ الشَّمْسِ لِآخِرِ '
              'القامة بغير ظل الزوال»',
          'ظہر زوال شمس سے شروع ہوتی ہے، یعنی سورج کا نصف النہار سے ڈھلنا، '
              'اور اس کا وقتِ اختیار اس وقت ختم ہوتا ہے جب چیز کا سایہ اس '
              'کی قد کے برابر ہو جائے — زوال کے وقت کا سایہ (ظل الزوال) '
              'ہمیشہ حساب سے خارج رکھا جاتا ہے۔ اس کا وقتِ ضرورت غروب آفتاب '
              'تک رہتا ہے۔ اوپر خلیل کا متن مذہب کی مختصر تعریف ہے، مطبوعہ '
              'متن سے لفظ بہ لفظ تصدیق شدہ۔',
          'D1 §2.4 · D4 A4.1 · A2.1',
          source: '«مختصر خليل»',
        ),
        LearnBlock(
          'عصر — مثل اول سے اصفرار تک',
          '«وهو أول وقت العصر للإصفرار»',
          'عصر وہیں سے شروع ہوتی ہے جہاں ظہر ختم ہوتی ہے: مثل اول سے — یعنی '
              'زوال کے سائے کے علاوہ ایک قامت کے برابر سایہ۔ اس کا وقتِ '
              'اختیار اس وقت تک رہتا ہے جب سورج سفید اور صاف ہو؛ اختیار کا '
              'خاتمہ سورج کی زردی (اصفرار) ہے، جو زمین اور دیواروں پر دیکھی '
              'جاتی ہے، خود سورج میں نہیں۔ وقتِ ضرورت غروب آفتاب تک رہتا ہے۔ '
              'یہ وہ واحد مقام ہے جہاں سوفٹ ویئر کا قاعدہ (سایہ فیکٹر 1) '
              'نص سے ثابت قاعدے سے بالکل مطابقت رکھتا ہے۔',
          'D1 §2.5 · D4 A4.1 · A6.5',
          source: '«مختصر خليل»',
        ),
        LearnBlock(
          'مغرب — غروب آفتاب، ایک تنگ وقت (مشہور)',
          '«ليس لها إلا وقت واحد لا تؤخر عنه»',
          'مغرب غروب آفتاب سے شروع ہوتی ہے — یعنی پورے قرص شمس کا غائب ہونا۔ '
              'مشہور پر اس کا ایک ہی تنگ وقت ہے، تقریباً اس کی شرائط کے بعد '
              'اس کی ادائیگی کے بقدر؛ اس سے تاخیر جائز نہیں۔ دوسرا معروف قول '
              '(اشہب، باجی کا اختیار) اسے سرخ شفق کے خاتمے تک پھیلاتا ہے — '
              'یہاں یہ متبادل کے طور پر نوٹ شدہ ہے، ڈیفالٹ نہیں۔',
          'D1 §2.6 · D4 A3.4 · A6.7',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'عشاء — سرخ شفق سے رات کے پہلے ثلث تک',
          '«غيبوبة الشفق والشفق الحمرة الباقية في المغرب من بقايا شعاع '
              'الشمس… ولا ينظر إلى البياض في المغرب»',
          'عشاء سرخ شفق کے غائب ہونے سے شروع ہوتی ہے — اس کے بعد باقی ماندہ '
              'سفیدی کا اعتبار نہیں، حنفی سفید شفق کے قول کے خلاف۔ اس کا '
              'وقتِ اختیار رات کے پہلے ثلث تک ہے، خام غروب سے فجر صادق تک '
              'ناپا ہوا (ابن حبیب کا قول: آدھی رات تک)۔ وقتِ ضرورت فجر تک '
              'رہتا ہے، اور مغرب و عشاء آخری چار رکعتوں میں مشترک ہیں۔',
          'D1 §2.7 · D4 A3.5 · A2.4',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'دو درجے: مختار اور ضروری',
          '«والضروري بعد المختار للطلوع في الصبح وللغروب في الظهرين وللفجر '
              'في العشاءين» — «وَأَثِمَ إلَّا لِعُذْرٍ»',
          'وقتِ مختار پسندیدہ وقت ہے؛ اس کے بعد آنے والا وقتِ ضرورت عذر '
              'والوں کے لیے ہے۔ خلیل: جو بغیر عذر کے اس میں تاخیر کرے وہ '
              'گناہ گار ہے (وأثم الا لعذر)۔ اس میں بھی نماز ایک رکعت سے پائی '
              'جاتی ہے، اور سب ادا شمار ہوتا ہے۔ مختار/ضروری کی جوڑی خلیل '
              'کی ترتیب ہے — مدونہ کے دور میں «وقت کا اول/آخر» اور «لا بأس» '
              'جیسی ابتدائی اصطلاحات تھیں۔',
          'D1 §2.2 · §2.8 · D4 A4.1 · A2.6',
          source: '«مختصر خليل»',
        ),
      ],
    ),
    'eighteen': LearnContent(
      '18° کیوں؟',
      '18° کے عدد کی کلاسیکی فلکیاتی بنیاد ہے — لیکن کسی کلاسیکی مالکی نص '
          'میں فجر کا زاویہ مقرر نہیں۔ دونوں باتیں اس حصے میں ہیں۔',
      [
        LearnBlock(
          'حبش الحاسب المروزی (وفات ~227ھ)',
          '«قد علم بالتجربة أن انحطاط الشمس عن الأفق في أول الصبح الكاذب '
              'وفي آخر الشفق ثماني عشرة درجة»',
          '18° کی سب سے قدیم ثابت ذکر: بغداد کے فلکیات دان حبش الحاسب اپنی '
              'ایک زیج میں sin(18°) استعمال کر کے طلوع فجر اور خاتمہ شفق '
              'معلوم کرنے کا طریقہ دیتے ہیں — مخطوطہ برلن میں ہے۔ بہاء الدین '
              'العاملی بھی اسی 18° کو «تجربے سے معلوم شدہ» لکھتے ہیں۔ یہ ایک '
              'فلکیات دان کا مشاہداتی پیمانہ ہے — مالکی حکم نہیں۔',
          'D1 §4.1 · D4 D3.4',
          source: '«تشريح الأفلاك»',
        ),
        LearnBlock(
          'ابن السمہ المہری (وفات 426ھ)',
          '',
          'اسطرلاب کے استعمال پر اپنی کتاب کے باب 74 میں اندلسی مہندس ابن '
              'السمہ ہدایت دیتے ہیں: شفق کے خاتمے اور فجر کے طلوع کا وقت '
              'معلوم کرنے کے لیے سورج کی جگہ کے نظیر کو 18ویں مقنطرے پر '
              'رکھو — «اور حبش کے مطابق (وفات 250ھ) 16ویں مقنطرے پر»۔ زاویے '
              'کا عدد ابتدائی مسلمان فلکیات دانوں کے ہاں آلے کی عملی ترتیب '
              'تھی۔',
          'D1 §4.1 · D4 D3.4',
        ),
        LearnBlock(
          'قرون وسطیٰ کے 16°–20° پیمانے',
          '',
          'قرون وسطیٰ کے فلکیات دان ایک مقرر عدد نہیں بلکہ پیمانوں کا ایک '
              'خاندان استعمال کرتے تھے: ابن یونس 20°/16°، مصری فلکیات دان '
              '19°/17°، اور 18°/18° عام (King/Ilyas، ثانوی خلاصہ)۔ قاضی زادہ '
              'نوٹ کرتے ہیں کہ تقریباً 72° عرض سے نیچے گرمیوں کے انقلاب پر '
              'شفق فجر کاذب سے مل جاتی ہے — قطبی عرض البلد کے مسئلے کی '
              'کلاسیکی بیان۔',
          'D1 §4.1 · D4 D3.3',
        ),
        LearnBlock(
          'دیانت دار حد: فقہ میں کوئی زاویہ نہیں',
          '',
          'کسی کلاسیکی مالکی نص میں فجر صادق کے لیے شمسی انخفاض کا کوئی '
              'زاویہ مقرر نہیں — تعریف محض بصری ہے: افقی فجر کا پھٹنا یہاں '
              'تک کہ افق کو گھیر لے۔ MWL 1986 کنونشن کے 18°/17° اور ہر ادارہ '
              'جاتی پری سیٹ شرعی علامات کے جدید عملی تخمینے ہیں — سوفٹ ویئر '
              'کنونشن، کبھی مالکی حکم نہیں۔',
          'D1 §4.1 · D4 NEG-1 · C7.1',
        ),
      ],
    ),
    'dawn': LearnContent(
      'فجر کے مشاہداتی مطالعات',
      'فجر صادق کے شمسی انخفاض کی جدید پیمائشیں۔ سائنس کنونشنز کو آگاہ کرتی '
          'ہے — فقہ نہیں ہے۔',
      [
        LearnBlock(
          'UKM، ملائیشیا (2018)',
          '',
          'قاسم بہالی وغیرہ، Jurnal Sains Malaysiana 47(11) 2018: DSLR '
              'کیمرے سے فجر صادق کے انخفاض کی پیمائش — −14.5° سے −18.5°، '
              'اوسط −16.67°، اور تجویز کردہ عملی قدر −17.0°۔ فجر کا ہر عام '
              'استعمال شدہ زاویہ اسی مشاہدہ شدہ حد کے اندر یا قریب ہے۔',
          'D1 §4.1 · D4 D3.1',
        ),
        LearnBlock(
          'UIN جکارتہ (2018)',
          '',
          'SQM فوٹومیٹر کے مطالعے میں فجر صادق صرف 15°–18° پر محسوس ہوئی۔ '
              'انڈونیشیا کا سرکاری 20° معیار وہاں کوئی قابل مشاہدہ فجر نہیں '
              'دکھاتا — یہ 8–20 منٹ جلد ہے۔ ایک بلند زاویے کو مستقل مقرر '
              'کرنے کے خلاف تنبیہ۔',
          'D1 §4.1 · D4 D3.2',
        ),
        LearnBlock(
          'شہروں میں فجر دیر سے کیوں نظر آتی ہے',
          '',
          'شیخ عبد السلام الشویعر: فجر صادق افقی سفیدی ہے، فجر کاذب کے عمودی '
              'ستون کے برعکس؛ مصنوعی روشنی کی وجہ سے شہروں میں فجر صادق نظر '
              'نہیں آتی — قصبوں کے قریب یا بجلی والے کھیتوں میں بھی نہیں — '
              'صرف وہاں جہاں روشنی کی آلودگی ختم ہو جائے۔ محتاط (دیر سے) '
              'فجر کے تخمینوں کی ایک وجہ۔',
          'Tawqit Instagram review, Post 3 · D1 §4.1',
        ),
      ],
    ),
    'faq': LearnContent(
      'عام سوالات',
      'ایسے جوابات جو تحقیقی شواہد کے اندر رہتے ہیں — کنونشنز کو ہمیشہ '
          'کنونشن ہی کہا گیا ہے۔',
      [
        LearnBlock(
          'کیا نماز کے اوقات حساب سے نکالے جا سکتے ہیں یا انہیں آنکھ سے دیکھنا ضروری '
              'ہے؟',
          '',
          'حساب جائز ہے — اور یہ کوئی جدید سہولت نہیں۔ مالکی مذہب نے یہ بات سات صدیاں '
              'پہلے صاف کہہ دی تھی۔ قرافی (متوفی 684ھ) نے الذخیرہ میں لکھا: "مجھے نماز کے '
              'اوقات کو حساب سے (پانی اور ریت کے آلات وغیرہ سے) ثابت کرنے میں کوئی اختلاف '
              'معلوم نہیں — تمام زمانوں میں بڑے شہروں کے لوگ سردیوں میں بارش اور بادلوں کے '
              'وقت یہی کرتے آئے ہیں۔" انہوں نے الفروق میں حد بھی واضح کی: نماز کے اوقات کا '
              'حساب ایک چیز ہے، رمضان کے چاند کا حساب دوسری، اور دونوں کا حکم ایک جیسا '
              'نہیں۔ اس ایپ میں ہر وقت آپ کے فون پر انہی فلکی علامات سے حساب کیا جاتا ہے — '
              'اور طریقہ آپ کو دکھایا جاتا ہے، چھپ کر بدلا نہیں جاتا۔',
          'D1 §4.1 · D4 (verification 2026-10-18: al-Dhakhira, Kitab al-Siyam)',
          source: '«الذخيرة»',
        ),
        LearnBlock(
          'حساب شدہ ٹائم ٹیبل پر اعتماد کیوں کیا جائے؟',
          '',
          'کیونکہ مذہب ماہر وقت شناس پر اعتماد کرتا ہے۔ برزلی — جنہیں حطاب نے مواہب '
              'الجلیل میں نقل کیا — مالکی مذہب کا ظاہر قول بیان کرتے ہیں: عادل اور ماہر '
              'مؤذن کی بات مطلقاً قبول کی جاتی ہے، بادل ہوں یا صاف آسمان، نماز ہو یا روزہ، '
              'جب وہ آلات — ریت کی گھڑیاں، فلکیاتی گھڑیاں وغیرہ — سے اوقات جانتا ہو۔ ابن '
              'یونس اور دیگر ائمہ نے کتاب الصوم میں اس عموم کی صراحت کی ہے۔ ٹائم ٹیبل اتنا '
              'ہی اچھا ہوتا ہے جتنا اس کے پیچھے کا علم: یہ ایپ آپ کو طریقہ، زاویے اور ہر '
              'وقت کے شواہد دکھاتی ہے، تاکہ آپ سے کبھی کسی بند ڈبے پر اعتماد کرنے کو نہ کہا '
              'جائے۔',
          'D1 §4.1 · D4 (verification 2026-10-18: Mawahib al-Jalil, bab mawaqit '
              'al-salat)',
          source: '«مواهب الجليل»',
        ),
        LearnBlock(
          'کیا نماز کے لیے فلکیات کا استعمال نجومیت (astrology) ہے؟',
          '',
          'نہیں — اور فقہاء نے یہ حد بہت پہلے کھینچ دی تھی۔ اخضری (متوفی 953ھ) اپنی '
              'فلکیاتی منظومہ السراج کا آغاز اسی سے کرتے ہیں: وہ علم جس سے اوقات، فجر، قبلہ '
              'اور گھنٹے معلوم ہوں "انتہائی عزیز اور بہترین راستوں میں سے ہے" — جبکہ غیب کا '
              'دعویٰ کرنے والی چیز "بلا شک حرام" ہے۔ نماز کے اوقات معلوم کرنے والی فلکیات '
              'ایک سیکھا ہوا فن ہے؛ غیب کا دعویٰ کرنے والی تنجیم بالکل دوسری چیز ہے۔ (اوپر '
              'عربی اشعار توقیت کی تعلیمی سلائیڈز سے مخطوطی روایت کے مطابق ہیں؛ لفظ بہ لفظ '
              'تصدیق کے لیے کوئی مطبوعہ نسخہ دستیاب نہ ہو سکا۔)',
          'D1 §4.1 · D4 (al-Siraj attribution verified 2026-10-18; verses per '
              'manuscript tradition)',
          source: '«السراج في علم الفلك»',
        ),
        LearnBlock(
          'فجر کے لیے 18 ڈگری کیوں؟',
          '',
          'کیونکہ مسلمان ماہرینِ فلکیات اور موقتین کی نسلوں نے اسے قابلِ مشاہدہ علامت — '
              'صبحِ صادق — کا عملی تخمینہ قرار دیا۔ بیرونی القانون المسعودی میں صاف کہتا '
              'ہے: صناعِ فن نے مشاہدہ کر کے "اس کے وقت کے قوانین سے یہ حاصل کیا کہ جب سورج '
              'انحطاط میں افق سے نیچے اٹھارہ ڈگری ہو تو یہی مشرق میں طلوعِ فجر اور مغرب میں '
              'مغیبِ شفق کا وقت ہے" — اور ساتھ ہی فوراً یہ بھی کہ یہ "کوئی طے شدہ چیز '
              'نہیں،" کیونکہ ان میں سے بعض کے نزدیک سترہ ڈگری تھا (قانون 2/948-949، '
              'حیدرآباد ایڈیشن)۔ اپنی تحدید میں وہی بات دوسری طرف سے: صناع کے نزدیک سترہ '
              'ڈگری، بعض کے نزدیک اٹھارہ — دونوں "تجربے اور بار بار کے امتحان سے ماخوذ"۔ اس '
              'کے ساتھ دو دیانت داریاں ضروری ہیں۔ اول، یہ کبھی متفق علیہ نہیں رہا: کلاسیکی '
              'کتابوں میں 16 سے 20 ڈگری تک کے اقوال ہیں — 17 اور 19 ڈگری بھی مستعمل رہے، '
              'اور کسی کلاسیکی مالکی نص نے کوئی ڈگری مقرر نہیں کی — زاویہ علامت کا تخمینہ '
              'ہے، حکم نہیں۔ دوم، یہ حضرات فلکیات دان تھے، فقہاء نہیں: ان کا اختیار '
              'مشاہداتی ہے، اور علامت کا فقہی فیصلہ فقہاء کے پاس رہتا ہے۔ اس ایپ کا طے شدہ '
              'پروفائل (رابطہ عالم اسلامی، 18°/17°) 1986ء کے رابطہ کے فقہی مجمع کے فیصلے کی '
              'پیروی کرتا ہے؛ باقی پروفائلز اپنی اپنی کنونشنز دیانت سے بتاتے ہیں۔',
          'D1 §4.2 · Biruni Qanun 2/948-949 & Tahdid (verbatim-verified); King 1973 '
              '(Habash/Nayrizi "probably"; Battani denial); Tusi Muiniyya 18°',
        ),
        LearnBlock(
          'مختلف ممالک مختلف زاویے کیوں استعمال کرتے ہیں؟',
          '',
          'کیونکہ زاویہ ایک ہی آسمان کو پڑھنے کی قومی کنونشن ہے، اس کے بارے میں کوئی '
              'حکم نہیں۔ مراکش کے جدول 19°/17° پر چلتے ہیں (ثانوی ذرائع میں مذکور — وزارتِ '
              'اوقاف کا اپنا طریقہ شائع شدہ نہیں)؛ مصر 19.5°/17.5° پر؛ سعودی عرب فجر کے لیے '
              '18.5° اور عشاء کے لیے 90 منٹ کے وقفے پر؛ ملائیشیا اور انڈونیشیا 20°/18° پر؛ '
              'اور مغربی افریقہ کا بڑا حصہ، موریتانیہ سمیت، رابطہ عالم اسلامی کے 18°/17° '
              'پر۔ ان میں سے کوئی عدد فقہ نہیں — فقہ صبحِ صادق اور شفقِ احمر کے غائب ہونے '
              'کی بات کرتی ہے، جسے مشاہدہ کرنے والے ہمیشہ جگہ اور موسم کے لحاظ سے قدرے '
              'مختلف پڑھتے آئے ہیں۔ یہ ایپ اہم کنونشنز کو نامزد پروفائلز کے طور پر ان کے '
              'ماخذ کے ساتھ پیش کرتی ہے، تاکہ آپ ہمیشہ جانیں کہ آپ کس کنونشن پر نماز پڑھ '
              'رہے ہیں۔ (ایک تنبیہ: توقیت کے نقشے کا نعرہ — "جس ریاست کی علمی روایت مضبوط، '
              'وہ 18 ڈگری سے قریب" — ناشر کی اپنی بلاغت ہے، کوئی علمی نتیجہ نہیں۔)',
          'D1 §4.2 · D4 (Morocco secondary-only per pass-2 C) · Tawqit angles map',
        ),
        LearnBlock(
          'ایپس کے اوقات آپس میں کیوں مختلف ہوتے ہیں؟',
          '',
          'ناموں کو ایک طرف رکھ کر دیکھیں تو عام طور پر ایک ہی فقہ ملتی ہے، بس سافٹ '
              'ویئر کی کنونشنز الگ الگ ہیں: ایک ایپ فجر 18° پر کھولتی ہے، دوسری 20° پر؛ '
              'ایک احتیاطی منٹ شامل کرتی ہے، دوسری نہیں؛ اور قطبی عرض البلد کا معاملہ '
              'ہر ایک کا اپنا۔ دو باتیں توجہ کی مستحق ہیں: پری سیٹ کے نام ہمیشہ وہ نہیں '
              'ہوتے جو وہ دعویٰ کرتے ہیں — مثلاً UOIF کا 12°/12° لیبل 15°/15° کے دعوے '
              'کے خلاف متنازع ہے۔ اور جہاں طریقۂ حساب ہی شائع شدہ نہ ہو، جیسے Muslim '
              'Pro اور IslamicFinder، وہاں ان کے جدول کسی اور کے اوقات کی جانچ کے لیے '
              'استعمال نہیں ہو سکتے۔',
          'D1 §4.6–4.7 · D4 NEG-5 · C3.2',
        ),
        LearnBlock(
          'اگر میں ایسی جگہ رہتا ہوں جہاں عشاء یا فجر کبھی داخل نہ ہو تو کیا کروں؟',
          '',
          'شمال کی دور دراز بستیوں میں گرمیوں میں شفقِ احمر فجر سے پہلے کبھی غائب نہیں '
              'ہوتا — تو عشاء کب ہوگی اور روزہ کب شروع ہوگا؟ فاس کے موقت العلمی نے یہی سوال '
              'شہر کے شیخ الجماعت ابن الخیاط الزکاری (متوفی 1343ھ/1924ء) کے سامنے رکھا۔ ان '
              'کے جواب نے "تیسرے قول" کو اختیار کیا: رات نصف پر تقسیم ہوتی ہے — اس کا پہلا '
              'نصف شفق کا ہے، دوسرا فجر کا؛ عشاء اس وقت واجب ہوتی ہے جب سورج کی روشنی کا '
              'اثر مغرب سے مشرق کی طرف منتقل ہو؛ پھر فجر عشاء کے بعد پڑھی جاتی ہے، ترتیب '
              'قائم رکھتے ہوئے؛ اور روزہ مقامی دن کے حساب سے ہوتا ہے، "رات تک روزہ پورا '
              'کرو" (قرآن 2:187)، چاہے دن کتنا ہی طویل ہو۔ سوال میں ایک قدیم روایت بھی نقل '
              'ہوئی تھی — قرافی نے الیوافیت میں امام الحرمین (جوینی) سے نقل کیا: عشاء اس '
              'وقت تک نہ پڑھی جائے جب تک شفق غائب نہ ہو، اور یہ قضا نہیں کیونکہ اس کا وقت '
              'باقی ہے؛ اور فجر قریبی ملک کی فجر کے حساب سے ہوگی۔ یہ فاس کی توقیت روایت کے '
              'ایک مفتی کا مدلل فتویٰ ہے — مذہب کا مشہور مسلک نہیں۔ اسی مسئلے کا اس ایپ کا '
              'جواب اس کا high-latitude fallback chooser ہے: جب شفق کے زاویے ناقابلِ رسائی '
              'ہوں تو وہ رات ہی سے تخمینہ لگاتا ہے (نصفِ شب وغیرہ نامزد کنونشنز) اور صاف '
              'بتا دیتا ہے کہ کون سی فعال ہے — فتوے کے دل میں جو نصفِ شب کی تقسیم ہے وہ '
              '"middle of the night" کنونشن کی قریبی رشتہ دار ہے۔',
          'D1 §4.5 · Tawqit Fez fatwa series (identities & al-Yawaqit correction per '
              'strand B 2026-10-18)',
        ),
        LearnBlock(
          'گرمیوں میں «ترجیحی خاتمہ» کا نشان عشاء سے پہلے کیوں آ سکتا ہے؟',
          '',
          'فرانس جیسے بلند عرض البلد پر گرمیوں کی بعض راتوں میں شفق — عشاء کی قدرتی '
              'علامت — رات کے پہلے ثلث کے گزرنے کے بعد بھی باقی رہتی ہے۔ ترجیحی مدت تو '
              'پہلے ثلث پر ختم ہوتی ہے، اس لیے اس کا حسابی خاتمہ کبھی خود عشاء کے وقت '
              'سے پہلے بھی آ سکتا ہے۔ 17 مئی کو پیرس میں مثلاً: مغرب 21:31، پہلے ثلث کا '
              'خاتمہ 23:30، عشاء 23:51، فجر 03:30۔ چاروں مذاہب کا متفقہ موقف یہ ہے کہ '
              'آدھی رات گزر جانے پر بھی اصل عشاء کے وقت کا انتظار کیا جائے؛ امام ابن '
              'حجر کے الفاظ میں، متبادل علامت کا اعتبار وہاں ہوتا ہے جہاں اصل علامت '
              'موجود نہ ہو، نہ کہ جہاں وہ موجود ہو۔',
          'Tawqit Instagram review, Post 1 · D1 §2.7',
        ),
        LearnBlock(
          'گرمیوں میں عشاء آدھی رات کے بعد کیوں آتی ہے؟',
          '',
          'دو بالکل غیر دینی وجوہات سے: ٹائم زون اور ڈے لائٹ سیونگ۔ مثلاً فرانس اپنے '
              'شمسی وقت سے پورا ایک گھنٹہ آگے جیتا ہے — 1940ء کی جنگی جرمن مسلط کردہ گھڑی '
              'جو کبھی واپس نہ ہوئی — اور پھر گرمیوں میں ڈے لائٹ سیونگ کا ایک گھنٹہ اور '
              'بڑھا دیتا ہے (1976ء سے)۔ اس لیے گھڑی کے حساب سے عشاء رات کے 1 بجے بھی آ سکتی '
              'ہے جبکہ سورج ابھی وہیں ہے جہاں پہلے آدھی رات ہوتی تھی۔ دینی علامات اپنی جگہ '
              'ہیں؛ گھڑی بدلی ہے۔ دیر سے نظر آنے والے ٹائم ٹیبل کو دیر سے دین نہ سمجھو: '
              'چاروں مذاہب متفق ہیں کہ آدھی رات گزر جانے پر بھی اصل عشاء کے وقت کا انتظار '
              'کیا جائے۔',
          'D1 §4.5 · Tawqit summer-midnight slide (history: general record)',
        ),
        LearnBlock(
          'گرمیوں میں نماز کے اوقات بہت دیر سے آتے ہیں — کیا کروں؟',
          '',
          'بہت دیر سے آنے والے گرمائی اوقات سے نمٹنے کے لیے توقیت کی سلائیڈز چار درجہ '
              'بند اقدامات تجویز کرتی ہیں — یہ رہنمائی ہے، اس ایپ کا فتویٰ نہیں۔ (1) حتی '
              'الامکان وقت کے شروع میں نماز پڑھو — "نماز اپنے اول وقت میں" (ام فروہ کی '
              'حدیث، سنن ابی داؤد #426؛ اس کی سند ضعیف قرار دی گئی ہے، اگرچہ اس کا مفہوم '
              'صحیحین میں ابن مسعود کی حدیث سے ثابت ہے)۔ (2) اگر نہ ہو سکے تو فجر کو اسفار '
              '(اجالے) کی طرف مؤخر کرو — جو خود صبح کے مستحب وقت کا مشہور خاتمہ ہے۔ سلائیڈز '
              'اسے ابن حبیب کے الفاظ میں دیتی ہیں، ابن ابی زید کی النوادر میں معاذ سے: "جب '
              'گرمی آئے تو صبح میں اسفار کرو کیونکہ رات مختصر ہے اور لوگ سوئے ہوتے ہیں؛ '
              'عشاء میں تاخیر نہ کرو کیونکہ رات مختصر ہے، اور اسے شفق کے غائب ہونے سے پہلے '
              'نہ پڑھو" — یہ الفاظ ہمیں کسی مطبوعہ نسخے میں نہ مل سکے، اس لیے اس قدم کو اس '
              'کے مضمون کی بنا پر لو، جس کی تائید مذہب کا اپنا قاعدہ کرتا ہے۔ (3) اگر یہ '
              'بھی نہ ہو سکے تو عشاء کو فجر سے بالکل پہلے تک مؤخر کر دو — کیونکہ "نماز میں '
              'کوتاہی یہی ہے کہ اسے اگلی نماز کے وقت تک مؤخر کر دیا جائے" (ابو ہریرہ کا '
              'قول؛ نبی ﷺ کے الفاظ کے طور پر یہ صحیح مسلم میں ابو قتادہ سے آتا ہے)۔ (4) '
              'آخری چارہ کار کے طور پر مغرب اور عشاء جمع کر لو: اشہب بغیر کسی خاص سبب کے دو '
              'نمازیں جمع کرنے کی اجازت دیتے تھے — یہ ایک حقیقی تسلیم شدہ داخلی اختلاف ہے، '
              'باجی اور ابن رشد نے خلیل کی التوضیح کے واسطے سے نقل کیا (جیسے حطاب نے درج '
              'کیا) — ابن عباس کی حدیث کی بنیاد پر کہ نبی ﷺ نے "بغیر خوف، سفر یا بارش کے" '
              'ظہر و عصر اور مغرب و عشاء جمع فرمائیں۔ چوتھے قدم کے بارے میں آنکھیں کھلی '
              'رکھو: یہ اقلیتی قول ہے، مشہور نہیں — مشہور مالکی موقف جمع کی اجازت صرف تقدیم '
              'کے ساتھ، بارش یا بیماری کے لیے دیتا ہے۔',
          'D1 §2.9 · Tawqit summer-management slide (attribution corrections per strand '
              'B 2026-10-18)',
        ),
        LearnBlock(
          'وقتِ ضرورت (ضروری) سے کیا مراد ہے؟',
          '',
          'جب ترجیحی وقت ختم ہو جائے تو عذر والوں کے لیے دروازہ بند نہیں ہوتا — اس '
              'کے بعد ضرورت کا ایک وقفہ کھلتا ہے۔ خلیل کا فرمان: ضروری مختار کے بعد آتا '
              'ہے — صبح کے لیے طلوع تک، ظہر و عصر کے لیے غروب تک، مغرب و عشاء کے لیے '
              'فجر تک۔ بغیر عذر اس میں داخل ہونا گناہ ہے، مگر اس کے اندر ایک رکعت پانے '
              'پر بھی نماز وقت پر ادا شمار ہوتی ہے۔ مشہور کے مطابق صبح بھی یہ درجہ '
              'رکھتی ہے؛ اقلیتی قول اس کے لیے ضروری نہیں مانتا۔',
          'D1 §2.8 · D4 A4.1 · A7.2',
        ),
        LearnBlock(
          'احتیاط کیا ہے؟',
          '',
          'حساب شدہ اوقات کے اوپر لگایا گیا ایک چھوٹا سا احتیاطی اضافہ — مثلاً ظہر '
              'اور مغرب پر +1 منٹ۔ اس کا تعلق احتیاط سے ہے، فقہ سے نہیں: اس ایپ میں '
              'احتیاط کا بٹن بدلنے سے فقہی حدیں اپنی جگہ رہتی ہیں۔ یہ خیال کلاسیکی '
              'روایت میں بھی موجود تھا — پہلے ہی زوالِ شرعی (قرصِ شمس کا نصف النہار سے '
              'ڈھلنا) اور زوالِ اصطلاحی (مرکزِ شمس کا گزرنا) الگ الگ تھے، تقریباً نصف '
              'درجے کا فرق، یعنی لگ بھگ دو منٹ۔',
          'D1 §4.4 · D4 A6.2',
        ),
      ],
    ),
    'glossary': LearnContent(
      'اصطلاحات',
      'اس ایپ میں استعمال ہونے والی اصطلاحات، مالکی فقہ کی زبان میں۔ تحقیق '
          'کی تنبیہ: «وقتِ فضیلت / وقتِ جواز» کی باقاعدہ جوڑی شافعی اصطلاح '
          'ہے، مالکی نہیں۔',
      [
        LearnBlock(
          'مختار (الوقت المختار)',
          '',
          'پسندیدہ یا منتخب وقت — اختیار کا وقت، جس میں نماز پڑھنا افضل ہے۔ '
              'اسے اختیاری وقت بھی کہتے ہیں۔',
          'D1 §2.2 · D4 A4.2',
        ),
        LearnBlock(
          'ضروری (الوقت الضروري)',
          '',
          'مختار کے بعد آنے والا ضرورت کا وقت، عذر والوں کے لیے؛ بغیر عذر '
              'کے اس میں تاخیر گناہ ہے۔ عذر والوں کے لیے یہ بھی ادا شمار '
              'ہوتا ہے۔',
          'D1 §2.8 · D4 A4.1',
        ),
        LearnBlock(
          'فجر صادق / فجر کاذب (الفجر الصادق / الكاذب)',
          '',
          'فجر صادق: وہ روشنی جو افقی پھیل کر افق کو گھیر لے — اسی سے صبح '
              'شروع ہوتی ہے۔ فجر کاذب: روشنی کا عمودی ستون جس میں افقی پھیلاؤ '
              'نہ ہو — اس کا کوئی اعتبار نہیں۔',
          'D1 §2.3 · D4 A3.1 · B2.2',
        ),
        LearnBlock(
          'شفق (الشفق)',
          '',
          'شفق۔ مالکی فقہ میں یہ غروب کے بعد مغرب میں باقی ماندہ سرخی ہے — '
              'اور عشاء اس کے غائب ہونے سے شروع ہوتی ہے۔ اس کے بعد کی سفیدی '
              'کا اعتبار نہیں۔',
          'D1 §2.7 · D4 A3.5',
        ),
        LearnBlock(
          'ظل زوال (ظل الزوال)',
          '',
          'زوال کے وقت موجود سایہ۔ بعد کے تمام سایوں کی پیمائش سے خارج ہے '
              '— قامت صرف اس کے بعد شمار ہوتی ہے۔ خط استوا کے علاقوں میں یہ '
              'معدوم ہو جاتا ہے اور موسم و عرض البلد کے ساتھ بدلتا ہے۔',
          'D1 §2.4 · D4 A2.1 · A6.1',
        ),
        LearnBlock(
          'اسفار (الإسفار)',
          '',
          'طلوع آفتاب سے پہلے واضح روشنی؛ صبح کے وقتِ اختیار کا خاتمہ۔ ایک '
              'مشاہدہ شدہ بصری علامت — کوئی فقہی مصدر اسے گھڑی کا وقت نہیں '
              'دیتا، اس لیے یہ صرف معلوماتی بینڈ کے طور پر دکھایا جاتا ہے، '
              'حساب شدہ وقت کے طور پر کبھی نہیں۔',
          'D1 §2.3 · D4 A2.5',
        ),
        LearnBlock(
          'اصفرار (الإصفرار)',
          '',
          'سورج کا زرد ہونا؛ عصر کے وقتِ اختیار کا خاتمہ۔ زمین اور دیواروں '
              'پر دیکھا جاتا ہے، خود سورج میں نہیں — ایک مشاہدہ شدہ بصری '
              'علامت، گھڑی کا وقت کبھی نہیں۔',
          'D1 §2.5 · D4 A6.5',
        ),
        LearnBlock(
          'غلس (الغلس)',
          '',
          'فجر سے پہلے کی تاریکی؛ اس میں صبح پڑھنا سنت ہے۔ مدونہ مدرسہ کہتا '
              'ہے: صبح غلس میں پڑھی جائے اور اس کا وقت اسفار پر ختم ہو۔',
          'D1 §2.3 · D4 A2.5',
        ),
        LearnBlock(
          'احتیاط (احتياط)',
          '',
          'حساب شدہ اوقات میں شامل احتیاطی منٹوں کا اضافہ (مثلاً ظہر/مغرب پر '
              '+1 منٹ) — ایک کنونشن، فقہ نہیں۔',
          'D1 §4.4 · D4 A6.2',
        ),
        LearnBlock(
          'مشہور (مشهور)',
          '',
          'مذہب کا معروف و معتمد قول — جہاں معروف اختلافات ہوں، ایپ ڈیفالٹ '
              'کے طور پر اسی کو استعمال کرتی ہے۔',
          'D1 §2.10 · D4 A6.7',
        ),
      ],
    ),
  },

  'ar': {
    'definitions': LearnContent(
      'الصلوات الخمس — التعريفات المالكية',
      'النصوص المالكية الكلاسيكية تعرّف أوقات الصلاة بعلامات مرئية: الفجر '
          'المنبسط، والظل المتطاول، والشمس الغائبة، والحمرة الزائلة. النصوص '
          'أدناه منقولة حرفياً من أدلة البحث.',
      [
        LearnBlock(
          'الصبح — من الفجر الصادق إلى الإسفار',
          '«أول وقتها انصداع الفجر المعترض بالضياء في أقصى المشرق ذاهبا من '
              'القبلة إلى دبر القبلة حتى يرتفع فيعم الأفق»',
          'يبدأ الصبح بالفجر الصادق — الضوء المنتشر أفقياً في أقصى المشرق '
              'حتى يعم الأفق — وينتهي وقته المختار بالإسفار البين، حين ينتشر '
              'الضوء بحيث إذا سلّم المصلي بدا حاجب الشمس. وعلى المشهور يمتد '
              'وقته الضروري إلى الطلوع؛ وقيل: لا ضروري له أصلاً.',
          'D1 §2.3 · D4 A3.1',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'الظهر — من الزوال إلى المثل الأول',
          '«الْوَقْتُ الْمُخْتَارُ لِلظُّهْرِ: مِنْ زَوَالِ الشَّمْسِ لِآخِرِ '
              'القامة بغير ظل الزوال»',
          'يبدأ الظهر بزوال الشمس عن خط وسط السماء، وينتهي وقته المختار '
              'حين يصير ظل الشيء مثله — وظل الزوال الموجود عند الزوال يُستبعد '
              'دائماً من الحساب. ويمتد وقته الضروري إلى الغروب. النص أعلاه '
              'من متن خليل هو تعريف المذهب المختصر، مُتحقق منه حرفياً من '
              'المطبوع.',
          'D1 §2.4 · D4 A4.1 · A2.1',
          source: '«مختصر خليل»',
        ),
        LearnBlock(
          'العصر — المثل الأول، إلى الاصفرار',
          '«وهو أول وقت العصر للإصفرار»',
          'يبدأ العصر حيث ينتهي الظهر: عند المثل الأول — قامة من الظل بعد '
              'ظل الزوال. ويمتد وقته المختار ما دامت الشمس بيضاء نقية؛ ونهاية '
              'المختار اصفرار الشمس، وتُعتبر الصفرة في الأرض والجدر لا في '
              'عين الشمس. والضروري إلى الغروب. وهذا هو الموضع الوحيد الذي '
              'يتطابق فيه قاعدة البرنامج (العامل 1) مع القاعدة الثابتة بالنص '
              'تماماً.',
          'D1 §2.5 · D4 A4.1 · A6.5',
          source: '«مختصر خليل»',
        ),
        LearnBlock(
          'المغرب — الغروب، وقت واحد ضيق (المشهور)',
          '«ليس لها إلا وقت واحد لا تؤخر عنه»',
          'يبدأ المغرب بالغروب — غياب جميع قرص الشمس. وعلى المشهور ليس له '
              'إلا وقت واحد ضيق، بقدر فعله بعد شروطه؛ ولا يُؤخَّر عنه. وقول '
              'ثانٍ معروف (أشهب، واختاره الباجي) يمدّه إلى مغيب الشفق الأحمر '
              '— مذكور هنا كبديل، لا كأصل.',
          'D1 §2.6 · D4 A3.4 · A6.7',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'العشاء — الشفق الأحمر، إلى الثلث الأول من الليل',
          '«غيبوبة الشفق والشفق الحمرة الباقية في المغرب من بقايا شعاع '
              'الشمس… ولا ينظر إلى البياض في المغرب»',
          'تبدأ العشاء بمغيب الشفق الأحمر — ولا يُنظر إلى البياض الباقي '
              'بعده، خلافاً لقراءة الحنفية للشفق الأبيض. وينتهي وقتها '
              'المختار بالثلث الأول من الليل، مقيساً من الغروب الخام إلى '
              'الفجر الصادق (وقول ابن حبيب: إلى منتصف الليل). والضروري إلى '
              'الفجر، ويشترك المغرب والعشاء في الأربع ركعات الأخيرة.',
          'D1 §2.7 · D4 A3.5 · A2.4',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'المرتبتان: المختار والضروري',
          '«والضروري بعد المختار للطلوع في الصبح وللغروب في الظهرين وللفجر '
              'في العشاءين» — «وَأَثِمَ إلَّا لِعُذْرٍ»',
          'الوقت المختار هو وقت الاختيار؛ والوقت الضروري الذي يليه لأهل '
              'العذر. قال خليل: من أخّر إليه بغير عذر أثم. وتُدرك الصلاة فيه '
              'بركعة، والكل أداء. وثنائية المختار/الضروري من تنظيم خليل — أما '
              'عصر المدونة فكان يستعمل ألفاظاً أقدم كـ«أول الوقت/آخره» و«لا '
              'بأس».',
          'D1 §2.2 · §2.8 · D4 A4.1 · A2.6',
          source: '«مختصر خليل»',
        ),
      ],
    ),
    'eighteen': LearnContent(
      'لماذا 18°؟',
      'لرقم 18° أصل فلكي كلاسيكي — لكن لا نص مالكي كلاسيكي يحدد الفجر بزاوية '
          'درجية. الحقيقتان معاً في هذا القسم.',
      [
        LearnBlock(
          'حبش الحاسب المروزي (ت. ~227هـ)',
          '«قد علم بالتجربة أن انحطاط الشمس عن الأفق في أول الصبح الكاذب '
              'وفي آخر الشفق ثماني عشرة درجة»',
          'أقدم ذكر ثابت لقيمة 18°: في أحد أزياجه يعطي الفلكي البغدادي حبش '
              'الحاسب طريقةً تستعمل sin(18°) لمعرفة طلوع الفجر ومغيب الشفق — '
              'والمخطوطة في برلين. وسجّل بهاء الدين العاملي القيمة نفسها على '
              'أنها معلومة «بالتجربة المتكررة». معامل رصد فلكي — لا حكم '
              'مالكي.',
          'D1 §4.1 · D4 D3.4',
          source: '«تشريح الأفلاك»',
        ),
        LearnBlock(
          'ابن السمح المهري (ت. 426هـ)',
          '',
          'في كتابه في استعمال الأسطرلاب، الباب 74، يعلّم المهندس الأندلسي '
              'ابن السمح: لمعرفة ساعة مغيب الشفق وطلوع الفجر، ضع نظير موضع '
              'الشمس على المقنطرة الثامنة عشرة — «وعلى قول حبش (ت. 250هـ) على '
              'السادسة عشرة». كانت القيمة الدرجية إعداداً عملياً للآلة عند '
              'الفلكيين المسلمين الأوائل.',
          'D1 §4.1 · D4 D3.4',
        ),
        LearnBlock(
          'مدى 16°–20° في العصور الوسطى',
          '',
          'استعمل فلكيو العصور الوسطى عائلة من المعاملات لا قيمة واحدة '
              'ثابتة: ابن يونس 20°/16°، وفلكيو مصر 19°/17°، و18°/18° شائعاً '
              '(كينغ/إلياس، ملخص ثانوي). ولاحظ قاضي زاده أنه دون عرض ~72° '
              'يتصل الشفق بالفجر الكاذب عند الانقلاب الصيفي — الصياغة '
              'الكلاسيكية لمشكلة الشفق في العروض العالية.',
          'D1 §4.1 · D4 D3.3',
        ),
        LearnBlock(
          'الحد الصادق: لا زاوية في الفقه',
          '',
          'لم يذكر أي نص مالكي كلاسيكي زاوية انخفاض شمسية للفجر الصادق — '
              'الوصف بصري محض: انصداع الفجر المعترض حتى يعم الأفق. فقيم '
              '18°/17° في عرف رابطة العالم الإسلامي 1986، وكل الأعراف '
              'المؤسسية، تقديرات تشغيلية حديثة للعلامات الشرعية — عرف برمجي، '
              'وليست حكماً مالكياً أبداً.',
          'D1 §4.1 · D4 NEG-1 · C7.1',
        ),
      ],
    ),
    'dawn': LearnContent(
      'دراسات رصد الفجر',
      'قياسات حديثة لانخفاض الفجر الصادق الشمسي. العلم يُرشد الأعراف — وهو '
          'ليس فقهاً.',
      [
        LearnBlock(
          'UKM، ماليزيا (2018)',
          '',
          'قاسم بهالي وآخرون، Jurnal Sains Malaysiana 47(11) 2018: قياس '
              'بكاميرا DSLR لانخفاض الفجر الصادق — من −14.5° إلى −18.5°، '
              'والمتوسط −16.67°، مع قيمة عملية مقترحة −17.0°. كل زاوية فجر '
              'شائعة الاستعمال تقع داخل هذا المدى المرصود أو قربه.',
          'D1 §4.1 · D4 D3.1',
        ),
        LearnBlock(
          'UIN جاكرتا (2018)',
          '',
          'دراسة بمقياس SQM: لا يُرصد الفجر الصادق إلا عند 15°–18°. المعيار '
              'الإندونيسي الرسمي 20° لا يُرصد عنده فجر — إنه مبكر بـ8–20 '
              'دقيقة. تحذير من تثبيت زاوية عالية واحدة.',
          'D1 §4.1 · D4 D3.2',
        ),
        LearnBlock(
          'لماذا يُرى الفجر متأخراً في المدن',
          '',
          'الشيخ عبد السلام الشويعر: الفجر الصادق هو البياض الأفقي، مقابل '
              'العمود الرأسي للفجر الكاذب؛ وبسبب الإضاءة الاصطناعية لا يُرى '
              'الفجر الصادق في المدن — ولا حتى قرب القرى أو في المزارع '
              'المكهربة — إلا حيث يزول التلوث الضوئي. سبب يدعو لتقديرات فجر '
              'حذرة (متأخرة).',
          'Tawqit Instagram review, Post 3 · D1 §4.1',
        ),
      ],
    ),
    'faq': LearnContent(
      'أسئلة شائعة',
      'أجوبة تبقى داخل أدلة البحث — والأعراف تُسمّى أعرافاً دائماً.',
      [
        LearnBlock(
          'هل يجوز حساب أوقات الصلاة أم يجب ترقبها بالعين؟',
          '',
          'يجوز حسابها — وليس هذا تسهيلا عصريا. قال المذهب المالكي ذلك صراحة قبل سبعة '
              'قرون. قال القرافي (ت 684هـ) في الذخيرة: «لا أعلم خلافا في إثبات أوقات الصلاة '
              'بالحساب في الآلات بالماء والرمل وغيرهما، وعلى ذلك أهل الأمصار في سائر '
              'الأعصار زمن الشتاء عند الأمطار والغيوم». وفرّق في الفروق بين حساب أوقات '
              'الصلاة وحساب هلال رمضان، فلا يقاس أحدهما على الآخر. في هذا التطبيق تحسب كل '
              'الأوقات على هاتفك من العلامات الفلكية نفسها، والطريقة معلنة لك لا مخفاة.',
          'D1 §4.1 · D4 (verification 2026-10-18: al-Dhakhira, Kitab al-Siyam)',
          source: '«الذخيرة»',
        ),
        LearnBlock(
          'لماذا أثق بجدول محسوب؟',
          '',
          'لأن المذهب يثق بالمؤقت العارف. قال البرزلي — ونقله الحطاب في مواهب الجليل — '
              'إن ظاهر المذهب قبول قول المؤذن العدل العارف مطلقا: في الغيم والصحو، في '
              'الصلاة والصوم، إذا كان عارفا بالأوقات بالآلات كالرمليات والمنقلات وغيرها. '
              'وقد نص ابن يونس وغيره على هذا العموم في كتاب الصوم. والجدول إنما يكون بقدر '
              'العلم الذي وراءه: هذا التطبيق يريك الطريقة والزوايا والدليل على كل وقت '
              'يعرضه، فلا يطلب منك أبدا أن تثق بصندوق مغلق.',
          'D1 §4.1 · D4 (verification 2026-10-18: Mawahib al-Jalil, bab mawaqit '
              'al-salat)',
          source: '«مواهب الجليل»',
        ),
        LearnBlock(
          'هل استعمال الفلك لأوقات الصلاة تنجيم؟',
          '',
          'لا — وقد رسم الفقهاء هذا الحد منذ زمن بعيد. يفتتح الأخضري (ت 953هـ) منظومته '
              'الفلكية السراج به: العلم الذي تدرى به الأوقات والفجر والقبلة والساعات «علم '
              'عزيز من أجل مسلك»، أما ما يدعي الوصول إلى الغيب فـ«حرام دون ريب». فالفلك '
              'الذي يعين أوقات الصلاة صنعة متعلمة، والتنجيم الذي يدعي علم الغيب شيء آخر '
              'تماما. (الأبيات العربية أعلاه كما وردت في الشرائح التعليمية لتوقيت عن '
              'المخطوطات؛ لم يتيسر نسخة مطبوعة للتحقق اللفظي.)',
          'D1 §4.1 · D4 (al-Siraj attribution verified 2026-10-18; verses per '
              'manuscript tradition)',
          source: '«السراج في علم الفلك»',
        ),
        LearnBlock(
          'لماذا 18 درجة للفجر؟',
          '',
          'لأن أجيالا من الفلكيين والموقتين المسلمين سجلوها تقديرهم العملي للعلامة '
              'المشاهدة — الفجر الصادق. يقول البيروني صراحة في القانون المسعودي: إن أصحاب '
              'هذه الصناعة رصدوا "فحصلوا من قوانين وقته أن انحطاط الشمس تحت الأفق متى كان '
              'ثمانية عشر جزءا كان ذلك وقت طلوع الفجر في المشرق ووقت مغيب الشفق في المغرب" '
              '— ويضيف في الحال أنه "ليس شيئا معينا" لأن بعضهم رأى سبعة عشر جزءا (القانون '
              '2/948-949، طبعة حيدرآباد). وفي التحديد يورد الخبر من الجهة الأخرى: سبعة عشر '
              'جزءا عند أصحاب الصناعة وثمانية عشر عند بعضهم — والمقداران "مأخوذان من '
              'التجربة والامتحان المترادف". ويلزم مع هذا أمانتان. الأولى: لم يكن إجماعا قط '
              '— ففي الكتب نفسها أقوال تتراوح بين 16 و20 درجة — والسبع عشرة والتسع عشرة '
              'مستعملة بجد، ولم ينص أي متن مالكي كلاسيكي على درجة — فالزاوية تقدير للعلامة '
              'لا حكم شرعي. الثانية: هؤلاء فلكيون لا فقهاء، فحجتهم رصدية، والحكم الفقهي في '
              'العلامة للفقهاء. الملف الافتراضي في هذا التطبيق (رابطة العالم الإسلامي '
              '18/17) يتبع قرار مجمع الفقه الإسلامي 1986م؛ والملفات الأخرى تسمي عرفها '
              'بأمانة.',
          'D1 §4.2 · Biruni Qanun 2/948-949 & Tahdid (verbatim-verified); King 1973 '
              '(Habash/Nayrizi "probably"; Battani denial); Tusi Muiniyya 18°',
        ),
        LearnBlock(
          'لماذا تستعمل الدول زوايا مختلفة؟',
          '',
          'لأن الزاوية عرف وطني لقراءة السماء نفسها، وليست حكما فيها. جداول المغرب على '
              '19/17 (مذكور في مصادر ثانوية — ومنهجية وزارة الأوقاف نفسها غير منشورة)؛ ومصر '
              'على 19.5/17.5؛ والسعودية على 18.5 للفجر مع فاصل 90 دقيقة للعشاء؛ وماليزيا '
              'وإندونيسيا على 20/18؛ وكثير من غرب أفريقيا، ومنها موريتانيا، على 18/17 '
              'لرابطة العالم الإسلامي. ولا واحد من هذه الأرقام هو الفقه — فالفقه يتكلم عن '
              'الفجر الصادق ومغيب الشفق الأحمر، وهما ما اختلف القراء في رصدهما دائما '
              'باختلاف المكان والموسم. يعرض هذا التطبيق الأعراف الرئيسية ملفاتٍ مسماة مع '
              'مصادرها، لتعلم دائما بأي عرف تصلي. (تنبيه: شعار خريطة توقيت — «كلما قويت '
              'التقاليد العلمية للدولة اقتربت من 18» — بلاغة الناشر نفسه، وليس نتيجة '
              'علمية.)',
          'D1 §4.2 · D4 (Morocco secondary-only per pass-2 C) · Tawqit angles map',
        ),
        LearnBlock(
          'لماذا تختلف الأوقات بين التطبيقات؟',
          '',
          'وراء التسميات ستجد غالباً فقهاً واحداً وأعرافاً برمجية مختلفة: تطبيق '
              'يفتتح الفجر على 18° وآخر على 20°؛ هذا يضيف دقائق احتياط وذاك لا يضيف؛ '
              'وكلٌّ يعالج العروض العالية على طريقته. وأمران يستحقان الانتباه: تسميات '
              'الأعراف ليست دائماً ما تدّعيه — فتسمية UOIF بـ12°/12° مثلاً متنازع عليها '
              'مقابل دعوى 15°/15°. وحيث لا يُنشَر منهج الحساب أصلاً، كما في Muslim Pro '
              'وIslamicFinder، فلا تصلح جداولهما لاختبار جداول غيرهما.',
          'D1 §4.6–4.7 · D4 NEG-5 · C3.2',
        ),
        LearnBlock(
          'ماذا لو كنت حيث لا يأتي العشاء ولا الفجر؟',
          '',
          'في أقصى الشمال صيفا قد لا يغيب الشفق الأحمر قبل الفجر أبدا — فمتى العشاء '
              'ومتى يبدأ الصوم؟ عرض موقت فاس العلمي هذا السؤال بعينه على شيخ الجماعة '
              'بالمدينة ابن الخياط الزكاري (ت 1343هـ/1924م). فاختار جوابه "القول الثالث": '
              'ينتصف الليل — نصفه الأول للشفق ونصفه الثاني للفجر؛ ويجب العشاء حين ينتقل أثر '
              'الشمس من المغرب إلى المشرق؛ ثم يصلى الفجر بعد العشاء حفظا للترتيب؛ والصوم '
              'بالنهار المحلي ﴿ثم أتموا الصيام إلى الليل﴾ مهما طال. وقد نقل في السؤال رواية '
              'أقدم — روى القرافي في اليواقيت عن إمام الحرمين (الجويني): لا تصلى العشاء حتى '
              'يغيب الشفق ولا تكون قضاء لبقاء وقتها، ويتحرى بصلاة الصبح فجر من يليهم من '
              'البلاد. وهذه فتوى معللة لمفت من تقليد التوقيت الفاسي — ليست مشهور المذهب. '
              'وجواب هذا التطبيق عن المشكلة نفسها هو منتقي الطوارئ لخطوط العرض العليا: إذا '
              'تعذر بلوغ زوايا الشفق قدّر من الليل نفسه (منتصف الليل وغيره من الأعراف '
              'المسماة) وأخبرك صراحة أيها يعمل — وقسمة منتصف الليل في قلب الفتوى قريبة '
              'النسب من عرف «منتصف الليل».',
          'D1 §4.5 · Tawqit Fez fatwa series (identities & al-Yawaqit correction per '
              'strand B 2026-10-18)',
        ),
        LearnBlock(
          'لماذا قد تسبق علامة "نهاية المفضل" العشاء في الصيف؟',
          '',
          'في العروض العالية — كفرنسا مثلاً — يتأخر غياب الشفق، وهو العلامة '
              'الطبيعية للعشاء، أحياناً إلى ما بعد انقضاء الثلث الأول من الليل. والمدة '
              'المفضلة تنتهي عند ذلك الثلث، فيقع خاتمها المحسوب قبل وقت العشاء نفسه. '
              'ففي باريس يوم 17 مايو: المغرب 21:31، ونهاية الثلث الأول 23:30، والعشاء '
              '23:51، والفجر 03:30. والمعتمد عند المذاهب الأربعة انتظار وقت العشاء '
              'الحقيقي ولو جاوز منتصف الليل؛ فكما قال الإمام ابن حجر، لا يُنظر في علامة '
              'بديلة إلا حيث تغيب العلامة الأصلية، لا حيث تكون حاضرة.',
          'Tawqit Instagram review, Post 1 · D1 §2.7',
        ),
        LearnBlock(
          'لماذا يأتي العشاء بعد منتصف الليل صيفا؟',
          '',
          'لسببين لا علاقة لهما بالدين: المناطق الزمنية والتوقيت الصيفي. ففرنسا مثلا '
              'تعيش متقدمة ساعة كاملة على وقتها الشمسي — فرض ألماني زمن الحرب سنة 1940م لم '
              'يلغ قط — ثم تضيف ساعة أخرى كل صيف للتوقيت الصيفي (منذ 1976م). فبالساعة قد '
              'يأتي العشاء الواحدة ليلا بينما الشمس لم تتجاوز بعد موضع منتصف الليل القديم. '
              'العلامات الدينية لم تتحرك؛ الساعة هي التي تحركت. فلا تحسبن جدولا متأخر '
              'المظهر دينا متأخرا: المذاهب الأربعة متفقة على انتظار وقت العشاء الحقيقي ولو '
              'جاوز منتصف الليل.',
          'D1 §4.5 · Tawqit summer-midnight slide (history: general record)',
        ),
        LearnBlock(
          'أوقات الصلاة متأخرة جدا في الصيف — ماذا أفعل؟',
          '',
          'تقترح شرائح توقيت أربع خطوات متدرجة لمواجهة تأخر الأوقات الصيفية — إرشاد '
              'عملي لا فتوى من هذا التطبيق. (1) صل في أول الوقت ما استطعت — «الصلاة في أول '
              'وقتها» (حديث أم فروة، سنن أبي داود رقم 426؛ سنده ضعيف، ومعناه ثابت بحديث ابن '
              'مسعود في الصحيحين). (2) فإن لم تقدر فأخر الفجر إلى الإسفار — وهو نفسه نهاية '
              'الوقت المختار للصبح في المشهور. تورد الشرائح ذلك بلفظ ابن حبيب — رواه ابن '
              'أبي زيد في النوادر عن معاذ — «وإذا كان الصيف فأسفر بالصبح فإن الليل قصير '
              'والناس ينامون، ولا تعتم بالعشاء فإن الليل قصير، ولا تصلها قبل الشفق» — ولم '
              'نقف على هذا اللفظ في نسخة مطبوعة، فخذ بالخطوة لمضمونها الذي يؤيده قاعد '
              'المذهب نفسه. (3) فإن تعذر فأخر العشاء إلى قبيل الفجر — فـ«التفريط في الصلاة '
              'أن تؤخرها إلى وقت التي بعدها» (قول أبي هريرة؛ ومرفوعا إلى النبي ﷺ من حديث '
              'أبي قتادة في صحيح مسلم). (4) وآخر الدواء الجمع بين المغرب والعشاء: أجاز أشهب '
              'الجمع بين الصلاتين لغير سبب — خلاف داخلي حقيقي معتبر، حكاه الباجي وابن رشد '
              'بواسطة توضيح خليل (كما أورده الحطاب) — لحديث ابن عباس أن النبي ﷺ جمع بين '
              'الظهر والعصر والمغرب والعشاء «في غير خوف ولا سفر ولا مطر». وكن على بينة في '
              'الخطوة الرابعة: هي قول الأقلية لا المشهور — فالمشهور المالكي لا يجيز الجمع '
              'إلا تقديما لعذر المطر أو المرض.',
          'D1 §2.9 · Tawqit summer-management slide (attribution corrections per strand '
              'B 2026-10-18)',
        ),
        LearnBlock(
          'ما معنى الضروري (وقت الضرورة)؟',
          '',
          'إذا انقضى الوقت المختار لم يُغلَق الباب دون المعذور — بل تُفتح بعده '
              'نافذة ضرورة. وقول خليل: الضروري بعد المختار، للطلوع في الصبح، وللغروب في '
              'الظهرين، وللفجر في العشاءين. والدخول إليه بغير عذر إثم، غير أن ركعة '
              'تُدرَك فيه تُحتسَب صلاةً مؤداةً في وقتها. وعلى المشهور يحتفظ الصبح بهذه '
              'المرتبة أيضاً؛ وقيل: لا ضروري له.',
          'D1 §2.8 · D4 A4.1 · A7.2',
        ),
        LearnBlock(
          'ما هو الاحتياط؟',
          '',
          'إزاحة احتياطية صغيرة تُضاف فوق الأوقات المحسوبة — دقيقة واحدة على الظهر '
              'والمغرب مثلاً. وهي من باب الاحتياط لا من الفقه: بدّل مفتاح الاحتياط في '
              'هذا التطبيق فلن تتحرك الحدود الفقهية معه. وللفكرة سلف في التراث — فقد '
              'فرّق القدماء أصلاً بين الزوال الشرعي (ميل قرص الشمس عن خط وسط السماء) '
              'والزوال الاصطلاحي (ميل مركزها) بنحو نصف درجة، أي نحو دقيقتين من الزمن.',
          'D1 §4.4 · D4 A6.2',
        ),
      ],
    ),
    'glossary': LearnContent(
      'مصطلحات',
      'المصطلحات المستعملة في هذا التطبيق، بلغة الفقه المالكي. تنبيه من '
          'البحث: ثنائية «وقت الفضيلة/وقت الجواز» الرسمية شافعية، لا مالكية.',
      [
        LearnBlock(
          'المختار (الوقت المختار)',
          '',
          'الوقت المفضل أو المختار — وقت الاختيار الذي تُفضَّل فيه الصلاة. '
              'ويسمّى أيضاً الوقت الاختياري.',
          'D1 §2.2 · D4 A4.2',
        ),
        LearnBlock(
          'الضروري (الوقت الضروري)',
          '',
          'وقت الضرورة الذي يلي المختار، لأهل العذر؛ والتأخير إليه بغير عذر '
              'إثم. وللمعذور يُحتسب أداءً.',
          'D1 §2.8 · D4 A4.1',
        ),
        LearnBlock(
          'الفجر الصادق / الكاذب',
          '',
          'الفجر الصادق: الضوء المنتشر أفقياً حتى يعم الأفق — وبه يبدأ '
              'الصبح. والفجر الكاذب: عمود ضوء رأسي بلا امتداد أفقي — لا '
              'عبرة له.',
          'D1 §2.3 · D4 A3.1 · B2.2',
        ),
        LearnBlock(
          'الشفق',
          '',
          'الشفق. في الفقه المالكي هو الحمرة الباقية في المغرب بعد الغروب — '
              'وتبدأ العشاء بمغيبه. والبياض الباقي بعده لا يُنظر إليه.',
          'D1 §2.7 · D4 A3.5',
        ),
        LearnBlock(
          'ظل الزوال',
          '',
          'الظل الموجود عند الزوال. يُستبعد من كل قياسات الظل اللاحقة — '
              'فالقامة لا تُحسب إلا بعده. وقد يعدم في البلاد الاستوائية '
              'ويختلف بالفصول والعروض.',
          'D1 §2.4 · D4 A2.1 · A6.1',
        ),
        LearnBlock(
          'الإسفار',
          '',
          'الوضوح البين قبل الطلوع؛ نهاية مختار الصبح. علامة مرئية مرصودة — '
              'لا مصدر فقهي يجعله وقت ساعة، فيُعرض نطاقاً إعلامياً لا وقتاً '
              'محسوباً أبداً.',
          'D1 §2.3 · D4 A2.5',
        ),
        LearnBlock(
          'الاصفرار',
          '',
          'اصفرار الشمس؛ نهاية مختار العصر. تُعتبر الصفرة في الأرض والجدر '
              'لا في عين الشمس — علامة مرئية، وليست وقت ساعة أبداً.',
          'D1 §2.5 · D4 A6.5',
        ),
        LearnBlock(
          'الغلس',
          '',
          'الظلمة قبل الفجر؛ وصلاة الصبح في الغلس سنة. تقول مدرسة المدونة: '
              'تُصلَّى الصبح في الغلس وآخر وقتها الإسفار.',
          'D1 §2.3 · D4 A2.5',
        ),
        LearnBlock(
          'الاحتياط',
          '',
          'إزاحة دقائق احتياطية تُضاف إلى الأوقات المحسوبة (مثل +1 دقيقة '
              'على الظهر/المغرب) — عرف، لا فقه.',
          'D1 §4.4 · D4 A6.2',
        ),
        LearnBlock(
          'المشهور',
          '',
          'القول المعتمد المعروف في المذهب — وهو ما يستعمله التطبيق افتراضياً '
              'حيث توجد خلافات معتبرة.',
          'D1 §2.10 · D4 A6.7',
        ),
      ],
    ),
  },

  'fr': {
    'definitions': LearnContent(
      'Les cinq prières — définitions malikites',
      'Les textes malikites classiques définissent les temps de prière par '
          'des signes observables : l’aube qui se répand, l’ombre qui '
          's’allonge, le soleil disparu, la rougeur qui s’efface. Les '
          'passages ci-dessous sont cités verbatim d’après les preuves de '
          'recherche.',
      [
        LearnBlock(
          'Subh — de l’aube vraie à l’isfar',
          '«أول وقتها انصداع الفجر المعترض بالضياء في أقصى المشرق ذاهبا من '
              'القبلة إلى دبر القبلة حتى يرتفع فيعم الأفق»',
          'Le Subh commence à l’aube vraie (fajr sadiq) — la lumière qui se '
              'répand horizontalement à l’extrême orient jusqu’à couvrir '
              'l’horizon — et son temps préféré finit à l’isfar clair, quand '
              'la lumière s’est répandue au point qu’à la fin de la prière le '
              'bord du soleil apparaît. Selon le mashhur, son temps daruri '
              'continue jusqu’au lever du soleil ; un avis minoritaire lui '
              'refuse tout daruri.',
          'D1 §2.3 · D4 A3.1',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'Dhuhr — du zawal au premier mithl',
          '«الْوَقْتُ الْمُخْتَارُ لِلظُّهْرِ: مِنْ زَوَالِ الشَّمْسِ لِآخِرِ '
              'القامة بغير ظل الزوال»',
          'Le Dhuhr commence au déclin du soleil passé le méridien (zawal), '
              'et son temps préféré finit quand l’ombre d’un objet égale sa '
              'propre longueur — l’ombre présente à midi (zill al-zawal) est '
              'toujours exclue du calcul. Son temps daruri continue jusqu’au '
              'coucher du soleil. Le passage de Khalil ci-dessus est la '
              'définition condensée de l’école, vérifiée verbatim sur le '
              'matn imprimé.',
          'D1 §2.4 · D4 A4.1 · A2.1',
          source: '«مختصر خليل»',
        ),
        LearnBlock(
          '‘Asr — le premier mithl, jusqu’au jaunissement',
          '«وهو أول وقت العصر للإصفرار»',
          'Le ‘Asr commence où finit le Dhuhr : au premier mithl — une '
              'longueur d’objet d’ombre au-delà de l’ombre de midi. Son '
              'temps préféré dure tant que le soleil reste blanc et pur ; '
              'la fin préférée est le jaunissement du soleil (isfirar), '
              'jugé sur le sol et les murs, pas dans le disque solaire. Le '
              'temps daruri continue jusqu’au coucher. C’est le seul point '
              'où la règle logicielle (facteur d’ombre 1) coïncide exactement '
              'avec la règle établie par les textes.',
          'D1 §2.5 · D4 A4.1 · A6.5',
          source: '«مختصر خليل»',
        ),
        LearnBlock(
          'Maghrib — le coucher, un temps étroit unique (mashhur)',
          '«ليس لها إلا وقت واحد لا تؤخر عنه»',
          'Le Maghrib commence au coucher du soleil — la disparition du '
              'disque solaire entier. Selon le mashhur, il n’a qu’un temps '
              'étroit unique, de quoi l’accomplir après ses conditions ; il '
              'n’est pas retardé au-delà. Un second avis reconnu (Ashhab, '
              'choix d’al-Baji) l’étend à la disparition du crépuscule rouge '
              '— noté ici comme alternative, pas comme défaut.',
          'D1 §2.6 · D4 A3.4 · A6.7',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'Isha — le crépuscule rouge, jusqu’au premier tiers de la nuit',
          '«غيبوبة الشفق والشفق الحمرة الباقية في المغرب من بقايا شعاع '
              'الشمس… ولا ينظر إلى البياض في المغرب»',
          'L’Isha commence à la disparition du crépuscule rouge (shafaq) — '
              'la blancheur restante ne compte pas, contre la lecture '
              'hanafite du crépuscule blanc. Son temps préféré finit au '
              'premier tiers de la nuit, mesurée du coucher brut à l’aube '
              'vraie (avis d’Ibn Habib : jusqu’à minuit). Le temps daruri '
              'continue jusqu’à l’aube, et Maghrib et Isha partagent les '
              'quatre dernières rak‘as.',
          'D1 §2.7 · D4 A3.5 · A2.4',
          source: '«الرسالة»',
        ),
        LearnBlock(
          'Les deux degrés : mukhtar et daruri',
          '«والضروري بعد المختار للطلوع في الصبح وللغروب في الظهرين وللفجر '
              'في العشاءين» — «وَأَثِمَ إلَّا لِعُذْرٍ»',
          'Le temps mukhtar est le temps de choix ; le temps daruri qui le '
              'suit est pour ceux qui ont une excuse. Khalil : qui le '
              'retarde sans excuse est pécheur (wa-athim illa li-‘udhr). La '
              'prière y est encore atteinte avec une rak‘a, et le tout '
              'compte comme accompli à temps (ada’). Le couple '
              'mukhtar/daruri est la systématisation de Khalil — l’époque de '
              'la Mudawwana usait d’un vocabulaire plus ancien comme '
              '« début/fin du temps » et « pas de mal ».',
          'D1 §2.2 · §2.8 · D4 A4.1 · A2.6',
          source: '«مختصر خليل»',
        ),
      ],
    ),
    'eighteen': LearnContent(
      'Pourquoi 18° ?',
      'Le chiffre 18° a un pedigree astronomique classique — mais aucun '
          'texte malikite classique ne fixe l’aube à un angle en degrés. Les '
          'deux vérités appartiennent à cette section.',
      [
        LearnBlock(
          'Habach al-Hasib al-Marwazi (m. ~227H)',
          '«قد علم بالتجربة أن انحطاط الشمس عن الأفق في أول الصبح الكاذب '
              'وفي آخر الشفق ثماني عشرة درجة»',
          'La plus ancienne mention établie de la valeur 18° : dans l’un de '
              'ses zij (tables astronomiques), l’astronome bagdadien Habach '
              'al-Hasib donne une procédure utilisant sin(18°) pour '
              'déterminer le lever de l’aube et la disparition du crépuscule '
              '— le manuscrit est conservé à Berlin. Baha’ al-Din al-‘Amili '
              'enregistre la même valeur comme connue « par observation '
              'répétée ». Un paramètre d’observation d’astronome — pas une '
              'règle malikite.',
          'D1 §4.1 · D4 D3.4',
          source: '«تشريح الأفلاك»',
        ),
        LearnBlock(
          'Ibn al-Samh al-Mahri (m. 426H)',
          '',
          'Dans son livre sur l’usage de l’astrolabe, chapitre 74, le '
              'muhandis andalou Ibn al-Samh enseigne : pour connaître l’heure '
              'où le crépuscule disparaît et où l’aube se lève, placer le '
              'nadir de la position du soleil sur le 18e almacantarat — « et '
              'selon Habach (m. 250H), sur le 16e almacantarat ». Le chiffre '
              'en degrés était un réglage d’instrument de travail chez les '
              'premiers astronomes musulmans.',
          'D1 §4.1 · D4 D3.4',
        ),
        LearnBlock(
          'La fourchette médiévale 16°–20°',
          '',
          'Les astronomes médiévaux travaillaient avec une famille de '
              'paramètres, pas une valeur unique : Ibn Yunus 20°/16°, les '
              'astronomes égyptiens 19°/17°, et 18°/18° répandu (King/Ilyas, '
              'résumé secondaire). Qadi Zadah note qu’en dessous d’environ '
              '72° de latitude le crépuscule rejoint la fausse aube au '
              'solstice d’été — la formulation classique du problème du '
              'crépuscule aux hautes latitudes.',
          'D1 §4.1 · D4 D3.3',
        ),
        LearnBlock(
          'La limite honnête : aucun angle dans le fiqh',
          '',
          'Aucun texte malikite classique ne fixe l’aube vraie à un angle '
              'de dépression solaire — la description est purement visuelle : '
              'la fente de l’aube transversale jusqu’à ce qu’elle couvre '
              'l’horizon. Les valeurs 18°/17° de la convention MWL 1986, et '
              'tous les préréglages institutionnels, sont des estimations '
              'opérationnelles modernes des signes légaux — une convention '
              'logicielle, jamais une règle malikite.',
          'D1 §4.1 · D4 NEG-1 · C7.1',
        ),
      ],
    ),
    'dawn': LearnContent(
      'Études d’observation de l’aube',
      'Mesures modernes de la dépression solaire de l’aube vraie. La '
          'science informe les conventions — elle n’est pas du fiqh.',
      [
        LearnBlock(
          'UKM, Malaisie (2018)',
          '',
          'Kassim Bahali et al., Jurnal Sains Malaysiana 47(11) 2018 : '
              'mesure par caméra DSLR de la dépression du fajr sadiq — '
              '-14,5° à -18,5°, moyenne -16,67°, avec une valeur de travail '
              'proposée de -17,0°. Tous les angles de Fajr couramment '
              'utilisés se situent dans cette fourchette observée ou près '
              'd’elle.',
          'D1 §4.1 · D4 D3.1',
        ),
        LearnBlock(
          'UIN Jakarta (2018)',
          '',
          'Une étude au photomètre SQM n’a détecté l’aube vraie qu’entre '
              '15° et 18°. La norme officielle indonésienne de 20° n’y montre '
              'aucune aube détectable — elle avance de 8 à 20 minutes. Un '
              'avertissement contre le figement d’un angle élevé unique.',
          'D1 §4.1 · D4 D3.2',
        ),
        LearnBlock(
          'Pourquoi l’aube se voit plus tard en ville',
          '',
          'Cheikh Abdessalam al-Shuway‘ir : l’aube vraie est la blancheur '
              'horizontale, par opposition à la hampe verticale de la fausse '
              'aube ; à cause de l’éclairage artificiel, l’aube vraie ne '
              'peut se voir en ville — ni même près des bourgs ni dans les '
              'fermes électrifiées — seulement là où la pollution lumineuse '
              'a disparu. Une raison d’estimer le Fajr avec prudence (plus '
              'tard).',
          'Tawqit Instagram review, Post 3 · D1 §4.1',
        ),
      ],
    ),
    'faq': LearnContent(
      'Questions fréquentes',
      'Des réponses qui restent dans les preuves de recherche — les '
          'conventions sont toujours nommées comme telles.',
      [
        LearnBlock(
          'Peut-on calculer les horaires de prière, ou faut-il les observer ?',
          '',
          'Oui, on peut les calculer — et ce n’est pas un raccourci moderne. L’école '
              'malikite l’a dit plainement il y a sept siècles. Al-Qarafi (m. 684 H.) écrit '
              'dans sa Dhakhira : « Je ne connais aucune divergence concernant '
              'l’établissement des temps de prière par le calcul, au moyen d’instruments à '
              'eau, à sable et autres — les habitants des grandes villes l’ont fait à '
              'toutes les époques, en hiver, lors des pluies et des nuages. » Dans ses '
              'Furuq, il trace soigneusement la limite : calculer les horaires de prière '
              'est une chose, calculer le croissant de Ramadan en est une autre. Dans cette '
              'application, chaque horaire est calculé sur votre téléphone à partir des '
              'signes astronomiques eux-mêmes — et la méthode vous est montrée, jamais '
              'modifiée en silence.',
          'D1 §4.1 · D4 (verification 2026-10-18: al-Dhakhira, Kitab al-Siyam)',
          source: '«الذخيرة»',
        ),
        LearnBlock(
          'Pourquoi faire confiance à un horaire calculé ?',
          '',
          'Parce que l’école fait confiance au connaisseur des horaires. Al-Burzuli — '
              'cité par al-Hattab dans les Mawahib al-Jalil — énonce l’avis apparent de '
              'l’école malikite : on accepte absolument la parole du muezzin intègre et '
              'connaisseur, par temps couvert comme par ciel dégagé, pour la prière comme '
              'pour le jeûne, dès lors qu’il connaît les horaires au moyen d’instruments — '
              'sabliers, horloges astronomiques et autres. Ibn Yunus et d’autres ont '
              'explicitement affirmé cette généralité dans le Livre du jeûne. Un horaire ne '
              'vaut que le savoir qui le fonde : cette application vous montre la méthode, '
              'les angles et la preuve de chaque horaire affiché — on ne vous demande '
              'jamais de faire confiance à une boîte noire.',
          'D1 §4.1 · D4 (verification 2026-10-18: Mawahib al-Jalil, bab mawaqit '
              'al-salat)',
          source: '«مواهب الجليل»',
        ),
        LearnBlock(
          'Utiliser l’astronomie pour les prières, est-ce de l’astrologie ?',
          '',
          'Non — et les juristes ont tracé cette limite il y a longtemps. Al-Akhdari '
              '(m. 953 H.) ouvre son poème astronomique al-Siraj sur ce point : la science '
              'par laquelle on connaît les temps, l’aube, la qibla et les heures est « une '
              'science précieuse, parmi les plus honorables voies » — tandis que ce qui '
              'prétend accéder à l’invisible est interdit « sans aucun doute ». '
              'L’astronomie qui détermine les horaires de prière est un savoir qui '
              's’apprend ; l’astrologie qui prétend connaître le caché est tout autre '
              'chose. (Les vers arabes ci-dessus sont transmis dans les diapositives '
              'pédagogiques de Tawqit d’après la tradition manuscrite d’al-Siraj ; aucune '
              'édition imprimée n’était accessible pour une vérification mot à mot.)',
          'D1 §4.1 · D4 (al-Siraj attribution verified 2026-10-18; verses per '
              'manuscript tradition)',
          source: '«السراج في علم الفلك»',
        ),
        LearnBlock(
          'Pourquoi 18° pour le fajr ?',
          '',
          'Parce que des générations d’astronomes et de muwaqqits musulmans l’ont '
              'consignée comme leur estimation pratique du signe observable — l’aube vraie. '
              'Al-Biruni s’exprime sans détour dans son Qanun al-Mas’udi : les praticiens '
              'du métier observèrent et « obtinrent des lois de son temps que, lorsque la '
              'dépression du soleil sous l’horizon est de dix-huit degrés, c’est le moment '
              'du lever de l’aube à l’est et de la disparition du crépuscule à l’ouest » — '
              'en ajoutant aussitôt que ce n’est « pas une chose fixe », puisque certains '
              'd’entre eux voyaient dix-sept degrés (Qanun 2/948-949, éd. d’Hyderabad). '
              'Dans son Tahdid il rapporte la même chose sous l’autre angle : dix-sept '
              'degrés selon les praticiens, dix-huit selon certains — les deux « pris de '
              'l’expérience et de l’examen répété ». Deux honnêtetés s’imposent. D’abord, '
              'ce ne fut jamais unanime : les mêmes livres rapportent une fourchette de 16° '
              'à 20° — 17° et 19° aussi en usage sérieux, et aucun texte malikite classique '
              'ne fixe un degré — l’angle est une estimation du signe, pas une règle. '
              'Ensuite, c’étaient des astronomes, non des juristes : leur autorité est '
              'observationnelle, et le jugement fiqh sur le signe reste aux fuqaha’. Le '
              'profil par défaut de cette application (Ligue islamique mondiale, 18°/17°) '
              'suit la décision de 1986 du Conseil de fiqh de la Ligue ; les autres profils '
              'nomment leurs propres conventions en toute honnêteté.',
          'D1 §4.2 · Biruni Qanun 2/948-949 & Tahdid (verbatim-verified); King 1973 '
              '(Habash/Nayrizi "probably"; Battani denial); Tusi Muiniyya 18°',
        ),
        LearnBlock(
          'Pourquoi les pays utilisent-ils des angles différents ?',
          '',
          'Parce que l’angle est une convention nationale pour lire le même ciel, pas '
              'une règle à son sujet. Les horaires du Maroc suivent 19°/17° (rapporté par '
              'des sources secondaires — la méthodologie du ministère des Habous n’est pas '
              'publiée) ; l’Égypte 19,5°/17,5° ; l’Arabie saoudite 18,5° pour le fajr avec '
              'un intervalle de 90 minutes pour l’icha ; la Malaisie et l’Indonésie 20°/18° '
              '; et une grande partie de l’Afrique de l’Ouest, dont la Mauritanie, le '
              '18°/17° de la Ligue islamique mondiale. Aucun de ces chiffres n’est le fiqh '
              '— le fiqh parle de l’aube vraie et de la disparition du crépuscule rouge, '
              'que les observateurs ont toujours lus légèrement différemment selon le lieu '
              'et la saison. Cette application propose les principales conventions comme '
              'profils nommés avec leur provenance, pour que vous sachiez toujours selon '
              'quelle convention vous priez. (Une mise en garde : le slogan de la carte '
              'Tawqit — « plus la tradition savante d’un État est forte, plus il reste '
              'proche des 18° » — est la rhétorique de l’éditeur, pas un résultat savant.)',
          'D1 §4.2 · D4 (Morocco secondary-only per pass-2 C) · Tawqit angles map',
        ),
        LearnBlock(
          'Pourquoi les heures diffèrent-elles d’une application à l’autre ?',
          '',
          'Derrière les étiquettes, on retrouve le plus souvent le même fiqh '
              'habillé de conventions logicielles différentes : un Fajr à 18° ici, à '
              '20° là ; des minutes d’ihtiyat ajoutées ou non ; et des traitements des '
              'hautes latitudes propres à chacun. Deux points méritent l’attention. Les '
              'étiquettes de préréglages ne tiennent pas toujours leurs promesses — '
              'l’étiquette UOIF 12°/12°, par exemple, est contestée face à une réalité '
              'alléguée de 15°/15°. Et quand la méthode elle-même reste inédite, comme '
              'chez Muslim Pro et IslamicFinder, leurs horaires ne peuvent juger ceux '
              'des autres.',
          'D1 §4.6–4.7 · D4 NEG-5 · C3.2',
        ),
        LearnBlock(
          'Et si j’habite là où l’icha ou le fajr n’arrive jamais ?',
          '',
          'dans le Grand Nord en été, le crépuscule rouge peut ne jamais disparaître '
              'avant l’aube — quand donc l’icha, et quand commence le jeûne ? Le muwaqqit '
              'de Fès, al-’Alami, posa exactement cette question au cheikh al-jama’a de la '
              'ville, Ibn al-Khayyat al-Zukari (m. 1343 H./1924). Sa réponse retint un « '
              'troisième avis » : la nuit se partage en son milieu — sa première moitié au '
              'crépuscule, sa seconde à l’aube ; l’icha devient dû quand l’effet de la '
              'lumière solaire passe de l’ouest à l’est ; le fajr se prie ensuite après '
              'l’icha, dans l’ordre requis ; et le jeûne suit le jour local, « accomplissez '
              'le jeûne jusqu’à la nuit » (Coran 2:187), si long soit-il. La question '
              'citait aussi un rapport plus ancien — al-Qarafi transmettant de l’Imam '
              'al-Haramayn (al-Juwayni) dans ses Yawaqit : on ne prie l’icha que le '
              'crépuscule dissipé, et ce n’est pas un qaḍa’ car son temps demeure ; la '
              'prière de l’aube suit le fajr du pays le plus proche. C’est la fatwa motivée '
              'd’un mufti de la tradition fassie du tawqit — pas la doctrine mashhur de '
              'l’école. La réponse de cette application au même problème est son sélecteur '
              'de repli hautes latitudes : quand les angles crépusculaires sont '
              'inatteignables, il estime à partir de la nuit elle-même (milieu de la nuit '
              'et autres conventions nommées) et vous dit plainement laquelle est active — '
              'le partage de minuit au cœur de la fatwa est proche parent de la convention '
              'du « milieu de la nuit ».',
          'D1 §4.5 · Tawqit Fez fatwa series (identities & al-Yawaqit correction per '
              'strand B 2026-10-18)',
        ),
        LearnBlock(
          'Pourquoi le repère « fin préférée » peut-il précéder l’Isha en '
              'été ?',
          '',
          'Aux hautes latitudes — la France, par exemple — le crépuscule qui ouvre '
              'l’Isha s’attarde parfois au-delà du premier tiers de la nuit. Or la '
              'période préférée s’achève à ce tiers : sa fin calculée peut donc tomber '
              'avant l’heure de l’Isha elle-même. À Paris, le 17 mai : Maghrib à 21h31, '
              'fin du premier tiers à 23h30, Isha à 23h51, Fajr à 03h30. Les quatre '
              'écoles s’accordent à attendre l’heure réelle de l’Isha, même passée '
              'minuit ; comme le dit l’imam Ibn Hajar, un signe de substitution n’a de '
              'sens que là où le vrai signe fait défaut, jamais là où il est présent.',
          'Tawqit Instagram review, Post 1 · D1 §2.7',
        ),
        LearnBlock(
          'Pourquoi l’icha dépasse-t-il minuit en été ?',
          '',
          'Pour deux raisons nullement religieuses : les fuseaux horaires et l’heure '
              'd’été. La France, par exemple, vit avec une heure d’avance sur son temps '
              'solaire — une imposition allemande du temps de guerre, en 1940, jamais '
              'annulée — puis ajoute une heure chaque été pour l’heure d’été (depuis 1976). '
              'À l’horloge, l’icha peut donc tomber à 1h du matin alors que le soleil n’a '
              'guère dépassé l’ancien minuit. Les signes religieux n’ont pas bougé ; c’est '
              'l’horloge qui a bougé. Ne prenez pas un horaire d’apparence tardive pour une '
              'religion tardive : les quatre écoles s’accordent à attendre l’heure '
              'véritable de l’icha même quand elle dépasse minuit.',
          'D1 §4.5 · Tawqit summer-midnight slide (history: general record)',
        ),
        LearnBlock(
          'Les horaires sont très tardifs en été — que faire ?',
          '',
          'les diapositives Tawqit proposent quatre paliers pour gérer des horaires '
              'd’été très tardifs — un accompagnement pastoral, pas une fatwa de cette '
              'application. (1) Priez au début du temps autant que possible — « la prière '
              'au début de son temps » (hadith d’Umm Farwa, Sunan d’Abi Dawud n° 426 ; sa '
              'chaîne est jugée faible, mais son sens est établi par le hadith d’Ibn Mas’ud '
              'dans les deux Sahihs). (2) Sinon, retardez le fajr vers l’isfar (la clarté) '
              '— qui est elle-même la fin mashhur du temps préféré du subh. Les '
              'diapositives le formulent comme une parole d’Ibn Habib, rapportée par Ibn '
              'Abi Zayd dans les Nawadir d’après Mu’adh : « quand vient l’été, prie le subh '
              'à la clarté, car la nuit est courte et les gens dorment ; ne retarde pas '
              'l’icha, car la nuit est courte, et ne la prie pas avant la disparition du '
              'crépuscule » — formulation que nous n’avons pas retrouvée dans une édition '
              'imprimée : retenez le palier pour son contenu, que la règle de l’école '
              'conforte. (3) À défaut, retardez l’icha jusqu’avant le fajr — car « la '
              'négligence dans la prière n’est que de la retarder jusqu’au temps de la '
              'suivante » (parole d’Abu Hurayra ; remontant au Prophète ﷺ par Abu Qatada '
              'dans le Sahih de Muslim). (4) En dernier recours, regroupez maghrib et icha '
              ': Achhab permettait de regrouper deux prières sans cause particulière — une '
              'divergence interne réelle et reconnue, rapportée par al-Baji et Ibn Rushd '
              'via le Tawdih de Khalil (comme l’enregistre al-Hattab) — d’après le hadith '
              'd’Ibn ’Abbas : le Prophète ﷺ regroupa le dohr et l’asr, le maghrib et l’icha '
              '« sans crainte, ni voyage, ni pluie ». Soyez lucide sur le palier 4 : c’est '
              'l’avis minoritaire, pas le mashhur — la position malikite bien connue ne '
              'permet le regroupement qu’en avançant (taqdim), pour la pluie ou la maladie.',
          'D1 §2.9 · Tawqit summer-management slide (attribution corrections per strand '
              'B 2026-10-18)',
        ),
        LearnBlock(
          'Que signifie daruri (temps de nécessité) ?',
          '',
          'Quand le temps préféré s’achève, la porte ne se ferme pas pour l’excusé '
              '— une fenêtre de nécessité s’ouvre après lui. La formule de Khalil : le '
              'daruri suit le mukhtar — jusqu’au lever pour le Subh, jusqu’au coucher '
              'pour Dhuhr et ‘Asr, jusqu’à l’aube pour Maghrib et Isha. Y entrer sans '
              'excuse est fautif, mais une rak‘a accomplie à l’intérieur compte encore '
              'comme prière faite à temps (ada’). Selon le mashhur, le Subh garde aussi '
              'ce degré ; un avis minoritaire le lui refuse.',
          'D1 §2.8 · D4 A4.1 · A7.2',
        ),
        LearnBlock(
          'Qu’est-ce que l’ihtiyat ?',
          '',
          'Un petit décalage de précaution posé sur les heures calculées — +1 '
              'minute sur Dhuhr et Maghrib, par exemple. Il relève de la prudence, non '
              'du fiqh : actionnez l’interrupteur d’ihtiyat dans cette application et '
              'aucune borne légale ne bougera avec lui. L’idée a des ancêtres — la '
              'tradition classique distinguait déjà le midi légal (le disque du soleil '
              'passé le méridien) du midi astronomique (son centre passé le méridien), '
              'd’environ un demi-degré, soit deux minutes de temps.',
          'D1 §4.4 · D4 A6.2',
        ),
      ],
    ),
    'glossary': LearnContent(
      'Glossaire',
      'Les termes utilisés dans cette application, dans le vocabulaire '
          'malikite. Une mise en garde de la recherche : le couple formel '
          '« waqt al-fadila / waqt al-jawaz » est du vocabulaire shafi‘ite, '
          'pas malikite.',
      [
        LearnBlock(
          'Mukhtar (الوقت المختار)',
          '',
          'Le temps préféré ou choisi — le temps de choix, dans lequel la '
              'prière est la meilleure. Aussi appelé temps ikhtiyari.',
          'D1 §2.2 · D4 A4.2',
        ),
        LearnBlock(
          'Daruri (الوقت الضروري)',
          '',
          'Le temps de nécessité qui suit le mukhtar, pour ceux qui ont une '
              'excuse ; le retarder sans excuse est pécheur. Pour l’excusé, '
              'il compte comme accompli à temps.',
          'D1 §2.8 · D4 A4.1',
        ),
        LearnBlock(
          'Fajr sadiq / fajr kadhib (الفجر الصادق / الكاذب)',
          '',
          'L’aube vraie : la lumière qui se répand horizontalement jusqu’à '
              'couvrir l’horizon — elle ouvre le Subh. La fausse aube : une '
              'colonne verticale de lumière sans extension horizontale — '
              'elle ne compte pour rien.',
          'D1 §2.3 · D4 A3.1 · B2.2',
        ),
        LearnBlock(
          'Shafaq (الشفق)',
          '',
          'Le crépuscule. En droit malikite, c’est la rougeur qui reste à '
              'l’ouest après le coucher — et l’Isha commence à sa '
              'disparition. La blancheur qui reste après n’est pas '
              'considérée.',
          'D1 §2.7 · D4 A3.5',
        ),
        LearnBlock(
          'Zill al-zawal (ظل الزوال)',
          '',
          'L’ombre présente au midi solaire. Elle est exclue de toutes les '
              'mesures d’ombre ultérieures — la qama ne se compte qu’après '
              'elle. Elle disparaît sous les tropiques et varie avec les '
              'saisons et les latitudes.',
          'D1 §2.4 · D4 A2.1 · A6.1',
        ),
        LearnBlock(
          'Isfar (الإسفار)',
          '',
          'L’éclairement net avant le lever ; la fin du temps préféré du '
              'Subh. Un signe visuel observé — aucune source fiqh n’en donne '
              'un décalage horaire, il est donc affiché comme bande '
              'informative, jamais comme heure calculée.',
          'D1 §2.3 · D4 A2.5',
        ),
        LearnBlock(
          'Isfirar (الإصفرار)',
          '',
          'Le jaunissement du soleil ; la fin du temps préféré du ‘Asr. '
              'Jugé sur le sol et les murs, pas dans le disque solaire — un '
              'signe visuel observé, jamais un décalage horaire.',
          'D1 §2.5 · D4 A6.5',
        ),
        LearnBlock(
          'Ghalas (الغلس)',
          '',
          'L’obscurité avant l’aube ; prier le Subh dans le ghalas est '
              'sunna. L’école de la Mudawwana dit : le Subh se prie dans le '
              'ghalas et son temps finit à l’isfar.',
          'D1 §2.3 · D4 A2.5',
        ),
        LearnBlock(
          'Ihtiyat (احتياط)',
          '',
          'Un décalage de minutes de précaution ajouté aux heures calculées '
              '(par exemple +1 min sur Dhuhr/Maghrib) — une convention, pas '
              'du fiqh.',
          'D1 §4.4 · D4 A6.2',
        ),
        LearnBlock(
          'Mashhur (مشهور)',
          '',
          'La position établie et bien connue de l’école — celle que '
              'l’application utilise par défaut là où existent des '
              'désaccords reconnus.',
          'D1 §2.10 · D4 A6.7',
        ),
      ],
    ),
  },
};

/// Localized content for section [id] in [languageCode] ('en' fallback for
/// the locale; the English section for an id missing in [languageCode]).
LearnContent learnContent(String languageCode, String sectionId) {
  final byId = _content[languageCode] ?? _content['en']!;
  return byId[sectionId] ?? _content['en']![sectionId]!;
}

/// All section ids localized for [languageCode] ('en' fallback).
List<LearnSection> learnLocalizedSections(String languageCode) {
  final byId = _content[languageCode] ?? _content['en']!;
  return learnSections.where((s) => byId.containsKey(s.id)).toList();
}

/// The evidence-reference line for a section: the union of its blocks'
/// references, in display order, de-duplicated.
String learnSectionRefs(String languageCode, String sectionId) {
  final c = learnContent(languageCode, sectionId);
  final seen = <String>[];
  for (final b in c.blocks) {
    for (final r in b.refs.split('·')) {
      final t = r.trim();
      if (!seen.contains(t)) seen.add(t);
    }
  }
  return seen.join(' · ');
}
