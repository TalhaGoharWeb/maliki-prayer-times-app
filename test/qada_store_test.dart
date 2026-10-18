import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/models/qada_models.dart';
import 'package:malikiprayertimes/services/qada_service.dart';
import 'package:malikiprayertimes/services/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fresh service with an isolated in-memory secure backend.
/// Callers must set SharedPreferences mock values first; [load] is async.
Future<QadaService> _newService() async {
  final s = QadaService(
    secureStore: SecureStore(backend: InMemorySecureBackend()),
  );
  await s.load();
  return s;
}

Future<QadaService> _loadedService({
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  return _newService();
}

String _v1Doc(List<Map<String, Object?>> entries) =>
    jsonEncode({'schema_version': 1, 'entries': entries});

Map<String, Object?> _v1entry(
  String id,
  String date,
  String prayer,
  bool done,
) => {'id': id, 'date': date, 'prayer': prayer, 'done': done};

void main() {
  group('v1 to v2 migration', () {
    test('migrates pending entries to confirmed counts and done entries '
        'to completion transactions', () async {
      final s = await _loadedService(
        initialPrefs: {
          'qada_entries_v1': _v1Doc([
            _v1entry('m1', '2026-10-10', 'fajr', false),
            _v1entry('m2', '2026-10-11', 'fajr', false),
            _v1entry('m3', '2026-10-12', 'dhuhr', false),
            _v1entry('m4', '2026-10-09', 'asr', true),
          ]),
        },
      );

      expect(s.confirmedCounts()[Prayer.fajr], 2);
      expect(s.confirmedCounts()[Prayer.dhuhr], 1);
      expect(s.confirmedCounts()[Prayer.isha], 0);
      // No double counting: the migrated debt lives in v2 only.
      expect(s.totalOutstanding(), 3);
      expect(s.totalCompleted(), 1);

      final completions = s.transactions().where(
        (t) =>
            t.type == QadaTxType.completion &&
            t.prayer == Prayer.asr &&
            t.amount == 1,
      );
      expect(completions, hasLength(1));
      expect(completions.single.idempotencyKey, 'migrated-v1:completion:asr');
      expect(
        s
            .transactions()
            .where(
              (t) =>
                  t.type == QadaTxType.exactSet &&
                  t.prayer == Prayer.fajr &&
                  t.amount == 2,
            )
            .single
            .note,
        contains('migrated-v1'),
      );

      // The v1 key is left intact on disk; v1 entries still list.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('qada_entries_v1'), isNotNull);
      expect(s.pending(), hasLength(3));
      expect(s.completed(), hasLength(1));

      // The v2 document was written in the specified shape.
      final v2 =
          jsonDecode(prefs.getString('qada_v2')!) as Map<String, dynamic>;
      expect(v2['schema_version'], 2);
      expect(v2['balances']['fajr'], 2);
      expect(v2['balances']['dhuhr'], 1);
      expect(v2['transactions'], isNotEmpty);
      expect(v2['periods'], isEmpty);
      expect(v2['planner'], isA<Map>());
    });

    test('does not migrate when a v2 document already exists', () async {
      final s = await _loadedService(
        initialPrefs: {
          'qada_entries_v1': _v1Doc([
            _v1entry('m1', '2026-10-10', 'fajr', false),
          ]),
          'qada_v2': jsonEncode({
            'schema_version': 2,
            'balances': {'fajr': 10},
            'transactions': [],
            'periods': [],
            'planner': {},
            'migrated_entry_ids': [],
          }),
        },
      );

      // Independent systems: v2 balances plus the unmigrated v1 entry.
      expect(s.totalOutstanding(), 11);
      expect(
        s.transactions().where((t) => (t.note ?? '').contains('migrated-v1')),
        isEmpty,
      );
    });

    test('markDone on a migrated entry keeps the v2 ledger in sync', () async {
      SharedPreferences.setMockInitialValues({
        'qada_entries_v1': _v1Doc([
          _v1entry('m1', '2026-10-10', 'fajr', false),
        ]),
      });
      final s = await _newService();
      expect(s.totalOutstanding(), 1);

      await s.markDone('m1');

      expect(s.totalOutstanding(), 0);
      expect(s.totalCompleted(), 1);
      expect(s.pending(), isEmpty);
    });

    test('v1-era writes suppress migration via the v2 marker', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _newService();
      await s.logMissed(date: DateTime(2026, 10, 15), prayer: Prayer.fajr);

      // Same process, second load: the marker written by _persist means
      // the v1 entry is NOT re-migrated into v2.
      final reloaded = await _newService();

      expect(reloaded.totalOutstanding(), 1);
      expect(reloaded.pending(), hasLength(1));
      expect(
        reloaded.transactions().where(
          (t) => (t.note ?? '').contains('migrated-v1'),
        ),
        isEmpty,
      );
    });

    test('unknown newer v2 schema loads empty and locks v2 writes', () async {
      final s = await _loadedService(
        initialPrefs: {
          'qada_v2': jsonEncode({'schema_version': 99}),
        },
      );

      expect(s.totalOutstanding(), 0);
      expect(s.remainingByPrayer()[Prayer.fajr], 0);
      await expectLater(
        s.setExactCounts({Prayer.fajr: 1}, 'x'),
        throwsStateError,
      );
      // v1 behaviour is unaffected by the lock.
      await s.logMissed(date: DateTime(2026, 10, 15), prayer: Prayer.fajr);
      expect(s.totalRemaining(), 1);
    });

    test('corrupt v2 JSON loads as empty without throwing', () async {
      final s = await _loadedService(
        initialPrefs: {'qada_v2': '{not valid json'},
      );

      expect(s.totalOutstanding(), 0);
      // ...and stays writable.
      await s.setExactCounts({Prayer.fajr: 2}, 'x');
      expect(s.totalOutstanding(), 2);
    });
  });

  group('exact counts', () {
    test('setExactCounts replaces balances and records the origin', () async {
      final s = await _loadedService();

      await s.setExactCounts({
        Prayer.fajr: 3,
        Prayer.dhuhr: 2,
      }, 'user-entered 2026-10-19');

      expect(s.confirmedCounts()[Prayer.fajr], 3);
      expect(s.confirmedCounts()[Prayer.dhuhr], 2);
      expect(s.confirmedCounts()[Prayer.isha], 0);
      expect(s.totalOutstanding(), 5);
      expect(s.countsOrigin(), 'user-entered 2026-10-19');
      expect(
        s.transactions().where((t) => t.type == QadaTxType.exactSet),
        hasLength(2),
      );

      // Absent prayers are zeroed: full replacement, not a merge.
      await s.setExactCounts({Prayer.fajr: 1}, 'second');
      expect(s.totalOutstanding(), 1);
    });

    test('setExactCounts rejects negative counts', () async {
      final s = await _loadedService();
      await s.setExactCounts({Prayer.fajr: 3}, 'seed');

      await expectLater(
        s.setExactCounts({Prayer.fajr: -1}, 'x'),
        throwsArgumentError,
      );
      expect(s.confirmedCounts()[Prayer.fajr], 3);
    });
  });

  group('estimation', () {
    List<EstimationPeriod> tenDaysFajr() => [
      EstimationPeriod(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 10),
        dailyRate: {Prayer.fajr: 1},
      ),
    ];

    test('previewEstimation is pure and delegates to the engine', () async {
      final s = await _loadedService();
      await s.setExactCounts({Prayer.fajr: 5}, 'seed');

      final r = await s.previewEstimation(tenDaysFajr());

      expect(r.estimated[Prayer.fajr], 10);
      expect(r.low[Prayer.fajr], 10);
      expect(r.high[Prayer.fajr], 10);
      expect(r.estimated[Prayer.dhuhr], 0);
      expect(r.needsReview, isTrue);
      expect(r.assumptions, isNotEmpty);
      // Pure: balances untouched, nothing persisted.
      expect(s.totalOutstanding(), 5);
      final prefs = await SharedPreferences.getInstance();
      final v2 =
          jsonDecode(prefs.getString('qada_v2')!) as Map<String, dynamic>;
      expect(v2['periods'], isEmpty);
    });

    test('previewEstimation surfaces engine rejections as warnings', () async {
      final s = await _loadedService();

      final overlapping = await s.previewEstimation([
        EstimationPeriod(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 1, 10),
          dailyRate: {Prayer.fajr: 1},
        ),
        EstimationPeriod(
          start: DateTime(2026, 1, 5),
          end: DateTime(2026, 1, 15),
          dailyRate: {Prayer.fajr: 1},
        ),
      ]);
      expect(overlapping.warnings, isNotEmpty);
      expect(overlapping.estimated[Prayer.fajr], 0);
      expect(overlapping.needsReview, isTrue);

      final reversed = await s.previewEstimation([
        EstimationPeriod(
          start: DateTime(2026, 1, 10),
          end: DateTime(2026, 1, 1),
          dailyRate: {Prayer.fajr: 1},
        ),
      ]);
      expect(reversed.warnings, isNotEmpty);
      expect(reversed.estimated[Prayer.fajr], 0);
    });

    test(
      'saveEstimation adds balances, stores periods, stays idempotent',
      () async {
        final s = await _loadedService();
        final periods = tenDaysFajr();
        final r = await s.previewEstimation(periods);

        await s.saveEstimation(r, periods);

        expect(s.totalOutstanding(), 10);
        expect(s.hasEstimatedBalances(), isTrue);
        expect(
          s.transactions().where((t) => t.type == QadaTxType.estimation),
          hasLength(1),
        );

        // Saving the same preview again is a safe no-op.
        await s.saveEstimation(r, periods);
        expect(s.totalOutstanding(), 10);
        expect(
          s.transactions().where((t) => t.type == QadaTxType.estimation),
          hasLength(1),
        );

        // Periods are kept as an audit trail and survive reload.
        final reloaded = await _newService();
        final exported = jsonDecode(await reloaded.exportJson());
        expect((exported['qada']['periods'] as List), hasLength(1));
      },
    );

    test('estimated balances are excluded from confirmedCounts', () async {
      final s = await _loadedService();
      final r = await s.previewEstimation(tenDaysFajr());
      await s.saveEstimation(r, tenDaysFajr());

      expect(s.totalOutstanding(), 10);
      expect(s.confirmedCounts()[Prayer.fajr], 0);

      await s.setExactCounts({Prayer.fajr: 4}, 'confirmed');
      expect(s.hasEstimatedBalances(), isFalse);
      expect(s.confirmedCounts()[Prayer.fajr], 4);
    });
  });

  group('ledger: adjust / complete / undo', () {
    test('adjust applies signed deltas and honours idempotency keys', () async {
      final s = await _loadedService();
      await s.setExactCounts({Prayer.dhuhr: 5}, 'seed');

      final t1 = await s.adjust(
        prayer: Prayer.dhuhr,
        delta: 2,
        reason: 'recheck',
        idempotencyKey: 'k1',
      );
      expect(t1.amount, 2);
      expect(s.confirmedCounts()[Prayer.dhuhr], 7);

      // Idempotent retry returns the original transaction.
      final t2 = await s.adjust(
        prayer: Prayer.dhuhr,
        delta: 2,
        reason: 'recheck',
        idempotencyKey: 'k1',
      );
      expect(t2.id, t1.id);
      expect(s.confirmedCounts()[Prayer.dhuhr], 7);
      expect(s.transactions(prayer: Prayer.dhuhr), hasLength(2));
      // (one exactSet + one adjustment; the idempotent retry added none)

      await expectLater(
        s.adjust(prayer: Prayer.dhuhr, delta: 0, reason: 'x'),
        throwsArgumentError,
      );
      await expectLater(
        s.adjust(prayer: Prayer.dhuhr, delta: -8, reason: 'too far'),
        throwsStateError,
      );
      expect(s.confirmedCounts()[Prayer.dhuhr], 7);

      await s.adjust(prayer: Prayer.dhuhr, delta: -7, reason: 'ok');
      expect(s.confirmedCounts()[Prayer.dhuhr], 0);
    });

    test('complete rejects over-completion instead of clamping', () async {
      final s = await _loadedService();
      await s.setExactCounts({Prayer.asr: 3}, 'seed');

      await expectLater(
        s.complete(prayer: Prayer.asr, count: 4),
        throwsStateError,
      );
      await expectLater(
        s.complete(prayer: Prayer.asr, count: 0),
        throwsArgumentError,
      );
      expect(s.confirmedCounts()[Prayer.asr], 3);
      expect(s.totalCompleted(), 0);

      final tx = await s.complete(
        prayer: Prayer.asr,
        count: 2,
        idempotencyKey: 'c1',
      );
      expect(tx.amount, 2);
      expect(s.confirmedCounts()[Prayer.asr], 1);
      expect(s.totalCompleted(), 2);

      // Double-complete protection via the idempotency key.
      final tx2 = await s.complete(
        prayer: Prayer.asr,
        count: 2,
        idempotencyKey: 'c1',
      );
      expect(tx2.id, tx.id);
      expect(s.totalCompleted(), 2);
      expect(s.confirmedCounts()[Prayer.asr], 1);
    });

    test('undoTransaction reverses without deleting history', () async {
      final s = await _loadedService();
      await s.setExactCounts({Prayer.maghrib: 5}, 'seed');
      final tx = await s.complete(prayer: Prayer.maghrib, count: 2);
      expect(s.confirmedCounts()[Prayer.maghrib], 3);

      expect(await s.undoTransaction(tx.id), isTrue);

      expect(s.confirmedCounts()[Prayer.maghrib], 5);
      expect(s.totalCompleted(), 0);
      final undone = s.transactions().firstWhere((t) => t.id == tx.id);
      expect(undone.reversedBy, isNotNull);
      expect(s.transactions().any((t) => t.type == QadaTxType.undo), isTrue);

      expect(await s.undoTransaction(tx.id), isFalse);
      expect(await s.undoTransaction('no-such-id'), isFalse);
    });

    test('undo of an exactSet restores the prior value', () async {
      final s = await _loadedService();
      await s.setExactCounts({Prayer.fajr: 2}, 'seed');
      final exactTx = s.transactions().firstWhere(
        (t) => t.type == QadaTxType.exactSet,
      );

      expect(await s.undoTransaction(exactTx.id), isTrue);
      expect(s.confirmedCounts()[Prayer.fajr], 0);
    });

    test('transactions() filters by prayer and caps the limit', () async {
      final s = await _loadedService();
      await s.setExactCounts({Prayer.fajr: 1, Prayer.dhuhr: 1}, 'seed');
      await s.adjust(prayer: Prayer.fajr, delta: 1, reason: 'x');

      final fajrTx = s.transactions(prayer: Prayer.fajr);
      expect(fajrTx.every((t) => t.prayer == Prayer.fajr), isTrue);
      expect(fajrTx, hasLength(2));
      // Newest first.
      expect(
        fajrTx.first.at.isAfter(fajrTx.last.at) ||
            fajrTx.first.at == fajrTx.last.at,
        isTrue,
      );
      expect(s.transactions(limit: 1), hasLength(1));
    });
  });

  group('planner', () {
    test('targets, reminder mirrors, and projected end date', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _newService();

      expect(s.projectedEndDate(), isNull);

      await s.setExactCounts({Prayer.fajr: 12}, 'seed');
      expect(s.projectedEndDate(), isNull); // no target yet

      await s.setDailyTarget(5);
      expect(s.dailyTarget(), 5);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(s.projectedEndDate(), today.add(const Duration(days: 3)));

      // SharedPreferences mirrors for Worker E.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('qada_daily_target'), 5);

      await s.setReminderMinutes(30);
      expect(s.reminderMinutes(), 30);
      expect(prefs.getInt('qada_reminder_minutes'), 30);
      await s.setReminderMinutes(null);
      expect(s.reminderMinutes(), isNull);
      expect(prefs.containsKey('qada_reminder_minutes'), isFalse);

      // Weekly target is the fallback when no daily target is set.
      await s.setDailyTarget(0);
      await s.setWeeklyTarget(7);
      expect(s.weeklyTarget(), 7);
      expect(s.projectedEndDate(), today.add(const Duration(days: 12)));

      // Nothing outstanding -> null.
      await s.setExactCounts({}, 'zeroed');
      expect(s.projectedEndDate(), isNull);
    });
  });

  group('bleeding records', () {
    test(
      'CRUD via the fake secure backend, never shared_preferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = await _newService();

        final rec = BleedingRecord(
          id: 'b1',
          type: BleedingType.hayd,
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 7),
          status: BleedingStatus.completed,
          purityGaps: [
            PurityGap(start: DateTime(2026, 10, 3), end: DateTime(2026, 10, 4)),
          ],
          purityConfirmed: true,
          note: 'first',
          confirmation: ConfirmationStatus.confirmed,
        );
        await s.saveBleedingRecord(rec);

        var all = await s.bleedingRecords();
        expect(all.map((r) => r.id), ['b1']);
        expect(all.single.purityGaps, hasLength(1));
        expect(all.single.confirmation, ConfirmationStatus.confirmed);

        // Upsert by id.
        await s.saveBleedingRecord(
          BleedingRecord(
            id: 'b1',
            type: BleedingType.hayd,
            status: BleedingStatus.ongoing,
            start: DateTime(2026, 10, 1),
            note: 'updated',
          ),
        );
        all = await s.bleedingRecords();
        expect(all, hasLength(1));
        expect(all.single.note, 'updated');

        // Bleeding JSON lives only in secure storage.
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs.getKeys()) {
          final v = prefs.getString(key) ?? '';
          expect(
            v.contains('b1'),
            isFalse,
            reason: 'bleeding data leaked into $key',
          );
        }

        await s.deleteBleedingRecord('b1');
        expect(await s.bleedingRecords(), isEmpty);
        await s.deleteBleedingRecord('missing'); // no-op, no throw
      },
    );

    test(
      'applyExemption reduces balances with exemption transactions',
      () async {
        final s = await _loadedService();
        await s.setExactCounts({Prayer.fajr: 10, Prayer.dhuhr: 4}, 'seed');
        final rec = BleedingRecord(
          id: 'b1',
          type: BleedingType.hayd,
          status: BleedingStatus.ongoing,
          start: DateTime(2026, 10, 1),
        );

        await s.applyExemption(
          record: rec,
          daysApplied: {Prayer.fajr: 6, Prayer.dhuhr: 4},
        );

        expect(s.confirmedCounts()[Prayer.fajr], 4);
        expect(s.confirmedCounts()[Prayer.dhuhr], 0);
        final exemptions = s
            .transactions()
            .where((t) => t.type == QadaTxType.exemption)
            .toList();
        expect(exemptions, hasLength(2));
        expect(exemptions.every((t) => (t.note ?? '').contains('b1')), isTrue);

        // Exempting more than outstanding is rejected, never floored.
        await expectLater(
          s.applyExemption(record: rec, daysApplied: {Prayer.fajr: 5}),
          throwsStateError,
        );
        expect(s.confirmedCounts()[Prayer.fajr], 4);
      },
    );
  });

  group('export / import', () {
    test('round-trips everything; re-import is duplicate-safe', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _newService();
      await s.setExactCounts({Prayer.fajr: 8}, 'seed');
      await s.complete(prayer: Prayer.fajr, count: 3);
      await s.setDailyTarget(2);
      await s.saveBleedingRecord(
        BleedingRecord(
          id: 'b1',
          type: BleedingType.nifas,
          status: BleedingStatus.ongoing,
          start: DateTime(2026, 9, 1),
        ),
      );
      final json = await s.exportJson();

      final envelope = jsonDecode(json) as Map<String, dynamic>;
      expect(envelope['format'], 'qada_export');
      expect(envelope['version'], 2);
      expect(envelope['qada']['schema_version'], 2);
      expect(envelope['bleeding'], hasLength(1));

      await s.deleteAll();
      expect(s.totalOutstanding(), 0);
      expect(await s.bleedingRecords(), isEmpty);

      final skippedFirst = await s.importJson(json);
      expect(skippedFirst, isEmpty);
      expect(s.confirmedCounts()[Prayer.fajr], 5);
      expect(s.totalCompleted(), 3);
      expect(s.dailyTarget(), 2);
      expect((await s.bleedingRecords()).single.id, 'b1');

      // Re-import: every id is skipped, state is unchanged.
      final skippedSecond = await s.importJson(json);
      expect(skippedSecond, isNotEmpty);
      expect(s.confirmedCounts()[Prayer.fajr], 5);
      expect(s.totalCompleted(), 3);
      expect((await s.bleedingRecords()).single.id, 'b1');
    });

    test(
      'malformed import throws FormatException and imports nothing',
      () async {
        final s = await _loadedService();
        await s.setExactCounts({Prayer.fajr: 4}, 'seed');

        await expectLater(
          s.importJson('{not valid json'),
          throwsFormatException,
        );
        await expectLater(
          s.importJson(jsonEncode({'format': 'nope'})),
          throwsFormatException,
        );
        await expectLater(
          s.importJson(jsonEncode({'format': 'qada_export', 'version': 99})),
          throwsFormatException,
        );
        await expectLater(
          s.importJson(
            jsonEncode({
              'format': 'qada_export',
              'version': 2,
              'qada': {'schema_version': 2, 'balances': 'bogus'},
            }),
          ),
          throwsFormatException,
        );
        await expectLater(
          s.importJson(
            jsonEncode({
              'format': 'qada_export',
              'version': 2,
              'qada': {
                'schema_version': 2,
                'balances': {},
                'transactions': [
                  {'id': 'bad', 'type': 'nope'},
                ],
                'periods': [],
                'planner': {},
              },
            }),
          ),
          throwsFormatException,
        );

        // Untouched: nothing was partially imported.
        expect(s.confirmedCounts()[Prayer.fajr], 4);
        expect(s.totalOutstanding(), 4);
        expect(s.transactions(), hasLength(1));
      },
    );
  });

  group('deleteAll', () {
    test(
      'wipes the v2 doc, legacy v1 key, mirrors, and secure storage',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = await _newService();
        await s.logMissed(date: DateTime(2026, 10, 15), prayer: Prayer.fajr);
        await s.setExactCounts({Prayer.dhuhr: 3}, 'seed');
        await s.setDailyTarget(2);
        await s.setReminderMinutes(15);
        await s.saveBleedingRecord(
          BleedingRecord(
            id: 'b1',
            type: BleedingType.hayd,
            status: BleedingStatus.ongoing,
            start: DateTime(2026, 10, 1),
          ),
        );

        await s.deleteAll();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('qada_v2'), isNull);
        expect(prefs.getString('qada_entries_v1'), isNull);
        expect(prefs.getInt('qada_daily_target'), isNull);
        expect(prefs.getInt('qada_reminder_minutes'), isNull);
        expect(await s.bleedingRecords(), isEmpty);
        expect(s.totalOutstanding(), 0);
        expect(s.pending(), isEmpty);
      },
    );
  });

  group('bridge adoption', () {
    test('adopts the interim bridge document once', () async {
      final s = await _loadedService(
        initialPrefs: {
          'qada_v2_state': jsonEncode({
            'counts': {'fajr': 6},
            'daily_target': 3,
            'weekly_target': 0,
            'reminder_minutes': 20,
            'estimated_flag': false,
            'origin': 'bridge',
            'transactions': [
              {
                'id': 't1',
                'type': 'completion',
                'prayer': 'fajr',
                'amount': 2,
                'reason': 'r',
                'note': null,
                'at': '2026-10-18T10:00:00.000',
                'idempotencyKey': 'k1',
                'reversedBy': null,
              },
            ],
            'tx_prior': {},
            'bleeding': [
              {
                'id': 'b9',
                'type': 'hayd',
                'start': '2026-10-01T00:00:00.000',
                'end': null,
                'status': 'completed',
                'purityGaps': [],
                'purityConfirmed': false,
                'note': null,
                'confirmation': 'unconfirmed',
                'childbirthDate': null,
              },
            ],
          }),
        },
      );

      expect(s.confirmedCounts()[Prayer.fajr], 6);
      expect(s.totalCompleted(), 2);
      expect(s.dailyTarget(), 3);
      expect(s.reminderMinutes(), 20);
      expect((await s.bleedingRecords()).single.id, 'b9');

      // Adopted into the new key; the bridge key is left intact.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('qada_v2'), isNotNull);
      expect(prefs.getString('qada_v2_state'), isNotNull);
    });
  });

  group('v1 / v2 coexistence', () {
    test('v1 entries and v2 balances stay independent systems', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _newService();

      await s.logMissed(date: DateTime(2026, 10, 15), prayer: Prayer.fajr);
      await s.setExactCounts({Prayer.dhuhr: 3}, 'seed');

      // The v1 entry is counted once, on the v1 side.
      expect(s.totalOutstanding(), 4);
      expect(s.remainingByPrayer()[Prayer.fajr], 1);
      expect(s.confirmedCounts()[Prayer.fajr], 1);
      expect(s.confirmedCounts()[Prayer.dhuhr], 3);
    });
  });
}
