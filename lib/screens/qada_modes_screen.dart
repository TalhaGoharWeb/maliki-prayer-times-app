import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/qada_models.dart';
import 'package:malikiprayertimes/services/qada_service.dart';
import 'package:malikiprayertimes/services/secure_store.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Calculation modes for qada balances: exact counts (A), estimation by
/// date ranges (B), a guided estimation wizard (C), and manual adjustment
/// (D). Estimations are always labelled as estimated and saved only after
/// an explicit confirmation.
class QadaModesScreen extends StatefulWidget {
  /// Injected secure storage backend (tests use the in-memory fake).
  final SecureStore? secureStore;

  const QadaModesScreen({super.key, this.secureStore});

  @override
  State<QadaModesScreen> createState() => _QadaModesScreenState();
}

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

class _QadaModesScreenState extends State<QadaModesScreen> {
  late final Future<QadaService> _future;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.qada2ModesTitle)),
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
                _ModeSection(
                  title: l10n.qada2ModeATitle,
                  description: l10n.qada2ModeADesc,
                  child: _ExactCountsForm(service: service),
                ),
                const SizedBox(height: 16),
                _ModeSection(
                  title: l10n.qada2ModeBTitle,
                  description: l10n.qada2ModeBDesc,
                  child: _PeriodsEstimator(service: service),
                ),
                const SizedBox(height: 16),
                _ModeSection(
                  title: l10n.qada2ModeCTitle,
                  description: l10n.qada2ModeCDesc,
                  child: _WizardEstimator(service: service),
                ),
                const SizedBox(height: 16),
                _ModeSection(
                  title: l10n.qada2ModeDTitle,
                  description: l10n.qada2ModeDDesc,
                  child: _ManualAdjust(service: service),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModeSection extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _ModeSection({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

int? _parseNonNegative(String text) {
  final v = int.tryParse(text.trim());
  if (v == null || v < 0) return null;
  return v;
}

/// Mode A: five numeric fields for exact per-prayer counts.
class _ExactCountsForm extends StatefulWidget {
  final QadaService service;

  const _ExactCountsForm({required this.service});

  @override
  State<_ExactCountsForm> createState() => _ExactCountsFormState();
}

class _ExactCountsFormState extends State<_ExactCountsForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<Prayer, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final current = widget.service.v2Counts();
    _controllers = {
      for (final p in loggableQadaPrayers)
        p: TextEditingController(text: '${current[p] ?? 0}'),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(AppLocalizations l10n, String? value) {
    if (_parseNonNegative(value ?? '') == null) {
      return l10n.qada2FieldErrorNumber;
    }
    return null;
  }

  int _total() {
    var sum = 0;
    for (final c in _controllers.values) {
      sum += _parseNonNegative(c.text) ?? 0;
    }
    return sum;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    final counts = {
      for (final p in loggableQadaPrayers) p: _parseNonNegative(_controllers[p]!.text)!,
    };
    final now = DateTime.now();
    await widget.service.setExactCounts(counts, 'user-entered ${_dateLabel(now)}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.qada2SavedOrigin)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in loggableQadaPrayers) ...[
            TextFormField(
              controller: _controllers[p],
              decoration: InputDecoration(labelText: _prayerName(l10n, p)),
              keyboardType: TextInputType.number,
              validator: (v) => _validate(l10n, v),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.qada2Total(_total()),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: Text(l10n.qadaSave),
          ),
        ],
      ),
    );
  }
}

/// One editable estimation period (Mode B).
class _PeriodDraft {
  DateTime start;
  DateTime end;
  final Map<Prayer, int> rates;

  _PeriodDraft({required this.start, required this.end})
      : rates = {for (final p in loggableQadaPrayers) p: 0};
}

/// Mode B: a list of date-range periods with per-prayer daily-rate
/// steppers, overlap validation, and a preview → confirm → save flow.
class _PeriodsEstimator extends StatefulWidget {
  final QadaService service;

  const _PeriodsEstimator({required this.service});

  @override
  State<_PeriodsEstimator> createState() => _PeriodsEstimatorState();
}

class _PeriodsEstimatorState extends State<_PeriodsEstimator> {
  final List<_PeriodDraft> _periods = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periods.add(_PeriodDraft(
      start: DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 30)),
      end: DateTime(now.year, now.month, now.day),
    ));
  }

  /// Returns an error string when the periods are invalid, else null.
  String? _validatePeriods(AppLocalizations l10n) {
    for (final p in _periods) {
      if (p.end.isBefore(p.start)) return l10n.qada2EndBeforeStart;
    }
    final sorted = List<_PeriodDraft>.from(_periods)
      ..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < sorted.length; i++) {
      if (!sorted[i].start.isAfter(sorted[i - 1].end)) {
        return l10n.qada2OverlapError;
      }
    }
    return null;
  }

  List<EstimationPeriod> _toPeriods() => [
        for (final d in _periods)
          EstimationPeriod(
            start: d.start,
            end: d.end,
            dailyRate: Map<Prayer, int>.from(d.rates),
          ),
      ];

  Future<void> _pickDate(_PeriodDraft draft, bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? draft.start : draft.end,
      firstDate: DateTime(now.year - 60),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          draft.start = picked;
        } else {
          draft.end = picked;
        }
      });
    }
  }

  Future<void> _preview() async {
    final l10n = AppLocalizations.of(context)!;
    final error = _validatePeriods(l10n);
    if (error != null) {
      setState(() {});
      return;
    }
    final result = await widget.service.previewEstimation(_toPeriods());
    if (!mounted) return;
    await showEstimationPreview(
      context: context,
      service: widget.service,
      periods: _toPeriods(),
      result: result,
      extraAssumptions: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = _validatePeriods(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _periods.length; i++) ...[
          _periodCard(context, l10n, i, _periods[i]),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () {
            final now = DateTime.now();
            setState(() {
              _periods.add(_PeriodDraft(
                start: DateTime(now.year, now.month, now.day)
                    .subtract(const Duration(days: 30)),
                end: DateTime(now.year, now.month, now.day),
              ));
            });
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.qada2AddPeriod),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: error == null ? _preview : null,
          child: Text(l10n.qada2Preview),
        ),
      ],
    );
  }

  Widget _periodCard(
      BuildContext context, AppLocalizations l10n, int index, _PeriodDraft draft) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.qada2Period(index + 1),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (_periods.length > 1)
                IconButton(
                  tooltip: l10n.qada2RemovePeriod,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _periods.removeAt(index)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(draft, true),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                      '${l10n.qada2StartDate}\n${_dateLabel(draft.start)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(draft, false),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text('${l10n.qada2EndDate}\n${_dateLabel(draft.end)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in loggableQadaPrayers)
            _rateStepper(context, l10n, draft, p),
        ],
      ),
    );
  }

  Widget _rateStepper(
      BuildContext context, AppLocalizations l10n, _PeriodDraft draft, Prayer p) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_prayerName(l10n, p)} — ${l10n.qada2DailyRate}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: draft.rates[p]! > 0
                ? () => setState(() => draft.rates[p] = draft.rates[p]! - 1)
                : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${draft.rates[p]}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: draft.rates[p]! < 5
                ? () => setState(() => draft.rates[p] = draft.rates[p]! + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

enum _WizardFrequency { daily, most, half, few }

/// Mode C: a simplified wizard converting approximate years/months/days
/// plus a frequency into a single [EstimationPeriod].
class _WizardEstimator extends StatefulWidget {
  final QadaService service;

  const _WizardEstimator({required this.service});

  @override
  State<_WizardEstimator> createState() => _WizardEstimatorState();
}

class _WizardEstimatorState extends State<_WizardEstimator> {
  final _years = TextEditingController(text: '0');
  final _months = TextEditingController(text: '0');
  final _days = TextEditingController(text: '0');
  bool _allFive = true;
  _WizardFrequency _frequency = _WizardFrequency.daily;
  String? _formError;

  @override
  void dispose() {
    _years.dispose();
    _months.dispose();
    _days.dispose();
    super.dispose();
  }

  int _freqRate() => switch (_frequency) {
        _WizardFrequency.daily => 5,
        _WizardFrequency.most => 4,
        _WizardFrequency.half => 3,
        _WizardFrequency.few => 2,
      };

  String _freqLabel(AppLocalizations l10n, _WizardFrequency f) => switch (f) {
        _WizardFrequency.daily => l10n.qada2WizardFreqDaily,
        _WizardFrequency.most => l10n.qada2WizardFreqMost,
        _WizardFrequency.half => l10n.qada2WizardFreqHalf,
        _WizardFrequency.few => l10n.qada2WizardFreqFew,
      };

  Future<void> _preview() async {
    final l10n = AppLocalizations.of(context)!;
    final years = _parseNonNegative(_years.text);
    final months = _parseNonNegative(_months.text);
    final days = _parseNonNegative(_days.text);
    if (years == null || months == null || days == null) {
      setState(() => _formError = l10n.qada2FieldErrorNumber);
      return;
    }
    final totalDays = years * 365 + months * 30 + days;
    if (totalDays <= 0) {
      setState(() => _formError = l10n.qada2FieldErrorNumber);
      return;
    }
    setState(() => _formError = null);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rate = _freqRate();
    final period = EstimationPeriod(
      start: today.subtract(Duration(days: totalDays - 1)),
      end: today,
      dailyRate: {for (final p in loggableQadaPrayers) p: rate},
      note: _allFive
          ? 'wizard: all five missed, ${_freqLabel(l10n, _frequency)}'
          : 'wizard: not all five missed (approximation), '
              '${_freqLabel(l10n, _frequency)}',
    );
    final result = await widget.service.previewEstimation([period]);
    if (!mounted) return;
    await showEstimationPreview(
      context: context,
      service: widget.service,
      periods: [period],
      result: result,
      extraAssumptions: _allFive
          ? const []
          : [
              'The "all five missed" toggle was off: the daily rate was '
                  'applied to each prayer as an approximation.'
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _years,
                decoration: InputDecoration(labelText: l10n.qada2WizardYears),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _months,
                decoration: InputDecoration(labelText: l10n.qada2WizardMonths),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _days,
                decoration: InputDecoration(labelText: l10n.qada2WizardDays),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.qada2WizardAllFive,
              style: theme.textTheme.bodyMedium),
          value: _allFive,
          onChanged: (v) => setState(() => _allFive = v),
        ),
        DropdownButtonFormField<_WizardFrequency>(
          initialValue: _frequency,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.qada2WizardFrequency),
          items: [
            for (final f in _WizardFrequency.values)
              DropdownMenuItem(value: f, child: Text(_freqLabel(l10n, f))),
          ],
          onChanged: (f) {
            if (f != null) setState(() => _frequency = f);
          },
        ),
        const SizedBox(height: 8),
        Text(
          l10n.qada2WizardDisclaimer,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(
            _formError!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _preview,
          child: Text(l10n.qada2Preview),
        ),
      ],
    );
  }
}

