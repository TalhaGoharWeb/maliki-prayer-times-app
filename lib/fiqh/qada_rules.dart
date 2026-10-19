/// Qada (missed-prayer) rules engine for the Maliki prayer-times app.
///
/// This file is PURE Dart: no Flutter imports, no UI, independently
/// testable. It has two parts:
///
/// 1. **Backlog estimation** ([MalikiQadaRulesEngine.estimatePeriods]):
///    pure date math turning user-supplied date ranges + per-prayer daily
///    miss rates into per-prayer estimated counts with a low/high band.
///    An estimate is never a confirmed obligation: every successful result
///    carries `needsReview: true`.
///
/// 2. **Fiqh rule registry** ([QadaRulesRegistry]): a data-model registry
///    of qada / hayd / nifas / istihada / ordering / traveler rules. Each
///    rule carries its source identification, review status, and an
///    explicit note of what is unverified. Review status lives in the data
///    model only — it never appears in user-facing strings.
///
/// Integrity boundaries:
/// * Nothing here is a ruling issued by this app. Rules marked
///   [ReviewStatus.reviewed] were verified against a primary-source text
///   actually read (book, chapter, URL/edition recorded in
///   [QadaRule.reviewNote]); the D7 scholarly review is still outstanding
///   for all of them. Everything else is [ReviewStatus.proposed] with the
///   unverified parts named in [QadaRule.notes].
/// * [MalikiQadaRulesEngine.assessBleeding] NEVER classifies bleeding as
///   hayd / nifas / istihada: no reviewed rule in this registry authorises
///   classification, so it always returns `needsScholarlyReview: true`,
///   echoes the recorded observations, and gives safe generic guidance.
/// * The engine has NO balance-mutating methods: it estimates and it
///   records rules; it never creates, confirms, or cancels an obligation.
library;

import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/models/review_status.dart';

