import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/services/settings_service.dart';

/// User settings: active calculation profile, per-prayer time adjustments,
/// the precautionary-delay (ihtiyat) switch, and adjustment reset.
///
/// The active profile is PROPOSED — pending scholarly review — and the
/// profile row says so.
class SettingsScreen extends StatelessWidget {
  final SettingsService settings;
  final Coordinates coordinates;
  final Duration timeZoneOffset;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.coordinates,
    required this.timeZoneOffset,
  });

  static const _adjustablePrayers = [
    Prayer.fajr,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  String _prayerLabel(Prayer p) => switch (p) {
        Prayer.fajr => 'Fajr',
        Prayer.sunrise => 'Sunrise',
        Prayer.dhuhr => 'Dhuhr',
        Prayer.asr => 'Asr',
        Prayer.maghrib => 'Maghrib',
        Prayer.isha => 'Isha',
      };

  String _adjustmentExplanation(Prayer p) {
    final label = _prayerLabel(p);
    return 'Moves the displayed $label time earlier or later. Use this to '
        'match your local mosque\u2019s timetable; it does not change the '
        'underlying calculation.';
  }

  void _openProfiles(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilesScreen(
          settings: settings,
          coordinates: coordinates,
          timeZoneOffset: timeZoneOffset,
        ),
      ),
    );
  }

  Widget _adjustmentRow(
      BuildContext context, SettingsService settings, Prayer prayer) {
    final theme = Theme.of(context);
    final value = settings.adjustments[prayer] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _prayerLabel(prayer),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: 'One minute earlier',
                  onPressed: value > -SettingsService.maxAdjustmentMinutes
                      ? () => settings.setAdjustment(prayer, value - 1)
                      : null,
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    '${value >= 0 ? '+' : ''}$value min',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'One minute later',
                  onPressed: value < SettingsService.maxAdjustmentMinutes
                      ? () => settings.setAdjustment(prayer, value + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _adjustmentExplanation(prayer),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // (1) Active profile.
              Text('Calculation profile', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Card(
                child: ListTile(
                  title: Text(settings.activeProfile.name),
                  subtitle: const Text(
                    'PROPOSED — pending scholarly review',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openProfiles(context),
                ),
              ),
              const SizedBox(height: 16),

              // (2) Per-prayer adjustments.
              Text('Prayer time adjustments',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Sunrise is a timetable marker, not a prayer, so it has no '
                'adjustment.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              ..._adjustablePrayers
                  .map((p) => _adjustmentRow(context, settings, p)),
              const SizedBox(height: 16),

              // (3) Precautionary delay (ihtiyat).
              Text('Precautionary delay (ihtiyat)',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Card(
                child: SwitchListTile(
                  title: const Text('Apply ihtiyat delays'),
                  subtitle: const Text(
                    'Adds a small delay after solar noon (Dhuhr) and after '
                    'sunset (Maghrib), as a precaution. This is a convention, '
                    'not part of the fiqh definition.',
                  ),
                  value: settings.ihtiyatEnabled,
                  onChanged: settings.setIhtiyatEnabled,
                ),
              ),
              const SizedBox(height: 16),

              // (4) Reset adjustments.
              TextButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset adjustments'),
                onPressed: () async {
                  await settings.resetAdjustments();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('All prayer time adjustments were reset.'),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
