import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/qada_rules.dart' as qada_rules;
import 'package:malikiprayertimes/models/qada_models.dart';
import 'package:malikiprayertimes/services/secure_store.dart';
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

  /// Creates a service. [secureStore] is an injectable seam for tests; the
  /// default talks to the platform secure storage. Constructing the default
  /// performs no platform-channel calls.
  QadaService({SecureStore? secureStore})
    : _secureStore = secureStore ?? SecureStore();

  final SecureStore _secureStore;

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
  ///
  /// After the v1 entries, the v2 ledger document is loaded (or migrated
  /// from v1 data, or adopted from the interim bridge key). See [_loadV2].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _entries.clear();
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          // Unknown (including newer) schema versions are treated as empty:
          // never crash on data written by a future version of the app.
          if (decoded['schema_version'] == schemaVersion) {
            final entries = decoded['entries'];
            if (entries is List) {
              for (final item in entries) {
                final entry = _decodeEntry(item);
                if (entry != null) _entries.add(entry);
              }
            }
          }
        }
      } catch (_) {
        // Corrupt JSON: keep the empty list.
        _entries.clear();
      }
    }
    await _loadV2(prefs);
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
    // v2-era marker: make sure a v2 document exists so a later [load] does
    // not mistake these v2-era v1 entries for pre-v2 data that still needs
    // migration. Never overwrites an existing v2 document.
    if (!_v2locked && prefs.getString(_v2key) == null) {
      await _persistV2();
    }
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
  ///
  /// When the entry was migrated into the v2 ledger, the ledger is kept in
  /// sync (balance -1 plus a completion transaction); otherwise v1 entries
  /// stay independent of v2.
  Future<void> markDone(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final e = _entries[index];
    if (e.done) return;
    _entries[index] =
        QadaEntry(id: e.id, date: e.date, prayer: e.prayer, done: true);
    await _persist();
    if (_migratedEntryIds.contains(id)) {
      _balances[e.prayer] = ((_balances[e.prayer] ?? 0) - 1).clamp(0, 1 << 30);
      _recordTx(
        QadaTransaction(
          id: _newTxId(),
          type: QadaTxType.completion,
          prayer: e.prayer,
          amount: 1,
          reason: 'Marked as made up (v1 entry)',
          note: 'v1 entry $id',
          at: DateTime.now(),
          idempotencyKey: 'v1-markdone:$id',
        ),
      );
      await _persistV2();
    }
    notifyListeners();
  }

  /// Deletes the entry with [id]. Unknown ids are ignored.
  ///
  /// Deleting a migrated-but-still-pending entry also releases it from the
  /// v2 ledger. The v2 ledger itself is append-only: use [undoTransaction]
  /// to reverse a transaction instead of deleting history.
  Future<void> deleteEntry(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final e = _entries.removeAt(index);
    await _persist();
    if (_migratedEntryIds.contains(id) && !e.done) {
      _balances[e.prayer] = ((_balances[e.prayer] ?? 0) - 1).clamp(0, 1 << 30);
      _recordTx(
        QadaTransaction(
          id: _newTxId(),
          type: QadaTxType.adjustment,
          prayer: e.prayer,
          amount: -1,
          reason: 'Deleted migrated v1 entry',
          note: 'v1 entry $id',
          at: DateTime.now(),
          idempotencyKey: 'v1-delete:$id',
        ),
      );
      await _persistV2();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Qada v2: count-based ledger (schema 2).
  //
  // Two balance systems coexist:
  //  * v1 entries (logMissed/markDone/deleteEntry above): individually
  //    logged missed prayers, the original QadaScreen behaviour. All v1
  //    semantics are unchanged.
  //  * v2 ledger (below): per-prayer outstanding balances plus an
  //    append-only transaction history, set by the calculation modes
  //    (exact counts, estimations, adjustments, exemptions).
  //
  // The systems are independent, except for migration: on [load], when only
  // pre-v2 data exists, v1 pending entries are seeded into the v2 balances
  // (origin 'migrated-v1') and v1 done entries become completion
  // transactions. Migrated v1 entry ids are recorded so the aggregate
  // methods never count the same debt twice, and later v1 markDone /
  // deleteEntry calls on migrated entries keep the ledger in sync.
  //
  // Storage: one JSON document at [_v2key]:
  //   {"schema_version":2,"balances":{"fajr":n,...},"transactions":[...],
  //    "periods":[...],"planner":{...},"migrated_entry_ids":[...],...}
  // Bleeding records are health data: their JSON lives ONLY in secure
  // storage (see [_bleedingKey]), never in shared_preferences.
  //
  // Atomicity, stated honestly: each mutation updates the in-memory state
  // first and then performs exactly ONE JSON write of the v2 document, so
  // no partial JSON is ever persisted. A crash between the in-memory
  // update and the write loses that single mutation (it is never
  // half-written); there is no write-ahead log. Bleeding records are a
  // second document with the same property.
  // ---------------------------------------------------------------------------

  /// SharedPreferences key of the v2 document.
  static const _v2key = 'qada_v2';

  /// Key written by the interim Worker-C bridge build. Adopted once on
  /// [load] when [_v2key] is absent; never written by this implementation.
  static const _bridgeV2Key = 'qada_v2_state';

  /// SharedPreferences mirror keys consumed by Worker E (reminders).
  /// Written through on every planner change; the v2 document stays
  /// authoritative.
  static const dailyTargetKey = 'qada_daily_target';
  static const reminderMinutesKey = 'qada_reminder_minutes';

  /// Secure-storage key for the bleeding records JSON.
  static const _bleedingKey = 'qada_bleeding_v2';

  final Map<Prayer, int> _balances = {for (final p in Prayer.values) p: 0};

  /// Append-only ledger, chronological (oldest first). History is never
  /// deleted; corrections are offsetting [QadaTxType.undo] transactions.
  final List<QadaTransaction> _tx = [];

  /// Estimation periods accepted via [saveEstimation], kept as an audit
  /// trail of where estimated balances came from.
  final List<EstimationPeriod> _periods = [];

  /// v1 entry ids already represented in the v2 ledger (migration seed).
  /// Aggregate methods exclude these from the v1 side so nothing is
  /// counted twice.
  final List<String> _migratedEntryIds = [];

  int _plannerDaily = 0;
  int _plannerWeekly = 0;
  int? _plannerReminder;

  /// True when any part of [_balances] came from an estimation.
  /// Cleared by [setExactCounts]. Drives the "Estimated" badge in the UI.
  bool _estimatedFlag = false;

  /// Origin string recorded by [setExactCounts] (e.g. `user-entered <date>`
  /// or "migrated-v1").
  String? _countsOrigin;

  /// True when the stored v2 document has an unrecognized schema: v2 reads
  /// stay empty and v2 writes throw, so a newer version's data is never
  /// clobbered. v1 behaviour is unaffected.
  bool _v2locked = false;

  int _txCounter = 0;

  final List<BleedingRecord> _bleeding = [];
  bool _bleedingLoaded = false;

  // -- v2 loading ----------------------------------------------------------

  void _resetV2State() {
    for (final p in Prayer.values) {
      _balances[p] = 0;
    }
    _tx.clear();
    _periods.clear();
    _migratedEntryIds.clear();
    _plannerDaily = 0;
    _plannerWeekly = 0;
    _plannerReminder = null;
    _estimatedFlag = false;
    _countsOrigin = null;
    _v2locked = false;
  }

  /// Loads the v2 document, adopting the interim bridge document or
  /// migrating pre-v2 data when appropriate. Never throws.
  Future<void> _loadV2(SharedPreferences prefs) async {
    _resetV2State();
    final raw = prefs.getString(_v2key);
    if (raw != null) {
      // Recognized schema (or unreadable JSON, treated as empty like the
      // v1 loader does). An unrecognized schema locks v2 writes.
      _v2locked = !_decodeV2(raw);
      return;
    }
    if (prefs.containsKey(_bridgeV2Key)) {
      await _adoptBridgeDocument(prefs);
      return;
    }
    if (prefs.containsKey(storageKey)) {
      await _migrateFromV1();
    }
  }

  /// Decodes a v2 document into memory. Returns false when the schema is
  /// unrecognized (the caller then locks v2 writes). Malformed pieces are
  /// skipped; corrupt JSON yields an empty state. Never throws.
  bool _decodeV2(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return true;
      if (decoded['schema_version'] != 2) return false;
      final balances = decoded['balances'];
      if (balances is Map) {
        for (final p in Prayer.values) {
          final v = balances[p.name];
          if (v is int && v >= 0) _balances[p] = v;
        }
      }
      final txs = decoded['transactions'];
      if (txs is List) {
        for (final item in txs) {
          try {
            if (item is Map) {
              _tx.add(
                QadaTransaction.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          } catch (_) {
            // Skip malformed transactions; the rest still load.
          }
        }
        _tx.sort((a, b) => a.at.compareTo(b.at));
      }
      final periods = decoded['periods'];
      if (periods is List) {
        for (final item in periods) {
          try {
            if (item is Map) {
              _periods.add(
                EstimationPeriod.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          } catch (_) {
            // Skip malformed periods.
          }
        }
      }
      final planner = decoded['planner'];
      if (planner is Map) {
        final daily = planner['daily_target'];
        final weekly = planner['weekly_target'];
        final reminder = planner['reminder_minutes'];
        if (daily is int && daily >= 0) _plannerDaily = daily;
        if (weekly is int && weekly >= 0) _plannerWeekly = weekly;
        _plannerReminder = reminder is int && reminder >= 0 ? reminder : null;
      }
      final migrated = decoded['migrated_entry_ids'];
      if (migrated is List) {
        for (final id in migrated) {
          if (id is String) _migratedEntryIds.add(id);
        }
      }
      _estimatedFlag = decoded['estimated_flag'] == true;
      final origin = decoded['origin'];
      _countsOrigin = origin is String ? origin : null;
      return true;
    } catch (_) {
      // Corrupt JSON: keep the empty state, stay writable.
      _resetV2State();
      return true;
    }
  }

  /// One-time adoption of the interim bridge document ('qada_v2_state').
  /// Counts, history, planner, flags and bleeding records carry over;
  /// the bridge key itself is left intact.
  Future<void> _adoptBridgeDocument(SharedPreferences prefs) async {
    final raw = prefs.getString(_bridgeV2Key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final counts = decoded['counts'];
      if (counts is Map) {
        for (final p in loggableQadaPrayers) {
          final v = counts[p.name];
          if (v is int && v >= 0) _balances[p] = v;
        }
      }
      final txs = decoded['transactions'];
      if (txs is List) {
        for (final item in txs) {
          try {
            if (item is Map) {
              _tx.add(
                QadaTransaction.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          } catch (_) {
            // Skip malformed transactions.
          }
        }
        _tx.sort((a, b) => a.at.compareTo(b.at));
      }
      _plannerDaily = (decoded['daily_target'] as int? ?? 0).clamp(0, 1 << 30);
      _plannerWeekly = (decoded['weekly_target'] as int? ?? 0).clamp(
        0,
        1 << 30,
      );
      final rm = decoded['reminder_minutes'];
      _plannerReminder = rm is int ? rm.clamp(0, 24 * 60) : null;
      _estimatedFlag = decoded['estimated_flag'] == true;
      final origin = decoded['origin'];
      _countsOrigin = origin is String ? origin : null;
      final bleeding = decoded['bleeding'];
      if (bleeding is List) {
        await _ensureBleedingLoaded();
        for (final item in bleeding) {
          try {
            if (item is Map) {
              _bleeding.add(
                BleedingRecord.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          } catch (_) {
            // Skip malformed records.
          }
        }
        await _persistBleeding();
      }
    } catch (_) {
      _resetV2State();
      return;
    }
    await _persistV2();
    await _mirrorPlannerKeys();
  }

  /// Migrates pre-v2 data: v1 pending entries seed the v2 balances
  /// (origin 'migrated-v1') and v1 done entries become completion
  /// transactions. The v1 key is left intact on disk; migrated entry ids
  /// are recorded so aggregates never double-count.
  Future<void> _migrateFromV1() async {
    final pendingCounts = <Prayer, int>{};
    final doneCounts = <Prayer, int>{};
    for (final e in _entries) {
      _migratedEntryIds.add(e.id);
      if (e.done) {
        doneCounts[e.prayer] = (doneCounts[e.prayer] ?? 0) + 1;
      } else {
        pendingCounts[e.prayer] = (pendingCounts[e.prayer] ?? 0) + 1;
      }
    }
    final now = DateTime.now();
    for (final entry in pendingCounts.entries) {
      if (entry.value <= 0) continue;
      _balances[entry.key] = entry.value;
      _recordTx(
        QadaTransaction(
          id: _newTxId(),
          type: QadaTxType.exactSet,
          prayer: entry.key,
          amount: entry.value,
          reason: 'Migrated pending entries from v1',
          note: 'origin: migrated-v1',
          at: now,
          idempotencyKey: 'migrated-v1:exact:${entry.key.name}',
        ),
      );
    }
    for (final entry in doneCounts.entries) {
      if (entry.value <= 0) continue;
      _recordTx(
        QadaTransaction(
          id: _newTxId(),
          type: QadaTxType.completion,
          prayer: entry.key,
          amount: entry.value,
          reason: 'Migrated completed entries from v1',
          note: 'origin: migrated-v1',
          at: now,
          idempotencyKey: 'migrated-v1:completion:${entry.key.name}',
        ),
      );
    }
    await _persistV2();
  }

  void _ensureV2Writable() {
    if (_v2locked) {
      throw StateError(
        'The qada v2 store has an unrecognized schema version; refusing '
        'to modify it so data written by a newer app version is never '
        'corrupted.',
      );
    }
  }

  // -- v2 persistence ------------------------------------------------------

  Map<String, dynamic> _v2doc() => {
    'schema_version': 2,
    'balances': {for (final e in _balances.entries) e.key.name: e.value},
    'transactions': [for (final t in _tx) t.toJson()],
    'periods': [for (final p in _periods) p.toJson()],
    'planner': {
      'daily_target': _plannerDaily,
      'weekly_target': _plannerWeekly,
      'reminder_minutes': _plannerReminder,
    },
    'migrated_entry_ids': _migratedEntryIds.toList(),
    'estimated_flag': _estimatedFlag,
    'origin': _countsOrigin,
  };

  /// Writes the whole v2 document in one JSON write: no partial JSON is
  /// ever persisted. Must only be called when [_ensureV2Writable] passes.
  Future<void> _persistV2() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_v2key, jsonEncode(_v2doc()));
  }

  /// Write-through mirrors of the planner for Worker E (reminders), which
  /// reads these SharedPreferences keys directly.
  Future<void> _mirrorPlannerKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(dailyTargetKey, _plannerDaily);
    if (_plannerReminder == null) {
      await prefs.remove(reminderMinutesKey);
    } else {
      await prefs.setInt(reminderMinutesKey, _plannerReminder!);
    }
  }

  // -- ledger helpers ------------------------------------------------------

  String _newTxId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_txCounter++}';

  void _recordTx(QadaTransaction tx) {
    _tx.add(tx);
  }

  QadaTransaction? _findByIdempotencyKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final t in _tx) {
      if (t.idempotencyKey == key) return t;
    }
    return null;
  }

  /// Replays the ledger for [prayer], stopping before [beforeId] when
  /// given. Reversed transactions are skipped (their undo carries the
  /// effect). Used to find the pre-image when undoing an absolute
  /// [QadaTxType.exactSet].
  int _replayBalance(Prayer prayer, {String? beforeId}) {
    var balance = 0;
    for (final t in _tx) {
      if (beforeId != null && t.id == beforeId) break;
      if (t.reversedBy != null) continue;
      if (t.prayer != prayer) continue;
      switch (t.type) {
        case QadaTxType.adjustment:
        case QadaTxType.estimation:
        case QadaTxType.undo:
          balance += t.amount;
        case QadaTxType.completion:
        case QadaTxType.exemption:
          balance -= t.amount;
        case QadaTxType.exactSet:
          balance = t.amount;
      }
    }
    return balance;
  }

  /// Applies one transaction's balance effect. Completion/exemption are
  /// floored at zero so a merge can never drive a balance negative.
  void _applyTxEffect(QadaTransaction t) {
    switch (t.type) {
      case QadaTxType.adjustment:
      case QadaTxType.estimation:
      case QadaTxType.undo:
        _balances[t.prayer] = (_balances[t.prayer] ?? 0) + t.amount;
      case QadaTxType.completion:
      case QadaTxType.exemption:
        _balances[t.prayer] = ((_balances[t.prayer] ?? 0) - t.amount).clamp(
          0,
          1 << 30,
        );
      case QadaTxType.exactSet:
        _balances[t.prayer] = t.amount;
    }
  }

  int _v1pendingNonMigrated() => _entries
      .where((e) => !e.done && !_migratedEntryIds.contains(e.id))
      .length;

  int _v1doneNonMigrated() =>
      _entries.where((e) => e.done && !_migratedEntryIds.contains(e.id)).length;

  Map<Prayer, int> _v1pendingCountsNonMigrated() {
    final out = <Prayer, int>{};
    for (final e in _entries) {
      if (!e.done && !_migratedEntryIds.contains(e.id)) {
        out[e.prayer] = (out[e.prayer] ?? 0) + 1;
      }
    }
    return out;
  }

  int _v2completionTotal() => _tx
      .where((t) => t.type == QadaTxType.completion && t.reversedBy == null)
      .fold(0, (sum, t) => sum + t.amount);

  // -- v2 public API --------------------------------------------------------

  /// Outstanding prayers: v2 ledger balances plus v1 pending entries that
  /// were never migrated (so migrated debt is never counted twice).
  int totalOutstanding() =>
      _balances.values.fold(0, (a, b) => a + b) + _v1pendingNonMigrated();

  /// Completed prayers: v2 completion transactions (net of undos) plus v1
  /// done entries that were never migrated.
  int totalCompleted() => _v1doneNonMigrated() + _v2completionTotal();

  /// Fraction of all recorded prayers that are made up (0 when none).
  double completionFraction() {
    final done = totalCompleted();
    final total = done + totalOutstanding();
    if (total <= 0) return 0.0;
    return done / total;
  }

  /// Per-prayer outstanding counts the user stated with certainty:
  /// non-migrated v1 entries plus v2 balances, but v2 balances only when
  /// they are NOT flagged as estimated.
  Map<Prayer, int> confirmedCounts() {
    final out = <Prayer, int>{};
    final v1counts = _v1pendingCountsNonMigrated();
    for (final p in loggableQadaPrayers) {
      out[p] = (v1counts[p] ?? 0) + (_estimatedFlag ? 0 : (_balances[p] ?? 0));
    }
    return out;
  }

  /// UI helper (not in the contract): whether any balance is estimated.
  bool hasEstimatedBalances() => _estimatedFlag;

  /// UI helper (not in the contract): origin recorded by [setExactCounts].
  String? countsOrigin() => _countsOrigin;

  /// UI helper (not in the contract): the v2 per-prayer balances.
  Map<Prayer, int> v2Counts() => Map<Prayer, int>.from(_balances);

  /// Replaces the v2 per-prayer balances with the exact counts the user
  /// entered. Prayers absent from [counts] are set to zero. [origin] is
  /// recorded on every transaction's note (e.g. "user-entered 2026-10-19"
  /// or "migrated-v1"). Negative counts throw [ArgumentError].
  Future<void> setExactCounts(Map<Prayer, int> counts, String origin) async {
    _ensureV2Writable();
    for (final entry in counts.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          'counts[${entry.key.name}]',
          'must be non-negative',
        );
      }
    }
    final now = DateTime.now();
    for (final p in Prayer.values) {
      final next = counts[p] ?? 0;
      if ((_balances[p] ?? 0) == next) continue;
      _balances[p] = next;
      _recordTx(
        QadaTransaction(
          id: _newTxId(),
          type: QadaTxType.exactSet,
          prayer: p,
          amount: next,
          reason: 'Exact counts set',
          note: 'origin: $origin',
          at: now,
          idempotencyKey:
              'exactset:${now.microsecondsSinceEpoch}:${p.name}:$next',
        ),
      );
    }
    _countsOrigin = origin;
    _estimatedFlag = false;
    await _persistV2();
    notifyListeners();
  }

  /// Builds an estimation preview from [periods] without changing any
  /// balances. Pure: no persistence, no state mutation.
  ///
  /// The math is delegated to Worker A's engine
  /// ([qada_rules.MalikiQadaRulesEngine.estimatePeriods]), which validates
  /// the input and never double-counts: reversed ranges and overlapping
  /// ranges are rejected by the engine and surface here as warnings with
  /// zero estimates (and `needsReview: true`) instead of throwing.
  Future<EstimationResult> previewEstimation(
    List<EstimationPeriod> periods,
  ) async {
    final inputs = <qada_rules.EstimationPeriodInput>[
      for (final p in periods)
        qada_rules.EstimationPeriodInput(
          start: p.start,
          end: p.end,
          dailyRates: {
            for (final e in p.dailyRate.entries) e.key: e.value.toDouble(),
          },
          label: p.note ?? '',
        ),
    ];
    final outcome = qada_rules.MalikiQadaRulesEngine.estimatePeriods(inputs);
    switch (outcome) {
      case qada_rules.EstimationSuccess(:var result):
        final estimated = <Prayer, int>{};
        final low = <Prayer, int>{};
        final high = <Prayer, int>{};
        for (final p in loggableQadaPrayers) {
          estimated[p] = 0;
          low[p] = 0;
          high[p] = 0;
        }
        for (final pe in result.perPrayer) {
          // The engine reports a low/high band; the single estimate is
          // their midpoint, rounded. No fiqh judgement is added here.
          estimated[pe.prayer] = ((pe.low + pe.high) / 2).round();
          low[pe.prayer] = pe.low.toInt();
          high[pe.prayer] = pe.high.toInt();
        }
        return EstimationResult(
          estimated: estimated,
          low: low,
          high: high,
          assumptions: result.assumptions,
          warnings: result.warnings,
          needsReview: result.needsReview,
        );
      case qada_rules.EstimationFailure(:var error):
        final zeros = <Prayer, int>{for (final p in loggableQadaPrayers) p: 0};
        return EstimationResult(
          estimated: zeros,
          low: Map<Prayer, int>.of(zeros),
          high: Map<Prayer, int>.of(zeros),
          assumptions: const [],
          warnings: [error.message],
          needsReview: true,
        );
    }
  }

  /// Adds the estimation [r] to the v2 balances and marks them estimated.
  /// Call only after the user explicitly confirmed the preview. One
  /// [QadaTxType.estimation] transaction is recorded per prayer with a
  /// deterministic idempotency key, so saving the same preview twice is a
  /// safe no-op. The [periods] are kept as an audit trail.
  Future<void> saveEstimation(
    EstimationResult r,
    List<EstimationPeriod> periods,
  ) async {
    _ensureV2Writable();
    for (final entry in r.estimated.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          'estimated[${entry.key.name}]',
          'must be non-negative',
        );
      }
    }
    final signature = jsonEncode([for (final p in periods) p.toJson()]);
    final now = DateTime.now();
    for (final p in loggableQadaPrayers) {
      final amount = r.estimated[p] ?? 0;
      if (amount <= 0) continue;
      final key = 'estimation:$signature:${p.name}';
      if (_findByIdempotencyKey(key) != null) continue;
      _balances[p] = (_balances[p] ?? 0) + amount;
      _recordTx(
        QadaTransaction(
          id: _newTxId(),
          type: QadaTxType.estimation,
          prayer: p,
          amount: amount,
          reason: 'Estimation saved',
          note: '${periods.length} period(s)',
          at: now,
          idempotencyKey: key,
        ),
      );
    }
    for (final period in periods) {
      final sig = jsonEncode(period.toJson());
      if (!_periods.any((e) => jsonEncode(e.toJson()) == sig)) {
        _periods.add(period);
      }
    }
    _estimatedFlag = true;
    await _persistV2();
    notifyListeners();
  }

  /// Adjusts one prayer's v2 balance by [delta] (negative allowed).
  /// [reason] must not be blank; [delta] must not be zero. A negative
  /// [delta] larger than the outstanding balance throws [StateError] —
  /// balances never go negative; use [undoTransaction] to correct a
  /// mistaken entry. A repeated [idempotencyKey] returns the original
  /// transaction without duplicating it.
  Future<QadaTransaction> adjust({
    required Prayer prayer,
    required int delta,
    required String reason,
    String? note,
    String? idempotencyKey,
  }) async {
    _ensureV2Writable();
    if (delta == 0) {
      throw ArgumentError.value(delta, 'delta', 'must be non-zero');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'must not be blank');
    }
    final existing = _findByIdempotencyKey(idempotencyKey);
    if (existing != null) return existing;
    final current = _balances[prayer] ?? 0;
    if (current + delta < 0) {
      throw StateError(
        'Cannot adjust ${prayer.name} by $delta: only $current outstanding. '
        'Adjustments never drive a balance negative; undo the mistaken '
        'transaction instead.',
      );
    }
    _balances[prayer] = current + delta;
    final tx = QadaTransaction(
      id: _newTxId(),
      type: QadaTxType.adjustment,
      prayer: prayer,
      amount: delta,
      reason: reason,
      note: note,
      at: DateTime.now(),
      idempotencyKey:
          idempotencyKey ??
          'adjust:${DateTime.now().microsecondsSinceEpoch}:$_txCounter',
    );
    _recordTx(tx);
    await _persistV2();
    notifyListeners();
    return tx;
  }

  /// Records [count] made-up prayers of [prayer] against the v2 balance.
  /// [count] must be positive and not exceed the outstanding balance,
  /// otherwise [StateError] is thrown (no negative balances; no silent
  /// clamping). A repeated [idempotencyKey] returns the original
  /// transaction without duplicating it.
  Future<QadaTransaction> complete({
    required Prayer prayer,
    required int count,
    String? note,
    String? idempotencyKey,
  }) async {
    _ensureV2Writable();
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'must be positive');
    }
    final existing = _findByIdempotencyKey(idempotencyKey);
    if (existing != null) return existing;
    final remaining = _balances[prayer] ?? 0;
    if (count > remaining) {
      throw StateError(
        'Cannot complete $count ${prayer.name}: only $remaining '
        'outstanding. Balances never go negative.',
      );
    }
    _balances[prayer] = remaining - count;
    final tx = QadaTransaction(
      id: _newTxId(),
      type: QadaTxType.completion,
      prayer: prayer,
      amount: count,
      reason: 'Marked as made up',
      note: note,
      at: DateTime.now(),
      idempotencyKey:
          idempotencyKey ??
          'complete:${DateTime.now().microsecondsSinceEpoch}:$_txCounter',
    );
    _recordTx(tx);
    await _persistV2();
    notifyListeners();
    return tx;
  }

  /// Reverses the transaction [id] with an offsetting [QadaTxType.undo]
  /// transaction and marks the original `reversedBy`. History is never
  /// deleted. Returns false when the id is unknown or already reversed.
  /// Undoing an absolute [QadaTxType.exactSet] restores the balance the
  /// prayer had just before that transaction (later adjustments to that
  /// prayer are superseded — use [adjust] for surgical corrections).
  Future<bool> undoTransaction(String id) async {
    _ensureV2Writable();
    final index = _tx.indexWhere((t) => t.id == id);
    if (index < 0) return false;
    final tx = _tx[index];
    if (tx.reversedBy != null) return false;
    final int delta;
    switch (tx.type) {
      case QadaTxType.adjustment:
      case QadaTxType.estimation:
      case QadaTxType.undo:
        delta = -tx.amount;
      case QadaTxType.completion:
      case QadaTxType.exemption:
        delta = tx.amount;
      case QadaTxType.exactSet:
        delta =
            _replayBalance(tx.prayer, beforeId: tx.id) -
            (_balances[tx.prayer] ?? 0);
    }
    _balances[tx.prayer] = (_balances[tx.prayer] ?? 0) + delta;
    final undoId = _newTxId();
    _tx[index] = tx.reversed(undoId);
    _recordTx(
      QadaTransaction(
        id: undoId,
        type: QadaTxType.undo,
        prayer: tx.prayer,
        amount: delta,
        reason: 'Undo of "${tx.reason}"',
        note: 'Reverses $id',
        at: DateTime.now(),
        idempotencyKey: 'undo:$id:$undoId',
      ),
    );
    await _persistV2();
    notifyListeners();
    return true;
  }

  /// Newest-first transaction history, optionally filtered by [prayer].
  List<QadaTransaction> transactions({Prayer? prayer, int limit = 200}) {
    final list = _tx.reversed
        .where((t) => prayer == null || t.prayer == prayer)
        .take(limit)
        .toList();
    return list;
  }

  int dailyTarget() => _plannerDaily;

  Future<void> setDailyTarget(int n) async {
    _ensureV2Writable();
    _plannerDaily = n.clamp(0, 100000);
    await _persistV2();
    await _mirrorPlannerKeys();
    notifyListeners();
  }

  int weeklyTarget() => _plannerWeekly;

  Future<void> setWeeklyTarget(int n) async {
    _ensureV2Writable();
    _plannerWeekly = n.clamp(0, 100000);
    await _persistV2();
    notifyListeners();
  }

  int? reminderMinutes() => _plannerReminder;

  Future<void> setReminderMinutes(int? m) async {
    _ensureV2Writable();
    _plannerReminder = m?.clamp(0, 24 * 60);
    await _persistV2();
    await _mirrorPlannerKeys();
    notifyListeners();
  }

  /// Projected date the outstanding balance reaches zero at the current
  /// target pace, or null when there is nothing outstanding or no target
  /// is set. The daily target wins when both are set. Always an estimate —
  /// the UI must label it as such.
  DateTime? projectedEndDate() {
    final total = totalOutstanding();
    if (total <= 0) return null;
    double perDay = 0;
    if (_plannerDaily > 0) {
      perDay = _plannerDaily.toDouble();
    } else if (_plannerWeekly > 0) {
      perDay = _plannerWeekly / 7.0;
    }
    if (perDay <= 0) return null;
    final days = (total / perDay).ceil();
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: days));
  }

  // -- bleeding records (secure storage only) -------------------------------

  Future<void> _ensureBleedingLoaded() async {
    if (_bleedingLoaded) return;
    _bleedingLoaded = true;
    try {
      final doc = await _secureStore.readJson(_bleedingKey);
      final records = doc?['records'];
      if (records is List) {
        for (final item in records) {
          try {
            if (item is Map) {
              _bleeding.add(
                BleedingRecord.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          } catch (_) {
            // Skip malformed records; the rest still load.
          }
        }
      }
    } on FormatException {
      // Corrupt secure document: start empty rather than crashing.
      _bleeding.clear();
    }
  }

  Future<void> _persistBleeding() async {
    await _secureStore.writeJson(_bleedingKey, {
      'schema_version': 1,
      'records': [for (final r in _bleeding) r.toJson()],
    });
  }

  /// Bleeding records, newest start first. Health data: stored only in
  /// secure storage, never in shared_preferences.
  Future<List<BleedingRecord>> bleedingRecords() async {
    await _ensureBleedingLoaded();
    final list = List<BleedingRecord>.from(_bleeding);
    list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  /// Inserts or replaces the record with the same id.
  Future<void> saveBleedingRecord(BleedingRecord r) async {
    await _ensureBleedingLoaded();
    final index = _bleeding.indexWhere((e) => e.id == r.id);
    if (index < 0) {
      _bleeding.add(r);
    } else {
      _bleeding[index] = r;
    }
    await _persistBleeding();
    notifyListeners();
  }

  /// Deletes the record with [id]; unknown ids are ignored.
  Future<void> deleteBleedingRecord(String id) async {
    await _ensureBleedingLoaded();
    final before = _bleeding.length;
    _bleeding.removeWhere((e) => e.id == id);
    if (_bleeding.length == before) return;
    await _persistBleeding();
    notifyListeners();
  }

  /// Applies a user-confirmed exemption: subtracts [daysApplied] per prayer
  /// from the v2 balances and records one [QadaTxType.exemption]
  /// transaction per prayer. This only runs after the user's explicit
  /// confirmation in the Hayd & Nifas screen; the app never calls it
  /// automatically. Exempting more than the outstanding balance throws
  /// [StateError]; negative values throw [ArgumentError].
  Future<void> applyExemption({
    required BleedingRecord record,
    required Map<Prayer, int> daysApplied,
  }) async {
    _ensureV2Writable();
    for (final entry in daysApplied.entries) {
      final v = entry.value;
      if (v < 0) {
        throw ArgumentError.value(
          v,
          'daysApplied[${entry.key.name}]',
          'must be non-negative',
        );
      }
      if (v > (_balances[entry.key] ?? 0)) {
        throw StateError(
          'Cannot exempt $v ${entry.key.name}: only '
          '${_balances[entry.key] ?? 0} outstanding. Balances never go '
          'negative.',
        );
      }
    }
    final now = DateTime.now();
    for (final p in loggableQadaPrayers) {
      final v = daysApplied[p] ?? 0;
      if (v <= 0) continue;
      final key = 'exemption:${record.id}:${p.name}:$v';
      if (_findByIdempotencyKey(key) != null) continue;
      _balances[p] = (_balances[p] ?? 0) - v;
      _recordTx(
        QadaTransaction(
          id: _newTxId(),
          type: QadaTxType.exemption,
          prayer: p,
          amount: v,
          reason: 'User-confirmed exemption',
          note: 'Record ${record.id} (${record.type.name})',
          at: now,
          idempotencyKey: key,
        ),
      );
    }
    await _persistV2();
    notifyListeners();
  }

  // -- export / import ------------------------------------------------------

  /// Full JSON backup: versioned envelope with the v2 document, the
  /// bleeding records, and the v1 entries.
  Future<String> exportJson() async {
    await _ensureBleedingLoaded();
    return jsonEncode({
      'format': 'qada_export',
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'qada': _v2doc(),
      'bleeding': [for (final r in _bleeding) r.toJson()],
      'entries': [
        for (final e in _entries)
          {
            'id': e.id,
            'date': _dateKey(e.date),
            'prayer': e.prayer.name,
            'done': e.done,
          },
      ],
    });
  }

  /// Restores state from [exportJson] output.
  ///
  /// The whole payload is validated before anything is mutated: malformed
  /// input throws a typed [FormatException] and nothing is imported
  /// (never a partial import). Merging is idempotent: transactions already
  /// present (by id or idempotency key), bleeding records and v1 entries
  /// already present (by id) are skipped, and their ids are returned.
  /// On a locally empty ledger the imported document is adopted wholesale;
  /// otherwise new transactions are appended and their effects applied.
  Future<List<String>> importJson(String json) async {
    _ensureV2Writable();
    final envelope = _parseExportEnvelope(json);
    final payload = _parseExportPayload(envelope);
    final bleeding = _parseExportBleeding(envelope);
    final entries = _parseExportEntries(envelope);

    // ---- everything validated; now merge ----
    final skipped = <String>[];
    final localIsEmpty = _tx.isEmpty && _balances.values.every((v) => v == 0);
    if (localIsEmpty) {
      for (final p in Prayer.values) {
        _balances[p] = payload.balances[p] ?? 0;
      }
      _tx
        ..clear()
        ..addAll(payload.txs);
      _periods
        ..clear()
        ..addAll(payload.periods);
      _plannerDaily = payload.planner.daily;
      _plannerWeekly = payload.planner.weekly;
      _plannerReminder = payload.planner.reminder;
      _migratedEntryIds
        ..clear()
        ..addAll(payload.migratedIds);
      _estimatedFlag = payload.estimatedFlag;
      _countsOrigin = payload.origin;
    } else {
      final knownIds = {for (final t in _tx) t.id};
      final knownKeys = {
        for (final t in _tx)
          if (t.idempotencyKey != null) t.idempotencyKey!,
      };
      for (final t in payload.txs) {
        if (knownIds.contains(t.id) ||
            (t.idempotencyKey != null &&
                knownKeys.contains(t.idempotencyKey))) {
          skipped.add(t.id);
          continue;
        }
        _tx.add(t);
        knownIds.add(t.id);
        if (t.idempotencyKey != null) knownKeys.add(t.idempotencyKey!);
        _applyTxEffect(t);
      }
      _tx.sort((a, b) => a.at.compareTo(b.at));
      for (final period in payload.periods) {
        final sig = jsonEncode(period.toJson());
        if (!_periods.any((e) => jsonEncode(e.toJson()) == sig)) {
          _periods.add(period);
        }
      }
      _plannerDaily = payload.planner.daily;
      _plannerWeekly = payload.planner.weekly;
      _plannerReminder = payload.planner.reminder;
      for (final id in payload.migratedIds) {
        if (!_migratedEntryIds.contains(id)) _migratedEntryIds.add(id);
      }
    }

    await _ensureBleedingLoaded();
    final knownBleeding = {for (final r in _bleeding) r.id};
    for (final r in bleeding) {
      if (knownBleeding.contains(r.id)) {
        skipped.add(r.id);
        continue;
      }
      _bleeding.add(r);
    }
    await _persistBleeding();

    final knownEntries = {for (final e in _entries) e.id};
    var entriesChanged = false;
    for (final e in entries) {
      if (knownEntries.contains(e.id)) {
        skipped.add(e.id);
        continue;
      }
      _entries.add(e);
      entriesChanged = true;
    }
    if (entriesChanged) await _persist();

    await _persistV2();
    await _mirrorPlannerKeys();
    notifyListeners();
    return skipped;
  }

  Map<String, dynamic> _parseExportEnvelope(String json) {
    dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      throw const FormatException('Import: not valid JSON.');
    }
    if (decoded is! Map) {
      throw const FormatException('Import: expected a JSON object.');
    }
    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['format'] != 'qada_export') {
      throw const FormatException(
        'Import: not a qada export (bad format tag).',
      );
    }
    final version = envelope['version'];
    if (version is! int || version > 2) {
      throw FormatException('Import: unsupported export version "$version".');
    }
    return envelope;
  }

  /// Validates the whole export payload before anything is mutated.
  /// Throws a typed [FormatException] on any malformation.
  _ExportPayload _parseExportPayload(Map<String, dynamic> envelope) {
    final raw = envelope['qada'];
    if (raw is! Map) {
      throw const FormatException('Import: missing qada document.');
    }
    final qada = Map<String, dynamic>.from(raw);
    if (qada['schema_version'] != 2) {
      throw const FormatException('Import: unsupported qada schema version.');
    }

    final balances = <Prayer, int>{};
    final bRaw = qada['balances'];
    if (bRaw is! Map) {
      throw const FormatException('Import: malformed balances.');
    }
    for (final p in Prayer.values) {
      final v = bRaw[p.name];
      if (v == null) continue;
      if (v is! int || v < 0) {
        throw FormatException('Import: malformed balance for ${p.name}.');
      }
      balances[p] = v;
    }

    final txs = <QadaTransaction>[];
    final tRaw = qada['transactions'];
    if (tRaw is! List) {
      throw const FormatException('Import: malformed transactions.');
    }
    for (final item in tRaw) {
      if (item is! Map) {
        throw const FormatException('Import: malformed transaction entry.');
      }
      final itemMap = Map<String, dynamic>.from(item);
      // The shared model decoders are lenient by design (they default
      // unknown values); import validation is strict instead.
      final typeStr = itemMap['type'];
      if (typeStr is! String ||
          !QadaTxType.values.any((t) => t.name == typeStr)) {
        throw FormatException('Import: unknown transaction type "$typeStr".');
      }
      final prayerStr = itemMap['prayer'];
      if (prayerStr is! String ||
          !Prayer.values.any((p) => p.name == prayerStr)) {
        throw FormatException(
          'Import: unknown prayer "$prayerStr" on transaction.',
        );
      }
      try {
        final tx = QadaTransaction.fromJson(itemMap);
        switch (tx.type) {
          case QadaTxType.exactSet:
          case QadaTxType.estimation:
          case QadaTxType.completion:
          case QadaTxType.exemption:
            if (tx.amount < 0) {
              throw FormatException(
                'Import: negative amount on ${tx.type.name} '
                'transaction ${tx.id}.',
              );
            }
          case QadaTxType.adjustment:
          case QadaTxType.undo:
            break; // Signed deltas are legal here.
        }
        txs.add(tx);
      } catch (e) {
        if (e is FormatException) rethrow;
        throw FormatException('Import: malformed transaction: $e');
      }
    }
    txs.sort((a, b) => a.at.compareTo(b.at));

    final periods = <EstimationPeriod>[];
    final pRaw = qada['periods'];
    if (pRaw is! List) {
      throw const FormatException('Import: malformed periods.');
    }
    for (final item in pRaw) {
      if (item is! Map) {
        throw const FormatException('Import: malformed estimation period.');
      }
      try {
        periods.add(EstimationPeriod.fromJson(Map<String, dynamic>.from(item)));
      } catch (e) {
        if (e is FormatException) rethrow;
        throw FormatException('Import: malformed estimation period: $e');
      }
    }

    var daily = 0;
    var weekly = 0;
    int? reminder;
    final plRaw = qada['planner'];
    if (plRaw != null) {
      if (plRaw is! Map) {
        throw const FormatException('Import: malformed planner.');
      }
      daily = _nonNegImportInt(plRaw['daily_target'], 'daily_target');
      weekly = _nonNegImportInt(plRaw['weekly_target'], 'weekly_target');
      final rm = plRaw['reminder_minutes'];
      if (rm != null) {
        reminder = _nonNegImportInt(rm, 'reminder_minutes');
      }
    }

    final migratedIds = <String>[];
    final mRaw = qada['migrated_entry_ids'];
    if (mRaw != null) {
      if (mRaw is! List || mRaw.any((e) => e is! String)) {
        throw const FormatException('Import: malformed migrated_entry_ids.');
      }
      migratedIds.addAll(mRaw.cast<String>());
    }

    final origin = qada['origin'];
    return _ExportPayload(
      balances: balances,
      txs: txs,
      periods: periods,
      planner: _ExportPlanner(daily: daily, weekly: weekly, reminder: reminder),
      migratedIds: migratedIds,
      estimatedFlag: qada['estimated_flag'] == true,
      origin: origin is String ? origin : null,
    );
  }

  int _nonNegImportInt(dynamic v, String field) {
    if (v is! int || v < 0) {
      throw FormatException('Import: malformed planner field $field.');
    }
    return v;
  }

  List<BleedingRecord> _parseExportBleeding(Map<String, dynamic> envelope) {
    final out = <BleedingRecord>[];
    final raw = envelope['bleeding'];
    if (raw == null) return out;
    if (raw is! List) {
      throw const FormatException('Import: malformed bleeding records.');
    }
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('Import: malformed bleeding record.');
      }
      final itemMap = Map<String, dynamic>.from(item);
      final typeStr = itemMap['type'];
      if (typeStr is! String ||
          !BleedingType.values.any((t) => t.name == typeStr)) {
        throw FormatException('Import: unknown bleeding type "$typeStr".');
      }
      try {
        out.add(BleedingRecord.fromJson(itemMap));
      } catch (e) {
        if (e is FormatException) rethrow;
        throw FormatException('Import: malformed bleeding record: $e');
      }
    }
    return out;
  }

  /// v1 entries use the lenient decoder: malformed entries are skipped so
  /// one bad legacy row cannot fail an otherwise valid import.
  List<QadaEntry> _parseExportEntries(Map<String, dynamic> envelope) {
    final out = <QadaEntry>[];
    final raw = envelope['entries'];
    if (raw == null) return out;
    if (raw is! List) {
      throw const FormatException('Import: malformed v1 entries.');
    }
    for (final item in raw) {
      final entry = _decodeEntry(item);
      if (entry != null) out.add(entry);
    }
    return out;
  }

  /// Deletes ALL qada data: the v2 document, the interim bridge document,
  /// the legacy v1 key, the planner mirror keys, the secure-storage
  /// bleeding records, and all in-memory state. The UI double-confirms
  /// before calling this.
  Future<void> deleteAll() async {
    _entries.clear();
    for (final p in Prayer.values) {
      _balances[p] = 0;
    }
    _tx.clear();
    _periods.clear();
    _migratedEntryIds.clear();
    _plannerDaily = 0;
    _plannerWeekly = 0;
    _plannerReminder = null;
    _estimatedFlag = false;
    _countsOrigin = null;
    _bleeding.clear();
    _bleedingLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_v2key);
    await prefs.remove(_bridgeV2Key);
    await prefs.remove(storageKey);
    await prefs.remove(dailyTargetKey);
    await prefs.remove(reminderMinutesKey);
    await _secureStore.deleteAll();
    notifyListeners();
  }
}

/// Validated pieces of an import payload.
class _ExportPayload {
  final Map<Prayer, int> balances;
  final List<QadaTransaction> txs;
  final List<EstimationPeriod> periods;
  final _ExportPlanner planner;
  final List<String> migratedIds;
  final bool estimatedFlag;
  final String? origin;

  _ExportPayload({
    required this.balances,
    required this.txs,
    required this.periods,
    required this.planner,
    required this.migratedIds,
    required this.estimatedFlag,
    required this.origin,
  });
}

/// Validated planner pieces of an import payload.
class _ExportPlanner {
  final int daily;
  final int weekly;
  final int? reminder;

  _ExportPlanner({
    required this.daily,
    required this.weekly,
    required this.reminder,
  });
}