/// The prayers that can be owed as qada. Sunrise is a timetable marker,
/// never a missed prayer, and is excluded.
const List<Prayer> qadaPrayers = <Prayer>[
  Prayer.fajr,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

/// One estimation window: an inclusive civil-date range plus the average
/// number of missed prayers per day for each prayer over that range.
///
/// A rate of 0.0 means "none of this prayer missed per day"; 5.0 is the
/// ceiling (a prayer cannot be missed more than once per day, and 5.0
/// leaves headroom for unusual cases without pretending precision).
class EstimationPeriodInput {
  /// First civil day of the window (time components are ignored).
  final DateTime start;

  /// Last civil day of the window, inclusive (time components ignored).
  final DateTime end;

  /// Average missed prayers per day, per prayer, in 0.0..5.0.
  /// Prayers absent from the map default to 0.0.
  final Map<Prayer, double> dailyRates;

  /// Optional user label, e.g. "university years". Shown nowhere
  /// user-facing unless the caller chooses to display it.
  final String label;

  const EstimationPeriodInput({
    required this.start,
    required this.end,
    required this.dailyRates,
    this.label = '',
  });
}

/// Why an estimation was rejected. Returned as data — never thrown —
/// so callers decide how to present it.
enum EstimationErrorKind {
  /// [EstimationPeriodInput.start] falls after
  /// [EstimationPeriodInput.end].
  reversedDates,

  /// Two windows share at least one civil day. Overlapping windows are
  /// rejected outright rather than merged: merging would silently
  /// double-count days, and silently dropping days would under-count.
  overlappingRanges,

  /// A daily rate is NaN, infinite, negative, or above 5.0.
  invalidRate,
}

/// A rejected estimation: the kind, a human-readable message, and the
/// index of the offending period in the input list when applicable.
///
/// The message contains no review-status wording.
class EstimationError {
  final EstimationErrorKind kind;
  final String message;
  final int? periodIndex;

  const EstimationError({
    required this.kind,
    required this.message,
    this.periodIndex,
  });
}

/// The estimated count band for one prayer.
class PrayerEstimate {
  final Prayer prayer;

  /// floor(total days x rate), summed across periods.
  final double low;

  /// ceil(total days x rate), summed across periods.
  final double high;

  const PrayerEstimate({
    required this.prayer,
    required this.low,
    required this.high,
  });
}

/// A successful backlog estimation.
class EstimationResult {
  /// One band per prayer, in [qadaPrayers] order.
  final List<PrayerEstimate> perPrayer;

  /// Sum of the per-prayer lows.
  final double totalLow;

  /// Sum of the per-prayer highs.
  final double totalHigh;

  /// Total civil days covered across all windows.
  final int totalDays;

  /// What the numbers assume, in fixed order (deterministic).
  final List<String> assumptions;

  /// Caveats about the input, in fixed order (deterministic).
  final List<String> warnings;

  /// ALWAYS true: an estimate is never a confirmed obligation.
  final bool needsReview;

  const EstimationResult({
    required this.perPrayer,
    required this.totalLow,
    required this.totalHigh,
    required this.totalDays,
    required this.assumptions,
    required this.warnings,
    required this.needsReview,
  });
}

/// The outcome of [MalikiQadaRulesEngine.estimatePeriods]: either a
/// result or a typed error. Never throws on bad input.
sealed class EstimationOutcome {
  const EstimationOutcome();
}

/// A successful estimation.
final class EstimationSuccess extends EstimationOutcome {
  final EstimationResult result;
  const EstimationSuccess(this.result);
}

/// A rejected estimation.
final class EstimationFailure extends EstimationOutcome {
  final EstimationError error;
  const EstimationFailure(this.error);
}

/// The fiqh domain a [QadaRule] belongs to.
enum QadaRuleDomain {
  /// Obligation to make up missed prayers, and when the obligation starts.
  qadaObligation,

  /// Menstruation.
  hayd,

  /// Postpartum bleeding.
  nifas,

  /// Non-menstrual vaginal bleeding.
  istihada,

  /// Order in which missed prayers are made up.
  ordering,

  /// Missed prayers of a traveler.
  traveler,
}

/// Plain domain name for data-model use. Never user-facing review wording.
String qadaRuleDomainName(QadaRuleDomain domain) =>
    switch (domain) {
      QadaRuleDomain.qadaObligation => 'qada-obligation',
      QadaRuleDomain.hayd => 'hayd',
      QadaRuleDomain.nifas => 'nifas',
      QadaRuleDomain.istihada => 'istihada',
      QadaRuleDomain.ordering => 'ordering',
      QadaRuleDomain.traveler => 'traveler',
    };

/// One fiqh rule in the registry: data only, never a ruling issued.
///
/// Rules the program verified against a source it actually read carry
/// [ReviewStatus.reviewed] with the reading recorded in [reviewNote]
/// (book, chapter, URL/edition, date); reviewed rules divide into
/// primary-text reads (QH-001..QH-004) and a secondary-manual read
/// (QH-103..QH-107 — an English contemporary manual, explicitly not a
/// primary classical Arabic text). Note the D7 scholarly review is still
/// outstanding for every rule: [reviewerName] stays null until a
/// scholar's answers are recorded. Everything else is
/// [ReviewStatus.proposed], and [notes] names exactly what is unverified.
class QadaRule {
  /// Registry id, e.g. 'QH-001'.
  final String id;

  final QadaRuleDomain domain;

  /// Short title, e.g. 'Prayer caught in daruri time counts as ada'.
  final String title;

  /// Verbatim Arabic source text. Set ONLY when the passage was actually
  /// read (see [reviewNote]); otherwise null — never reconstructed.
  final String? arabicSourceText;

  /// Book + chapter + edition/publication details identifying the source.
  /// Never empty, even for proposed rules (which name where the passage
  /// is expected, without asserting page numbers).
  final String sourceIdentification;

  /// Plain-English summary of the rule's content.
  final String englishSummary;

  /// Conditions under which the rule applies.
  final List<String> conditions;

  /// Cases the rule does not cover.
  final List<String> exceptions;

  /// Recorded disagreement inside the school, or 'Not yet researched.'
  final String knownDisagreement;

  final ReviewStatus status;

  /// Answering scholar's name, once recorded. Null until then.
  final String? reviewerName;

  /// When the answers were given. Null until then.
  final DateTime? reviewDate;

  /// What was read, when, and by whom — e.g. the shamela URL, edition,
  /// and reading date for engineering-verified rules.
  final String? reviewNote;

  /// Registry schema version of this rule entry, e.g. '1.0'.
  final String ruleVersion;

  /// Exactly what is unverified or unresolved about this rule.
  /// Required non-empty for [ReviewStatus.proposed] rules.
  final String notes;

  /// Whether this rule authorises classifying observed bleeding as
  /// hayd / nifas / istihada. No current rule sets this: it is the
  /// extension point for a future recorded scholarly review.
  final bool classifiesBleeding;

  const QadaRule({
    required this.id,
    required this.domain,
    required this.title,
    this.arabicSourceText,
    required this.sourceIdentification,
    required this.englishSummary,
    this.conditions = const <String>[],
    this.exceptions = const <String>[],
    this.knownDisagreement = 'Not yet researched.',
    required this.status,
    this.reviewerName,
    this.reviewDate,
    this.reviewNote,
    required this.ruleVersion,
    required this.notes,
    this.classifiesBleeding = false,
  });
}

/// A user's recorded bleeding observation. Facts only — the engine never
/// infers a classification from these.
class BleedingObservation {
  /// Civil date the bleeding started, if known.
  final DateTime? startDate;

  /// How many days it has lasted so far, if known.
  final int? durationDays;

  /// The user's own description, recorded verbatim.
  final String? notes;

  const BleedingObservation({this.startDate, this.durationDays, this.notes});
}

/// The outcome of [MalikiQadaRulesEngine.assessBleeding].
class BleedingAssessment {
  /// True whenever no reviewed rule authorises a classification —
  /// currently always true.
  final bool needsScholarlyReview;

  /// The input facts echoed back, so the record is auditable.
  final List<String> recordedObservations;

  /// Safe generic guidance. Contains no classification and no
  /// review-status wording.
  final String guidance;

  /// Registry rules consulted, by id (all unreviewed for classification).
  final List<String> relatedRuleIds;

  const BleedingAssessment({
    required this.needsScholarlyReview,
    required this.recordedObservations,
    required this.guidance,
    required this.relatedRuleIds,
  });
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The qada rules engine: estimation math plus the fiqh rule registry.
///
/// All members are static; the engine keeps no state, mutates no
/// balances, and issues no rulings.
abstract final class MalikiQadaRulesEngine {
  /// Estimates missed-prayer counts over [periods].
  ///
  /// Deterministic: identical inputs produce identical outputs — windows
  /// are sorted by start date, days are counted as UTC civil days
  /// (inclusive), and assumption/warning lists are built in fixed order.
  /// No clock, no randomness.
  ///
  /// Rejections (typed, never thrown, never double-counted):
  /// * a window whose start is after its end →
  ///   [EstimationErrorKind.reversedDates]
  /// * two windows sharing a civil day →
  ///   [EstimationErrorKind.overlappingRanges]
  /// * a rate that is NaN, infinite, negative, or above 5.0 →
  ///   [EstimationErrorKind.invalidRate]
  ///
  /// An empty [periods] list is a valid zero backlog, not an error.
  static EstimationOutcome estimatePeriods(
      List<EstimationPeriodInput> periods) {
    // Normalise to UTC civil days and validate each window.
    final starts = <DateTime>[];
    final ends = <DateTime>[];
    for (var i = 0; i < periods.length; i++) {
      final p = periods[i];
      final s = DateTime.utc(p.start.year, p.start.month, p.start.day);
      final e = DateTime.utc(p.end.year, p.end.month, p.end.day);
      if (s.isAfter(e)) {
        return EstimationFailure(EstimationError(
          kind: EstimationErrorKind.reversedDates,
          message:
              'The start date (${_ymd(s)}) is after the end date (${_ymd(e)}). '
              'Swap them or correct the range and try again.',
          periodIndex: i,
        ));
      }
      for (final prayer in qadaPrayers) {
        final rate = p.dailyRates[prayer] ?? 0.0;
        if (rate.isNaN || rate.isInfinite || rate < 0.0 || rate > 5.0) {
          return EstimationFailure(EstimationError(
            kind: EstimationErrorKind.invalidRate,
            message:
                'The daily rate for ${prayer.name} must be between 0.0 and '
                '5.0 missed prayers per day.',
            periodIndex: i,
          ));
        }
      }
      starts.add(s);
      ends.add(e);
    }

    // Sort windows by start (then end) so overlap detection and the
    // output are independent of input order.
    final order = List<int>.generate(periods.length, (i) => i)
      ..sort((a, b) {
        final c = starts[a].compareTo(starts[b]);
        return c != 0 ? c : ends[a].compareTo(ends[b]);
      });

    for (var k = 1; k < order.length; k++) {
      final prev = order[k - 1];
      final curr = order[k];
      // Inclusive ranges: sharing even one civil day is an overlap.
      if (!starts[curr].isAfter(ends[prev])) {
        return EstimationFailure(EstimationError(
          kind: EstimationErrorKind.overlappingRanges,
          message:
              'Two date ranges share at least one day (${_ymd(starts[curr])} '
              'falls inside another range). Overlapping ranges are not '
              'allowed because shared days would be counted twice. Split '
              'them into non-overlapping ranges and try again.',
          periodIndex: curr,
        ));
      }
    }

    // Accumulate days x rate per prayer. DateTime handles leap years and
    // month boundaries; the inclusive count is difference + 1.
    final totals = <Prayer, double>{for (final p in qadaPrayers) p: 0.0};
    var totalDays = 0;
    var sawFractionalRate = false;
    for (final i in order) {
      final p = periods[i];
      final days = ends[i].difference(starts[i]).inDays + 1;
      totalDays += days;
      for (final prayer in qadaPrayers) {
        final rate = p.dailyRates[prayer] ?? 0.0;
        if (rate != rate.truncateToDouble()) sawFractionalRate = true;
        totals[prayer] = totals[prayer]! + days * rate;
      }
    }
    final zeroRatePrayers = <Prayer>[];
    for (final prayer in qadaPrayers) {
      var allZero = true;
      for (final p in periods) {
        if ((p.dailyRates[prayer] ?? 0.0) > 0.0) {
          allZero = false;
          break;
        }
      }
      if (allZero) zeroRatePrayers.add(prayer);
    }

    final perPrayer = <PrayerEstimate>[
      for (final prayer in qadaPrayers)
        PrayerEstimate(
          prayer: prayer,
          low: totals[prayer]!.floorToDouble(),
          high: totals[prayer]!.ceilToDouble(),
        ),
    ];
    final totalLow = perPrayer.fold<double>(0.0, (sum, e) => sum + e.low);
    final totalHigh = perPrayer.fold<double>(0.0, (sum, e) => sum + e.high);

    final assumptions = <String>[
      'Each civil day from a range\u2019s start to its end (inclusive) '
          'is counted exactly once.',
      'Daily rates are averages: the estimated count for a prayer is '
          '(days x rate) summed over all ranges.',
      'The low end rounds the estimate down and the high end rounds it up, '
          'so fractional rates widen the band.',
      'Prayers missing from a range\u2019s rates are treated as 0.0 '
          '(none missed) for that range.',
      if (periods.isEmpty)
        'No date ranges were given, so the estimated backlog is zero.'
      else
        'Ranges are ${periods.length} in number and cover $totalDays civil '
            'day(s) in total.',
      'This is an estimate only. It does not establish a confirmed '
          'obligation; confirm the count with a qualified scholar.',
    ];

    final warnings = <String>[
      if (sawFractionalRate)
        'At least one daily rate was fractional, so the low/high band was '
            'widened by rounding.',
      if (totalDays > 365)
        'The estimation window is long ($totalDays days); memory-based '
            'estimates over long periods are rough bounds, not precise counts.',
      for (final prayer in zeroRatePrayers)
        'The rate for ${prayer.name} was zero everywhere: days on which it '
            'was missed but forgotten are not counted.',
    ];

    return EstimationSuccess(EstimationResult(
      perPrayer: perPrayer,
      totalLow: totalLow,
      totalHigh: totalHigh,
      totalDays: totalDays,
      assumptions: assumptions,
      warnings: warnings,
      needsReview: true,
    ));
  }

  /// Assesses a bleeding observation WITHOUT classifying it.
  ///
  /// Only a [QadaRule] with [ReviewStatus.reviewed] AND
  /// [QadaRule.classifiesBleeding] could authorise a hayd / nifas /
  /// istihada classification. No such rule exists in this registry, so
  /// this always returns [BleedingAssessment.needsScholarlyReview] true,
  /// echoes the recorded facts, and gives safe generic guidance.
  ///
  /// An unreviewed rule NEVER alters this outcome.
  static BleedingAssessment assessBleeding(BleedingObservation observation) {
    final recorded = <String>[];
    if (observation.startDate != null) {
      recorded.add('Start date: ${_ymd(DateTime.utc(
        observation.startDate!.year,
        observation.startDate!.month,
        observation.startDate!.day,
      ))}');
    }
    if (observation.durationDays != null) {
      recorded.add(
          'Reported duration so far: ${observation.durationDays} day(s)');
    }
    final notes = observation.notes?.trim() ?? '';
    if (notes.isNotEmpty) {
      recorded.add('User notes: $notes');
    }

    final authorising = QadaRulesRegistry.allRules()
        .where((r) => r.status == ReviewStatus.reviewed && r.classifiesBleeding)
        .toList();

    // No authorising rule exists today; the branch below is the extension
    // point for a future recorded scholarly review.
    if (authorising.isNotEmpty) {
      return BleedingAssessment(
        needsScholarlyReview: true,
        recordedObservations: recorded,
        guidance:
            'A rule authorising classification exists in the registry, but '
            'classification still requires a qualified scholar to apply it '
            'to these facts. Record the facts and ask a qualified scholar.',
        relatedRuleIds: [for (final r in authorising) r.id],
      );
    }

    return BleedingAssessment(
      needsScholarlyReview: true,
      recordedObservations: recorded,
      guidance:
          'This app does not decide whether bleeding is menstruation, '
          'postpartum bleeding, or irregular bleeding. Record the start '
          'date, how long it lasts, and any relevant details, and ask a '
          'qualified scholar for a ruling before deciding about prayer '
          'and fasting.',
      relatedRuleIds: const [
        'QH-002',
        'QH-103',
        'QH-104',
        'QH-105',
        'QH-107'
      ],
    );
  }

  /// All registered fiqh rules, reviewed and proposed.
  static List<QadaRule> registeredRules() => QadaRulesRegistry.allRules();

  /// Lookup of one rule by id, or null.
  static QadaRule? ruleById(String id) => QadaRulesRegistry.byId(id);
}

