library;

/// Localized content for the Methodology screen.
///
/// Every row of the method table carries a status — [MethodStatus.fiqhDerived]
/// or [MethodStatus.convention] — and the screen renders that status as a
/// badge. The integrity boundary from the research deliverables (D1 Part IV)
/// is structural here: angles (18°/17° and the rest), the 0.833° horizon,
/// ihtiyat minutes, rounding, and the high-latitude fallback are stored as
/// [MethodStatus.convention] rows and can never render under a fiqh badge.
///
/// Nothing here invents fiqh, scholars, angles, or endorsements: every row
/// traces to docs/MALIKI_RULES.md, docs/CALCULATION_METHODS.md, or D1 Part
/// IV of the research deliverables. Digits stay Western 0-9 in every locale
/// (Urdu-first rule: standard digits, never Arabic-Indic).
///
/// Content keys: locale code ('en'/'ur'/'ar'/'fr') -> row id -> [MethodologyText].
/// Unknown locales and unknown row ids fall back to English.

import 'package:malikiprayertimes/utils/app_info.dart';

/// Why a method-table row is what it is.
///
/// - [fiqhDerived]: a Maliki legal rule with attested textual basis.
/// - [convention]: an institutional or software convention estimating an
///   observable sign or keeping computation deterministic — NEVER a fiqh
///   ruling.
enum MethodStatus { fiqhDerived, convention }

/// One row of the method table: parameter, value used, and a detail line.
class MethodologyRow {
  /// Stable identifier used as the content-map key.
  final String id;

  /// Fiqh-derived rule or institutional/software convention.
  final MethodStatus status;

  const MethodologyRow(this.id, this.status);
}

/// The method table in display order: fiqh-derived rules first, then
/// operational conventions. 10 fiqh rows + 14 convention rows = 24 rows.
const List<MethodologyRow> methodologyRows = [
  // --- Fiqh-derived rules ---
  MethodologyRow('fajr-sign', MethodStatus.fiqhDerived),
  MethodologyRow('isha-sign', MethodStatus.fiqhDerived),
  MethodologyRow('dhuhr-start', MethodStatus.fiqhDerived),
  MethodologyRow('asr-start', MethodStatus.fiqhDerived),
  MethodologyRow('maghrib-start', MethodStatus.fiqhDerived),
  MethodologyRow('maghrib-mukhtar', MethodStatus.fiqhDerived),
  MethodologyRow('isha-ikhtiyari', MethodStatus.fiqhDerived),
  MethodologyRow('isha-daruri', MethodStatus.fiqhDerived),
  MethodologyRow('subh-daruri', MethodStatus.fiqhDerived),
  MethodologyRow('isfirar', MethodStatus.fiqhDerived),
  // --- Institutional / software conventions ---
  MethodologyRow('fajr-angle', MethodStatus.convention),
  MethodologyRow('isha-angle', MethodStatus.convention),
  MethodologyRow('horizon', MethodStatus.convention),
  MethodologyRow('ihtiyat', MethodStatus.convention),
  MethodologyRow('rounding', MethodStatus.convention),
  MethodologyRow('high-lat', MethodStatus.convention),
  MethodologyRow('asr-fallback', MethodStatus.convention),
  MethodologyRow('tz-frame', MethodStatus.convention),
  MethodologyRow('solar-model', MethodStatus.convention),
  MethodologyRow('asr-accept', MethodStatus.convention),
  MethodologyRow('maghrib-20', MethodStatus.convention),
  MethodologyRow('midnight-variant', MethodStatus.convention),
  MethodologyRow('grazing', MethodStatus.convention),
  MethodologyRow('profile-variants', MethodStatus.convention),
];

/// The localized texts for one method-table row.
class MethodologyText {
  /// What the parameter is (e.g. "Fajr angle: 18° solar depression").
  final String parameter;

  /// The value the app actually uses (e.g. "MWL Islamic Fiqh Council, 1986").
  final String value;

  /// One-line explanation of source and limits.
  final String detail;

  const MethodologyText(this.parameter, this.value, this.detail);
}

/// Screen chrome strings (titles, section headers, badge labels, header).
class MethodologyStrings {
  /// Screen title shown in the header card.
  final String title;

  /// The unmistakable integrity note: conventions are not rulings.
  final String integrityNote;

  /// Section header for the fiqh-derived rows.
  final String fiqhSection;

  /// Section header for the convention rows.
  final String conventionSection;

  /// Badge label for a fiqh-derived rule.
  final String badgeFiqh;

  /// Badge label for an institutional/software convention.
  final String badgeConvention;

  /// Header line labels.
  final String profileLabel;
  final String versionLabel;
  final String vintageLabel;

  /// Header values: method version and data vintage.
  final String versionValue;
  final String vintageValue;

  const MethodologyStrings({
    required this.title,
    required this.integrityNote,
    required this.fiqhSection,
    required this.conventionSection,
    required this.badgeFiqh,
    required this.badgeConvention,
    required this.profileLabel,
    required this.versionLabel,
    required this.vintageLabel,
    required this.versionValue,
    required this.vintageValue,
  });
}

