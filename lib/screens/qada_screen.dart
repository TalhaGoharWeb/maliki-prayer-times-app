import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/hayd_nifas_screen.dart';
import 'package:malikiprayertimes/screens/qada_modes_screen.dart';
import 'package:malikiprayertimes/screens/qada_planner_screen.dart';
import 'package:malikiprayertimes/services/qada_service.dart';
import 'package:malikiprayertimes/services/secure_store.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Missed-prayer (qada) tracker: log prayers that were missed, mark them
/// done as they are made up, and delete entries.
///
/// The dashboard header shows the total still outstanding (logged entries
/// plus balances set through the calculation modes). A progress bar, the
/// completed count, today's plan, and the projected finish date follow,
/// then navigation to the calculation modes, the planner & history, and
/// the Hayd & Nifas tracker. The per-prayer card, pending list, and
/// completed list keep the original entry-based behaviour.
class QadaScreen extends StatefulWidget {
  /// Injected secure storage backend, threaded through to the calculation
  /// modes, planner, and Hayd & Nifas screens (tests use the in-memory
  /// fake; production uses the platform secure storage).
  final SecureStore? secureStore;

  const QadaScreen({super.key, this.secureStore});

  @override
  State<QadaScreen> createState() => _QadaScreenState();
}

/// The five prayers that can be missed: sunrise is a timetable marker, not
/// a prayer to be made up.
const _loggablePrayers = [
  Prayer.fajr,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

class _QadaScreenState extends State<QadaScreen> {
  late Future<QadaService> _future;

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

  String _prayerName(AppLocalizations l10n, Prayer p) => switch (p) {
        Prayer.fajr => l10n.prayerFajr,
        Prayer.sunrise => l10n.prayerSunrise,
        Prayer.dhuhr => l10n.prayerDhuhr,
        Prayer.asr => l10n.prayerAsr,
        Prayer.maghrib => l10n.prayerMaghrib,
        Prayer.isha => l10n.prayerIsha,
      };

  /// Plain ISO date (2026-10-16): digits are standard 0-9 in every locale.
  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _openLogDialog(BuildContext context, QadaService service) async {
    final l10n = AppLocalizations.of(context)!;
    Prayer prayer = Prayer.fajr;
    DateTime date = DateTime.now();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.qadaLogMissed),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<Prayer>(
                initialValue: prayer,
                decoration: InputDecoration(labelText: l10n.qadaPickPrayer),
                items: [
                  for (final p in _loggablePrayers)
                    DropdownMenuItem(value: p, child: Text(_prayerName(l10n, p))),
                ],
                onChanged: (p) {
                  if (p != null) setDialogState(() => prayer = p);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.qadaPickDate}: ${_dateLabel(date)}',
                      style: Theme.of(ctx).textTheme.bodyLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.qadaPickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(now.year - 50),
                        lastDate: now,
                      );
                      if (picked != null) {
                        setDialogState(() => date = picked);
                      }
                    },
                  ),
                ],
              ),
            ],
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
      ),
    );
    if (result == true) {
      await service.logMissed(date: date, prayer: prayer);
    }
  }

  Future<void> _refreshAfterPush(Future<void> Function() open) async {
    await open();
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  void _openModes(BuildContext context) {
    _refreshAfterPush(() => Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                QadaModesScreen(secureStore: widget.secureStore)))
        .then((_) {}));
  }

  void _openPlanner(BuildContext context) {
    _refreshAfterPush(() => Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                QadaPlannerScreen(secureStore: widget.secureStore)))
        .then((_) {}));
  }

  void _openHaydNifas(BuildContext context) {
    _refreshAfterPush(() => Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                HaydNifasScreen(secureStore: widget.secureStore)))
        .then((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QadaService>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final service = snapshot.data!;
        return ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final l10n = AppLocalizations.of(context)!;
            final theme = Theme.of(context);
            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _headerCard(context, l10n, service),
                    const SizedBox(height: 16),
                    _progressCard(context, l10n, service),
                    const SizedBox(height: 16),
                    _statsRow(context, l10n, service),
                    const SizedBox(height: 16),
                    _navigationCard(context, l10n),
                    const SizedBox(height: 16),
                    _perPrayerCard(context, l10n, service),
                    const SizedBox(height: 16),
                    if (service.pending().isEmpty &&
                        service.completed().isEmpty)
                      _emptyState(context, l10n, theme)
                    else ...[
                      _pendingList(context, l10n, theme, service),
                      if (service.completed().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _completedSection(context, l10n, theme, service),
                      ],
                    ],
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    tooltip: l10n.qadaLogMissed,
                    onPressed: () => _openLogDialog(context, service),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Deep-green header card with the gold "total outstanding" headline and
  /// the Estimated badge when any balance comes from an estimation.
  Widget _headerCard(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = service.totalOutstanding();
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryFixed,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.history_outlined,
                      color: scheme.onTertiaryFixed, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.qadaTitle.toUpperCase(),
                        style: AppFonts.eyebrow(context).copyWith(
                          color: scheme.tertiaryFixed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.qadaTotalRemaining(total),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (service.hasEstimatedBalances()) ...[
              const SizedBox(height: 12),
              _estimatedBadge(context, l10n, scheme),
              const SizedBox(height: 8),
              Text(
                l10n.qada2EstimatedHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Icon + text badge (never color-only) marking estimated balances.
  Widget _estimatedBadge(
      BuildContext context, AppLocalizations l10n, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.tertiaryFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline,
              size: 14, color: scheme.onTertiaryFixed),
          const SizedBox(width: 4),
          Text(
            l10n.qada2EstimatedBadge,
            style: AppFonts.badgeLabel(context).copyWith(
              color: scheme.onTertiaryFixed,
            ),
          ),
        ],
      ),
    );
  }

  /// Completion progress: bar plus a text label (not color-only).
  Widget _progressCard(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = service.totalCompleted();
    final outstanding = service.totalOutstanding();
    final fraction = service.completionFraction();
    final percent = (fraction * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.qada2ProgressTitle.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
              semanticsLabel: l10n.qada2ProgressText(
                  done, done + outstanding, percent),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.qada2ProgressText(done, done + outstanding, percent),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Two small stat cards: made-up count, and today's plan / projected
  /// finish.
  Widget _statsRow(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    final daily = service.dailyTarget();
    final eta = service.projectedEndDate();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _statCard(
            context,
            icon: Icons.check_circle_outline,
            value: l10n.qada2MadeUp(service.totalCompleted()),
            caption: null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            context,
            icon: Icons.today_outlined,
            value: daily > 0
                ? l10n.qada2TodaysPlanValue(daily)
                : l10n.qada2NoTargetSet,
            caption: eta == null
                ? l10n.qada2NoEta
                : '${l10n.qada2ProjectedFinish}: '
                    '${l10n.qada2ProjectedFinishValue(_dateLabel(eta))}',
          ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context,
      {required IconData icon, required String value, String? caption}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleSmall),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Navigation to the three new screens. Every button works.
  Widget _navigationCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Column(
        children: [
          _navRow(
            context,
            icon: Icons.calculate_outlined,
            title: l10n.qada2OpenModes,
            subtitle: l10n.qada2OpenModesDesc,
            onTap: () => _openModes(context),
          ),
          Divider(height: 1, indent: 16, endIndent: 16,
              color: scheme.outlineVariant),
          _navRow(
            context,
            icon: Icons.event_note_outlined,
            title: l10n.qada2OpenPlanner,
            subtitle: l10n.qada2OpenPlannerDesc,
            onTap: () => _openPlanner(context),
          ),
          Divider(height: 1, indent: 16, endIndent: 16,
              color: scheme.outlineVariant),
          _navRow(
            context,
            icon: Icons.water_drop_outlined,
            title: l10n.qada2OpenHayd,
            subtitle: l10n.qada2OpenHaydDesc,
            onTap: () => _openHaydNifas(context),
          ),
        ],
      ),
    );
  }

  Widget _navRow(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: scheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// One row per prayer (sunrise excluded) with its remaining count.
  Widget _perPrayerCard(
      BuildContext context, AppLocalizations l10n, QadaService service) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = service.remainingByPrayer();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (int i = 0; i < _loggablePrayers.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant,
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _prayerName(l10n, _loggablePrayers[i]),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      l10n.qadaRemaining(counts[_loggablePrayers[i]] ?? 0),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.qadaEmpty,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _pendingList(BuildContext context, AppLocalizations l10n,
      ThemeData theme, QadaService service) {
    final pending = service.pending();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in pending)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prayerName(l10n, entry.prayer),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateLabel(entry.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => service.markDone(entry.id),
                    child: Text(l10n.qadaMarkDone),
                  ),
                  IconButton(
                    tooltip: l10n.qadaDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => service.deleteEntry(entry.id),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _completedSection(BuildContext context, AppLocalizations l10n,
      ThemeData theme, QadaService service) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.qadaCompleted.toUpperCase(),
          style: AppFonts.eyebrow(context).copyWith(
            color: scheme.secondary,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in service.completed())
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 20, color: scheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_prayerName(l10n, entry.prayer)} · '
                      '${_dateLabel(entry.date)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.qadaDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => service.deleteEntry(entry.id),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
