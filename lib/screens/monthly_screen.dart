import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/maliki_rules.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/band_texts.dart';
import 'package:malikiprayertimes/screens/date_labels.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/hijri.dart';

/// Monthly view: a month grid of computed prayer times.
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
    final lang = Localizations.localeOf(context).languageCode;
    final rows = [
      (label: l10n.prayerFajr, arabic: 'الفجر', time: times.fajr),
      (label: l10n.prayerSunrise, arabic: 'الشروق', time: times.sunrise),
      (label: l10n.prayerDhuhr, arabic: 'الظهر', time: times.dhuhr),
      (label: l10n.prayerAsr, arabic: 'العصر', time: times.asr),
      (label: l10n.prayerMaghrib, arabic: 'المغرب', time: times.maghrib),
      (label: l10n.prayerIsha, arabic: 'العشاء', time: times.isha),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  materialL10n.formatFullDate(gregorian),
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  formatHijriDate(l10n, hijri),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
                if (times.highLatitudeFallback) ...[
                  const SizedBox(height: 12),
                  _EstimateNotice(text: l10n.highLatitudeNote),
                ],
                const SizedBox(height: 12),
                ...rows.map((r) {
                  final isMarker = r.label == l10n.prayerSunrise;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        r.label,
                                        style: theme.textTheme.titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      r.arabic,
                                      style: const TextStyle(
                                        fontFamily: AppFonts.arabic,
                                        fontSize: 14,
                                        color: Color(0xFF404944),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isMarker)
                                  Text(
                                    l10n.timetableMarkerNote,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            localizeDigits(_hhmm(r.time), lang),
                            style: AppFonts.timeLabel(context),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.auto_stories,
                        size: 18, color: scheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.bandsTitle.toUpperCase(),
                        style: AppFonts.eyebrow(context).copyWith(
                          color: scheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.bandsInfoNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...bands.map((b) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${bandDisplayName(l10n, b.arabicName)}  ${b.arabicName}',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              _MiniChip(
                                text: l10n.informationalChip,
                                background: scheme.secondaryContainer,
                                foreground: scheme.onSecondaryContainer,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _bandLine(
                            theme,
                            l10n.preferredWord,
                            bandIkhtiyariText(l10n, b.arabicName, times),
                            b.ikhtiyariIsComputed,
                            l10n,
                          ),
                          const SizedBox(height: 6),
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
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: '${label.toUpperCase()}  ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _MiniChip(
          text: isComputed ? l10n.computedChip : l10n.informationalChip,
          background: scheme.surfaceContainerHigh,
          foreground: scheme.onSurfaceVariant,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
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

    return Column(
      children: [
        // Month navigator header.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.previousMonth,
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      materialL10n.formatMonthYear(DateTime(_year, _month)),
                      style: theme.textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hijriLabel(l10n),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.nextMonth,
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
        ),
        // Verified-calculation chip.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified,
                    size: 14, color: scheme.onSecondaryContainer),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l10n.standardApplied,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                          color: scheme.secondary,
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
            // least 48dp wide on a 360dp phone:
            // (360 - 6 - 6 - 6*2) / 7 = 48.
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 2,
              childAspectRatio: 0.72 / textScale,
            ),
            itemCount: leadingBlanks + _daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }
              final day = index - leadingBlanks + 1;
              final times = _days[day - 1];
              final today = DateTime.now();
              final isToday = today.year == _year &&
                  today.month == _month &&
                  today.day == day;
              final dayFg = isToday ? scheme.onPrimary : scheme.onSurface;
              final timeFg = isToday
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant;
              // One clean announcement per day cell ("15 October 2026")
              // instead of the raw day-number + time fragments; the cell
              // is a button that opens the day's detail sheet.
              return Semantics(
                button: true,
                label: materialL10n.formatFullDate(
                  DateTime(_year, _month, day),
                ),
                excludeSemantics: true,
                child: _DayCellMaterial(
                  isToday: isToday,
                  scheme: scheme,
                  onTap: () => _showDaySheet(day),
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
                                localizeDigits('$day', lang),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: dayFg,
                                ),
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
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onTertiaryContainer,
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
                      _CellTime(
                        text: l10n.dayCellFajr(
                            localizeDigits(_hhmm(times.fajr), lang)),
                        color: timeFg,
                      ),
                      _CellTime(
                        text: l10n.dayCellMaghrib(
                            localizeDigits(_hhmm(times.maghrib), lang)),
                        color: timeFg,
                      ),
                    ],
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
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Material-backed tappable day cell: provides the Material ancestor
/// InkWell needs (the screen itself has no Scaffold), with the
/// today-highlight and rounded border baked in.
class _DayCellMaterial extends StatelessWidget {
  const _DayCellMaterial({
    required this.isToday,
    required this.scheme,
    required this.onTap,
    required this.child,
  });

  final bool isToday;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final border = isToday
        ? scheme.primaryContainer
        : scheme.outlineVariant;
    return Material(
      color: isToday ? scheme.primaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: child,
        ),
      ),
    );
  }
}

/// Single-line shrink-to-fit time label inside a day cell.
class _CellTime extends StatelessWidget {
  const _CellTime({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color),
        ),
      ),
    );
  }
}

/// Tiny rounded chip for computed/informational markers.
class _MiniChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _MiniChip({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppFonts.badgeLabel(context).copyWith(color: foreground),
      ),
    );
  }
}

/// Tertiary-toned notice for high-latitude estimation.
class _EstimateNotice extends StatelessWidget {
  final String text;

  const _EstimateNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryFixed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 16, color: scheme.onTertiaryFixed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryFixed,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
