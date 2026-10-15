import 'dart:async';

import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/maliki_rules.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/hijri.dart';

/// Milestone 2 home screen: today's timetable for the user's chosen location
/// (or a "choose your location" prompt when none is set), the next-prayer
/// countdown, the Hijri date line, the Maliki two-tier bands, and the
/// calculation-profile status label.
///
/// Time frame: every computation here uses `DateTime.now().timeZoneOffset`
/// (the device timezone). Manual far-away locations are therefore
/// approximate — a documented Milestone 2 limitation.
///
/// The displayed prayer times are the engine times passed through
/// [SettingsService.adjustedTime], so any ihtiyat (precautionary) adjustment
/// configured in the profile is reflected in the timetable and the countdown.
class HomeScreen extends StatefulWidget {
  final SettingsService settings;
  final LocationService location;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.location,
  });

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
    final tomorrow = calculatePrayerTimes(
      coordinates: _coordinates!,
      date: _civilDay!.add(const Duration(days: 1)),
      timeZoneOffset: _offset,
      profile: settings.effectiveProfile,
    );
    return (
      prayer: Prayer.fajr,
      time: settings.adjustedTime(Prayer.fajr, tomorrow.fajr),
    );
  }

  static const _prayerRows = [
    (prayer: Prayer.fajr, label: 'Fajr', arabic: 'الفجر'),
    (prayer: Prayer.sunrise, label: 'Sunrise', arabic: 'الشروق'),
    (prayer: Prayer.dhuhr, label: 'Dhuhr', arabic: 'الظهر'),
    (prayer: Prayer.asr, label: 'Asr', arabic: 'العصر'),
    (prayer: Prayer.maghrib, label: 'Maghrib', arabic: 'المغرب'),
    (prayer: Prayer.isha, label: 'Isha', arabic: 'العشاء'),
  ];

  String _prayerLabel(Prayer p) =>
      switch (p) {
        Prayer.fajr => 'Fajr',
        Prayer.sunrise => 'Sunrise',
        Prayer.dhuhr => 'Dhuhr',
        Prayer.asr => 'Asr',
        Prayer.maghrib => 'Maghrib',
        Prayer.isha => 'Isha',
      };

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _countdown(DateTime target) {
    var remaining = target.difference(_now);
    if (remaining.isNegative) remaining = Duration.zero;
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maliki Prayer Times'),
      ),
      body: _times == null ? _locationPrompt(theme) : _timetable(theme),
    );
  }

  /// Shown when no location is set yet: a prompt card that navigates to the
  /// location picker. No timetable is rendered.
  Widget _locationPrompt(ThemeData theme) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your location',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Prayer times are computed for a specific place. Pick your '
                'location to see today\'s timetable.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _openLocationScreen,
                child: const Text('Set location'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timetable(ThemeData theme) {
    final times = _times!;
    final bands = _bands!;
    final settings = widget.settings;
    final loc = widget.location.current!;
    final next = _nextPrayer();
    final hijri = gregorianToHijri(_civilDay!);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Location chip: name + tap → location picker.
        Row(
          children: [
            ActionChip(
              avatar: const Icon(Icons.place, size: 18),
              label: Text(loc.name),
              onPressed: _openLocationScreen,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Hijri date line (tabular calendar, approximate).
        Text(
          'Hijri: ${hijri.monthName} · $hijriCalendarNote',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),

        // Next-prayer countdown card.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_prayerLabel(next.prayer)} in ${_countdown(next.time)}',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Next prayer at ${_hhmm(next.time)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Today's timetable (engine times after adjustedTime).
        Text("Today's times", style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        ..._prayerRows.map((row) {
          final isNext = row.prayer == next.prayer;
          final isSunrise = row.prayer == Prayer.sunrise;
          return Card(
            color: isNext ? theme.colorScheme.primaryContainer : null,
            child: ListTile(
              title: Text('${row.label}  ${row.arabic}'),
              trailing: Text(
                _hhmm(settings.adjustedTime(row.prayer, times.timeFor(row.prayer))),
                style: theme.textTheme.titleMedium,
              ),
              subtitle: isNext
                  ? const Text('Next prayer')
                  : (isSunrise
                      ? const Text('Timetable marker — not a prayer')
                      : null),
            ),
          );
        }),
        const SizedBox(height: 12),

        // Two-tier fiqh bands.
        Text('Preferred and necessity times (Maliki)',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        ...bands.map((b) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${b.prayerName}  ${b.arabicName}',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Preferred: ${b.ikhtiyariText}',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text('Absolute end: ${b.daruriText}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),

        // Prominent calculation-profile status label.
        Card(
          color: theme.colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Calculation profile: PROPOSED — pending scholarly review',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(times.profile.name,
                    style: theme.textTheme.bodyMedium),
                ExpansionTile(
                  title: const Text('About this profile'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'The angles used to compute these times (for '
                        'example the 18\u00b0 Fajr angle and 17\u00b0 Isha '
                        'angle) are astronomical conventions that '
                        'approximate the legal signs described in the '
                        'fiqh sources. They are not fiqh rulings '
                        'themselves. No scholar has reviewed this profile; '
                        'it is a proposed starting point, and nothing on '
                        'this screen should be treated as a scholarly '
                        'determination.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
