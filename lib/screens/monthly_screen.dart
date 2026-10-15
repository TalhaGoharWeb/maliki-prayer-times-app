import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/maliki_rules.dart';
import 'package:malikiprayertimes/utils/hijri.dart';

/// Milestone 2 monthly view: a month grid of computed prayer times.
///
/// Each day cell shows the day number plus that day's Fajr and Maghrib.
/// Tapping a day opens a bottom sheet with all six computed times and the
/// Maliki two-tier informational bands for the day (clearly marked as
/// informational — never presented as adhan times). Days computed with the
/// high-latitude fallback are flagged with an "estimated" marker.
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
  static const _gregorianMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

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
  String _hijriLabel() {
    final first = gregorianToHijri(DateTime(_year, _month, 1));
    final last = gregorianToHijri(DateTime(_year, _month, _daysInMonth));
    if (first.month == last.month && first.year == last.year) {
      return '${first.monthName} ${first.year}';
    }
    final firstPart = '${first.monthName} ${first.year}';
    final lastPart = last.year == first.year
        ? last.monthName
        : '${last.monthName} ${last.year}';
    return '$firstPart–$lastPart';
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showDaySheet(int day) {
    final times = _days[day - 1];
    final bands = malikiPrayerBands(times);
    final gregorian = DateTime(_year, _month, day);
    final hijri = gregorianToHijri(gregorian);
    final rows = [
      ('Fajr', 'الفجر', times.fajr, false),
      ('Sunrise', 'الشروق', times.sunrise, true),
      ('Dhuhr', 'الظهر', times.dhuhr, false),
      ('Asr', 'العصر', times.asr, false),
      ('Maghrib', 'المغرب', times.maghrib, false),
      ('Isha', 'العشاء', times.isha, false),
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
                  '${_weekdayLabels[gregorian.weekday - 1]}, '
                  '$day ${_gregorianMonths[_month - 1]} $_year',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '$hijri',
                  style: theme.textTheme.bodySmall,
                ),
                if (times.highLatitudeFallback) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: theme.colorScheme.tertiaryContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Some times on this day are estimates: the sun never '
                        'reaches the configured angles here, so a '
                        'high-latitude approximation was used.',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ...rows.map((r) {
                  return ListTile(
                    title: Text('${r.$1}  ${r.$2}'),
                    trailing: Text(
                      _hhmm(r.$3),
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: r.$4
                        ? const Text('Timetable marker — not a prayer')
                        : null,
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  'Preferred and necessity times (Maliki)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Informational bands describing the preferred and necessity '
                  'windows — they are not adhan times and never drive a '
                  'countdown.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                ...bands.map((b) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.prayerName}  ${b.arabicName}',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          _bandLine(
                            theme,
                            'Preferred',
                            b.ikhtiyariText,
                            b.ikhtiyariIsComputed,
                          ),
                          const SizedBox(height: 2),
                          _bandLine(
                            theme,
                            'Absolute end',
                            b.daruriText,
                            b.daruriIsComputed,
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
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '$label: $text',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text(
            isComputed ? 'computed' : 'informational',
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
    final leadingBlanks = DateTime(_year, _month, 1).weekday - 1;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_gregorianMonths[_month - 1]} $_year'),
            Text(
              '${_hijriLabel()} · Hijri dates: tabular calendar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: () => _shiftMonth(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: () => _shiftMonth(1),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mon–Sun header.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: _weekdayLabels
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
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.78,
              ),
              itemCount: leadingBlanks + _daysInMonth,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) {
                  return const SizedBox.shrink();
                }
                final day = index - leadingBlanks + 1;
                final times = _days[day - 1];
                return InkWell(
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
                            Text(
                              '$day',
                              style: theme.textTheme.titleSmall,
                            ),
                            if (times.highLatitudeFallback)
                              Tooltip(
                                message: 'Estimated times '
                                    '(high-latitude approximation)',
                                child: Text(
                                  'est.',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'F ${_hhmm(times.fajr)}',
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          'M ${_hhmm(times.maghrib)}',
                          style: theme.textTheme.labelSmall,
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
            child: Text(
              hijriCalendarNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
