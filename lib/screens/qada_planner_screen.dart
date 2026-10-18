import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/qada_models.dart';
import 'package:malikiprayertimes/services/qada_service.dart';
import 'package:malikiprayertimes/services/secure_store.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Qada planner: plan modes with daily/weekly targets, a reminder toggle
/// (notification only — never a completion), the projected finish date,
/// a quick "log made-up prayers" action, the full transaction history with
/// per-record undo, and backup export/import plus delete-all in a privacy
/// section.
class QadaPlannerScreen extends StatefulWidget {
  /// Injected secure storage backend (tests use the in-memory fake).
  final SecureStore? secureStore;

  const QadaPlannerScreen({super.key, this.secureStore});

  @override
  State<QadaPlannerScreen> createState() => _QadaPlannerScreenState();
}

enum _PlanMode { afterFard, fullDay, daily, weekly, custom }

String _prayerName(AppLocalizations l10n, Prayer p) => switch (p) {
      Prayer.fajr => l10n.prayerFajr,
      Prayer.sunrise => l10n.prayerSunrise,
      Prayer.dhuhr => l10n.prayerDhuhr,
      Prayer.asr => l10n.prayerAsr,
      Prayer.maghrib => l10n.prayerMaghrib,
      Prayer.isha => l10n.prayerIsha,
    };

