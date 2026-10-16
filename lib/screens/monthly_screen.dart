import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/maliki_rules.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/band_texts.dart';
import 'package:malikiprayertimes/screens/date_labels.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/services/timetable_share.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/hijri.dart';
import 'package:malikiprayertimes/utils/prayer_names.dart';
import 'package:malikiprayertimes/widgets/adjustment_chip.dart';

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

  /// Settings supply the per-prayer adjustments (ihtiyat) applied to the
  /// displayed times, matching the home timetable.
  final SettingsService settings;

  /// The month to show first; defaults to the current month.
  final DateTime? initialMonth;

  const MonthlyScreen({
    super.key,
    required this.coordinates,
    required this.profile,
    required this.timeZoneOffset,
    required this.settings,
    this.initialMonth,
  });

  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen> {
  late int _year;
  late int _month;
  late List<PrayerTimes> _days; // index 0 == day 1

  /// Snapshot of the per-prayer adjustments the grid was last built with.
  /// The map getter returns a fresh copy each call, so identity comparison
  /// can't detect a change — [didUpdateWidget] deep-compares against this.
  late Map<Prayer, int> _appliedAdjustments;

  /// Keys the [RepaintBoundary] around the timetable grid so the grid can
  /// be captured to a PNG for sharing.
  final _timetableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _year = initial.year;
    _month = initial.month;
    _loadMonth();
  }

  @override
  void didUpdateWidget(covariant MonthlyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recompute when the profile, the zone offset, or the per-prayer
    // adjustments change while the screen is open. The guard prevents
    // reload loops; profile comparison is by identity because profiles are
    // immutable engine constants (a toggled ihtiyat yields a new instance).
    if (widget.profile != oldWidget.profile ||
        widget.timeZoneOffset != oldWidget.timeZoneOffset ||
        !_adjustmentsEqual(_appliedAdjustments, widget.settings.adjustments)) {
      setState(_loadMonth);
    }
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  void _loadMonth() {
    _days = List.generate(_daysInMonth, (i) {
      final date = DateTime(_year, _month, i + 1);
      return calculatePrayerTimes(
        coordinates: widget.coordinates,
        date: date,
        // Per-date device offset: one offset for the whole month shifts
        // displayed times by an hour across DST transitions.
        timeZoneOffset: _offsetForDate(date),
        profile: widget.profile,
      );
    });
    _appliedAdjustments = Map.of(widget.settings.adjustments);
  }

  /// The device UTC offset for [date], falling back to the
  /// constructor-supplied offset when derivation is unavailable.
  Duration _offsetForDate(DateTime date) {
    try {
      return date.timeZoneOffset;
    } catch (_) {
      return widget.timeZoneOffset;
    }
  }

  /// The user-visible time for [prayer]: the raw engine time shifted by the
  /// configured per-prayer adjustment (ihtiyat), matching the home
  /// timetable. The two-tier band texts keep the raw engine times, also
  /// matching home.
  DateTime _adjusted(Prayer prayer, DateTime computed) =>
      widget.settings.adjustedTime(prayer, computed);

  /// True when [prayer]'s displayed time carries a manual or ihtiyat
  /// adjustment — the "never silently adjust" requirement (program
  /// Part A §2.3).
  bool _hasAdjustment(Prayer prayer) {
    if ((widget.settings.adjustments[prayer] ?? 0) != 0) return true;
    final ihtiyat = switch (prayer) {
      Prayer.dhuhr => widget.profile.dhuhrIhtiyatMinutes,
      Prayer.maghrib => widget.profile.maghribIhtiyatMinutes,
      _ => 0,
    };
    return ihtiyat > 0;
  }

  /// Adjustment chips disclosing what was added to [prayer]'s displayed
  /// time. Empty when nothing applies — zero adjustments never render.
  List<AdjustmentChip> _adjustmentChips(Prayer prayer) {
    final chips = <AdjustmentChip>[];
    final manual = widget.settings.adjustments[prayer] ?? 0;
    if (manual != 0) {
      chips.add(AdjustmentChip(minutes: manual, kind: AdjustmentKind.manual));
    }
    final ihtiyat = switch (prayer) {
      Prayer.dhuhr => widget.profile.dhuhrIhtiyatMinutes,
      Prayer.maghrib => widget.profile.maghribIhtiyatMinutes,
      _ => 0,
    };
    if (ihtiyat > 0) {
      chips.add(AdjustmentChip(minutes: ihtiyat, kind: AdjustmentKind.ihtiyat));
    }
    return chips;
  }

  /// Deep equality for per-prayer adjustment maps (the getter returns a
  /// fresh copy each call, so identity comparison never works).
  static bool _adjustmentsEqual(Map<Prayer, int> a, Map<Prayer, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
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
      (
        prayer: Prayer.fajr,
        label: l10n.prayerFajr,
        arabic: 'الفجر',
        time: _adjusted(Prayer.fajr, times.fajr)
      ),
      (
        prayer: Prayer.sunrise,
        label: l10n.prayerSunrise,
        arabic: 'الشروق',
        time: _adjusted(Prayer.sunrise, times.sunrise)
      ),
      (
        prayer: Prayer.dhuhr,
        label: l10n.prayerDhuhr,
        arabic: 'الظهر',
        time: _adjusted(Prayer.dhuhr, times.dhuhr)
      ),
      (
        prayer: Prayer.asr,
        label: l10n.prayerAsr,
        arabic: 'العصر',
        time: _adjusted(Prayer.asr, times.asr)
      ),
      (
        prayer: Prayer.maghrib,
        label: l10n.prayerMaghrib,
        arabic: 'المغرب',
        time: _adjusted(Prayer.maghrib, times.maghrib)
      ),
      (
        prayer: Prayer.isha,
        label: l10n.prayerIsha,
        arabic: 'العشاء',
        time: _adjusted(Prayer.isha, times.isha)
      ),
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
                // Hijri date, digit-localized like the home hero, with the
                // tabular-approximation qualifier (I-07, I-08).
                Text(
                  '${localizeDigits(formatHijriDate(l10n, hijri), lang)} · ${l10n.hijriApproxQualifier}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
                if (times.highLatitudeFallback) ...[
                  const SizedBox(height: 12),
                  _EstimateNotice(text: l10n.highLatitudeNote),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 12),
                ...rows.map((r) {
                  final isMarker = r.label == l10n.prayerSunrise;
                  // Adjustment chips disclose what was added to this row's
                  // displayed time (program Part A §2.3); empty when none.
                  final chips = _adjustmentChips(r.prayer);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                                    if (!omitArabicCompanion(context)) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        r.arabic,
                                        style: TextStyle(
                                          fontFamily: AppFonts.arabic,
                                          fontSize: 14,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                localizeDigits(_hhmm(r.time), lang),
                                style: AppFonts.timeLabel(context),
                              ),
                              if (chips.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.end,
                                  children: chips,
                                ),
                              ],
                            ],
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
                        // Screen readers get the un-uppercased string: all
                        // caps can degrade pronunciation in en/fr.
                        semanticsLabel: l10n.bandsTitle,
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pairedPrayerName(context, bandDisplayName(l10n, b.arabicName), b.arabicName),
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
    // The "PREFERRED"/"NECESSITY" prefixes render uppercased; expose the
    // whole line to screen readers with the un-uppercased label so the
    // announcement stays natural in en/fr. The chip's status (computed vs
    // informational) is folded into the label because the wrapped row is
    // excluded from the semantics tree.
    final chipText = isComputed ? l10n.computedChip : l10n.informationalChip;
    return Semantics(
      label: '$label: $text ($chipText)',
      excludeSemantics: true,
      child: Row(
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
            text: chipText,
            background: scheme.surfaceContainerHigh,
            foreground: scheme.onSurfaceVariant,
          ),
        ],
      ),
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
        // Month header card: navigator + Hijri subtitle + standard chip.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Card(
            color: scheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 14),
              child: Column(
                children: [
                  Row(
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
                              materialL10n
                                  .formatMonthYear(DateTime(_year, _month)),
                              style: theme.textTheme.displaySmall,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _hijriLabel(l10n),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.secondary,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: l10n.nextMonth,
                        onPressed: () => _shiftMonth(1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        tooltip: l10n.shareTimetable,
                        onPressed: () async {
                          final png = await renderTimetablePng(_timetableKey);
                          if (png != null && context.mounted) {
                            await shareTimetable(
                              pngBytes: png,
                              fileName: 'timetable.png',
                              subject: l10n.shareSubject,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Standard-calculation chip.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calculate,
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
                ],
              ),
            ),
          ),
        ),
        // Mon–Sun strip.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
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
        ),
        Expanded(
          child: RepaintBoundary(
            key: _timetableKey,
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
                // Today gets the filled primary treatment so it is
                // unmistakable; other days stay quiet.
                final dayFg = isToday ? scheme.onPrimary : scheme.onSurface;
                final timeFg =
                    isToday ? scheme.onPrimary : scheme.onSurfaceVariant;
                // The estimated marker sits on the plain day-cell surface, so
                // it needs the darker gold-brown onTertiaryFixedVariant
                // (#5B4301, ~8:1) — onTertiaryContainer (#CEAC63) was only
                // 2.06:1 and failed WCAG AA.
                final markerFg =
                    isToday ? scheme.onPrimary : scheme.onTertiaryFixedVariant;
                // One clean announcement per day cell ("15 October 2026")
                // instead of the raw day-number + time fragments; the cell
                // is a button that opens the day's detail sheet. When either
                // displayed time carries an adjustment, the announcement says
                // so and a subtle dot marks the adjusted line — a marker,
                // not clutter (program Part A §2.3).
                final fajrAdjusted = _hasAdjustment(Prayer.fajr);
                final maghribAdjusted = _hasAdjustment(Prayer.maghrib);
                final cellLabel = materialL10n.formatFullDate(
                  DateTime(_year, _month, day),
                );
                return Semantics(
                  button: true,
                  label: (fajrAdjusted || maghribAdjusted)
                      ? '$cellLabel, ${l10n.adjustmentMarkerSemantics}'
                      : cellLabel,
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
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  localizeDigits('$day', lang),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: dayFg,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            if (times.highLatitudeFallback)
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Tooltip(
                                    message: l10n.estimatedTooltip,
                                    child: Text(
                                      l10n.estimatedMarker,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: markerFg,
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
                          text: l10n.dayCellFajr(localizeDigits(
                              _hhmm(_adjusted(Prayer.fajr, times.fajr)), lang)),
                          color: timeFg,
                          adjusted: fajrAdjusted,
                          markerTooltip: l10n.adjustmentMarkerSemantics,
                        ),
                        _CellTime(
                          text: l10n.dayCellMaghrib(localizeDigits(
                              _hhmm(_adjusted(Prayer.maghrib, times.maghrib)),
                              lang)),
                          color: timeFg,
                          adjusted: maghribAdjusted,
                          markerTooltip: l10n.adjustmentMarkerSemantics,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
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
    return Material(
      color: isToday ? scheme.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: child,
        ),
      ),
    );
  }
}

/// Single-line shrink-to-fit time label inside a day cell, with an optional
/// subtle dot marking an adjusted time (program Part A §2.3). The dot is
/// never the only disclosure: the day sheet shows the full chips, the cell
/// tooltip names it, and the cell's semantics label announces it.
class _CellTime extends StatelessWidget {
  const _CellTime({
    required this.text,
    required this.color,
    this.adjusted = false,
    this.markerTooltip,
  });

  final String text;
  final Color color;

  /// Whether the displayed time carries a manual or ihtiyat adjustment.
  final bool adjusted;

  /// Tooltip/semantics text for the marker; used only when [adjusted].
  final String? markerTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color),
        ),
      ),
    );
    if (!adjusted) return label;
    // Same dark gold-brown as the estimated marker (~8:1 on the cell
    // surface — the lighter gold failed WCAG AA there).
    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 4),
        Tooltip(
          message: markerTooltip ?? '',
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.onTertiaryFixedVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
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
