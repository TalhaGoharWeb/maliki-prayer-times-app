import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One missed prayer waiting to be made up (or already made up).
///
/// The [date] is the civil day the prayer was missed (time components are
/// discarded); [prayer] is never [Prayer.sunrise] (sunrise is a timetable
/// marker, not a prayer to be made up), though stored entries from older
/// schemas are tolerated on read.
@immutable
class QadaEntry {
  final String id;
  final DateTime date;
  final Prayer prayer;
  final bool done;

  const QadaEntry({
    required this.id,
    required this.date,
    required this.prayer,
    this.done = false,
  });
}

/// Missed-prayer (qada) tracker, persisted with shared_preferences.
///
/// The store is versioned: the JSON at [_storageKey] is
/// `{"schema_version":1,"entries":[{"id":"&lt;micros&gt;","date":"2026-10-16",
/// "prayer":"fajr","done":false}]}`. [load] never throws: a missing key,
/// corrupt JSON, an unknown schema version, or malformed entries all yield
/// an empty list. Malformed individual entries are skipped; the rest load.
class QadaService extends ChangeNotifier {
  static const storageKey = 'qada_entries_v1';
  static const schemaVersion = 1;

  final List<QadaEntry> _entries = [];

  /// Entries still to be made up, oldest missed date first.
  List<QadaEntry> pending() {
    final list = _entries.where((e) => !e.done).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// Entries already made up, most recently missed first.
  List<QadaEntry> completed() {
    final list = _entries.where((e) => e.done).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Remaining (not-done) counts per prayer.
  Map<Prayer, int> remainingByPrayer() {
    final counts = {for (final p in Prayer.values) p: 0};
    for (final e in _entries) {
      if (!e.done) counts[e.prayer] = counts[e.prayer]! + 1;
    }
    return counts;
  }

  /// Total number of not-done entries.
  int totalRemaining() => _entries.where((e) => !e.done).length;

  /// Loads the entries from shared_preferences. Never throws: missing keys,
  /// corrupt JSON, unknown schema versions, and malformed entries yield an
  /// (empty or partial) list instead.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _entries.clear();
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      // Unknown (including newer) schema versions are treated as empty:
      // never crash on data written by a future version of the app.
      if (decoded['schema_version'] != schemaVersion) return;
      final entries = decoded['entries'];
      if (entries is! List) return;
      for (final item in entries) {
        final entry = _decodeEntry(item);
        if (entry != null) _entries.add(entry);
      }
    } catch (_) {
      // Corrupt JSON: keep the empty list.
      _entries.clear();
    }
    notifyListeners();
  }

  /// Decodes one stored entry; returns `null` when the item is malformed
  /// (unknown prayer name, unparsable date, or wrong field types) so the
  /// rest of the list still loads.
  QadaEntry? _decodeEntry(dynamic item) {
    if (item is! Map) return null;
    final id = item['id'];
    final dateStr = item['date'];
    final prayerStr = item['prayer'];
    if (id is! String || dateStr is! String || prayerStr is! String) {
      return null;
    }
    DateTime date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
    Prayer? prayer;
    for (final p in Prayer.values) {
      if (p.name == prayerStr) {
        prayer = p;
        break;
      }
    }
    if (prayer == null) return null;
    final done = item['done'] is bool ? item['done'] as bool : false;
    return QadaEntry(
      id: id,
      date: DateTime(date.year, date.month, date.day),
      prayer: prayer,
      done: done,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode({
        'schema_version': schemaVersion,
        'entries': [
          for (final e in _entries)
            {
              'id': e.id,
              'date': _dateKey(e.date),
              'prayer': e.prayer.name,
              'done': e.done,
            },
        ],
      }),
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Logs a missed [prayer] on [date]. The id is the current time in
  /// microseconds, unique enough for user-driven logging.
  Future<void> logMissed({
    required DateTime date,
    required Prayer prayer,
  }) async {
    _entries.add(QadaEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime(date.year, date.month, date.day),
      prayer: prayer,
    ));
    await _persist();
    notifyListeners();
  }

  /// Marks the entry with [id] as made up. Unknown ids are ignored.
  Future<void> markDone(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final e = _entries[index];
    if (e.done) return;
    _entries[index] =
        QadaEntry(id: e.id, date: e.date, prayer: e.prayer, done: true);
    await _persist();
    notifyListeners();
  }

  /// Deletes the entry with [id]. Unknown ids are ignored.
  Future<void> deleteEntry(String id) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length == before) return;
    await _persist();
    notifyListeners();
  }
}
