import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/services/qada_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<QadaService> _loaded() async {
  final service = QadaService();
  await service.load();
  return service;
}

void main() {
  group('QadaService', () {
    test('starts empty when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _loaded();

      expect(s.pending(), isEmpty);
      expect(s.completed(), isEmpty);
      expect(s.totalRemaining(), 0);
      expect(s.remainingByPrayer().values.every((c) => c == 0), isTrue);
    });

    test('logMissed adds a pending entry with the right date and prayer',
        () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _loaded();

      await s.logMissed(
          date: DateTime(2026, 10, 15), prayer: Prayer.fajr);

      expect(s.totalRemaining(), 1);
      final pending = s.pending();
      expect(pending, hasLength(1));
      expect(pending.single.prayer, Prayer.fajr);
      expect(pending.single.date, DateTime(2026, 10, 15));
      expect(pending.single.done, isFalse);
      expect(s.remainingByPrayer()[Prayer.fajr], 1);
      expect(s.remainingByPrayer()[Prayer.dhuhr], 0);
    });

    test('pending is sorted oldest date first', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _loaded();

      await s.logMissed(
          date: DateTime(2026, 10, 16), prayer: Prayer.maghrib);
      await s.logMissed(date: DateTime(2026, 10, 14), prayer: Prayer.fajr);

      final pending = s.pending();
      expect(pending.map((e) => e.date),
          [DateTime(2026, 10, 14), DateTime(2026, 10, 16)]);
    });

    test('markDone moves the entry to completed and drops the counts',
        () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _loaded();

      await s.logMissed(date: DateTime(2026, 10, 15), prayer: Prayer.asr);
      final id = s.pending().single.id;

      await s.markDone(id);

      expect(s.pending(), isEmpty);
      expect(s.totalRemaining(), 0);
      expect(s.remainingByPrayer()[Prayer.asr], 0);
      final completed = s.completed();
      expect(completed, hasLength(1));
      expect(completed.single.id, id);
      expect(completed.single.done, isTrue);
    });

    test('markDone with an unknown id does nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _loaded();

      await s.logMissed(date: DateTime(2026, 10, 15), prayer: Prayer.isha);
      await s.markDone('no-such-id');

      expect(s.totalRemaining(), 1);
    });

    test('deleteEntry removes pending and completed entries', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _loaded();

      await s.logMissed(date: DateTime(2026, 10, 15), prayer: Prayer.fajr);
      await s.logMissed(date: DateTime(2026, 10, 16), prayer: Prayer.dhuhr);
      final doneId = s.pending().first.id;
      await s.markDone(doneId);
      final pendingId = s.pending().single.id;

      await s.deleteEntry(pendingId);
      expect(s.totalRemaining(), 0);
      expect(s.pending(), isEmpty);

      await s.deleteEntry(doneId);
      expect(s.completed(), isEmpty);

      await s.deleteEntry('no-such-id'); // unknown ids are ignored
    });

    test('entries persist across service instances', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _loaded();

      await s.logMissed(date: DateTime(2026, 10, 15), prayer: Prayer.fajr);
      await s.logMissed(date: DateTime(2026, 10, 16), prayer: Prayer.maghrib);
      final id = s.pending().first.id;
      await s.markDone(id);

      final reloaded = await _loaded();

      expect(reloaded.totalRemaining(), 1);
      expect(reloaded.pending().single.prayer, Prayer.maghrib);
      expect(reloaded.pending().single.date, DateTime(2026, 10, 16));
      expect(reloaded.completed(), hasLength(1));
      expect(reloaded.completed().single.id, id);
    });

    test('stored JSON has the documented shape', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await _loaded();

      await s.logMissed(date: DateTime(2026, 10, 16), prayer: Prayer.fajr);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(QadaService.storageKey)!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['schema_version'], 1);
      final entries = decoded['entries'] as List;
      expect(entries, hasLength(1));
      final entry = entries.single as Map<String, dynamic>;
      expect(entry['date'], '2026-10-16');
      expect(entry['prayer'], 'fajr');
      expect(entry['done'], isFalse);
      expect(entry['id'], isA<String>());
    });

    test('unknown schema version loads as empty without throwing', () async {
      SharedPreferences.setMockInitialValues({
        QadaService.storageKey: jsonEncode({
          'schema_version': 2,
          'entries': [
            {
              'id': '1',
              'date': '2026-10-16',
              'prayer': 'fajr',
              'done': false,
            },
          ],
        }),
      });
      final s = await _loaded();

      expect(s.totalRemaining(), 0);
      expect(s.pending(), isEmpty);
    });

    test('corrupt JSON loads as empty without throwing', () async {
      SharedPreferences.setMockInitialValues({
        QadaService.storageKey: '{not valid json',
      });
      final s = await _loaded();

      expect(s.totalRemaining(), 0);
      expect(s.pending(), isEmpty);
    });

    test('malformed entries are skipped, valid ones still load', () async {
      SharedPreferences.setMockInitialValues({
        QadaService.storageKey: jsonEncode({
          'schema_version': 1,
          'entries': [
            {
              'id': 'good',
              'date': '2026-10-16',
              'prayer': 'fajr',
              'done': false,
            },
            {
              'id': 'bad-prayer',
              'date': '2026-10-16',
              'prayer': 'witr',
              'done': false,
            },
            {
              'id': 'bad-date',
              'date': 'not-a-date',
              'prayer': 'dhuhr',
              'done': false,
            },
            'just-a-string',
          ],
        }),
      });
      final s = await _loaded();

      expect(s.totalRemaining(), 1);
      expect(s.pending().single.id, 'good');
    });
  });
}