String _dateLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _QadaPlannerScreenState extends State<QadaPlannerScreen> {
  late final Future<QadaService> _future;
  _PlanMode _mode = _PlanMode.custom;
  Prayer? _historyFilter;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<QadaService> _load() async {
    final service = QadaService(secureStore: widget.secureStore);
    await service.load();
    return service;
  }

  String _modeLabel(AppLocalizations l10n, _PlanMode m) => switch (m) {
        _PlanMode.afterFard => l10n.qada2PlanModeAfterFard,
        _PlanMode.fullDay => l10n.qada2PlanModeFullDay,
        _PlanMode.daily => l10n.qada2PlanModeDaily,
        _PlanMode.weekly => l10n.qada2PlanModeWeekly,
        _PlanMode.custom => l10n.qada2PlanModeCustom,
      };

  String? _modeDesc(AppLocalizations l10n, _PlanMode m) => switch (m) {
        _PlanMode.afterFard => l10n.qada2PlanModeAfterFardDesc,
        _PlanMode.fullDay => l10n.qada2PlanModeFullDayDesc,
        _PlanMode.custom => l10n.qada2PlanModeCustomDesc,
        _PlanMode.daily || _PlanMode.weekly => null,
      };

  Future<void> _onModeChanged(_PlanMode? m, QadaService service) async {
    if (m == null) return;
    setState(() => _mode = m);
    switch (m) {
      case _PlanMode.afterFard:
      case _PlanMode.fullDay:
        await service.setDailyTarget(5);
      case _PlanMode.daily:
      case _PlanMode.weekly:
      case _PlanMode.custom:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.qada2PlannerTitle)),
      body: FutureBuilder<QadaService>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final service = snapshot.data!;
          return ListenableBuilder(
            listenable: service,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _sectionCard(
                  context,
                  title: l10n.qada2PlanMode,
                  child: _planModeSection(context, l10n, service),
                ),
                const SizedBox(height: 16),
                _etaCard(context, l10n, service),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: l10n.qada2LogMadeUp,
                  child: _LogMadeUpForm(service: service),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: l10n.qada2Reminder,
                  child: _ReminderSection(service: service),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: l10n.qada2History,
                  child: _historySection(context, l10n, service),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: l10n.qada2Export,
                  child: _backupSection(context, l10n, service),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: l10n.qada2Privacy,
                  child: _privacySection(context, l10n, service),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionCard(BuildContext context,
      {required String title, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _planModeSection(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<_PlanMode>(
          initialValue: _mode,
          decoration: InputDecoration(labelText: l10n.qada2PlanMode),
          items: [
            for (final m in _PlanMode.values)
              DropdownMenuItem(value: m, child: Text(_modeLabel(l10n, m))),
          ],
          onChanged: (m) => _onModeChanged(m, service),
        ),
        if (_modeDesc(l10n, _mode) != null) ...[
          const SizedBox(height: 8),
          Text(
            _modeDesc(l10n, _mode)!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_mode == _PlanMode.daily || _mode == _PlanMode.custom)
          _TargetField(
            label: l10n.qada2DailyTargetLabel,
            initial: service.dailyTarget(),
            onSaved: service.setDailyTarget,
          ),
        if (_mode == _PlanMode.weekly || _mode == _PlanMode.custom) ...[
          if (_mode == _PlanMode.custom) const SizedBox(height: 8),
          _TargetField(
            label: l10n.qada2WeeklyTargetLabel,
            initial: service.weeklyTarget(),
            onSaved: service.setWeeklyTarget,
          ),
        ],
        if (_mode == _PlanMode.afterFard || _mode == _PlanMode.fullDay)
          Text(
            l10n.qada2TodaysPlanValue(service.dailyTarget()),
            style: theme.textTheme.titleSmall,
          ),
      ],
    );
  }

  Widget _etaCard(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eta = service.projectedEndDate();
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined,
                size: 26, color: scheme.tertiaryFixed),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.qada2EtaLabel.toUpperCase(),
                    style: AppFonts.eyebrow(context).copyWith(
                      color: scheme.tertiaryFixed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    eta == null
                        ? l10n.qada2NoEta
                        : l10n.qada2ProjectedFinishValue(_dateLabel(eta)),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historySection(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    final theme = Theme.of(context);
    final tx = service.transactions(prayer: _historyFilter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<Prayer?>(
          initialValue: _historyFilter,
          decoration: const InputDecoration(),
          items: [
            DropdownMenuItem<Prayer?>(
                value: null, child: Text(l10n.qada2FilterAll)),
            for (final p in loggableQadaPrayers)
              DropdownMenuItem<Prayer?>(
                  value: p, child: Text(_prayerName(l10n, p))),
          ],
          onChanged: (p) => setState(() => _historyFilter = p),
        ),
        const SizedBox(height: 8),
        if (tx.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.qada2NoHistory,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final t in tx) _txRow(context, l10n, service, t),
      ],
    );
  }

  Widget _txRow(BuildContext context, AppLocalizations l10n,
      QadaService service, QadaTransaction t) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = switch (t.type) {
      QadaTxType.exactSet => Icons.edit_note_outlined,
      QadaTxType.estimation => Icons.auto_awesome_outlined,
      QadaTxType.adjustment => Icons.tune_outlined,
      QadaTxType.completion => Icons.check_circle_outline,
      QadaTxType.exemption => Icons.water_drop_outlined,
      QadaTxType.undo => Icons.undo_outlined,
    };
    final undone = t.reversedBy != null;
    final canUndo = !undone && t.type != QadaTxType.undo;
    final signed = t.type == QadaTxType.adjustment
        ? '${t.amount >= 0 ? '+' : ''}${t.amount}'
        : '${t.amount}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: undone ? scheme.outline : scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.reason,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration:
                        undone ? TextDecoration.lineThrough : null,
                    color: undone ? scheme.outline : null,
                  ),
                ),
                Text(
                  '${_prayerName(l10n, t.prayer)} · $signed · '
                  '${_dateLabel(t.at)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (t.note != null && t.note!.isNotEmpty)
                  Text(
                    t.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (canUndo)
            TextButton(
              onPressed: () async {
                final ok = await service.undoTransaction(t.id);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.qada2Undone)),
                  );
                }
              },
              child: Text(l10n.qada2Undo),
            ),
        ],
      ),
    );
  }

  Widget _backupSection(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showExport(context, l10n, service),
          icon: const Icon(Icons.ios_share_outlined),
          label: Text(l10n.qada2Export),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showImport(context, l10n, service),
          icon: const Icon(Icons.file_download_outlined),
          label: Text(l10n.qada2Import),
        ),
      ],
    );
  }

  Future<void> _showExport(
      BuildContext context, AppLocalizations l10n, QadaService service) async {
    final json = await service.exportJson();
    if (!context.mounted) return;
    final controller = TextEditingController(text: json);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.qada2ExportTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            readOnly: true,
            maxLines: 8,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.qadaCancel),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.qada2Copied)),
                );
                Navigator.of(ctx).pop();
              }
            },
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: Text(l10n.qada2Copy),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showImport(
      BuildContext context, AppLocalizations l10n, QadaService service) async {
    // The controller must stay alive until every dialog in this flow is
    // fully dismissed (including pop transitions): dispose in finally.
    final controller = TextEditingController();
    try {
      final pasted = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.qada2Import),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n.qada2ImportHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.qadaCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(l10n.qada2Import),
            ),
          ],
        ),
      );
      if (pasted == null || pasted.isEmpty || !context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.qada2ImportTitle),
          content: Text(l10n.qada2ImportBody),
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
      if (confirmed != true || !context.mounted) return;
      // Malformed input throws FormatException instead of returning warnings.
      List<String> warnings;
      try {
        warnings = await service.importJson(pasted);
      } on FormatException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.qada2ImportInvalid} (${e.message})')),
        );
        return;
      }
      if (!context.mounted) return;
      if (warnings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.qada2Imported)),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.qada2Imported),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $w'),
                    ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.qada2Confirm),
              ),
            ],
          ),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Widget _privacySection(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => _confirmDeleteAll(context, l10n, service),
      icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
      label: Text(
        l10n.qada2DeleteAll,
        style: TextStyle(color: scheme.error),
      ),
    );
  }

  /// Double confirmation before wiping all qada data.
  Future<void> _confirmDeleteAll(
      BuildContext context, AppLocalizations l10n, QadaService service) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.qada2DeleteAllTitle),
        content: Text(l10n.qada2DeleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.qadaCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.qada2DeleteAllConfirm),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.qada2DeleteAllTitle),
        content: Text(l10n.qada2DeleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.qadaCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.qada2DeleteAllConfirm),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;
    await service.deleteAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.qada2DeleteAllDone)),
    );
    Navigator.of(context).pop();
  }
}

