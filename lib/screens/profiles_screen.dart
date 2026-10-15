import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/services/settings_service.dart';

/// Lists the proposed calculation profiles and lets the user select one, plus
/// a two-profile comparison of today's computed times.
///
/// Every profile on this screen is PROPOSED — pending scholarly review — and
/// the banner at the top states this. Profiles are immutable engine
/// constants; selection only stores the profile id in [SettingsService].
class ProfilesScreen extends StatefulWidget {
  final SettingsService settings;
  final Coordinates coordinates;
  final Duration timeZoneOffset;

  const ProfilesScreen({
    super.key,
    required this.settings,
    required this.coordinates,
    required this.timeZoneOffset,
  });

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late PrayerProfile _profileA = PrayerProfiles.all[0];
  late PrayerProfile _profileB = PrayerProfiles.all[1];

  static const _prayerRows = [
    (prayer: Prayer.fajr, label: 'Fajr'),
    (prayer: Prayer.sunrise, label: 'Sunrise (marker)'),
    (prayer: Prayer.dhuhr, label: 'Dhuhr'),
    (prayer: Prayer.asr, label: 'Asr'),
    (prayer: Prayer.maghrib, label: 'Maghrib'),
    (prayer: Prayer.isha, label: 'Isha'),
  ];

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _diffMinutes(DateTime a, DateTime b) {
    final d = b.difference(a).inMinutes;
    if (d == 0) return 'same';
    return '${d > 0 ? '+' : ''}$d min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Today's civil day in the offset's wall-clock frame.
    final now = DateTime.now().toUtc().add(widget.timeZoneOffset);
    final day = DateTime(now.year, now.month, now.day);
    final timesA = calculatePrayerTimes(
      coordinates: widget.coordinates,
      date: day,
      timeZoneOffset: widget.timeZoneOffset,
      profile: _profileA,
    );
    final timesB = calculatePrayerTimes(
      coordinates: widget.coordinates,
      date: day,
      timeZoneOffset: widget.timeZoneOffset,
      profile: _profileB,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculation profiles'),
      ),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Persistent PROPOSED status banner.
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'PROPOSED — pending scholarly review. Angles are '
                          'astronomical conventions, not fiqh rulings. No '
                          'scholar has reviewed these profiles.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text('Select a profile', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              RadioGroup<String>(
                groupValue: widget.settings.activeProfileId,
                onChanged: (id) {
                  if (id != null) widget.settings.setActiveProfile(id);
                },
                child: Column(
                  children: [
                    for (final profile in PrayerProfiles.all)
                      Card(
                        child: RadioListTile<String>(
                          title: Text(profile.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(profile.basis,
                                  style: theme.textTheme.bodySmall),
                              const SizedBox(height: 6),
                              Text(
                                'Fajr angle ${profile.fajrAngle}\u00b0  ·  '
                                'Isha angle ${profile.ishaAngle}\u00b0  ·  '
                                'Asr factor ${profile.asrShadowFactor}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          value: profile.id,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Profile comparison.
              Text('Compare profiles', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                "Today's computed times side by side (engine values, before "
                'your per-prayer adjustments).',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<PrayerProfile>(
                      initialValue: _profileA,
                      decoration:
                          const InputDecoration(labelText: 'Profile A'),
                      items: PrayerProfiles.all
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (p) {
                        if (p != null) setState(() => _profileA = p);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<PrayerProfile>(
                      initialValue: _profileB,
                      decoration:
                          const InputDecoration(labelText: 'Profile B'),
                      items: PrayerProfiles.all
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (p) {
                        if (p != null) setState(() => _profileB = p);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Prayer')),
                      DataColumn(label: Text('A')),
                      DataColumn(label: Text('B')),
                      DataColumn(label: Text('B − A')),
                    ],
                    rows: _prayerRows.map((row) {
                      final a = timesA.timeFor(row.prayer);
                      final b = timesB.timeFor(row.prayer);
                      return DataRow(cells: [
                        DataCell(Text(row.label)),
                        DataCell(Text(_hhmm(a))),
                        DataCell(Text(_hhmm(b))),
                        DataCell(Text(_diffMinutes(a, b))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Differences come from the Fajr/Isha angles each profile uses; '
                'the profiles themselves are PROPOSED — pending scholarly '
                'review.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
