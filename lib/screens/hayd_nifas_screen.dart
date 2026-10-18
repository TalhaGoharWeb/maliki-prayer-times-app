import 'dart:async';

import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/qada_models.dart';
import 'package:malikiprayertimes/services/qada_service.dart';
import 'package:malikiprayertimes/services/secure_store.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Optional Hayd & Nifas tracker. Records are observations only: the app
/// never classifies bleeding automatically, and uncertain cases need a
/// qualified scholar. The irregular tab records observations with no
/// classification UI at all.
class HaydNifasScreen extends StatefulWidget {
  /// Injected secure storage backend (tests use the in-memory fake).
  final SecureStore? secureStore;

  const HaydNifasScreen({super.key, this.secureStore});

  @override
  State<HaydNifasScreen> createState() => _HaydNifasScreenState();
}

String _dateTimeLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

String _dateLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _HaydNifasScreenState extends State<HaydNifasScreen> {
  late final Future<QadaService> _future;
  BleedingType _tab = BleedingType.hayd;
  List<BleedingRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<QadaService> _load() async {
    final service = QadaService(secureStore: widget.secureStore);
    await service.load();
    // The encrypted store must never leave this screen on an infinite
    // spinner: bound the wait and surface failures as an error state.
    try {
      _records = await service.bleedingRecords().timeout(
            const Duration(seconds: 10),
          );
    } on TimeoutException {
      throw StateError('secure-storage timeout');
    }
    return service;
  }

  Future<void> _reload(QadaService service) async {
    try {
      _records = await service.bleedingRecords().timeout(
            const Duration(seconds: 10),
          );
    } on TimeoutException {
      // Keep the last good list; the load path already surfaces errors.
      return;
    }
    if (mounted) setState(() {});
  }

  String _typeLabel(AppLocalizations l10n, BleedingType t) => switch (t) {
        BleedingType.hayd => l10n.hnTabHayd,
        BleedingType.nifas => l10n.hnTabNifas,
        BleedingType.irregular => l10n.hnTabIrregular,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hnTitle)),
      body: FutureBuilder<QadaService>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: scheme.error),
                    const SizedBox(height: 16),
                    Text(
                      l10n.hnLoadError,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final service = snapshot.data!;
          final visible =
              _records.where((r) => r.type == _tab).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _banner(context, l10n, scheme),
              const SizedBox(height: 16),
              SegmentedButton<BleedingType>(
                segments: [
                  for (final t in BleedingType.values)
                    ButtonSegment(
                      value: t,
                      label: Text(_typeLabel(l10n, t)),
                    ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              if (_tab == BleedingType.irregular) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.hnIrregularNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    l10n.hnNoRecords,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final r in visible) ...[
                  _recordCard(context, l10n, service, r),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _openEditor(context, service, null),
                icon: const Icon(Icons.add),
                label: Text(l10n.hnAddRecord),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The no-automatic-classification banner (icon + text, never color-only).
  Widget _banner(
      BuildContext context, AppLocalizations l10n, ColorScheme scheme) {
    final theme = Theme.of(context);
    return Card(
      color: scheme.tertiaryFixed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 22, color: scheme.onTertiaryFixed),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.hnNoAutoClassify,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onTertiaryFixed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(BuildContext context, AppLocalizations l10n,
      QadaService service, BleedingRecord r) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ongoing = r.status == BleedingStatus.ongoing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ongoing ? Icons.timelapse_outlined : Icons.check_circle_outline,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ongoing
                        ? '${_dateTimeLabel(r.start)} — ${l10n.hnRecordOngoing}'
                        : '${_dateTimeLabel(r.start)} — '
                            '${r.end == null ? '' : _dateTimeLabel(r.end!)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  r.confirmation == ConfirmationStatus.confirmed
                      ? Icons.verified_outlined
                      : Icons.help_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  r.confirmation == ConfirmationStatus.confirmed
                      ? l10n.hnConfirmed
                      : l10n.hnUnconfirmed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (r.purityGaps.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.water_drop_outlined,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '${r.purityGaps.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            if (r.note != null && r.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                r.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _openExemption(context, service, r),
                  child: Text(l10n.hnReviewExemption),
                ),
                IconButton(
                  tooltip: l10n.hnEditRecord,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openEditor(context, service, r),
                ),
                IconButton(
                  tooltip: l10n.hnDeleteRecord,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, service, r),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(
      BuildContext context, QadaService service, BleedingRecord? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RecordEditorDialog(
        type: _tab,
        existing: existing,
        service: service,
      ),
    );
    if (saved == true) {
      await _reload(service);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, QadaService service, BleedingRecord r) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.hnDeleteConfirmTitle),
        content: Text(l10n.hnDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.qadaCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.qadaDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.deleteBleedingRecord(r.id);
      await _reload(service);
    }
  }

  Future<void> _openExemption(
      BuildContext context, QadaService service, BleedingRecord r) async {
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ExemptionDialog(record: r, service: service),
    );
    if (applied == true) {
      await _reload(service);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.hnExempted)),
      );
    }
  }
}