/// Numeric target field (daily/weekly) with validation and save.
class _TargetField extends StatefulWidget {
  final String label;
  final int initial;
  final Future<void> Function(int) onSaved;

  const _TargetField({
    required this.label,
    required this.initial,
    required this.onSaved,
  });

  @override
  State<_TargetField> createState() => _TargetFieldState();
}

class _TargetFieldState extends State<_TargetField> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initial}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: _error,
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FilledButton(
            onPressed: () async {
              final v = int.tryParse(_controller.text.trim());
              if (v == null || v < 0) {
                setState(() => _error = l10n.qada2FieldErrorNumber);
                return;
              }
              setState(() => _error = null);
              await widget.onSaved(v);
            },
            child: Text(l10n.qadaSave),
          ),
        ),
      ],
    );
  }
}

/// Quick "log made-up prayers" form: prayer + count + note → complete().
class _LogMadeUpForm extends StatefulWidget {
  final QadaService service;

  const _LogMadeUpForm({required this.service});

  @override
  State<_LogMadeUpForm> createState() => _LogMadeUpFormState();
}

class _LogMadeUpFormState extends State<_LogMadeUpForm> {
  Prayer _prayer = Prayer.fajr;
  final _count = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _log() async {
    final l10n = AppLocalizations.of(context)!;
    final count = int.tryParse(_count.text.trim());
    if (count == null || count <= 0) {
      setState(() => _error = l10n.qada2FieldErrorNumber);
      return;
    }
    setState(() => _error = null);
    // The service throws StateError when count exceeds the outstanding
    // balance, so validate first and show a field error instead.
    final balance = widget.service.v2Counts()[_prayer] ?? 0;
    if (count > balance) {
      setState(() => _error = l10n.qada2CompleteTooMany(
          balance, _prayerName(l10n, _prayer)));
      return;
    }
    QadaTransaction tx;
    try {
      tx = await widget.service.complete(
        prayer: _prayer,
        count: count,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    } on StateError {
      // Completing more than the outstanding balance is rejected by the
      // service; surface it as a field error instead of crashing.
      if (!mounted) return;
      final balance = widget.service.v2Counts()[_prayer] ?? 0;
      setState(() => _error = l10n.qada2CompleteTooMany(
          balance, _prayerName(l10n, _prayer)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.qada2LoggedMadeUp(
            tx.amount, _prayerName(l10n, _prayer))),
      ),
    );
    _count.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<Prayer>(
          initialValue: _prayer,
          decoration: InputDecoration(labelText: l10n.qadaPickPrayer),
          items: [
            for (final p in loggableQadaPrayers)
              DropdownMenuItem(value: p, child: Text(_prayerName(l10n, p))),
          ],
          onChanged: (p) {
            if (p != null) setState(() => _prayer = p);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _count,
          decoration: InputDecoration(
            labelText: l10n.qada2Count,
            errorText: _error,
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: l10n.qada2AdjustNote),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _log,
          child: Text(l10n.qadaSave),
        ),
      ],
    );
  }
}

/// Reminder toggle: persists minutes-since-midnight via
/// [QadaService.setReminderMinutes]. Scheduling itself is wired by Worker E;
/// this toggle never marks anything as done.
class _ReminderSection extends StatefulWidget {
  final QadaService service;

  const _ReminderSection({required this.service});

  @override
  State<_ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends State<_ReminderSection> {
  Future<void> _pickTime(int? current) async {
    final l10n = AppLocalizations.of(context)!;
    final initial = current == null
        ? const TimeOfDay(hour: 21, minute: 0)
        : TimeOfDay(hour: current ~/ 60, minute: current % 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null || !mounted) return;
    await widget.service
        .setReminderMinutes(picked.hour * 60 + picked.minute);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.qada2ReminderSet(picked.format(context)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final minutes = widget.service.reminderMinutes();
    final on = minutes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            on
                ? '${l10n.qada2ReminderTime}: '
                    '${TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context)}'
                : l10n.qada2ReminderOff,
            style: theme.textTheme.bodyMedium,
          ),
          value: on,
          onChanged: (v) async {
            if (v) {
              await _pickTime(minutes);
            } else {
              await widget.service.setReminderMinutes(null);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.qada2ReminderOffDone)),
                );
              }
            }
          },
        ),
        if (on)
          TextButton(
            onPressed: () => _pickTime(minutes),
            child: Text(l10n.qada2ReminderTime),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline,
                size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.qada2ReminderNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
