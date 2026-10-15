import 'dart:async';

import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/maliki_rules.dart';

/// Milestone 1 home screen: today's timetable for the default location
/// (Nouakchott, Mauritania), the next-prayer countdown, the Maliki
/// two-tier bands, and the calculation-profile status label.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _defaultCoordinates = Coordinates(18.08581, -15.9785);
  static const _offset = Duration.zero; // Nouakchott is UTC+0.

  late DateTime _civilDay; // wall-clock day the times were computed for
  late PrayerTimes _times;
  late List<PrayerBand> _bands;
  late Timer _timer;
  DateTime _now = DateTime.now().toUtc().add(_offset);

  @override
  void initState() {
    super.initState();
    _computeForToday();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now().toUtc().add(_offset);
      setState(() {
        _now = now;
        // Recompute the timetable when the civil day rolls over.
        if (now.year != _civilDay.year ||
            now.month != _civilDay.month ||
            now.day != _civilDay.day) {
          _computeForToday();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _computeForToday() {
    final now = DateTime.now().toUtc().add(_offset);
    _civilDay = DateTime(now.year, now.month, now.day);
    _times = calculatePrayerTimes(
      coordinates: _defaultCoordinates,
      date: _civilDay,
      timeZoneOffset: _offset,
      profile: PrayerProfiles.defaultProfile,
    );
    _bands = malikiPrayerBands(_times);
  }

  /// The next prayer's wall-clock time in the same frame as [_times].
  /// When nothing remains today, Fajr belongs to tomorrow's timetable.
  ({Prayer prayer, DateTime time}) _nextPrayer() {
    for (final p in const [
      Prayer.fajr,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ]) {
      final t = _times.timeFor(p);
      if (t.isAfter(_now)) return (prayer: p, time: t);
    }
    final tomorrow = calculatePrayerTimes(
      coordinates: _defaultCoordinates,
      date: _civilDay.add(const Duration(days: 1)),
      timeZoneOffset: _offset,
      profile: PrayerProfiles.defaultProfile,
    );
    return (prayer: Prayer.fajr, time: tomorrow.fajr);
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
    final next = _nextPrayer();
    final bands = _bands;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maliki Prayer Times'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Nouakchott — default location (device location in a later milestone)',
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

          // Today's timetable.
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
                  _hhmm(_times.timeFor(row.prayer)),
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
                  Text('Calculation profile: PROPOSED — pending scholarly review',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(_times.profile.name,
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
      ),
    );
  }
}