/// Chrome strings per locale; unknown locales fall back to English.
const Map<String, MethodologyStrings> _chrome = {
  'en': MethodologyStrings(
    title: 'Methodology',
    integrityNote:
        'Nothing in this table is a scholarly endorsement. Angles (18°/17° '
        'and the rest) are institutional conventions estimating observable '
        'legal signs — never Maliki rulings. None of these rules has been '
        'reviewed by a qualified Maliki scholar.',
    fiqhSection: 'Fiqh-derived rules',
    conventionSection: 'Institutional / software conventions',
    badgeFiqh: 'Fiqh-derived rule',
    badgeConvention: 'Institutional / software convention',
    profileLabel: 'Profile',
    versionLabel: 'Method version',
    vintageLabel: 'Data vintage',
    versionValue: kAppVersion,
    vintageValue: 'Research deliverables D1–D10 · 2026-10-16',
  ),
  'ur': MethodologyStrings(
    title: 'طریقۂ حساب',
    integrityNote:
        'اس جدول میں کوئی علمی توثیق نہیں۔ زاویے (18°/17° وغیرہ) ادارہ جاتی '
        'کنونشن ہیں جو قابل مشاہدہ شرعی علامات کا تخمینہ لگاتے ہیں — کبھی مالکی '
        'احکام نہیں۔ ان میں سے کسی اصول کی اہل مالکی عالم نے نظرثانی نہیں کی۔',
    fiqhSection: 'فقہی اصول',
    conventionSection: 'ادارہ جاتی / سوفٹ ویئر کنونشنز',
    badgeFiqh: 'فقہی اصول',
    badgeConvention: 'ادارہ جاتی / سوفٹ ویئر کنونشن',
    profileLabel: 'پروفائل',
    versionLabel: 'طریقہ کار کا ورژن',
    vintageLabel: 'ڈیٹا کی مدت',
    versionValue: kAppVersion,
    vintageValue: 'تحقیقی دستاویزات D1–D10 · 2026-10-16',
  ),
  'ar': MethodologyStrings(
    title: 'المنهجية',
    integrityNote:
        'لا يوجد في هذا الجدول أي توثيق علمي. الزوايا (18°/17° وغيرها) أعراف '
        'مؤسسية تقدّر علامات شرعية قابلة للرصد — وليست أحكاماً مالكية أبداً. '
        'لم يراجع أيٌّ من هذه القواعد عالمٌ مالكي مؤهل.',
    fiqhSection: 'القواعد الفقهية',
    conventionSection: 'أعراف المؤسسات والبرمجيات',
    badgeFiqh: 'قاعدة فقهية',
    badgeConvention: 'عرف مؤسسي / برمجي',
    profileLabel: 'الملف',
    versionLabel: 'إصدار المنهجية',
    vintageLabel: 'حداثة البيانات',
    versionValue: kAppVersion,
    vintageValue: 'وثائق البحث D1–D10 · 2026-10-16',
  ),
  'fr': MethodologyStrings(
    title: 'Méthodologie',
    integrityNote:
        "Rien dans ce tableau n'est une approbation savante. Les angles "
        "(18°/17° et autres) sont des conventions institutionnelles estimant "
        "des signes légaux observables — jamais des règles malikites. Aucune "
        "de ces règles n'a été révisée par un savant malikite qualifié.",
    fiqhSection: 'Règles issues du fiqh',
    conventionSection: 'Conventions institutionnelles / logicielles',
    badgeFiqh: 'Règle issue du fiqh',
    badgeConvention: 'Convention institutionnelle / logicielle',
    profileLabel: 'Profil',
    versionLabel: 'Version de la méthode',
    vintageLabel: 'Ancienneté des données',
    versionValue: kAppVersion,
    vintageValue: 'Livrables de recherche D1–D10 · 2026-10-16',
  ),
};

/// Chrome strings for [languageCode] ('en' fallback).
MethodologyStrings methodologyStrings(String languageCode) =>
    _chrome[languageCode] ?? _chrome['en']!;

/// Badge label for [status] in [languageCode] ('en' fallback).
String methodologyBadgeText(String languageCode, MethodStatus status) {
  final s = methodologyStrings(languageCode);
  return status == MethodStatus.fiqhDerived ? s.badgeFiqh : s.badgeConvention;
}