/// The fiqh rule registry: the data behind [MalikiQadaRulesEngine].
///
/// QH-001..QH-004 were verified against a primary-source text actually
/// read (Mukhtasar Khalil, Kitab al-Salat — see each rule's
/// [QadaRule.reviewNote]). QH-103..QH-107 were engineering-verified
/// against a contemporary secondary manual actually read (Mathieu
/// Gallant, Students' Guide to Maliki Fiqh, Ch. 1, §§29–31 — see each
/// rule's [QadaRule.reviewNote]); this is not a primary classical
/// Arabic text and does not substitute for one. The D7 scholarly review
/// is still outstanding for every rule. QH-101, QH-102, QH-108, QH-109
/// are proposed: their [QadaRule.notes] name exactly what is
/// unverified, and no citation, page number, or quotation is asserted
/// for them.
abstract final class QadaRulesRegistry {
  /// All registered rules, in registry order.
  ///
  /// Non-const because reviewed rules carry a [DateTime] review date.
  static List<QadaRule> allRules() => <QadaRule>[
        // ---------------------------------------------------------------
        // Reviewed against a primary source actually read (2026-10-19).
        // ---------------------------------------------------------------
        QadaRule(
          id: 'QH-001',
          domain: QadaRuleDomain.qadaObligation,
          title: 'Prayer caught in daruri time counts as ada\u2019, not qada',
          arabicSourceText:
              'وَالضَّرُورِيُّ بَعْدَ الْمُخْتَارِ لِلطُّلُوعِ فِي الصُّبْحِ '
              'وَلِلْغُرُوبِ في الظهرين وللفجر في العشاءين وتدرك فيه الصبح '
              'بركعة لا أقل والكل أداء',
          sourceIdentification:
              'Mukhtasar Khalil (Khalil ibn Ishaq al-Jundi, d. 776H), '
              'Kitab al-Salat \u2014 bab fi ahkam al-salat / bayan awqat '
              'al-salawat al-khams (the mawaqit passage).',
          englishSummary:
              'Each prayer has a daruri (necessity) time after its mukhtar '
              'time: Subh to sunrise, Dhuhr and Asr to sunset, Maghrib and '
              'Isha to (true) dawn. A prayer caught in its daruri time with '
              'at least one rak\u2019a counts as ada\u2019 (on-time '
              'performance), not qada. The qada obligation only begins once '
              'the daruri time has fully passed.',
          conditions: const <String>[
            'At least one rak\u2019a is performed inside the daruri window '
                '(the matn states Subh is \u201ccaught\u201d with one rak\u2019a, no less).',
          ],
          exceptions: const <String>[
            'None stated in the passage for the ada\u2019/qada boundary itself.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: the matn passage was read in full '
              'on shamela.ws/book/11355/27 (Dar al-Hadith, Cairo edition '
              '1426H/2005, ed. Ahmad Jad) on 2026-10-19. No independent '
              'scholarly review has been conducted; the D7 scholarly review '
              'is still outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: commentary-level detail (exactly which rak\u2019a '
              'counts, shared-time edge cases) has not been read. The engine '
              'treats a prayer as a qada candidate only after its daruri end.',
        ),
        QadaRule(
          id: 'QH-002',
          domain: QadaRuleDomain.hayd,
          title: 'Hayd is among the excuses for daruri-time performance',
          arabicSourceText:
              'وَأَثِمَ إلَّا لِعُذْرٍ بِكُفْرٍ وَإِنْ بِرِدَّةٍ وَصِبًا '
              'وَإِغْمَاءٍ وَجُنُونٍ وَنَوْمٍ وَغَفْلَةٍ: كَحَيْضٍ لَا سُكْرٍ',
          sourceIdentification:
              'Mukhtasar Khalil (Khalil ibn Ishaq al-Jundi, d. 776H), '
              'Kitab al-Salat \u2014 bab fi ahkam al-salat / bayan awqat '
              'al-salawat al-khams (the mawaqit passage).',
          englishSummary:
              'Delaying a prayer into its daruri time is sinful except with '
              'an excuse. The matn lists disbelief (even apostasy), '
              'childhood, unconsciousness, madness, sleep, and '
              'forgetfulness \u2014 \u201clike menstruation (hayd)\u201d '
              '\u2014 while intoxication is explicitly not an excuse.',
          conditions: const <String>[
            'The excuse genuinely obtained at the time of the delay.',
          ],
          exceptions: const <String>[
            'Intoxication (sukr) is explicitly excluded: \u201c\u0644\u0627 \u0633\u0643\u0631\u201d.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: the matn passage was read in full '
              'on shamela.ws/book/11355/27 (Dar al-Hadith, Cairo edition '
              '1426H/2005, ed. Ahmad Jad) on 2026-10-19. No independent '
              'scholarly review has been conducted; the D7 scholarly review '
              'is still outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: this passage governs delay into daruri time '
              'without sin; it does not address whether prayers missed '
              'during hayd are made up afterwards (see QH-103, '
              'engineering-verified against a secondary manual; the D7 '
              'scholarly review is still outstanding). '
              'The engine must not infer the latter from the former.',
        ),
        QadaRule(
          id: 'QH-003',
          domain: QadaRuleDomain.ordering,
          title: 'Remembered prayer requiring order is made up (qada)',
          arabicSourceText:
              'وَإِنْ تَطَهَّرَ فَأَحْدَثَ أَوْ تَبَيَّنَ عَدَمُ طَهُورِيَّةِ '
              'الماء أو ذكر ما يرتب فالقضاء',
          sourceIdentification:
              'Mukhtasar Khalil (Khalil ibn Ishaq al-Jundi, d. 776H), '
              'Kitab al-Salat \u2014 bab fi ahkam al-salat / bayan awqat '
              'al-salawat al-khams (the mawaqit passage).',
          englishSummary:
              'If one purified then lost wudu, discovered the water was '
              'impure, or remembered a missed prayer that must be ordered '
              'before the current one (\u201cma yurattab\u201d \u2014 what '
              'requires ordering), the remedy is qada: the prayer is made '
              'up in its required order.',
          conditions: const <String>[
            'The remembered prayer is one whose order relative to the '
                'current prayer is required.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: the matn passage was read in full '
              'on shamela.ws/book/11355/27 (Dar al-Hadith, Cairo edition '
              '1426H/2005, ed. Ahmad Jad) on 2026-10-19. No independent '
              'scholarly review has been conducted; the D7 scholarly review '
              'is still outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: the matn is terse and covers only the '
              'remembered-prayer case. The general doctrine of ordering '
              'across many missed prayers (fawa\u2019it) and its exceptions '
              'are not stated in this passage (see QH-102, unverified).',
        ),
        QadaRule(
          id: 'QH-004',
          domain: QadaRuleDomain.qadaObligation,
          title:
              'Time exits while catching both shared-time prayers: qada of the last',
          arabicSourceText:
              'وَإِنْ ظَنَّ إدْرَاكَهُمَا فَرَكَعَ فَخَرَجَ الْوَقْتُ قَضَى '
              'الأخيرة',
          sourceIdentification:
              'Mukhtasar Khalil (Khalil ibn Ishaq al-Jundi, d. 776H), '
              'Kitab al-Salat \u2014 bab fi ahkam al-salat / bayan awqat '
              'al-salawat al-khams (the mawaqit passage).',
          englishSummary:
              'One who expected to catch both of the shared-time prayers '
              '(e.g. Dhuhr with Asr), bowed, but the time exited before he '
              'finished: he makes up (qada) the last of the two.',
          conditions: const <String>[
            'He began within the time expecting to catch both prayers.',
            'The time exited before completion.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: the matn passage was read in full '
              'on shamela.ws/book/11355/27 (Dar al-Hadith, Cairo edition '
              '1426H/2005, ed. Ahmad Jad) on 2026-10-19. No independent '
              'scholarly review has been conducted; the D7 scholarly review '
              'is still outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: commentary detail on which prayer counts as '
              '\u201cthe last\u201d and on the shared-time locus dispute '
              'has not been read.',
        ),
        // ---------------------------------------------------------------
        // Proposed: registered as data only. No citation, page number,
        // quotation, or endorsement is asserted for any of these; each
        // rule's notes name exactly what is unverified.
        // (QH-103..QH-107 were moved above: they are now
        // engineering-verified against the Gallant secondary manual.)
        // ---------------------------------------------------------------
        QadaRule(
          id: 'QH-101',
          domain: QadaRuleDomain.qadaObligation,
          title: 'Missed prayers without excuse must be made up',
          sourceIdentification:
              'Expected location: Mukhtasar Khalil, chapter on qada\u2019 '
              'al-fawa\u2019it (exact passage not yet located or read in '
              'this program). No page number asserted.',
          englishSummary:
              'As commonly understood, a prayer whose entire daruri time '
              'passes without performance and without a valid excuse '
              'remains a debt and must be made up (qada).',
          conditions: const <String>[
            'The full daruri time passed without the prayer being performed.',
            'No valid excuse covered the miss.',
          ],
          exceptions: const <String>[
            'Excuses such as those in QH-002 remove the sin of delay; '
                'whether they remove the makeup obligation differs by '
                'excuse and is not settled in this registry.',
          ],
          status: ReviewStatus.proposed,
          ruleVersion: '1.0',
          notes:
              'UNVERIFIED: no primary-source passage for this rule has been '
              'read in this program. The English summary states the commonly '
              'understood doctrine only and must not be presented as an '
              'established ruling.',
        ),
        QadaRule(
          id: 'QH-102',
          domain: QadaRuleDomain.ordering,
          title:
              'Multiple missed prayers are made up in chronological order (tartib)',
          sourceIdentification:
              'Expected location: Mukhtasar Khalil and its commentaries, '
              'discussion of tartib al-fawa\u2019it (exact passage not yet '
              'located or read in this program). No page number asserted.',
          englishSummary:
              'As commonly understood, when several prayers have been '
              'missed, they are made up in the order in which they were '
              'missed, before the current prayer.',
          conditions: const <String>[
            'More than one prayer was missed.',
          ],
          status: ReviewStatus.proposed,
          ruleVersion: '1.0',
          notes:
              'UNVERIFIED: no primary-source passage for the general tartib '
              'doctrine has been read in this program. Only the narrow '
              'remembered-prayer case is verified (QH-003); the general '
              'rule, its conditions, and its exceptions must not be inferred '
              'from it.',
        ),
        QadaRule(
          id: 'QH-103',
          domain: QadaRuleDomain.hayd,
          title:
              'Prayer neither obligatory nor valid during hayd/nifas; no qada for missed prayers',
          sourceIdentification:
              'Mathieu Gallant, Students\u2019 Guide to Maliki Fiqh, '
              'Ch. 1: Ritual Purity, \u00a731 (Prohibitions of Menses and '
              'Lochia) \u2014 English contemporary manual, last update '
              '2024-04-24. A secondary source, not a primary classical '
              'Arabic text.',
          englishSummary:
              'Prayer is not obligatory for a woman during her menses or '
              'lochia, and no ritual prayer is valid for her in that '
              'state \u2014 obligatory, voluntary, funeral prayer, or the '
              'prostrations of forgetfulness and recitation. It is not '
              'prescribed for her to make up any of the prayers she '
              'missed during her menses or lochia. Fasting differs: '
              'fasting is likewise not obligatory or valid during menses '
              'or lochia, but the Ramadan fasts missed because of them '
              'must be made up. (This app tracks prayers, not fasts; the '
              'fasting distinction is recorded here only as the manual\u2019s '
              'stated boundary of the rule.)',
          conditions: const <String>[
            'The woman is in a state of menses or lochia as those terms '
                'are defined in QH-104/QH-106.',
          ],
          exceptions: const <String>[
            'Ramadan fasts missed during menses or lochia must be made '
                'up \u2014 the manual\u2019s stated exception to the '
                'no-makeup rule, applying to fasting only.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: content read in Mathieu Gallant, '
              'Students\u2019 Guide to Maliki Fiqh, \u00a731 (Prohibitions '
              'of Menses and Lochia), English contemporary manual, last '
              'update 2024-04-24, on 2026-10-19. This is a secondary '
              'source, not a primary classical Arabic text; primary-text '
              'verification and the D7 scholarly review are still '
              'outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: the manual\u2019s underlying classical sources '
              'were not read in this program; primary-text verification '
              'and the D7 scholarly review are still outstanding. This '
              'rule is data-model only: assessBleeding never auto-applies '
              'it and no Qada balance is ever altered on its basis.',
        ),
        QadaRule(
          id: 'QH-104',
          domain: QadaRuleDomain.hayd,
          title: 'Duration thresholds for hayd',
          sourceIdentification:
              'Mathieu Gallant, Students\u2019 Guide to Maliki Fiqh, '
              'Ch. 1: Ritual Purity, \u00a729 (Menses) \u2014 English '
              'contemporary manual, last update 2024-04-24. A secondary '
              'source, not a primary classical Arabic text.',
          englishSummary:
              'For worship rulings there is no minimum duration of menses: '
              'a single isolated gush of untriggered vaginal bleeding '
              'counts as menses (ghusl required, fasting invalidated, '
              'intercourse forbidden until ghusl); mere soiling of the '
              'vulva without gushing counts only if it lasted more than '
              'an instant. The minimum purity between menses is 15 days. '
              'Maximum menses: 15 days for the non-pregnant (first-timer '
              'and habituated alike); a pregnant woman in months 3\u20135 '
              'has up to 20 days, from month 6 up to 30 days (no extra '
              'three days for the pregnant). A habituated woman\u2019s norm '
              'is her longest period to date plus 3 additional days, '
              'capped at 15 days total. Irregular bleeding: bleeding days '
              'separated by fewer than 15 blood-free days are added '
              'together until the maximum; bleeding past the maximum is '
              'metrorrhagia. Menses end with qassah (milky white liquid) '
              'or a clean rag test. Age bands: under 9 or over 70 lunar '
              'years \u2014 not menses; 9\u201313 and 50\u201369 \u2014 '
              'consult expert women; 14\u201349 \u2014 menses.',
          conditions: const <String>[
            'Untriggered vaginal bleeding of a woman of childbearing '
                'capacity (see age bands above); pregnancy modifies the '
                'maximum.',
          ],
          exceptions: const <String>[
            'Bleeding triggered by childbirth (lochia), illness '
                '(metrorrhagia), hymen/ vessel rupture, or drugs is not '
                'menses.',
            'For the divorced/widowed waiting period the manual gives a '
                'different minimum (a day or a good part of a day) \u2014 '
                'outside this rule\u2019s worship-rulings scope.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: content read in Mathieu Gallant, '
              'Students\u2019 Guide to Maliki Fiqh, \u00a729 (Menses), '
              'English contemporary manual, last update 2024-04-24, on '
              '2026-10-19. This is a secondary source, not a primary '
              'classical Arabic text; primary-text verification and the '
              'D7 scholarly review are still outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: the manual\u2019s underlying classical sources '
              'were not read in this program; primary-text verification '
              'and the D7 scholarly review are still outstanding. This '
              'rule is data-model only: assessBleeding never auto-applies '
              'it and no Qada balance is ever altered on its basis.',
        ),
        QadaRule(
          id: 'QH-105',
          domain: QadaRuleDomain.nifas,
          title: 'Nifas excuses from prayer like hayd',
          sourceIdentification:
              'Mathieu Gallant, Students\u2019 Guide to Maliki Fiqh, '
              'Ch. 1: Ritual Purity, \u00a731 (Prohibitions of Menses and '
              'Lochia) \u2014 English contemporary manual, last update '
              '2024-04-24. A secondary source, not a primary classical '
              'Arabic text.',
          englishSummary:
              'The manual treats menses and lochia jointly throughout its '
              'prohibitions section: prayer is not obligatory for a woman '
              'during her lochia any more than during her menses, and no '
              'ritual prayer is valid for her in either state. It is not '
              'prescribed for her to make up prayers missed during her '
              'lochia.',
          conditions: const <String>[
            'The woman is in a state of lochia as defined in QH-106.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: content read in Mathieu Gallant, '
              'Students\u2019 Guide to Maliki Fiqh, \u00a731 (Prohibitions '
              'of Menses and Lochia), English contemporary manual, last '
              'update 2024-04-24, on 2026-10-19. This is a secondary '
              'source, not a primary classical Arabic text; primary-text '
              'verification and the D7 scholarly review are still '
              'outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: the manual\u2019s underlying classical sources '
              'were not read in this program; primary-text verification '
              'and the D7 scholarly review are still outstanding. This '
              'rule is data-model only: assessBleeding never auto-applies '
              'it and no Qada balance is ever altered on its basis.',
        ),
        QadaRule(
          id: 'QH-106',
          domain: QadaRuleDomain.nifas,
          title: 'Duration of nifas: up to 60 bleeding days',
          sourceIdentification:
              'Mathieu Gallant, Students\u2019 Guide to Maliki Fiqh, '
              'Ch. 1: Ritual Purity, \u00a730 (Lochia) \u2014 English '
              'contemporary manual, last update 2024-04-24. A secondary '
              'source, not a primary classical Arabic text.',
          englishSummary:
              'The minimum duration of lochia is a short moment; the '
              'maximum is 60 bleeding days, whether continuous or '
              'interrupted by blood-free days. With irregular postpartum '
              'bleeding she makes ghusl and prays each time the bleeding '
              'stops. Bleeding past 60 days is metrorrhagia. If bleeding '
              'ceases for 15 or more successive blood-free days and then '
              'resumes, the new bleeding is menses, not lochia.',
          conditions: const <String>[
            'Post-childbirth vaginal bleeding (the manual notes lochia '
                'discharge may be blood, yellowish sufrah, or dark kudrah).',
          ],
          exceptions: const <String>[
            'Twins: the manual states bleeding days around separate '
                'deliveries are combined, with exceptions \u2014 the '
                'section\u2019s text is too garbled in the supplied copy '
                'to encode the conditions, so they are not asserted here.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: content read in Mathieu Gallant, '
              'Students\u2019 Guide to Maliki Fiqh, \u00a730 (Lochia), '
              'English contemporary manual, last update 2024-04-24, on '
              '2026-10-19. This is a secondary source, not a primary '
              'classical Arabic text; primary-text verification and the '
              'D7 scholarly review are still outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: the manual\u2019s underlying classical sources '
              'were not read in this program; primary-text verification '
              'and the D7 scholarly review are still outstanding. The '
              'twins-delivery exception could not be confidently encoded '
              'from the supplied copy. This rule is data-model only: '
              'assessBleeding never auto-applies it and no Qada balance '
              'is ever altered on its basis.',
        ),
        QadaRule(
          id: 'QH-107',
          domain: QadaRuleDomain.istihada,
          title: 'Metrorrhagia: pray and fast once past the maximum',
          sourceIdentification:
              'Mathieu Gallant, Students\u2019 Guide to Maliki Fiqh, '
              'Ch. 1: Ritual Purity, \u00a729 (Menses) \u2014 English '
              'contemporary manual, last update 2024-04-24. A secondary '
              'source, not a primary classical Arabic text.',
          englishSummary:
              'Once a woman experiencing untriggered vaginal bleeding '
              'reaches the maximum number of days she can legally count '
              'as menses, she is afflicted with metrorrhagia: she must '
              'make ghusl, pray and fast, and she may do anything '
              'permissible for a woman outside her menstrual period, '
              'even if the bleeding continues through the following '
              'minimum 15-day purity period.',
          conditions: const <String>[
            'Her bleeding has reached the maximum duration for her '
                'category (see QH-104) without ceasing.',
          ],
          exceptions: const <String>[
            'If the blood later takes on menstrual characteristics '
                '(colour, smell, thickness, cramps) after 15 purity days, '
                'a new menstrual period may begin \u2014 the manual\u2019s '
                'detailed conditions are not encoded here.',
          ],
          status: ReviewStatus.reviewed,
          reviewDate: DateTime.utc(2026, 10, 19),
          reviewNote:
              'Engineering verification: content read in Mathieu Gallant, '
              'Students\u2019 Guide to Maliki Fiqh, \u00a729 (Menses), '
              'English contemporary manual, last update 2024-04-24, on '
              '2026-10-19. This is a secondary source, not a primary '
              'classical Arabic text; primary-text verification and the '
              'D7 scholarly review are still outstanding.',
          ruleVersion: '1.0',
          notes:
              'Unresolved: the manual\u2019s underlying classical sources '
              'were not read in this program; primary-text verification '
              'and the D7 scholarly review are still outstanding. This '
              'rule is data-model only: assessBleeding never auto-applies '
              'it and no Qada balance is ever altered on its basis.',
        ),
        QadaRule(
          id: 'QH-108',
          domain: QadaRuleDomain.traveler,
          title: 'Making up prayers missed while traveling',
          sourceIdentification:
              'Expected location: Mukhtasar Khalil and commentaries, '
              'discussion of qada\u2019 al-musafir (exact passage not yet '
              'located or read in this program). No citation asserted.',
          englishSummary:
              'Whether a traveler makes up prayers missed on a journey in '
              'shortened or complete form is not stated in this registry: '
              'no passage has been read.',
          status: ReviewStatus.proposed,
          ruleVersion: '1.0',
          notes:
              'UNVERIFIED: no primary-source passage has been read. No '
              'outcome (shortened vs. complete) is asserted; the engine must '
              'not default either way.',
        ),
        QadaRule(
          id: 'QH-109',
          domain: QadaRuleDomain.qadaObligation,
          title:
              'Prayer missed through sleep or forgetfulness is made up when remembered',
          sourceIdentification:
              'Commonly attributed basis: the hadith \u201cwhoever forgets '
              'a prayer or sleeps through it, its expiation is to pray it '
              'when he remembers\u201d \u2014 text not yet read in this '
              'program; collection, wording, and grading unverified. No '
              'citation asserted.',
          englishSummary:
              'As commonly understood, one who misses a prayer through '
              'sleep or forgetfulness makes it up when he wakes or '
              'remembers.',
          status: ReviewStatus.proposed,
          ruleVersion: '1.0',
          notes:
              'UNVERIFIED: the hadith text, its collection, wording, and '
              'grading have not been read in this program. Note the matn '
              'passage read for QH-002 lists sleep and forgetfulness among '
              'the excuses for delay into daruri time; the '
              'makeup-after-the-time question is separate and unverified.',
        ),
      ];

  /// Rule by id, or null if unknown.
  static QadaRule? byId(String id) {
    for (final r in allRules()) {
      if (r.id == id) return r;
    }
    return null;
  }
}
