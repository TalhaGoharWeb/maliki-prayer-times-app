library;

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

  const LearnBlock(this.title, this.arabic, this.body, this.refs);
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
        'rulings. Every block names the evidence behind it, and every '
        'modern convention is labeled a convention. Nothing here has been '
        'reviewed by a qualified Maliki scholar.',
  ),
  'ur': LearnStrings(
    title: 'سیکھیں',
    integrityNote:
        'تحقیقی شواہد سے ماخوذ تعلیمی مواد — فقہی احکام نہیں۔ ہر حصہ اپنے '
        'شواہد کا نام دیتا ہے، اور ہر جدید کنونشن کو کنونشن ہی کہا گیا ہے۔ '
        'یہاں کی کسی بات کی اہل مالکی عالم نے نظرثانی نہیں کی۔',
  ),
  'ar': LearnStrings(
    title: 'التعليم',
    integrityNote:
        'مواد تعليمي مستمد من أدلة البحث — وليس أحكاماً فقهية. كل فقرة تذكر '
        'الدليل الذي تقوم عليه، وكل عرف حديث مسمّى عرفاً. لم يراجع أيَّ شيء '
        'هنا عالمٌ مالكي مؤهل.',
  ),
  'fr': LearnStrings(
    title: 'Enseignement',
    integrityNote:
        'Matériel pédagogique tiré des preuves de recherche — pas des règles '
        'de fiqh. Chaque bloc nomme la preuve qui le fonde, et chaque '
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
          'Why can the "preferred until" marker fall before Isha in summer?',
          '',
          'At high latitudes such as France, the twilight — the natural sign '
              'for Isha — may not disappear until after the first third of '
              'the night has passed, so the calculated end of the preferred '
              'period (one-third of the night) can land earlier than the Isha '
              'time itself. Example from Paris, 17 May: Maghrib 21:31, end of '
              'the first third 23:30, Isha 23:51, Fajr 03:30. The established '
              'view of the four schools is to wait for the real Isha time '
              'even when it falls after midnight — a substitute sign is '
              'considered only when the sign is absent, not when it exists '
              '(Imam Ibn Hajar, as quoted in the Tawqit review).',
          'Tawqit Instagram review, Post 1 · D1 §2.7',
        ),
        LearnBlock(
          'Why do times differ between apps?',
          '',
          'Most differences are different conventions, not different fiqh: '
              'different Fajr/Isha angles (18° vs 20° and the rest), '
              'different precautionary (ihtiyat) minutes, and different '
              'high-latitude fallbacks. Two cautions from the research: '
              'preset labels are not always trustworthy (the UOIF 12°/12° '
              'label is disputed against a claimed 15°/15° reality), and the '
              'methods of Muslim Pro and IslamicFinder are not publicly '
              'documented, so their timetables cannot be used as validation '
              'truth.',
          'D1 §4.6–4.7 · D4 NEG-5 · C3.2',
        ),
        LearnBlock(
          'What does daruri (necessity time) mean?',
          '',
          'After the preferred (mukhtar) time ends, a necessity window '
              'remains for those with an excuse — Khalil: the daruri follows '
              'the mukhtar, to sunrise for Subh, to sunset for Dhuhr and '
              'Asr, to dawn for Maghrib and Isha. Delaying into it without '
              'excuse is sinful. A prayer is still caught in it with one '
              'rak‘a, and all of it counts as on-time (ada’). On the mashhur '
              'Subh keeps this tier; a minority holds it has none.',
          'D1 §2.8 · D4 A4.1 · A7.2',
        ),
        LearnBlock(
          'What is ihtiyat?',
          '',
          'A precautionary offset added to the computed times — for example '
              '+1 minute on Dhuhr and Maghrib. It is a convention for '
              'caution, never part of the fiqh definition; fiqh boundaries in '
              'this app never move when the ihtiyat toggle changes. The '
              'classical tradition already distinguished the legal noon (the '
              'sun’s disk past the meridian) from the astronomical noon (the '
              'sun’s center past the meridian) by about half a degree — '
              'about two minutes of time.',
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
          'گرمیوں میں «ترجیحی خاتمہ» کا نشان عشاء سے پہلے کیوں آ سکتا ہے؟',
          '',
          'فرانس جیسے بلند عرض البلد پر شفق — عشاء کی طبعی علامت — رات کے '
              'پہلے ثلث کے گزرنے کے بعد تک ختم نہیں ہوتی، اس لیے ترجیحی مدت '
              'کا حسابی خاتمہ (رات کا ایک تہائی) خود عشاء کے وقت سے پہلے آ '
              'سکتا ہے۔ پیرس کی مثال، 17 مئی: مغرب 21:31، پہلے ثلث کا خاتمہ '
              '23:30، عشاء 23:51، فجر 03:30۔ چاروں مذاہب کا معروف موقف یہ '
              'ہے کہ آدھی رات کے بعد بھی اصل عشاء کے وقت کا انتظار کیا جائے '
              '— متبادل علامت کا اعتبار صرف اس وقت ہوتا ہے جب علامت موجود '
              'نہ ہو، جب موجود ہو تو نہیں (امام ابن حجر، Tawqit جائزے میں '
              'منقول)۔',
          'Tawqit Instagram review, Post 1 · D1 §2.7',
        ),
        LearnBlock(
          'ایپس کے اوقات آپس میں کیوں مختلف ہوتے ہیں؟',
          '',
          'زیادہ تر فرق مختلف کنونشنز کا ہے، مختلف فقہ کا نہیں: فجر/عشاء کے '
              'مختلف زاویے (18° بمقابلہ 20° وغیرہ)، احتیاط کے مختلف منٹ، اور '
              'قطبی عرض البلد کے مختلف فال بیک۔ تحقیق کی دو تنبیہات: پری '
              'سیٹ کے لیبل ہمیشہ قابل اعتماد نہیں (UOIF 12°/12° کا لیبل 15°/'
              '15° کے دعوے کے خلاف متنازع ہے)، اور Muslim Pro اور '
              'IslamicFinder کے حساب کے طریقے عوامی طور پر دستاویزی نہیں، '
              'اس لیے ان کے جدول توثیق کی بنیاد نہیں بن سکتے۔',
          'D1 §4.6–4.7 · D4 NEG-5 · C3.2',
        ),
        LearnBlock(
          'وقتِ ضرورت (ضروری) سے کیا مراد ہے؟',
          '',
          'وقتِ مختار کے ختم ہونے کے بعد عذر والوں کے لیے ضرورت کی ایک کھڑکی '
              'باقی رہتی ہے — خلیل: ضروری مختار کے بعد ہے، صبح کے لیے طلوع '
              'تک، ظہر و عصر کے لیے غروب تک، مغرب و عشاء کے لیے فجر تک۔ بغیر '
              'عذر کے اس میں تاخیر گناہ ہے۔ اس میں بھی نماز ایک رکعت سے پائی '
              'جاتی ہے، اور سب ادا شمار ہوتا ہے۔ مشہور پر صبح یہ درجہ رکھتی '
              'ہے؛ اقلیتی قول کے مطابق اس کا کوئی ضروری نہیں۔',
          'D1 §2.8 · D4 A4.1 · A7.2',
        ),
        LearnBlock(
          'احتیاط کیا ہے؟',
          '',
          'حساب شدہ اوقات میں شامل کیا گیا احتیاطی اضافہ — مثلاً ظہر اور مغرب '
              'پر +1 منٹ۔ یہ احتیاط کی کنونشن ہے، فقہی تعریف کا حصہ کبھی '
              'نہیں؛ اس ایپ میں احتیاط کا بٹن بدلنے سے فقہی حدیں نہیں بدلتیں۔ '
              'کلاسیکی روایت پہلے ہی زوالِ شرعی (قرصِ شمس کا نصف النہار سے '
              'ڈھلنا) اور زوالِ اصطلاحی (مرکزِ شمس کا گزرنا) میں تقریباً نصف '
              'درجے — یعنی تقریباً دو منٹ — کا فرق کرتی تھی۔',
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
        ),
        LearnBlock(
          'المغرب — الغروب، وقت واحد ضيق (المشهور)',
          '«ليس لها إلا وقت واحد لا تؤخر عنه»',
          'يبدأ المغرب بالغروب — غياب جميع قرص الشمس. وعلى المشهور ليس له '
              'إلا وقت واحد ضيق، بقدر فعله بعد شروطه؛ ولا يُؤخَّر عنه. وقول '
              'ثانٍ معروف (أشهب، واختاره الباجي) يمدّه إلى مغيب الشفق الأحمر '
              '— مذكور هنا كبديل، لا كأصل.',
          'D1 §2.6 · D4 A3.4 · A6.7',
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
          'لماذا قد تسبق علامة "نهاية المفضل" العشاء في الصيف؟',
          '',
          'في العروض العالية كفرنسا قد لا يغيب الشفق — العلامة الطبيعية '
              'للعشاء — إلا بعد انقضاء الثلث الأول من الليل، فيقع نهاية '
              'المدة المفضلة المحسوبة (ثلث الليل) قبل وقت العشاء نفسه. مثال '
              'باريس، 17 مايو: المغرب 21:31، نهاية الثلث الأول 23:30، العشاء '
              '23:51، الفجر 03:30. والمعتمد عند المذاهب الأربعة انتظار وقت '
              'العشاء الحقيقي ولو بعد منتصف الليل — ولا يُنظر في علامة بديلة '
              'إلا عند غياب العلامة لا عند وجودها (الإمام ابن حجر، كما نُقل '
              'في مراجعة Tawqit).',
          'Tawqit Instagram review, Post 1 · D1 §2.7',
        ),
        LearnBlock(
          'لماذا تختلف الأوقات بين التطبيقات؟',
          '',
          'أغلب الفروق فروق أعراف لا فروق فقه: زوايا فجر/عشاء مختلفة (18° '
              'مقابل 20° وغيرها)، ودقائق احتياط مختلفة، وسياسات عروض عالية '
              'مختلفة. وتحذيران من البحث: تسميات الأعراف ليست دائماً موثوقة '
              '(تسمية UOIF بـ12°/12° متنازع عليها مقابل دعوى 15°/15°)، ومنهجا '
              'Muslim Pro وIslamicFinder غير موثقين علناً فلا تصلح جداولهما '
              'حقيقةً للتحقق.',
          'D1 §4.6–4.7 · D4 NEG-5 · C3.2',
        ),
        LearnBlock(
          'ما معنى الضروري (وقت الضرورة)؟',
          '',
          'بعد انتهاء الوقت المختار تبقى نافذة ضرورة لأهل العذر — قال خليل: '
              'الضروري بعد المختار، للطلوع في الصبح، وللغروب في الظهرين، '
              'وللفجر في العشاءين. والتأخير إليه بغير عذر إثم. وتُدرك الصلاة '
              'فيه بركعة، والكل أداء. وعلى المشهور يحتفظ الصبح بهذه المرتبة؛ '
              'وقيل: لا ضروري له.',
          'D1 §2.8 · D4 A4.1 · A7.2',
        ),
        LearnBlock(
          'ما هو الاحتياط؟',
          '',
          'إزاحة احتياطية تُضاف إلى الأوقات المحسوبة — مثل +1 دقيقة على '
              'الظهر والمغرب. عرفٌ للاحتياط، وليس جزءاً من التعريف الفقهي '
              'أبداً؛ وحدود الفقه في هذا التطبيق لا تتحرك بتبديل الاحتياط. '
              'وقد فرّق التراث الكلاسيكي أصلاً بين الزوال الشرعي (ميل قرص '
              'الشمس عن خط وسط السماء) والزوال الاصطلاحي (ميل مركزها) بنحو '
              'نصف درجة — أي نحو دقيقتين من الزمن.',
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
          'Pourquoi le repère « fin préférée » peut-il précéder l’Isha en '
              'été ?',
          '',
          'Aux hautes latitudes comme la France, le crépuscule — le signe '
              'naturel de l’Isha — peut ne disparaître qu’après l’écoulement '
              'du premier tiers de la nuit, de sorte que la fin calculée de '
              'la période préférée (un tiers de la nuit) tombe avant l’heure '
              'de l’Isha elle-même. Exemple de Paris, 17 mai : Maghrib '
              '21h31, fin du premier tiers 23h30, Isha 23h51, Fajr 03h30. '
              'L’avis établi des quatre écoles est d’attendre l’heure réelle '
              'de l’Isha même après minuit — un signe de substitution n’est '
              'envisagé que lorsque le signe est absent, pas quand il '
              'existe (imam Ibn Hajar, cité dans la revue Tawqit).',
          'Tawqit Instagram review, Post 1 · D1 §2.7',
        ),
        LearnBlock(
          'Pourquoi les heures diffèrent-elles d’une application à l’autre ?',
          '',
          'La plupart des écarts sont des conventions différentes, pas un '
              'fiqh différent : des angles Fajr/Isha différents (18° contre '
              '20° et autres), des minutes d’ihtiyat différentes, et des '
              'secours de hautes latitudes différents. Deux mises en garde '
              'de la recherche : les étiquettes de préréglages ne sont pas '
              'toujours fiables (l’étiquette UOIF 12°/12° est contestée face '
              'à une réalité alléguée de 15°/15°), et les méthodes de Muslim '
              'Pro et d’IslamicFinder ne sont pas documentées publiquement, '
              'donc leurs horaires ne peuvent servir de vérité de validation.',
          'D1 §4.6–4.7 · D4 NEG-5 · C3.2',
        ),
        LearnBlock(
          'Que signifie daruri (temps de nécessité) ?',
          '',
          'Après la fin du temps préféré (mukhtar), une fenêtre de '
              'nécessité reste pour ceux qui ont une excuse — Khalil : le '
              'daruri suit le mukhtar, jusqu’au lever pour le Subh, jusqu’au '
              'coucher pour Dhuhr et ‘Asr, jusqu’à l’aube pour Maghrib et '
              'Isha. Le retarder sans excuse est pécheur. La prière y est '
              'encore atteinte avec une rak‘a, et le tout compte comme '
              'accompli à temps (ada’). Selon le mashhur, le Subh garde ce '
              'degré ; un avis minoritaire lui refuse tout daruri.',
          'D1 §2.8 · D4 A4.1 · A7.2',
        ),
        LearnBlock(
          'Qu’est-ce que l’ihtiyat ?',
          '',
          'Un décalage de précaution ajouté aux heures calculées — par '
              'exemple +1 minute sur Dhuhr et Maghrib. C’est une convention '
              'de prudence, jamais une partie de la définition fiqh ; les '
              'bornes fiqh de cette application ne bougent pas quand '
              'l’interrupteur d’ihtiyat change. La tradition classique '
              'distinguait déjà le midi légal (le disque du soleil passé le '
              'méridien) du midi astronomique (le centre du soleil passé le '
              'méridien) d’environ un demi-degré — environ deux minutes de '
              'temps.',
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
