import 'dart:async';

import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/maliki_rules.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/band_texts.dart';
import 'package:malikiprayertimes/screens/date_labels.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/services/travel_service.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/hijri.dart';
import 'package:malikiprayertimes/utils/prayer_names.dart';
import 'package:malikiprayertimes/widgets/adjustment_chip.dart';
import 'package:malikiprayertimes/widgets/travel_banner.dart';
import 'package:malikiprayertimes/widgets/why_time_sheet.dart';

/// Home tab: today's timetable with a next-prayer hero, the Maliki two-tier
/// bands, and the calculation-profile status.
///
/// Time frame: every computation here uses `DateTime.now().timeZoneOffset`
/// (the device timezone). Manual far-away locations are therefore
/// approximate — a documented limitation.
///
/// The displayed prayer times are the engine times passed through
/// [SettingsService.adjustedTime], so any ihtiyat (precautionary) adjustment
/// configured in the profile is reflected in the timetable and the countdown.
class HomeScreen extends StatefulWidget {
  final SettingsService settings;
  final LocationService location;

  /// Travel mode (Maliki qasr) state for the travel banner. Null in widget
  /// tests; when null the banner stays hidden.
  final TravelService? travel;

  const HomeScreen(
      {super.key,
      required this.settings,
      required this.location,
      this.travel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _civilDay; // wall-clock day the times were computed for
  PrayerTimes? _times; // raw engine output (pre-adjustment)
  List<PrayerBand>? _bands;
  late Timer _timer;
  DateTime _now = _frameNow();

  /// Wall-clock "now" in the same frame as the engine output:
  /// `DateTime.now().toUtc().add(offset)`.
  static DateTime _frameNow() {
    final offset = DateTime.now().timeZoneOffset;
    return DateTime.now().toUtc().add(offset);
  }

  Duration get _offset => DateTime.now().timeZoneOffset;

  /// Device UTC offset for [date], falling back to today's offset when
  /// derivation is unavailable.
  Duration _offsetForDate(DateTime date) {
    try {
      return DateTime(date.year, date.month, date.day).timeZoneOffset;
    } catch (_) {
      return _offset;
    }
  }

  Coordinates? get _coordinates {
    final loc = widget.location.current;
    return loc == null ? null : Coordinates(loc.latitude, loc.longitude);
  }

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onServicesChanged);
    widget.location.addListener(_onServicesChanged);
    _computeForToday();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = _frameNow();
      setState(() {
        _now = now;
        // Recompute the timetable when the civil day rolls over.
        if (_civilDay != null &&
            (now.year != _civilDay!.year ||
                now.month != _civilDay!.month ||
                now.day != _civilDay!.day)) {
          _computeForToday();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.settings.removeListener(_onServicesChanged);
    widget.location.removeListener(_onServicesChanged);
    super.dispose();
  }

  void _onServicesChanged() {
    if (!mounted) return;
    _computeForToday();
    setState(() {});
  }

  void _computeForToday() {
    final coords = _coordinates;
    if (coords == null) {
      _civilDay = null;
      _times = null;
      _bands = null;
      return;
    }
    final now = _frameNow();
    _civilDay = DateTime(now.year, now.month, now.day);
    _times = calculatePrayerTimes(
      coordinates: coords,
      date: _civilDay!,
      timeZoneOffset: _offset,
      profile: widget.settings.effectiveProfile,
    );
    _bands = malikiPrayerBands(_times!);
  }

  void _openLocationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationScreen(locationService: widget.location),
      ),
    );
  }

  /// The next prayer's wall-clock time in the same frame as [_times],
  /// after [SettingsService.adjustedTime] is applied. When nothing remains
  /// today, Fajr belongs to tomorrow's timetable.
  ({Prayer prayer, DateTime time}) _nextPrayer() {
    final times = _times!;
    final settings = widget.settings;
    for (final p in const [
      Prayer.fajr,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ]) {
      final t = settings.adjustedTime(p, times.timeFor(p));
      if (t.isAfter(_now)) return (prayer: p, time: t);
    }
    final tomorrowDate = _civilDay!.add(const Duration(days: 1));
    final tomorrow = calculatePrayerTimes(
      coordinates: _coordinates!,
      date: tomorrowDate,
      // Per-date offset: tomorrow's UTC offset can differ from today's
      // across a DST transition.
      timeZoneOffset: _offsetForDate(tomorrowDate),
      profile: settings.effectiveProfile,
    );
    return (
      prayer: Prayer.fajr,
      time: settings.adjustedTime(Prayer.fajr, tomorrow.fajr),
    );
  }

