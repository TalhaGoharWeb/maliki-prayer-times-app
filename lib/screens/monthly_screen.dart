import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/maliki_rules.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/band_texts.dart';
import 'package:malikiprayertimes/screens/date_labels.dart';
import 'package:malikiprayertimes/utils/hijri.dart';

/// Milestone 2 monthly view: a month grid of computed prayer times.
///
/// Each day cell shows the day number plus that day's Fajr and Maghrib.
/// Tapping a day opens a bottom sheet with all six computed times and the
/// Maliki two-tier informational bands for the day (clearly marked as
/// informational — never presented as adhan times). Days computed with the
/// high-latitude fallback are flagged with an "estimated" marker.
///
/// Gregorian month/weekday names come from Flutter's own
/// [MaterialLocalizations] so they follow the UI locale; Hijri month names
/// come from the ARB files.
class MonthlyScreen extends StatefulWidget {
  final Coordinates coordinates;
  final PrayerProfile profile;
  final Duration timeZoneOffset;

  /// The month to show first; defaults to the current month.
  final DateTime? initialMonth;

  const MonthlyScreen({
    super.key,
    required this.coordinates,
    required this.profile,
    required this.timeZoneOffset,
    this.initialMonth,
  });

  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen> {
  late int _year;
  late int _month;
  late List<PrayerTimes> _days; // index 0 == day 1

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _year = initial.year;
    _month = initial.month;
    _loadMonth();
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  void _loadMonth() {
    _days = List.generate(_daysInMonth, (i) {
      return calculatePrayerTimes(
        coordinates: widget.coordinates,
        date: DateTime(_year, _month, i + 1),
        timeZoneOffset: widget.timeZoneOffset,
        profile: widget.profile,
      );
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      var m = _month + delta;
      var y = _year;
      while (m < 1) {
        m += 12;
        y -= 1;
      }
      while (m > 12) {
        m -= 12;
        y += 1;
      }
      _month = m;
      _year = y;
      _loadMonth();
    });
  }

  /// Hijri label for the displayed Gregorian month, e.g. "Rajab 1447" or,
  /// when the month straddles two Hijri months, "Rajab–Sha'ban 1447".
  String _hijriLabel(AppLocalizations l10n) {
    final first = gregorianToHijri(DateTime(_year, _month, 1));
    final last = gregorianToHijri(DateTime(_year, _month, _daysInMonth));
    String part(HijriDate d) => '${hijriMonthName(l10n, d.month)} ${d.year}';
    if (first.month == last.month && first.year == last.year) {
      return part(first);
    }
    final firstPart = part(first);
    final lastPart =
        last.year == first.year ? hijriMonthName(l10n, last.month) : part(last);
    return '$firstPart–$lastPart';
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showDaySheet(int day) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final times = _days[day - 1];
    final bands = malikiPrayerBands(times);
    final gregorian = DateTime(_year, _month, day);
    final hijri = gregorianToHijri(gregorian);
    final rows = [
      (
        label: l10n.prayerFajr,
        arabic: 'الفجر',
        time: times.fajr,
        isMarker: false,
      ),
      (
        label: l10n.prayerSunrise,
        arabic: 'الشروق',
        time: times.sunrise,
        isMarker: true,
      ),
      (
        label: l10n.prayerDhuhr,
        arabic: 'الظهر',
        time: times.dhuhr,
        isMarker: false,
      ),
      (
        label: l10n.prayerAsr,
        arabic: 'العصر',
        time: times.asr,
        isMarker: false,
      ),
      (
        label: l10n.prayerMaghrib,
        arabic: 'المغرب',
        time: times.maghrib,
        isMarker: false,
      ),
      (
        label: l10n.prayerIsha,
        arabic: 'العشاء',
        time: times.isha,
        isMarker: false,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  materialL10n.formatFullDate(gregorian),
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  formatHijriDate(l10n, hijri),
                  style: theme.textTheme.bodySmall,
                ),
                if (times.highLatitudeFallback) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: theme.colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(l10n.highLatitudeNote),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ...rows.map((r) {
                  return ListTile(
                    title: Text('${r.label}  ${r.arabic}'),
                    trailing: Text(
                      _hhmm(r.time),
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle:
                        r.isMarker ? Text(l10n.timetableMarkerNote) : null,
                  );
                }),
                const SizedBox(height: 8),
                Text(l10n.bandsTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(l10n.bandsInfoNote, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                ...bands.map((b) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${bandDisplayName(l10n, b.arabicName)}  ${b.arabicName}',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          _bandLine(
                            theme,
                            l10n.preferredWord,
                            bandIkhtiyariText(l10n, b.arabicName, times),
                            b.ikhtiyariIsComputed,
                            l10n,
                          ),
                          const SizedBox(height: 2),
                          _bandLine(
                            theme,
                            l10n.necessityWord,
                            bandDaruriText(l10n, b.arabicName, times),
                            b.daruriIsComputed,
                            l10n,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _bandLine(
    ThemeData theme,
    String label,
    String text,
    bool isComputed,
    AppLocalizations l10n,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text('$label: $text', style: theme.textTheme.bodySmall),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text(
            isComputed ? l10n.computedChip : l10n.informationalChip,
            style: theme.textTheme.labelSmall,
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final leadingBlanks = DateTime(_year, _month, 1).weekday - 1;
    // Text-scaler multiplier (1.0 at the default size) used below to grow
    // the day cells taller, so large-text sizes never overflow the fixed
    // 7-column grid — the grid scrolls instead. Only the lower end is
    // clamped: at huge scales the cells keep growing with the text.
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, double.infinity);
    // MaterialLocalizations.narrowWeekdays starts on Sunday; the grid is
    // Monday-first.
    final weekdayHeaders = List.generate(
      7,
      (i) => materialL10n.narrowWeekdays[(i + 1) % 7],
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(materialL10n.formatMonthYear(DateTime(_year, _month))),
            Text(
              l10n.monthSubtitle(_hijriLabel(l10n)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.previousMonth,
            onPressed: () => _shiftMonth(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.nextMonth,
            onPressed: () => _shiftMonth(1),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mon–Sun header.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: weekdayHeaders
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              // Horizontal padding + spacing sized so a day cell is at
              // least 48dp wide on a 360dp phone: (360 - 12 - 12) / 7 = 48.
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 2,
                childAspectRatio: 0.78 / textScale,
              ),
              itemCount: leadingBlanks + _daysInMonth,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) {
                  return const SizedBox.shrink();
                }
                final day = index - leadingBlanks + 1;
                final times = _days[day - 1];
                // One clean announcement per day cell ("15 October 2026")
                // instead of the raw day-number + time fragments; the cell
                // is a button that opens the day's detail sheet.
                return Semantics(
                  button: true,
                  label: materialL10n.formatFullDate(
                    DateTime(_year, _month, day),
                  ),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _showDaySheet(day),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Shrink-to-fit: at very large text sizes on
                              // narrow phones the day number must not push
                              // the row (or the column) into overflow.
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '$day',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                              ),
                              if (times.highLatitudeFallback)
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Tooltip(
                                      message: l10n.estimatedTooltip,
                                      child: Text(
                                        l10n.estimatedMarker,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          // Single-line shrink-to-fit time labels: on a
                          // 7-column grid the labels must never wrap into
                          // extra lines (or overflow) at large text scales.
                          // Full-size times remain one tap away in the day
                          // detail sheet.
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.dayCellFajr(_hhmm(times.fajr)),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.dayCellMaghrib(_hhmm(times.maghrib)),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            // Capped so the footnote can never push the month grid into
            // overflow at very large text sizes; it scrolls internally
            // only when constrained, and is unaffected at normal sizes.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 3,
              ),
              child: SingleChildScrollView(
                child: Text(
                  l10n.hijriCalendarNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