/// Localized row texts: locale -> row id -> text. English is the fallback
/// for missing locales and missing rows.
const Map<String, Map<String, MethodologyText>> _content = {
  'en': {
    'fajr-sign': MethodologyText(
      'Fajr begins: true dawn',
      'The spread of light across the horizon — al-fajr al-sadiq',
      'The classical texts define a visual sign, not a degree figure. The '
          'app estimates the sign with an institutional angle (see '
          'conventions below).',
    ),
    'isha-sign': MethodologyText(
      'Isha begins: disappearance of the red twilight',
      'Redness (al-shafaq al-ahmar); whiteness does not count',
      'Attested in the Mudawwana school and the Risala ("The twilight is '
          'the redness").',
    ),
    'dhuhr-start': MethodologyText(
      'Dhuhr begins: solar transit',
      'Zawal — the sun’s crossing of the meridian',
      'Risala 8.2a; Khalil: "from the decline of the sun".',
    ),
    'asr-start': MethodologyText(
      'Asr begins: the first mithl',
      'Shadow = one object’s length plus the noon shadow, zawal shadow '
          'excluded',
      'Six-text unanimous attestation; Khalil: "to the end of the qama '
          'without the zawal shadow". Factor t = 1.',
    ),
    'maghrib-start': MethodologyText(
      'Maghrib begins: sunset',
      'Complete disappearance of the solar disk',
      'Risala 8.4; Khalil/Aqrab: Maghrib is for the setting of the sun.',
    ),
    'maghrib-mukhtar': MethodologyText(
      'Maghrib mukhtar: narrow window (mashhur)',
      'About the time for its performance after its conditions',
      'Mashhur position; the minority qawl (extension to red-twilight '
          'disappearance) is noted but not computed until scholars rule.',
    ),
    'isha-ikhtiyari': MethodologyText(
      'Isha ikhtiyari end: first third of the night',
      'Night measured from raw sunset to true dawn',
      'Aqrab: "to the first third". Anchored on the raw solar sunset — '
          'fiqh boundaries never move when the ihtiyat toggle changes.',
    ),
    'isha-daruri': MethodologyText(
      'Isha daruri end: true dawn',
      'Maghrib and Isha share the final four rak‘as (Risala 8.6)',
      'The absolute end of Isha.',
    ),
    'subh-daruri': MethodologyText(
      'Subh daruri end: sunrise',
      'Sunrise ends Subh’s daruri window',
      'Risala: isfar is the ikhtiyari end, sunrise the daruri end.',
    ),
    'isfirar': MethodologyText(
      'Asr ikhtiyari end: isfirar',
      'Yellowing of the sun — informational band, no clock time',
      'No fiqh source gives isfirar as a clock offset; it is shown as text '
          'only.',
    ),
    'fajr-angle': MethodologyText(
      'Fajr angle: 18° solar depression',
      'MWL Islamic Fiqh Council, 1986 (9th session)',
      'An institutional estimate of true dawn — NOT a Maliki ruling. '
          'Dawn-observation studies measure true dawn at roughly 14.5°–18.5°.',
    ),
    'isha-angle': MethodologyText(
      'Isha angle: 17° solar depression',
      'MWL 1986 identification with red-twilight disappearance',
      'An institutional identification of an astronomical proxy with a '
          'legal sign — the angle is the proxy, not the ruling.',
    ),
    'horizon': MethodologyText(
      'Sunrise/sunset: 90.833° zenith',
      'Upper limb + mean refraction (NOAA/USNO/Meeus convention)',
      'The standard apparent-sunrise convention shared by NOAA, USNO, '
          'Meeus, and the adhan libraries.',
    ),
    'ihtiyat': MethodologyText(
      'Ihtiyat: +1 min Dhuhr, +1 min Maghrib',
      'Precautionary offset, user-toggleable',
      'A precautionary convention, not part of the fiqh definition. The '
          'fiqh night interval is anchored on the raw sunset so boundaries '
          'do not move with this toggle.',
    ),
    'rounding': MethodologyText(
      'Rounding to the nearest minute',
      'Applied after offsets; pre-rounding values kept in diagnostics',
      'Display convention; whole-minute manual adjustments commute with '
          'rounding.',
    ),
    'high-lat': MethodologyText(
      'High-latitude fallback: middle-of-night estimates',
      'Flagged "est." in the UI, never applied silently',
      'No Maliki body was found prescribing any high-latitude method — the '
          'choice is a documented policy decision.',
    ),
    'asr-fallback': MethodologyText(
      'Asr fallback: midpoint of Dhuhr–Maghrib',
      'Used when the shadow-rule Asr falls outside Dhuhr–Maghrib',
      'A software convention: a shadow-based Asr is undefined when the sun '
          'never rises; flagged as estimated.',
    ),
    'tz-frame': MethodologyText(
      'Time-zone frame: caller’s offset',
      'Engine takes a fixed offset; callers currently pass today’s device '
          'offset for all dates',
      'A software convention with a known limitation: times follow the '
          'caller’s zone, not necessarily the location’s zone (future IANA '
          'tz work).',
    ),
    'solar-model': MethodologyText(
      'Solar model: Meeus low-precision',
      'Deterministic: identical inputs give identical outputs',
      'A deterministic software convention, as formulated by the adhan '
          'libraries; see ATTRIBUTION.md.',
    ),
    'asr-accept': MethodologyText(
      'Asr acceptance window',
      'Shadow-rule Asr accepted only strictly between Dhuhr and Maghrib',
      'A software convention guarding the shadow rule; otherwise the '
          'fallback estimate is used.',
    ),
    'maghrib-20': MethodologyText(
      'Maghrib preferred end: sunset + 20 min',
      'Practical quantification, not a matn value',
      'A practical convention, not a matn value: from malikifiqhqa.com '
          '(15–20 min), verified live; displayed as raw sunset + 20 min.',
    ),
    'midnight-variant': MethodologyText(
      'Midnight Isha variant: informational marker',
      'Ibn Habib: to midnight (Muslim 612; Risala 8.5c commentary)',
      'A labeled alternative convention, not the mashhur default.',
    ),
    'grazing': MethodologyText(
      'Grazing-event tolerance',
      '|cosH| > 1 + 1e-9 rejected as non-occurring',
      'A software convention: a small epsilon keeps near-horizon grazing '
          'events computable.',
    ),
    'profile-variants': MethodologyText(
      'Alternative profiles: named conventions',
      'Egyptian 19.5°/17.5°; UOIF 12°/12° (disputed label)',
      'Each is an institutional convention with Asr factor 1. The UOIF '
          '12°/12° label is disputed against a claimed 15°/15° reality.',
    ),
  },
  'ur': {
    'fajr-sign': MethodologyText(
      'فجر کا آغاز: فجر صادق',
      'افق پر روشنی کا پھیلنا — ظاہری علامت',
      'کلاسیکی نصوص ظاہری علامت بیان کرتی ہیں، کوئی زاویہ مقرر نہیں۔ ایپ اس '
          'علامت کا تخمینہ ادارہ جاتی زاویے سے لگاتی ہے (نیچے کنونشنز دیکھیں)۔',
    ),
    'isha-sign': MethodologyText(
      'عشاء کا آغاز: شفق احمر کا خاتمہ',
      'سرخی کا مٹنا (الشفق الأحمر)؛ سفیدی شمار نہیں',
      'مدونہ مدرسہ اور رسالہ میں ثابت ("شفق سرخی ہے")۔',
    ),
    'dhuhr-start': MethodologyText(
      'ظہر کا آغاز: زوال شمسی',
      'زوال — سورج کا نصف النہار سے گزرنا',
      'رسالہ 8.2a؛ خلیل: "زوال شمس سے"۔',
    ),
    'asr-start': MethodologyText(
      'عصر کا آغاز: مثل اول',
      'سایہ = چیز کی لمبائی جمع زوال کا سایہ، زوال کا سایہ شامل نہیں',
      'چھ نصوص میں اتفاق؛ خلیل: "آخر القامة بغیر ظل الزوال"۔ فیکٹر t = 1۔',
    ),
    'maghrib-start': MethodologyText(
      'مغرب کا آغاز: غروب آفتاب',
      'سورج کی ٹکیا کا مکمل غروب',
      'رسالہ 8.4؛ خلیل/اقرب: مغرب سورج کے غروب پر۔',
    ),
    'maghrib-mukhtar': MethodologyText(
      'مغرب مختار: تنگ وقفہ (مشہور)',
      'اس کی شرطوں کے بعد ادائیگی کے بقدر',
      'مشہور موقف؛ اقلیتی قول (شفق احمر کے خاتمے تک توسیع) نوٹ شدہ ہے، علماء '
          'کے حکم تک حساب میں شامل نہیں۔',
    ),
    'isha-ikhtiyari': MethodologyText(
      'عشاء اختیاری کا خاتمہ: رات کا پہلا ثلث',
      'رات خام غروب سے فجر صادق تک',
      'اقرب: "للثلث الأول"۔ خام شمسی غروب پر مبنی — احتیاط بدلنے سے فقہی حدیں '
          'نہیں بدلتیں۔',
    ),
    'isha-daruri': MethodologyText(
      'عشاء ضروری کا خاتمہ: فجر صادق',
      'مغرب اور عشاء آخری چار رکعت میں مشترک (رسالہ 8.6)',
      'عشاء کی آخری حد۔',
    ),
    'subh-daruri': MethodologyText(
      'صبح ضروری کا خاتمہ: طلوع آفتاب',
      'طلوع آفتاب صبح کی ضروری حد ختم کرتا ہے',
      'رسالہ: اسفار اختیاری کا خاتمہ ہے، طلوع ضروری کا۔',
    ),
    'isfirar': MethodologyText(
      'عصر اختیاری کا خاتمہ: اصفرار',
      'سورج کی زردی — معلوماتی بینڈ، گھڑی کا وقت نہیں',
      'کوئی فقہی مصدر اصفرار کو گھڑی کا وقت نہیں دیتا؛ صرف متن کے طور پر '
          'دکھایا جاتا ہے۔',
    ),
    'fajr-angle': MethodologyText(
      'فجر کا زاویہ: 18° شمسی انحطاط',
      'MWL اسلامی فقہ کونسل، 1986 (9واں اجلاس)',
      'فجر صادق کا ادارہ جاتی تخمینہ — مالکی حکم نہیں۔ مشاہداتی مطالعات فجر '
          'صادق کو تقریباً 14.5°–18.5° پر ماپتی ہیں۔',
    ),
    'isha-angle': MethodologyText(
      'عشاء کا زاویہ: 17° شمسی انحطاط',
      'MWL 1986 کا شفق احمر سے شناخت',
      'قانونی علامت کے ساتھ فلکیاتی پراکسی کی ادارہ جاتی شناخت — زاویہ پراکسی '
          'ہے، حکم نہیں۔',
    ),
    'horizon': MethodologyText(
      'طلوع/غروب: 90.833° زنیتھ',
      'اوپری کنارہ + اوسط انکسار (NOAA/USNO/Meeus کنونشن)',
      'NOAA، USNO، Meeus اور adhan لائبریریوں کی مشترکہ معیاری ظاہری طلوع کی '
          'کنونشن۔',
    ),
    'ihtiyat': MethodologyText(
      'احتیاط: ظہر +1 منٹ، مغرب +1 منٹ',
      'احتیاطی اضافہ، صارف بند/کھول سکتا ہے',
      'احتیاطی کنونشن ہے، فقہی تعریف کا حصہ نہیں۔ رات کا وقفہ خام غروب پر '
          'مبنی ہے تاکہ حدیں نہ بدلیں۔',
    ),
    'rounding': MethodologyText(
      'قریب ترین منٹ تک تقریب',
      'اضافوں کے بعد لاگو؛ تقریب سے پہلے کی قیمتیں ڈائگناسٹکس میں',
      'ڈسپلے کنونشن؛ پورے منٹ کی دستی تبدیلیاں تقریب کے ساتھ بدلے بغیر لاگو '
          'ہوتی ہیں۔',
    ),
    'high-lat': MethodologyText(
      'قطبی عرض البلد فال بیک: آدھی رات کا تخمینہ',
      'UI میں "تخمینی" کا نشان، کبھی خفیہ نہیں',
      'کوئی مالکی ادارہ کسی قطبی طریقے کی تجویز میں نہیں ملا — انتخاب '
          'دستاویزی پالیسی فیصلہ ہے۔',
    ),
    'asr-fallback': MethodologyText(
      'عصر فال بیک: ظہر–مغرب کا وسط',
      'جب سایہ والے عصر ظہر–مغرب سے باہر ہو',
      'سوفٹ ویئر کنونشن: جب سورج طلوع نہ ہو تو سایہ والا عصر غیرمعین ہے؛ '
          'تخمینے کے نشان کے ساتھ۔',
    ),
    'tz-frame': MethodologyText(
      'ٹائم زون فریم: کالر کا آفسیٹ',
      'انجن مقررہ آفسیٹ لیتا ہے؛ کالرز فی الحال تمام تاریخوں کے لیے آج کا '
          'ڈیوائس آفسیٹ دیتے ہیں',
      'سوفٹ ویئر کنونشن کی معلوم حد: اوقات کالر کے زون کے مطابق ہیں، مقام کے '
          'زون کے مطابق ضروری نہیں (مستقبل میں IANA tz)۔',
    ),
    'solar-model': MethodologyText(
      'شمسی ماڈل: Meeus کم صحت والا',
      'مقرر: ایک جیسے ان پٹ پر ایک جیسے آؤٹ پٹ',
      'مقرر سوفٹ ویئر کنونشن، adhan لائبریریوں کی صیغہ بندی کے مطابق؛ '
          'ATTRIBUTION.md دیکھیں۔',
    ),
    'asr-accept': MethodologyText(
      'عصر قبولیت کی حد',
      'سایہ والا عصر صرف ظہر اور مغرب کے درمیان قبول',
      'سوفٹ ویئر کنونشن سایہ والے اصول کی حفاظت کرتا ہے؛ ورنہ فال بیک تخمینہ '
          'استعمال ہوتا ہے۔',
    ),
    'maghrib-20': MethodologyText(
      'مغرب ترجیحی خاتمہ: غروب + 20 منٹ',
      'عملی تخمینہ، متنی قدر نہیں',
      'عملی کنونشن، متنی قدر نہیں: malikifiqhqa.com (15–20 منٹ) سے، براہ '
          'راست تصدیق شدہ؛ خام غروب + 20 منٹ دکھایا جاتا ہے۔',
    ),
    'midnight-variant': MethodologyText(
      'آدھی رات والا عشاء: معلوماتی نشان',
      'ابن حبیب: آدھی رات تک (مسلم 612؛ رسالہ 8.5c حاشیہ)',
      'نامزد متبادل کنونشن، مشہور ڈیفالٹ نہیں۔',
    ),
    'grazing': MethodologyText(
      'غروب کے قریب رواداری',
      '|cosH| > 1 + 1e-9 غیر واقع شمار',
      'سوفٹ ویئر کنونشن: چھوٹا epsilon افق کے قریب کے واقعات کو قابل حساب '
          'رکھتا ہے۔',
    ),
    'profile-variants': MethodologyText(
      'متبادل پروفائلز: نامزد کنونشنز',
      'مصری 19.5°/17.5°؛ UOIF 12°/12° (متنازع لیبل)',
      'ہر ایک عصر فیکٹر 1 کے ساتھ ادارہ جاتی کنونشن ہے۔ UOIF 12°/12° کے خلاف '
          '15°/15° کا دعویٰ متنازع ہے۔',
    ),
  },
  'ar': {
    'fajr-sign': MethodologyText(
      'بداية الفجر: الفجر الصادق',
      'انتشار الضوء في الأفق — علامة مرئية',
      'النصوص الكلاسيكية تحدد علامة مرئية لا درجة. التطبيق يقدّر العلامة '
          'بزاوية مؤسسية (انظر الأعراف أدناه).',
    ),
    'isha-sign': MethodologyText(
      'بداية العشاء: مغيب الشفق الأحمر',
      'زوال الحمرة (الشفق الأحمر)؛ البياض لا يُعتد به',
      'ثابت في مدرسة المدونة والرسالة ("الشفق الحمرة").',
    ),
    'dhuhr-start': MethodologyText(
      'بداية الظهر: الزوال الشمسي',
      'الزوال — عبور الشمس خط الزوال',
      'الرسالة 8.2a؛ خليل: "من زوال الشمس".',
    ),
    'asr-start': MethodologyText(
      'بداية العصر: المثل الأول',
      'الظل = طول الشيء زائد ظل الزوال، دون ظل الزوال',
      'اتفاق ستة نصوص؛ خليل: "لآخر القامة بغير ظل الزوال". العامل t = 1.',
    ),
    'maghrib-start': MethodologyText(
      'بداية المغرب: الغروب',
      'الاختفاء التام لقرص الشمس',
      'الرسالة 8.4؛ خليل/أقرب: المغرب لغروب الشمس.',
    ),
    'maghrib-mukhtar': MethodologyText(
      'مختار المغرب: نافذة ضيقة (المشهور)',
      'بقدر فعلها بعد شروطها',
      'الموقف المشهور؛ القول المخالف (الامتداد إلى مغيب الشفق الأحمر) مذكور '
          'لكنه غير محسوب حتى يحكم العلماء.',
    ),
    'isha-ikhtiyari': MethodologyText(
      'نهاية اختياري العشاء: الثلث الأول من الليل',
      'الليل من الغروب الخام إلى الفجر الصادق',
      'أقرب: "للثلث الأول". مثبت على الغروب الشمسي الخام — الحدود الفقهية لا '
          'تتحرك بتبديل الاحتياط.',
    ),
    'isha-daruri': MethodologyText(
      'نهاية ضروري العشاء: الفجر الصادق',
      'المغرب والعشاء يشتركان في الأربع ركعات الأخيرة (الرسالة 8.6)',
      'النهاية المطلقة للعشاء.',
    ),
    'subh-daruri': MethodologyText(
      'نهاية ضروري الصبح: الشروق',
      'الشروق ينهي نافذة ضروري الصبح',
      'الرسالة: الإسفار نهاية الاختياري، والشروق نهاية الضروري.',
    ),
    'isfirar': MethodologyText(
      'نهاية اختياري العصر: الاصفرار',
      'اصفرار الشمس — نطاق إعلامي، لا وقت ساعة',
      'لا مصدر فقهي يجعل الاصفرار وقت ساعة؛ يُعرض نصاً فقط.',
    ),
    'fajr-angle': MethodologyText(
      'زاوية الفجر: 18° انحطاط شمسي',
      'مجمع الفقه الإسلامي برابطة العالم الإسلامي، 1986 (الدورة 9)',
      'تقدير مؤسسي للفجر الصادق — ليس حكماً مالكياً. دراسات الرصد تقيس الفجر '
          'الصادق عند 14.5°–18.5° تقريباً.',
    ),
    'isha-angle': MethodologyText(
      'زاوية العشاء: 17° انحطاط شمسي',
      'تحديد رابطة 1986 لمغيب الشفق الأحمر',
      'تحديد مؤسسي لوكيل فلكي بعلامة شرعية — الزاوية وكيل، لا حكم.',
    ),
    'horizon': MethodologyText(
      'الشروق/الغروب: سمت 90.833°',
      'الحافة العليا + الانكسار المتوسط (عرف NOAA/USNO/Meeus)',
      'عرف الشروق الظاهري القياسي المشترك بين NOAA وUSNO وMeeus ومكتبات الأذان.',
    ),
    'ihtiyat': MethodologyText(
      'الاحتياط: +1 دقيقة ظهر، +1 دقيقة مغرب',
      'إزاحة احتياطية، قابلة للتبديل من المستخدم',
      'عرف احتياطي، ليس جزءاً من التعريف الفقهي. فترة الليل مثبتة على الغروب '
          'الخام فلا تتحرك الحدود.',
    ),
    'rounding': MethodologyText(
      'التقريب إلى أقرب دقيقة',
      'يُطبق بعد الإزاحات؛ القيم قبل التقريب في التشخيص',
      'عرف عرض؛ تعديلات الدقائق الكاملة اليدوية تتبادل مع التقريب.',
    ),
    'high-lat': MethodologyText(
      'احتياطي العروض العالية: تقديرات منتصف الليل',
      'يُعلَّم "تقديري" في الواجهة، لا يُطبق خفية أبداً',
      'لم يُعثر على هيئة مالكية تشرّع أي طريقة للعروض العالية — الاختيار قرار '
          'سياسة موثق.',
    ),
    'asr-fallback': MethodologyText(
      'احتياطي العصر: منتصف الظهر–المغرب',
      'يُستخدم عند خروج عصر الظل عن الظهر–المغرب',
      'عرف برمجي: عصر الظل غير معرّف عندما لا تشرق الشمس؛ بعلامة تقدير.',
    ),
    'tz-frame': MethodologyText(
      'إطار المنطقة الزمنية: إزاحة المتصل',
      'المحرك يأخذ إزاحة ثابتة؛ المتصلون يمررون حالياً إزاحة الجهاز لليوم لكل '
          'التواريخ',
      'عرف برمجي بقيد معلوم: الأوقات تتبع منطقة المتصل لا الموقع بالضرورة '
          '(عمل IANA tz مستقبلاً).',
    ),
    'solar-model': MethodologyText(
      'النموذج الشمسي: Meeus منخفض الدقة',
      'حتمي: المدخلات نفسها تعطي المخرجات نفسها',
      'عرف برمجي حتمي، بصياغة مكتبات الأذان؛ انظر ATTRIBUTION.md.',
    ),
    'asr-accept': MethodologyText(
      'نافذة قبول العصر',
      'عصر الظل مقبول فقط بين الظهر والمغرب حصراً',
      'عرف برمجي يحرس قاعدة الظل؛ وإلا استُخدم التقدير الاحتياطي.',
    ),
    'maghrib-20': MethodologyText(
      'نهاية مفضل المغرب: الغروب + 20 دقيقة',
      'تقدير عملي، ليس قيمة متنية',
      'عرف عملي، ليس قيمة متنية: من malikifiqhqa.com (15–20 دقيقة)، مُتحقق '
          'منه مباشرة؛ يُعرض كغروب خام + 20 دقيقة.',
    ),
    'midnight-variant': MethodologyText(
      'بديل العشاء لنصف الليل: علامة إعلامية',
      'ابن حبيب: إلى منتصف الليل (مسلم 612؛ حاشية الرسالة 8.5c)',
      'عرف بديل مسمّى، ليس الافتراضي المشهور.',
    ),
    'grazing': MethodologyText(
      'تسامح الأحداث المماسية',
      '|cosH| > 1 + 1e-9 تُرفض كغير واقعة',
      'عرف برمجي: إبسيلون صغير يُبقي أحداث الأفق المماسية قابلة للحساب.',
    ),
    'profile-variants': MethodologyText(
      'ملفات بديلة: أعراف مسماة',
      'المصري 19.5°/17.5°؛ UOIF 12°/12° (تسمية متنازع عليها)',
      'كلٌّ عرف مؤسسي بعامل عصر 1. تسمية UOIF 12°/12° متنازع عليها مقابل دعوى '
          '15°/15°.',
    ),
  },
  'fr': {
    'fajr-sign': MethodologyText(
      'Début du Fajr : l’aube vraie',
      'La diffusion de la lumière à l’horizon — al-fajr al-sadiq',
      'Les textes classiques définissent un signe visible, pas un angle. '
          'L’app estime le signe par un angle institutionnel (voir '
          'conventions ci-dessous).',
    ),
    'isha-sign': MethodologyText(
      'Début de l’Isha : disparition du crépuscule rouge',
      'La rougeur (al-shafaq al-ahmar) ; la blancheur ne compte pas',
      'Attesté dans l’école de la Mudawwana et la Risala (« le crépuscule, '
          'c’est la rougeur »).',
    ),
    'dhuhr-start': MethodologyText(
      'Début du Dhuhr : transit solaire',
      'Le zawal — passage du soleil au méridien',
      'Risala 8.2a ; Khalil : « dès le déclin du soleil ».',
    ),
    'asr-start': MethodologyText(
      'Début du ‘Asr : le premier mithl',
      'Ombre = une longueur d’objet plus l’ombre de midi, ombre du zawal '
          'exclue',
      'Attestation unanime de six textes ; Khalil : « jusqu’à la fin de la '
          'qama sans l’ombre du zawal ». Facteur t = 1.',
    ),
    'maghrib-start': MethodologyText(
      'Début du Maghrib : coucher du soleil',
      'Disparition complète du disque solaire',
      'Risala 8.4 ; Khalil/Aqrab : le Maghrib est pour le coucher du soleil.',
    ),
    'maghrib-mukhtar': MethodologyText(
      'Mukhtar du Maghrib : fenêtre étroite (mashhur)',
      'De quoi l’accomplir après ses conditions',
      'Position mashhur ; l’avis minoritaire (extension à la disparition du '
          'crépuscule rouge) est noté, non calculé, jusqu’à décision savante.',
    ),
    'isha-ikhtiyari': MethodologyText(
      'Fin ikhtiyari de l’Isha : premier tiers de la nuit',
      'Nuit mesurée du coucher brut à l’aube vraie',
      'Aqrab : « jusqu’au premier tiers ». Ancrée sur le coucher solaire '
          'brut — les bornes fiqh ne bougent pas avec l’ihtiyat.',
    ),
    'isha-daruri': MethodologyText(
      'Fin daruri de l’Isha : l’aube vraie',
      'Maghrib et Isha partagent les quatre dernières rak‘as (Risala 8.6)',
      'La fin absolue de l’Isha.',
    ),
    'subh-daruri': MethodologyText(
      'Fin daruri du Subh : lever du soleil',
      'Le lever du soleil clôt la fenêtre daruri du Subh',
      'Risala : l’isfar est la fin ikhtiyari, le lever la fin daruri.',
    ),
    'isfirar': MethodologyText(
      'Fin ikhtiyari du ‘Asr : l’isfirar',
      'Jaunissement du soleil — bande informative, pas d’heure',
      'Aucune source fiqh ne donne l’isfirar comme heure ; affiché en texte '
          'seul.',
    ),
    'fajr-angle': MethodologyText(
      'Angle du Fajr : 18° de dépression solaire',
      'Conseil de fiqh islamique de la MWL, 1986 (9e session)',
      'Estimation institutionnelle de l’aube vraie — pas une règle malikite. '
          'Les études d’observation mesurent l’aube vraie vers 14,5°–18,5°.',
    ),
    'isha-angle': MethodologyText(
      'Angle de l’Isha : 17° de dépression solaire',
      'Identification MWL 1986 avec la disparition du crépuscule rouge',
      'Identification institutionnelle d’un proxy astronomique avec un signe '
          'légal — l’angle est le proxy, pas la règle.',
    ),
    'horizon': MethodologyText(
      'Lever/coucher : zénith 90,833°',
      'Limb supérieur + réfraction moyenne (convention NOAA/USNO/Meeus)',
      'La convention standard du lever apparent partagée par NOAA, USNO, '
          'Meeus et les bibliothèques adhan.',
    ),
    'ihtiyat': MethodologyText(
      'Ihtiyat : +1 min Dhuhr, +1 min Maghrib',
      'Décalage de précaution, désactivable par l’utilisateur',
      'Convention de précaution, pas partie de la définition fiqh. '
          'L’intervalle de nuit est ancré sur le coucher brut pour que les '
          'bornes ne bougent pas.',
    ),
    'rounding': MethodologyText(
      'Arrondi à la minute la plus proche',
      'Appliqué après les décalages ; valeurs pré-arrondi en diagnostic',
      'Convention d’affichage ; les ajustements manuels en minutes entières '
          'commutent avec l’arrondi.',
    ),
    'high-lat': MethodologyText(
      'Secours hautes latitudes : estimations milieu de nuit',
      'Signalé « est. » dans l’UI, jamais appliqué en silence',
      'Aucun organisme malikite prescrivant une méthode de hautes latitudes '
          'n’a été trouvé — le choix est une décision de politique documentée.',
    ),
    'asr-fallback': MethodologyText(
      'Secours ‘Asr : milieu Dhuhr–Maghrib',
      'Utilisé quand le ‘Asr d’ombre sort de Dhuhr–Maghrib',
      'Convention logicielle : un ‘Asr d’ombre est indéfini quand le soleil '
          'ne se lève pas ; signalé comme estimé.',
    ),
    'tz-frame': MethodologyText(
      'Cadre de fuseau : décalage de l’appelant',
      'Le moteur prend un décalage fixe ; les appelants passent aujourd’hui '
          'le décalage de l’appareil pour toutes les dates',
      'Convention logicielle à limite connue : les heures suivent le fuseau '
          'de l’appelant, pas forcément celui du lieu (futur travail IANA tz).',
    ),
    'solar-model': MethodologyText(
      'Modèle solaire : Meeus basse précision',
      'Déterministe : mêmes entrées, mêmes sorties',
      'Convention logicielle déterministe, telle que formulée par les '
          'bibliothèques adhan ; voir ATTRIBUTION.md.',
    ),
    'asr-accept': MethodologyText(
      'Fenêtre d’acceptation du ‘Asr',
      '‘Asr d’ombre accepté uniquement strictement entre Dhuhr et Maghrib',
      'Convention logicielle gardant la règle d’ombre ; sinon l’estimation '
          'de secours est utilisée.',
    ),
    'maghrib-20': MethodologyText(
      'Fin préférée du Maghrib : coucher + 20 min',
      'Quantification pratique, pas une valeur de matn',
      'Convention pratique, pas une valeur de matn : d’après '
          'malikifiqhqa.com (15–20 min), vérifié en direct ; affiché comme '
          'coucher brut + 20 min.',
    ),
    'midnight-variant': MethodologyText(
      'Variante minuit de l’Isha : repère informatif',
      'Ibn Habib : jusqu’à minuit (Muslim 612 ; commentaire Risala 8.5c)',
      'Convention alternative étiquetée, pas le défaut mashhur.',
    ),
    'grazing': MethodologyText(
      'Tolérance des événements rasants',
      '|cosH| > 1 + 1e-9 rejeté comme non survenu',
      'Convention logicielle : un petit epsilon garde les événements '
          'rasants calculables.',
    ),
    'profile-variants': MethodologyText(
      'Profils alternatifs : conventions nommées',
      'Égyptien 19,5°/17,5° ; UOIF 12°/12° (étiquette contestée)',
      'Chacun est une convention institutionnelle avec facteur ‘Asr 1. '
          'L’étiquette UOIF 12°/12° est contestée face à une réalité alléguée '
          'de 15°/15°.',
    ),
  },
};

/// Localized texts for [rowId] in [languageCode] ('en' fallback for both).
MethodologyText methodologyText(String languageCode, String rowId) {
  final byId = _content[languageCode] ?? _content['en']!;
  return byId[rowId] ?? _content['en']![rowId]!;
}

/// All localized row texts for [languageCode] ('en' fallback).
Map<String, MethodologyText> methodologyTexts(String languageCode) =>
    _content[languageCode] ?? _content['en']!;