  /// Timetable rows in display order with template icons and descriptors.
  ///
  /// The Maliki two-tier bands call this prayer "Subh"; the timetable keeps
  /// the app's existing "Fajr" label and the bands keep "Subh", per the
  /// established per-screen convention.
  List<_PrayerRow> _prayerRows(AppLocalizations l10n) {
    return [
      _PrayerRow(Prayer.fajr, l10n.prayerFajr, 'الفجر', Icons.bedtime,
          l10n.prayerDescFajr),
      _PrayerRow(Prayer.sunrise, l10n.prayerSunrise, 'الشروق', Icons.wb_sunny,
          l10n.timetableMarkerNote,
          isMarker: true),
      _PrayerRow(Prayer.dhuhr, l10n.prayerDhuhr, 'الظهر', Icons.sunny,
          l10n.prayerDescDhuhr),
      _PrayerRow(Prayer.asr, l10n.prayerAsr, 'العصر', Icons.wb_twilight,
          l10n.prayerDescAsr),
      _PrayerRow(Prayer.maghrib, l10n.prayerMaghrib, 'المغرب', Icons.nights_stay,
          l10n.prayerDescMaghrib),
      _PrayerRow(Prayer.isha, l10n.prayerIsha, 'العشاء', Icons.dark_mode,
          l10n.prayerDescIsha),
    ];
  }

  String _prayerLabel(AppLocalizations l10n, Prayer p) =>
      _prayerRows(l10n).firstWhere((r) => r.prayer == p).label;

  /// Adjustment chips disclosing what was added to [prayer]'s displayed
  /// time: the user's manual offset and/or the profile's ihtiyat minutes.
  /// Empty when nothing applies — zero adjustments never render a chip, so
  /// no silent adjustment is possible in code without a visible chip.
  List<AdjustmentChip> _adjustmentChips(Prayer prayer) {
    final chips = <AdjustmentChip>[];
    final manual = widget.settings.adjustments[prayer] ?? 0;
    if (manual != 0) {
      chips.add(
          AdjustmentChip(minutes: manual, kind: AdjustmentKind.manual));
    }
    // The ihtiyat minutes come from the effective profile the times were
    // actually computed with, so a disabled ihtiyat yields 0 and no chip.
    final ihtiyat = switch (prayer) {
      Prayer.dhuhr => _times!.profile.dhuhrIhtiyatMinutes,
      Prayer.maghrib => _times!.profile.maghribIhtiyatMinutes,
      _ => 0,
    };
    if (ihtiyat > 0) {
      chips.add(
          AdjustmentChip(minutes: ihtiyat, kind: AdjustmentKind.ihtiyat));
    }
    return chips;
  }

  String _prayerArabic(Prayer p) => switch (p) {
        Prayer.fajr => 'الفجر',
        Prayer.sunrise => 'الشروق',
        Prayer.dhuhr => 'الظهر',
        Prayer.asr => 'العصر',
        Prayer.maghrib => 'المغرب',
        Prayer.isha => 'العشاء',
      };

  @override
  Widget build(BuildContext context) {
    return _times == null ? _locationPrompt() : _timetable();
  }

