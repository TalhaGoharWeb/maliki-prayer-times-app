import 'package:malikiprayertimes/engine/prayer_times.dart';

/// Five prayers that can be missed (sunrise is a timetable marker, not a
/// prayer to be made up). Shared by the qada UI screens.
const loggableQadaPrayers = [
  Prayer.fajr,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

/// Kind of bleeding for the Hayd & Nifas tracker. The app never classifies
/// bleeding automatically; the user picks the tab they are recording under.
enum BleedingType { hayd, nifas, irregular }

/// Lifecycle state of a [BleedingRecord].
enum BleedingStatus { ongoing, completed }

/// Whether the user confirmed the record's details are accurate.
enum ConfirmationStatus { confirmed, unconfirmed }

/// Kinds of qada balance transactions kept in the planner history.
enum QadaTxType { exactSet, estimation, adjustment, completion, exemption, undo }

/// One date range with a per-prayer daily miss rate, used by the
/// estimation (Mode B) and wizard (Mode C) flows.
class EstimationPeriod {
  final DateTime start;
  final DateTime end;
  final Map<Prayer, int> dailyRate;
  final String? note;

  const EstimationPeriod({
    required this.start,
    required this.end,
    required this.dailyRate,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'dailyRate': {for (final e in dailyRate.entries) e.key.name: e.value},
        'note': note,
      };

  factory EstimationPeriod.fromJson(Map<String, dynamic> json) {
    final rates = <Prayer, int>{};
    final raw = json['dailyRate'];
    if (raw is Map) {
      for (final p in Prayer.values) {
        final v = raw[p.name];
        if (v is int) rates[p] = v;
      }
    }
    return EstimationPeriod(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      dailyRate: rates,
      note: json['note'] as String?,
    );
  }
}

/// The outcome of previewing an estimation: per-prayer estimate with a
/// low–high uncertainty band, plus human-readable assumptions/warnings.
class EstimationResult {
  final Map<Prayer, int> estimated;
  final Map<Prayer, int> low;
  final Map<Prayer, int> high;
  final List<String> assumptions;
  final List<String> warnings;
  final bool needsReview;

  const EstimationResult({
    required this.estimated,
    required this.low,
    required this.high,
    required this.assumptions,
    required this.warnings,
    required this.needsReview,
  });

  Map<String, dynamic> toJson() => {
        'estimated': _countsJson(estimated),
        'low': _countsJson(low),
        'high': _countsJson(high),
        'assumptions': assumptions,
        'warnings': warnings,
        'needsReview': needsReview,
      };

  factory EstimationResult.fromJson(Map<String, dynamic> json) =>
      EstimationResult(
        estimated: _countsFromJson(json['estimated']),
        low: _countsFromJson(json['low']),
        high: _countsFromJson(json['high']),
        assumptions: List<String>.from(json['assumptions'] as List? ?? const []),
        warnings: List<String>.from(json['warnings'] as List? ?? const []),
        needsReview: json['needsReview'] as bool? ?? false,
      );

  static Map<String, int> _countsJson(Map<Prayer, int> counts) =>
      {for (final e in counts.entries) e.key.name: e.value};

  static Map<Prayer, int> _countsFromJson(dynamic raw) {
    final out = <Prayer, int>{};
    if (raw is Map) {
      for (final p in Prayer.values) {
        final v = raw[p.name];
        if (v is int) out[p] = v;
      }
    }
    return out;
  }
}

/// One auditable change to the qada balances, shown in the planner history.
class QadaTransaction {
  final String id;
  final QadaTxType type;
  final Prayer prayer;
  final int amount;
  final String reason;
  final String? note;
  final DateTime at;
  final String? idempotencyKey;
  final String? reversedBy;

  const QadaTransaction({
    required this.id,
    required this.type,
    required this.prayer,
    required this.amount,
    required this.reason,
    this.note,
    required this.at,
    this.idempotencyKey,
    this.reversedBy,
  });

  QadaTransaction reversed(String undoId) => QadaTransaction(
        id: id,
        type: type,
        prayer: prayer,
        amount: amount,
        reason: reason,
        note: note,
        at: at,
        idempotencyKey: idempotencyKey,
        reversedBy: undoId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'prayer': prayer.name,
        'amount': amount,
        'reason': reason,
        'note': note,
        'at': at.toIso8601String(),
        'idempotencyKey': idempotencyKey,
        'reversedBy': reversedBy,
      };

  factory QadaTransaction.fromJson(Map<String, dynamic> json) {
    QadaTxType type = QadaTxType.adjustment;
    for (final t in QadaTxType.values) {
      if (t.name == json['type']) {
        type = t;
        break;
      }
    }
    Prayer prayer = Prayer.fajr;
    for (final p in Prayer.values) {
      if (p.name == json['prayer']) {
        prayer = p;
        break;
      }
    }
    return QadaTransaction(
      id: json['id'] as String,
      type: type,
      prayer: prayer,
      amount: json['amount'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
      note: json['note'] as String?,
      at: DateTime.parse(json['at'] as String),
      idempotencyKey: json['idempotencyKey'] as String?,
      reversedBy: json['reversedBy'] as String?,
    );
  }
}

/// One interval of purity (tuhr) inside a bleeding episode, recorded by
/// the user — the app never derives these automatically.
class PurityGap {
  final DateTime start;
  final DateTime end;

  const PurityGap({required this.start, required this.end});

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  factory PurityGap.fromJson(Map<String, dynamic> json) => PurityGap(
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
      );
}

/// One user-recorded bleeding episode. Records are observations only: the
/// app does not classify bleeding and does not derive rulings from them.
class BleedingRecord {
  final String id;
  final BleedingType type;
  final DateTime start;
  final DateTime? end;
  final BleedingStatus status;
  final List<PurityGap> purityGaps;
  final bool purityConfirmed;
  final String? note;
  final ConfirmationStatus confirmation;
  final DateTime? childbirthDate;

  const BleedingRecord({
    required this.id,
    required this.type,
    required this.start,
    this.end,
    required this.status,
    this.purityGaps = const [],
    this.purityConfirmed = false,
    this.note,
    this.confirmation = ConfirmationStatus.unconfirmed,
    this.childbirthDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'status': status.name,
        'purityGaps': [for (final g in purityGaps) g.toJson()],
        'purityConfirmed': purityConfirmed,
        'note': note,
        'confirmation': confirmation.name,
        'childbirthDate': childbirthDate?.toIso8601String(),
      };

  factory BleedingRecord.fromJson(Map<String, dynamic> json) {
    BleedingType type = BleedingType.hayd;
    for (final t in BleedingType.values) {
      if (t.name == json['type']) {
        type = t;
        break;
      }
    }
    BleedingStatus status = BleedingStatus.completed;
    for (final s in BleedingStatus.values) {
      if (s.name == json['status']) {
        status = s;
        break;
      }
    }
    ConfirmationStatus confirmation = ConfirmationStatus.unconfirmed;
    for (final c in ConfirmationStatus.values) {
      if (c.name == json['confirmation']) {
        confirmation = c;
        break;
      }
    }
    final endRaw = json['end'] as String?;
    final cbRaw = json['childbirthDate'] as String?;
    final gapsRaw = json['purityGaps'];
    return BleedingRecord(
      id: json['id'] as String,
      type: type,
      start: DateTime.parse(json['start'] as String),
      end: endRaw == null ? null : DateTime.parse(endRaw),
      status: status,
      purityGaps: gapsRaw is List
          ? [
              for (final g in gapsRaw)
                if (g is Map<String, dynamic>)
                  PurityGap.fromJson(g)
                else if (g is Map)
                  PurityGap.fromJson(Map<String, dynamic>.from(g))
            ]
          : const [],
      purityConfirmed: json['purityConfirmed'] as bool? ?? false,
      note: json['note'] as String?,
      confirmation: confirmation,
      childbirthDate: cbRaw == null ? null : DateTime.parse(cbRaw),
    );
  }
}
