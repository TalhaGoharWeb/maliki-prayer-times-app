import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/qada_rules.dart';
import 'package:malikiprayertimes/models/review_status.dart';

/// Unit tests for [MalikiQadaRulesEngine] and [QadaRulesRegistry].
///
/// Two halves:
/// 1. Calculation tests — pure date math, fully asserted.
/// 2. Fiqh registry tests — structural integrity ONLY. No test asserts a
///    specific religious outcome for an unreviewed rule: that would be
///    inventing answers to make tests pass.

EstimationResult _successOf(EstimationOutcome outcome) {
  expect(outcome, isA<EstimationSuccess>());
  return (outcome as EstimationSuccess).result;
}

EstimationError _failureOf(EstimationOutcome outcome) {
  expect(outcome, isA<EstimationFailure>());
  return (outcome as EstimationFailure).error;
}

double _band(EstimationResult r, Prayer p) {
  final e = r.perPrayer.firstWhere((e) => e.prayer == p);
  expect(e.low, e.high); // helper for exact bands; use _bandLow/_bandHigh otherwise
  return e.low;
}

double _low(EstimationResult r, Prayer p) =>
    r.perPrayer.firstWhere((e) => e.prayer == p).low;

double _high(EstimationResult r, Prayer p) =>
    r.perPrayer.firstWhere((e) => e.prayer == p).high;

/// Deterministic fingerprint of a result for the determinism tests.
String _fingerprint(EstimationResult r) {
  final b = StringBuffer()
    ..write('days=${r.totalDays};')
    ..write('low=${r.totalLow};high=${r.totalHigh};');
  for (final e in r.perPrayer) {
    b.write('${e.prayer.name}:${e.low}-${e.high};');
  }
  b.write('assumptions=${r.assumptions.join('|')};');
  b.write('warnings=${r.warnings.join('|')};');
  b.write('needsReview=${r.needsReview};');
  return b.toString();
}