/// Mode D: manual per-prayer adjustment with a required reason.
class _ManualAdjust extends StatefulWidget {
  final QadaService service;

  const _ManualAdjust({required this.service});

  @override
  State<_ManualAdjust> createState() => _ManualAdjustState();
}

class _ManualAdjustState extends State<_ManualAdjust> {
  Prayer _prayer = Prayer.fajr;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _note = TextEditingController();
  String? _amountError;
  String? _reasonError;
  String? _result;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context)!;
    final delta = int.tryParse(_amount.text.trim());
    setState(() {
      _amountError = delta == null
          ? l10n.qada2FieldErrorNumber
          : (delta == 0 ? l10n.qada2AdjustNonZero : null);
      _reasonError =
          _reason.text.trim().isEmpty ? l10n.qada2AdjustReasonRequired : null;
      _result = null;
    });
    if (delta == null || delta == 0 || _reason.text.trim().isEmpty) return;
    // The service throws StateError when a negative delta would take the
    // balance below zero; validate first and show a field error instead.
    if (delta < 0) {
      final balance = widget.service.v2Counts()[_prayer] ?? 0;
      if (-delta > balance) {
        setState(() => _amountError = l10n.qada2AdjustTooMuch(
            _prayerName(l10n, _prayer), balance));
        return;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.qada2AdjustConfirmTitle),
        content: Text(l10n.qada2AdjustConfirmBody(
          '${delta >= 0 ? '+' : ''}$delta',
          _prayerName(l10n, _prayer),
          _reason.text.trim(),
        )),
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
    await widget.service.adjust(
      prayer: _prayer,
      delta: delta,
      reason: _reason.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (!mounted) return;
    final balance = widget.service.v2Counts()[_prayer] ?? 0;
    setState(() {
      _result =
          l10n.qada2AdjustResult(_prayerName(l10n, _prayer), balance);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.qada2Adjusted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
          controller: _amount,
          decoration: InputDecoration(
            labelText: l10n.qada2AdjustAmount,
            errorText: _amountError,
          ),
          keyboardType:
              const TextInputType.numberWithOptions(signed: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reason,
          decoration: InputDecoration(
            labelText: l10n.qada2AdjustReason,
            errorText: _reasonError,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: l10n.qada2AdjustNote),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          Text(
            _result!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _apply,
          child: Text(l10n.qada2Confirm),
        ),
      ],
    );
  }
}

/// Shared preview → review → save flow for estimations (Modes B and C).
///
/// Shows the assumptions, warnings, and the low–high range with an
/// "Estimated" label, then asks for an explicit confirmation before
/// saving anything to the balances.
Future<void> showEstimationPreview({
  required BuildContext context,
  required QadaService service,
  required List<EstimationPeriod> periods,
  required EstimationResult result,
  required List<String> extraAssumptions,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final total = result.estimated.values.fold(0, (a, b) => a + b);
  final low = result.low.values.fold(0, (a, b) => a + b);
  final high = result.high.values.fold(0, (a, b) => a + b);

  final save = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.qada2Preview),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.qada2EstimatedLabel,
                    style: AppFonts.badgeLabel(context).copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final p in loggableQadaPrayers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_prayerName(l10n, p),
                          style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      '${result.low[p] ?? 0} – ${result.high[p] ?? 0}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              l10n.qada2EstimatedRange(low, high),
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.qada2PreviewAssumptions.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            for (final a in [...result.assumptions, ...extraAssumptions])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $a', style: theme.textTheme.bodySmall),
              ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.qada2PreviewWarnings.toUpperCase(),
                style: AppFonts.eyebrow(context).copyWith(
                  color: scheme.error,
                ),
              ),
              const SizedBox(height: 4),
              for (final w in result.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $w',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.qadaCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.qadaSave),
        ),
      ],
    ),
  );
  if (save != true || !context.mounted) return;

  // Review-before-save: explicit confirmation dialog.
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.qada2ConfirmSaveTitle),
      content: Text(l10n.qada2ConfirmSaveBody(total)),
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
  await service.saveEstimation(result, periods);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.qada2EstimateSaved)),
  );
}