/// Add/edit dialog for a bleeding record. All fields are user-entered
/// observations; nothing is classified or derived.
class _RecordEditorDialog extends StatefulWidget {
  final BleedingType type;
  final BleedingRecord? existing;
  final QadaService service;

  const _RecordEditorDialog({
    required this.type,
    this.existing,
    required this.service,
  });

  @override
  State<_RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<_RecordEditorDialog> {
  late DateTime _start;
  late DateTime _end;
  late bool _ongoing;
  late List<PurityGap> _gaps;
  late bool _purityConfirmed;
  late TextEditingController _note;
  late ConfirmationStatus _confirmation;
  DateTime? _childbirthDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _start = e?.start ?? DateTime(now.year, now.month, now.day);
    _end = e?.end ?? DateTime(now.year, now.month, now.day);
    _ongoing = e?.status == BleedingStatus.ongoing || e == null;
    _gaps = List<PurityGap>.from(e?.purityGaps ?? const []);
    _purityConfirmed = e?.purityConfirmed ?? false;
    _note = TextEditingController(text: e?.note ?? '');
    _confirmation = e?.confirmation ?? ConfirmationStatus.unconfirmed;
    _childbirthDate = e?.childbirthDate;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 60),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final dt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  Future<void> _pickDate(
      {required ValueChanged<DateTime> onPicked, DateTime? initial}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 60),
      lastDate: DateTime.now().add(const Duration(days: 370)),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    final record = BleedingRecord(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: widget.existing?.type ?? widget.type,
      start: _start,
      end: _ongoing ? null : _end,
      status: _ongoing ? BleedingStatus.ongoing : BleedingStatus.completed,
      purityGaps: _gaps,
      purityConfirmed: _purityConfirmed,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      confirmation: _confirmation,
      childbirthDate: _childbirthDate,
    );
    await widget.service.saveBleedingRecord(record);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.hnAddRecord : l10n.hnEditRecord),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dateTimeRow(
              context,
              label: l10n.hnStart,
              value: _dateTimeLabel(_start),
              onTap: () => _pickDateTime(isStart: true),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  Text(l10n.hnOngoing, style: theme.textTheme.bodyMedium),
              value: _ongoing,
              onChanged: (v) => setState(() => _ongoing = v),
            ),
            if (!_ongoing)
              _dateTimeRow(
                context,
                label: l10n.hnEnd,
                value: _dateTimeLabel(_end),
                onTap: () => _pickDateTime(isStart: false),
              ),
            const SizedBox(height: 8),
            Text(
              l10n.hnPurityIntervals.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < _gaps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_dateLabel(_gaps[i].start)} — ${_dateLabel(_gaps[i].end)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.hnRemoveInterval,
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: () => setState(() => _gaps.removeAt(i)),
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                DateTime? gs;
                await _pickDate(
                  onPicked: (d) => gs = d,
                  initial: _start,
                );
                if (gs == null || !mounted) return;
                DateTime? ge;
                await _pickDate(
                  onPicked: (d) => ge = d,
                  initial: gs,
                );
                if (ge == null || !mounted) return;
                setState(() => _gaps.add(PurityGap(start: gs!, end: ge!)));
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.hnAddInterval),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.hnPurityConfirmed,
                  style: theme.textTheme.bodyMedium),
              value: _purityConfirmed,
              onChanged: (v) => setState(() => _purityConfirmed = v ?? false),
            ),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.hnPrivateNote),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(l10n.hnConfirmation, style: theme.textTheme.bodyMedium),
            SegmentedButton<ConfirmationStatus>(
              segments: [
                ButtonSegment(
                  value: ConfirmationStatus.confirmed,
                  label: Text(l10n.hnConfirmed),
                ),
                ButtonSegment(
                  value: ConfirmationStatus.unconfirmed,
                  label: Text(l10n.hnUnconfirmed),
                ),
              ],
              selected: {_confirmation},
              onSelectionChanged: (s) =>
                  setState(() => _confirmation = s.first),
            ),
            if ((widget.existing?.type ?? widget.type) ==
                BleedingType.nifas) ...[
              const SizedBox(height: 8),
              _dateTimeRow(
                context,
                label: l10n.hnChildbirthDate,
                value: _childbirthDate == null
                    ? '—'
                    : _dateLabel(_childbirthDate!),
                onTap: () => _pickDate(
                  onPicked: (d) => setState(() => _childbirthDate = d),
                  initial: _childbirthDate,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.qadaCancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.qadaSave),
        ),
      ],
    );
  }

  Widget _dateTimeRow(BuildContext context,
      {required String label,
      required String value,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('$label: $value',
                style: theme.textTheme.bodyMedium),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// "Review for exemption" flow: the user picks how many days to exempt per
/// prayer, confirms explicitly, and only then is [QadaService.applyExemption]
/// called. Nothing is derived automatically.
class _ExemptionDialog extends StatefulWidget {
  final BleedingRecord record;
  final QadaService service;

  const _ExemptionDialog({required this.record, required this.service});

  @override
  State<_ExemptionDialog> createState() => _ExemptionDialogState();
}

String _prayerName(AppLocalizations l10n, Prayer p) => switch (p) {
      Prayer.fajr => l10n.prayerFajr,
      Prayer.sunrise => l10n.prayerSunrise,
      Prayer.dhuhr => l10n.prayerDhuhr,
      Prayer.asr => l10n.prayerAsr,
      Prayer.maghrib => l10n.prayerMaghrib,
      Prayer.isha => l10n.prayerIsha,
    };

class _ExemptionDialogState extends State<_ExemptionDialog> {
  final Map<Prayer, int> _days = {
    for (final p in loggableQadaPrayers) p: 0,
  };
  String? _error;

  int _total() => _days.values.fold(0, (a, b) => a + b);

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context)!;
    final total = _total();
    // The service throws StateError when the exemption exceeds the
    // outstanding balance; validate first and show an inline error.
    final balances = widget.service.v2Counts();
    for (final p in loggableQadaPrayers) {
      final balance = balances[p] ?? 0;
      if ((_days[p] ?? 0) > balance) {
        setState(() => _error =
            l10n.hnExemptionTooMany(_prayerName(l10n, p), balance));
        return;
      }
    }
    setState(() => _error = null);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.hnExemptionConfirmTitle),
        content: Text(l10n.hnExemptionConfirmBody(total)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.qadaCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.qada2Confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.service.applyExemption(
      record: widget.record,
      daysApplied: Map<Prayer, int>.from(_days),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.hnExemptionTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.hnExemptionDays,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),            for (final p in loggableQadaPrayers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _prayerName(l10n, p),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _days[p]! > 0
                          ? () => setState(() => _days[p] = _days[p]! - 1)
                          : null,
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${_days[p]}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _days[p]! < 365
                          ? () => setState(() => _days[p] = _days[p]! + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.qadaCancel),
        ),
        FilledButton(
          onPressed: _total() > 0 ? _apply : null,
          child: Text(l10n.qada2Confirm),
        ),
      ],
    );
  }
}