void main() {
  group('estimatePeriods: calculation', () {
    test('zero backlog: empty input is a valid zero estimate', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([]));
      expect(r.totalDays, 0);
      expect(r.totalLow, 0.0);
      expect(r.totalHigh, 0.0);
      for (final p in qadaPrayers) {
        expect(_band(r, p), 0.0);
      }
      // An estimate is never a confirmed obligation — even a zero one.
      expect(r.needsReview, isTrue);
      expect(r.assumptions, isNotEmpty);
    });

    test('single prayer over one range', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 10), // 10 days inclusive
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]));
      expect(r.totalDays, 10);
      expect(_band(r, Prayer.fajr), 10.0);
      expect(_band(r, Prayer.dhuhr), 0.0);
      expect(r.totalLow, 10.0);
      expect(r.totalHigh, 10.0);
      expect(r.needsReview, isTrue);
    });

    test('per-prayer bands follow qadaPrayers order and skip sunrise', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([]));
      expect(
        r.perPrayer.map((e) => e.prayer).toList(),
        [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha],
      );
      expect(qadaPrayers, isNot(contains(Prayer.sunrise)));
    });

    test('overlapping ranges are rejected, never double-counted', () {
      final outcome = MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 10),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
        EstimationPeriodInput(
          start: DateTime(2024, 1, 5),
          end: DateTime(2024, 1, 15),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]);
      final err = _failureOf(outcome);
      expect(err.kind, EstimationErrorKind.overlappingRanges);
      expect(err.periodIndex, isNotNull);
    });

    test('ranges sharing exactly one day are rejected', () {
      final outcome = MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 10),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
        EstimationPeriodInput(
          start: DateTime(2024, 1, 10),
          end: DateTime(2024, 1, 20),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]);
      expect(
        _failureOf(outcome).kind,
        EstimationErrorKind.overlappingRanges,
      );
    });

    test('adjacent (non-overlapping) ranges are accepted', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 10),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
        EstimationPeriodInput(
          start: DateTime(2024, 1, 11),
          end: DateTime(2024, 1, 20),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]));
      expect(r.totalDays, 20);
      expect(_band(r, Prayer.fajr), 20.0);
    });

    test('reversed dates are rejected', () {
      final outcome = MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 10),
          end: DateTime(2024, 1, 1),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]);
      final err = _failureOf(outcome);
      expect(err.kind, EstimationErrorKind.reversedDates);
      expect(err.periodIndex, 0);
    });

    test('leap-year day counts', () {
      // 2024 is a leap year: Feb 28, 29, Mar 1.
      final leap = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 2, 28),
          end: DateTime(2024, 3, 1),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]));
      expect(leap.totalDays, 3);
      expect(_band(leap, Prayer.fajr), 3.0);

      // 2023 is not: Feb 28, Mar 1.
      final common = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2023, 2, 28),
          end: DateTime(2023, 3, 1),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]));
      expect(common.totalDays, 2);
      expect(_band(common, Prayer.fajr), 2.0);
    });

    test('month boundaries are counted inclusively', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 31),
          end: DateTime(2024, 2, 2), // Jan 31, Feb 1, Feb 2
          dailyRates: const {Prayer.isha: 1.0},
        ),
      ]));
      expect(r.totalDays, 3);
      expect(_band(r, Prayer.isha), 3.0);
    });

    test('time components of inputs are ignored', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1, 23, 59),
          end: DateTime(2024, 1, 3, 0, 1),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]));
      expect(r.totalDays, 3);
    });

    test('multi-period combine with per-period rates', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 10), // 10 days
          dailyRates: const {Prayer.fajr: 1.0, Prayer.dhuhr: 0.5},
        ),
        EstimationPeriodInput(
          start: DateTime(2024, 2, 1),
          end: DateTime(2024, 2, 5), // 5 days
          dailyRates: const {Prayer.fajr: 2.0, Prayer.asr: 1.0},
        ),
      ]));
      expect(r.totalDays, 15);
      expect(_band(r, Prayer.fajr), 20.0); // 10*1 + 5*2
      expect(_low(r, Prayer.dhuhr), 5.0); // 10*0.5
      expect(_high(r, Prayer.dhuhr), 5.0);
      expect(_band(r, Prayer.asr), 5.0); // 5*1
      expect(_band(r, Prayer.maghrib), 0.0);
      expect(r.totalLow, 30.0);
      expect(r.totalHigh, 30.0);
    });

    test('fractional rates widen the low/high band', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 3), // 3 days x 0.5 = 1.5
          dailyRates: const {Prayer.fajr: 0.5},
        ),
      ]));
      expect(_low(r, Prayer.fajr), 1.0);
      expect(_high(r, Prayer.fajr), 2.0);
      expect(
        r.warnings.any((w) => w.contains('fractional')),
        isTrue,
      );
    });

    test('invalid rates are rejected', () {
      for (final bad in [5.5, -1.0, double.nan, double.infinity]) {
        final outcome = MalikiQadaRulesEngine.estimatePeriods([
          EstimationPeriodInput(
            start: DateTime(2024, 1, 1),
            end: DateTime(2024, 1, 2),
            dailyRates: {Prayer.fajr: bad},
          ),
        ]);
        expect(
          _failureOf(outcome).kind,
          EstimationErrorKind.invalidRate,
          reason: 'rate $bad should be rejected',
        );
      }
      // Boundary values 0.0 and 5.0 are accepted.
      final ok = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 2),
          dailyRates: const {Prayer.fajr: 5.0, Prayer.dhuhr: 0.0},
        ),
      ]));
      expect(_band(ok, Prayer.fajr), 10.0);
    });

    test('deterministic: identical inputs give identical outputs', () {
      List<EstimationPeriodInput> inputs() => [
            EstimationPeriodInput(
              start: DateTime(2024, 3, 5),
              end: DateTime(2024, 3, 25),
              dailyRates: const {Prayer.fajr: 1.0, Prayer.asr: 0.5},
              label: 'b',
            ),
            EstimationPeriodInput(
              start: DateTime(2024, 1, 2),
              end: DateTime(2024, 1, 9),
              dailyRates: const {Prayer.maghrib: 2.0},
              label: 'a',
            ),
          ];
      final a = _fingerprint(
          _successOf(MalikiQadaRulesEngine.estimatePeriods(inputs())));
      final b = _fingerprint(
          _successOf(MalikiQadaRulesEngine.estimatePeriods(inputs())));
      expect(a, b);
    });

    test('deterministic: input order does not change the output', () {
      final first = EstimationPeriodInput(
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 10),
        dailyRates: const {Prayer.fajr: 1.0},
      );
      final second = EstimationPeriodInput(
        start: DateTime(2024, 2, 1),
        end: DateTime(2024, 2, 10),
        dailyRates: const {Prayer.fajr: 2.0},
      );
      final a = _fingerprint(_successOf(
          MalikiQadaRulesEngine.estimatePeriods([first, second])));
      final b = _fingerprint(_successOf(
          MalikiQadaRulesEngine.estimatePeriods([second, first])));
      expect(a, b);
    });

    test('long windows carry a degradation warning', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2020, 1, 1),
          end: DateTime(2021, 6, 30),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]));
      expect(r.totalDays, greaterThan(365));
      expect(
        r.warnings.any((w) => w.contains('rough bounds')),
        isTrue,
      );
    });

    test('zero-rate prayers get a forgotten-days warning', () {
      final r = _successOf(MalikiQadaRulesEngine.estimatePeriods([
        EstimationPeriodInput(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 5),
          dailyRates: const {Prayer.fajr: 1.0},
        ),
      ]));
      expect(
        r.warnings.any((w) => w.contains('dhuhr')),
        isTrue,
      );
    });

    test('needsReview is always true', () {
      final inputs = [
        <EstimationPeriodInput>[],
        [
          EstimationPeriodInput(
            start: DateTime(2024, 1, 1),
            end: DateTime(2024, 1, 31),
            dailyRates: const {Prayer.fajr: 1.0},
          ),
        ],
      ];
      for (final periods in inputs) {
        expect(
          _successOf(MalikiQadaRulesEngine.estimatePeriods(periods))
              .needsReview,
          isTrue,
        );
      }
    });

    test('error messages carry no review-status wording', () {
      const banned = ['proposed', 'pending scholarly review'];
      final outcomes = [
        MalikiQadaRulesEngine.estimatePeriods([
          EstimationPeriodInput(
            start: DateTime(2024, 2, 1),
            end: DateTime(2024, 1, 1),
            dailyRates: const {},
          ),
        ]),
        MalikiQadaRulesEngine.estimatePeriods([
          EstimationPeriodInput(
            start: DateTime(2024, 1, 1),
            end: DateTime(2024, 1, 10),
            dailyRates: const {},
          ),
          EstimationPeriodInput(
            start: DateTime(2024, 1, 10),
            end: DateTime(2024, 1, 20),
            dailyRates: const {},
          ),
        ]),
        MalikiQadaRulesEngine.estimatePeriods([
          EstimationPeriodInput(
            start: DateTime(2024, 1, 1),
            end: DateTime(2024, 1, 10),
            dailyRates: const {Prayer.fajr: 9.0},
          ),
        ]),
      ];
      for (final o in outcomes) {
        final msg = _failureOf(o).message.toLowerCase();
        for (final b in banned) {
          expect(msg, isNot(contains(b)));
        }
      }
    });
  });

  group('QadaRulesRegistry: structural integrity', () {
    test('registry is non-empty with unique QH- ids', () {
      final rules = QadaRulesRegistry.allRules();
      expect(rules, isNotEmpty);
      final ids = rules.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(id, startsWith('QH-'));
      }
    });

    test('every rule has non-empty source identification and summary', () {
      for (final r in QadaRulesRegistry.allRules()) {
        expect(r.sourceIdentification.trim(), isNotEmpty,
            reason: '${r.id} needs source identification');
        expect(r.englishSummary.trim(), isNotEmpty,
            reason: '${r.id} needs an English summary');
        expect(r.title.trim(), isNotEmpty, reason: '${r.id} needs a title');
        expect(r.ruleVersion.trim(), isNotEmpty,
            reason: '${r.id} needs a rule version');
      }
    });

    test('every domain is represented', () {
      final domains =
          QadaRulesRegistry.allRules().map((r) => r.domain).toSet();
      expect(
        domains,
        containsAll([
          QadaRuleDomain.qadaObligation,
          QadaRuleDomain.hayd,
          QadaRuleDomain.nifas,
          QadaRuleDomain.istihada,
          QadaRuleDomain.ordering,
          QadaRuleDomain.traveler,
        ]),
      );
    });

    test('proposed rules name what is unverified and have no reviewer', () {
      final proposed = QadaRulesRegistry.allRules()
          .where((r) => r.status == ReviewStatus.proposed);
      // All 13 rules are currently engineering-verified, so this is
      // vacuous today; it guards any future proposed registration.
      for (final r in proposed) {
        expect(r.notes.trim(), isNotEmpty,
            reason: '${r.id}: proposed rules must say what is unverified');
        expect(r.reviewerName, isNull, reason: r.id);
        expect(r.reviewDate, isNull, reason: r.id);
        expect(r.arabicSourceText, isNull,
            reason: '${r.id}: no quotation without a read source');
      }
    });

    test('reviewed rules record what was read and when', () {
      final reviewed = QadaRulesRegistry.allRules()
          .where((r) => r.status == ReviewStatus.reviewed)
          .toList();
      expect(
          reviewed.map((r) => r.id),
          containsAll([
            'QH-001',
            'QH-002',
            'QH-003',
            'QH-004',
            'QH-101',
            'QH-102',
            'QH-103',
            'QH-104',
            'QH-105',
            'QH-106',
            'QH-107',
            'QH-108',
            'QH-109',
          ]));
      for (final r in reviewed) {
        expect(r.reviewDate, isNotNull, reason: r.id);
        expect(r.reviewNote, isNotNull, reason: r.id);
        // Engineering verification is not a scholarly review.
        expect(r.reviewerName, isNull, reason: r.id);
      }
    });

    test('primary-text reviewed rules quote the read matn passage', () {
      for (final id in ['QH-001', 'QH-002', 'QH-003', 'QH-004']) {
        final r = MalikiQadaRulesEngine.ruleById(id)!;
        expect(r.reviewNote, contains('shamela.ws'), reason: id);
        expect(r.arabicSourceText, isNotNull, reason: id);
      }
    });

    test('Gallant-verified rules name the secondary manual, quote no Arabic',
        () {
      for (final id in [
        'QH-101',
        'QH-102',
        'QH-103',
        'QH-104',
        'QH-105',
        'QH-106',
        'QH-107',
        'QH-108',
        'QH-109',
      ]) {
        final r = MalikiQadaRulesEngine.ruleById(id)!;
        expect(r.status, ReviewStatus.reviewed, reason: id);
        expect(r.reviewDate, DateTime.utc(2026, 10, 19), reason: id);
        expect(r.sourceIdentification, contains('Mathieu Gallant'),
            reason: id);
        expect(r.sourceIdentification, contains('secondary source'),
            reason: id);
        expect(r.reviewNote, contains('Mathieu Gallant'), reason: id);
        expect(r.reviewNote, contains('secondary source'), reason: id);
        expect(r.reviewNote,
            contains('declared scholarly-verified by the user on 2026-10-19'),
            reason: id);
        expect(r.reviewNote, contains('malikifiqhqa.com'), reason: id);
        // No Arabic quotation without a read Arabic passage.
        expect(r.arabicSourceText, isNull, reason: id);
        expect(r.reviewerName, isNull, reason: id);
        expect(r.ruleVersion, '1.0', reason: id);
        // Data-model only: nothing here authorises classification.
        expect(r.classifiesBleeding, isFalse, reason: id);
      }
    });

    test('QH-104 records the manual\u2019s duration thresholds', () {
      final r = MalikiQadaRulesEngine.ruleById('QH-104')!;
      final s = r.englishSummary;
      expect(s, contains('15 days'), reason: 'max menses / min purity');
      expect(s, contains('20 days'), reason: 'pregnancy months 3-5');
      expect(s, contains('30 days'), reason: 'pregnancy month 6+');
      expect(s, contains('no minimum'), reason: 'no-minimum worship ruling');
    });

    test('QH-103 records no-qada plus the fasting boundary', () {
      final r = MalikiQadaRulesEngine.ruleById('QH-103')!;
      expect(r.englishSummary, contains('not prescribed'));
      expect(r.englishSummary, contains('Ramadan'));
      expect(r.englishSummary, contains('not fasts'));
    });

    test('QH-106 records the 60-day nifas maximum', () {
      final r = MalikiQadaRulesEngine.ruleById('QH-106')!;
      expect(r.englishSummary, contains('60'));
      expect(r.englishSummary, contains('metrorrhagia'));
    });

    test('QH-107 records the metrorrhagia procedure', () {
      final r = MalikiQadaRulesEngine.ruleById('QH-107')!;
      final s = r.englishSummary.toLowerCase();
      expect(s, contains('ghusl'));
      expect(s, contains('pray'));
      expect(s, contains('fast'));
    });

    test('QH-101 records the qada obligation and its boundaries', () {
      final r = MalikiQadaRulesEngine.ruleById('QH-101')!;
      final s = r.englishSummary;
      expect(s, contains('Hastening'));
      expect(s, contains('any time'));
      expect(s, contains('voluntary prayers'));
      expect(s, contains('Fajr'));
      expect(r.exceptions.join(' '), contains('menses'));
    });

    test('QH-102 records tartib as obligation, not validity condition', () {
      final r = MalikiQadaRulesEngine.ruleById('QH-102')!;
      final s = r.englishSummary;
      expect(s, contains('NOT a condition of validity'));
      expect(s, contains('five or less'));
      expect(s, contains('four or less'));
      expect(s, contains('mashhur'));
    });

    test('QH-108 records the 48-mile threshold and shortened-vs-full rule',
        () {
      final r = MalikiQadaRulesEngine.ruleById('QH-108')!;
      final s = r.englishSummary;
      expect(s, contains('48 shar'));
      expect(s, contains('80 km'));
      expect(s, contains('shortened'));
      expect(s, contains('four full days'));
      expect(s, contains('20+ prayers'));
    });

    test('QH-109 keeps sleep distinct from the makeup-lifting excuses', () {
      final r = MalikiQadaRulesEngine.ruleById('QH-109')!;
      final s = r.englishSummary;
      expect(s, contains('made up'));
      expect(s, contains('eight'));
      expect(s, contains('must not be conflated'));
    });

    test('ruleById finds rules and returns null for unknown ids', () {
      expect(MalikiQadaRulesEngine.ruleById('QH-001')?.domain,
          QadaRuleDomain.qadaObligation);
      expect(MalikiQadaRulesEngine.ruleById('QH-107')?.domain,
          QadaRuleDomain.istihada);
      expect(MalikiQadaRulesEngine.ruleById('QH-999'), isNull);
    });

    test('qadaRuleDomainName covers every domain', () {
      for (final d in QadaRuleDomain.values) {
        expect(qadaRuleDomainName(d).trim(), isNotEmpty);
      }
    });
  });

  group('assessBleeding: never classifies', () {
    test('always returns needsScholarlyReview=true', () {
      final observations = [
        const BleedingObservation(),
        const BleedingObservation(durationDays: 3),
        const BleedingObservation(durationDays: 20),
        BleedingObservation(
          startDate: DateTime(2024, 5, 1),
          durationDays: 7,
          notes: 'heavy first days',
        ),
      ];
      for (final o in observations) {
        final a = MalikiQadaRulesEngine.assessBleeding(o);
        expect(a.needsScholarlyReview, isTrue);
        expect(a.guidance.trim(), isNotEmpty);
        expect(a.relatedRuleIds, isNotEmpty);
      }
    });

    test('echoes the recorded observations back', () {
      final a = MalikiQadaRulesEngine.assessBleeding(BleedingObservation(
        startDate: DateTime(2024, 5, 1),
        durationDays: 7,
        notes: '  heavy first days  ',
      ));
      expect(a.recordedObservations, hasLength(3));
      expect(
        a.recordedObservations.any((s) => s.contains('2024-05-01')),
        isTrue,
      );
      expect(
        a.recordedObservations.any((s) => s.contains('7 day(s)')),
        isTrue,
      );
      // Notes are trimmed and echoed verbatim otherwise.
      expect(
        a.recordedObservations.any((s) => s.endsWith('heavy first days')),
        isTrue,
      );
    });

    test('guidance classifies nothing and carries no review-status wording',
        () {
      final a = MalikiQadaRulesEngine.assessBleeding(
        const BleedingObservation(durationDays: 10),
      );
      final g = a.guidance.toLowerCase();
      expect(g, isNot(contains('proposed')));
      expect(g, isNot(contains('pending scholarly review')));
      // Structural check only: no classification vocabulary is asserted
      // as an outcome for this observation.
      expect(a.needsScholarlyReview, isTrue);
    });

    test('empty observation still returns a safe assessment', () {
      final a = MalikiQadaRulesEngine.assessBleeding(
        const BleedingObservation(),
      );
      expect(a.needsScholarlyReview, isTrue);
      expect(a.recordedObservations, isEmpty);
      expect(a.guidance, contains('qualified scholar'));
    });

    test('no registered rule authorises classification', () {
      final authorising = QadaRulesRegistry.allRules()
          .where((r) =>
              r.status == ReviewStatus.reviewed && r.classifiesBleeding);
      expect(authorising, isEmpty);
    });
  });
}