  /// Shown when no location is set yet: a prompt card that navigates to the
  /// location picker. No timetable is rendered.
  Widget _locationPrompt() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.add_location_alt,
                    color: scheme.onSecondaryContainer, size: 26),
              ),
              const SizedBox(height: 16),
              Text(l10n.chooseLocationTitle,
                  style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(l10n.homePromptBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openLocationScreen,
                icon: const Icon(Icons.near_me),
                label: Text(l10n.setLocation),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timetable() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final times = _times!;
    final bands = _bands!;
    final settings = widget.settings;
    final next = _nextPrayer();
    final hijri = gregorianToHijri(_civilDay!);
    final rows = _prayerRows(l10n);
    final lang = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Prominent location header: unmistakable current horizon, taps
        // through to the Location screen.
        _LocationHeader(
          location: widget.location,
          onTap: _openLocationScreen,
        ),
        const SizedBox(height: 12),
        // Travel mode banner (Maliki qasr): visible only when enabled.
        if (widget.travel?.isEnabled == true) ...[
          const TravelBanner(),
          const SizedBox(height: 12),
        ],
        // Hijri date line (tabular calendar, approximate).
        Row(
          children: [
            Icon(Icons.calendar_today,
                size: 14, color: theme.colorScheme.secondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.hijriDateLine(
                  hijriMonthName(l10n, hijri.month),
                  l10n.hijriCalendarNote,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _HeroCard(
          next: next,
          label: _prayerLabel(l10n, next.prayer),
          arabic: _prayerArabic(next.prayer),
          descriptor: rows
              .firstWhere((r) => r.prayer == next.prayer)
              .descriptor,
          now: _now,
          languageCode: lang,
          hijriDate: localizeDigits(formatHijriDate(l10n, hijri), lang),
        ),
        const SizedBox(height: 20),

        // High-latitude estimate notice: the engine flags these times as
        // approximations — same pattern as the monthly day sheet.
        if (times.highLatitudeFallback) ...[
          _EstimateNotice(text: l10n.highLatitudeNote),
          const SizedBox(height: 12),
        ],

        // Today's timetable.
        _SectionHeader(
            icon: Icons.view_timeline, title: l10n.todaysTimes),
        const SizedBox(height: 8),
        ...rows.map((row) {
          final isNext = row.prayer == next.prayer;
          final time = settings.adjustedTime(
              row.prayer, times.timeFor(row.prayer));
          final timeLabel = formatPrayerTime(time, lang);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PrayerRowCard(
              row: row,
              time: timeLabel,
              adjustments: _adjustmentChips(row.prayer),
              isNext: isNext,
              nextBadge: l10n.nextPrayerBadge,
              onTap: () => showWhyTimeSheet(
                context: context,
                prayer: row.prayer,
                timeLabel: timeLabel,
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        // Rounding is disclosed once per screen, not per row.
        Text(
          l10n.roundingFootnote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Two-tier fiqh bands.
        _SectionHeader(icon: Icons.auto_stories, title: l10n.bandsTitle),
        const SizedBox(height: 4),
        Text(
          l10n.bandsInfoNote,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.secondary),
        ),
        const SizedBox(height: 8),
        ...bands.map((b) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BandCard(band: b, times: times),
          );
        }),
        const SizedBox(height: 20),

        // Prominent calculation-profile status label.
        _ProfileStatusCard(times: times),
      ],
    );
  }
}

class _PrayerRow {
  final Prayer prayer;
  final String label;
  final String arabic;
  final IconData icon;
  final String descriptor;
  final bool isMarker;

  const _PrayerRow(this.prayer, this.label, this.arabic, this.icon,
      this.descriptor,
      {this.isMarker = false});
}

/// Section header: small icon + eyebrow-style title.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: AppFonts.eyebrow(context).copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Prominent current-location header: large name, coordinates beneath,
/// taps through to the Location screen. The active horizon must be
/// unmistakable at a glance.
class _LocationHeader extends StatelessWidget {
  final LocationService location;
  final VoidCallback onTap;

  const _LocationHeader({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final current = location.current;
    final name = current == null
        ? l10n.setLocation
        : current.displayName(l10n.deviceLocationName);
    final coords = current == null
        ? null
        : '${current.latitude.toStringAsFixed(5)}, '
            '${current.longitude.toStringAsFixed(5)}';

    return Card(
      color: scheme.secondaryContainer,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.secondary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.near_me,
                    color: scheme.onSecondary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (coords != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        coords,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          // Coordinates are Latin-script data: pin the Latin
                          // font so "." never misrenders in Nastaleeq.
                          fontFamily: AppFonts.latinSans,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: scheme.onSecondaryContainer, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ({Prayer prayer, DateTime time}) next;
  final String label;
  final String arabic;
  final String descriptor;
  final DateTime now;
  final String? languageCode;

  /// Localized Hijri date for today, e.g. "27 Sha'ban 1447 AH".
  final String hijriDate;

  const _HeroCard({
    required this.next,
    required this.label,
    required this.arabic,
    required this.descriptor,
    required this.now,
    required this.languageCode,
    required this.hijriDate,
  });

  String _countdownParts() {
    var remaining = next.time.difference(now);
    if (remaining.isNegative) remaining = Duration.zero;
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final onHero = scheme.onPrimary;
    final heroDim = scheme.onInverseSurface;

    final parts = _countdownParts().split(':');
    final localized =
        parts.map((p) => localizeDigits(p, languageCode)).toList();
    final heroTime = formatPrayerTime(next.time, languageCode);

    // Flexible + shrink-to-fit: at large text sizes the three boxes share
    // the row width and scale their content down instead of overflowing.
    Widget digitBox(String digits) {
      return Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              digits,
              style: theme.textTheme.displaySmall?.copyWith(color: onHero),
            ),
          ),
        ),
      );
    }

    Widget colon() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(':',
              style:
                  theme.textTheme.displaySmall?.copyWith(color: heroDim)),
        );

    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: scheme.inversePrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.heroEyebrow.toUpperCase(),
                    style: AppFonts.eyebrow(context).copyWith(
                      color: scheme.inversePrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Hijri date for today: day, month name, year (tabular
            // calendar — the approximation note lives on the date line
            // above the card).
            Text(
              hijriDate,
              style: theme.textTheme.bodySmall?.copyWith(color: heroDim),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(label,
                      style: theme.textTheme.displayMedium
                          ?.copyWith(color: onHero),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ),
                if (!omitArabicCompanion(context)) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      arabic,
                      style: const TextStyle(
                        fontFamily: AppFonts.arabic,
                        fontSize: 22,
                        color: Color(0xFFD9F7ED),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              heroTime,
              style: theme.textTheme.displayLarge?.copyWith(color: onHero),
            ),
            const SizedBox(height: 4),
            Text(
              descriptor,
              style: theme.textTheme.bodySmall?.copyWith(color: heroDim),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.heroCountdownLabel.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(color: heroDim),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                digitBox(localized[0]),
                colon(),
                digitBox(localized[1]),
                colon(),
                digitBox(localized[2]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One timetable row: icon medallion, names + descriptor, HH:MM readout.
/// The next prayer is highlighted and carries a text badge (never color-only).
/// Any manual or ihtiyat adjustment applied to the row's time is disclosed
/// by [adjustments] chips hugging the time readout.
class _PrayerRowCard extends StatelessWidget {
  final _PrayerRow row;
  final String time;

  /// Disclosure chips for the row's adjustments; empty when none apply.
  final List<AdjustmentChip> adjustments;
  final bool isNext;
  final String nextBadge;
  final VoidCallback? onTap;

  const _PrayerRowCard({
    required this.row,
    required this.time,
    this.adjustments = const [],
    required this.isNext,
    required this.nextBadge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final highlighted = isNext;

    final fg = highlighted ? scheme.onPrimary : scheme.onSurface;
    final sub = highlighted ? scheme.onInverseSurface : scheme.onSurfaceVariant;

    return Card(
      color: highlighted ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: highlighted
                      ? scheme.primary
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  row.icon,
                  size: 22,
                  color: highlighted
                      ? scheme.onPrimary
                      : scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              // Name, badge and time form one tight cluster: the time sits
              // adjacent to the name instead of being stranded at the far
              // edge by an expanding spacer (user feedback on the Urdu home
              // screen). Loose flexibles shrink-wrap; the time's FittedBox
              // is leading-aligned so it hugs the name in both LTR and RTL.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            row.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: fg,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!omitArabicCompanion(context)) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              row.arabic,
                              style: TextStyle(
                                fontFamily: AppFonts.arabic,
                                fontSize: 15,
                                color: sub,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (highlighted) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryFixed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                nextBadge,
                                style: AppFonts.badgeLabel(context).copyWith(
                                  color: scheme.onTertiaryFixed,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        // Shrink-to-fit: the readout scales down instead of
                        // pushing the row into overflow at large text sizes.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              time,
                              style: AppFonts.timeLabel(context)
                                  .copyWith(color: fg),
                            ),
                          ),
                        ),
                        // Adjustment chips hug the time: every offset applied
                        // to the displayed time is disclosed right next to
                        // it (program Part A §2.3). Empty in the common case
                        // — the row layout is unchanged when no adjustment
                        // applies.
                        for (final chip in adjustments) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment:
                                  AlignmentDirectional.centerStart,
                              child: chip,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.descriptor,
                      style: theme.textTheme.bodySmall?.copyWith(color: sub),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One two-tier band card: name + informational Preferred/Necessity ranges.
class _BandCard extends StatelessWidget {
  final PrayerBand band;
  final PrayerTimes times;

  const _BandCard({required this.band, required this.times});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    Widget rangeRow(String eyebrow, String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pairedPrayerName(context, bandDisplayName(l10n, band.arabicName), band.arabicName),
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                // Shrink-to-fit: at large text sizes the chip scales down
                // instead of pushing the Row into overflow.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.informationalChip,
                        style: AppFonts.badgeLabel(context).copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            rangeRow(
              l10n.preferredWord,
              bandIkhtiyariText(l10n, band.arabicName, times),
            ),
            rangeRow(
              l10n.necessityWord,
              bandDaruriText(l10n, band.arabicName, times),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calculation-profile card in tertiary tones, with an expandable
/// "About this profile" section.
class _ProfileStatusCard extends StatelessWidget {
  final PrayerTimes times;

  const _ProfileStatusCard({required this.times});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.tertiaryFixed,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 16, color: scheme.onTertiaryFixed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.calculationProfile,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryFixed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              profileLabel(l10n, times.profile).name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onTertiaryFixed,
              ),
            ),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  l10n.aboutProfile,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onTertiaryFixed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                iconColor: scheme.onTertiaryFixed,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.aboutProfileText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryFixedVariant,
                      ),
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
}

/// Tertiary-toned notice for high-latitude estimation — same pattern as the
/// monthly day sheet.
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
