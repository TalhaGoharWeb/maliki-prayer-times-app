import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/services/settings_service.dart';

/// Lists the proposed calculation profiles and lets the user select one, plus
/// a two-profile comparison of today's computed times.
///
/// Every profile on this screen is PROPOSED — pending scholarly review — and
/// the banner at the top states this. Profiles are immutable engine
/// constants; selection only stores the profile id in [SettingsService].
/// Profile display names are localized by profile id
/// (see [profileLabel]); the engine constants keep their English names.
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
    Prayer.fajr,
    Prayer.sunrise,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _diffMinutes(AppLocalizations l10n, DateTime a, DateTime b) {
    final d = b.difference(a).inMinutes;
    if (d == 0) return l10n.diffSame;
    final value = '${d > 0 ? '+' : ''}$d';
    return l10n.diffMinutes(value);
  }

  String _rowLabel(AppLocalizations l10n, Prayer p) => switch (p) {
        Prayer.fajr => l10n.prayerFajr,
        Prayer.sunrise => l10n.sunriseMarkerRow,
        Prayer.dhuhr => l10n.prayerDhuhr,
        Prayer.asr => l10n.prayerAsr,
        Prayer.maghrib => l10n.prayerMaghrib,
        Prayer.isha => l10n.prayerIsha,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
      appBar: AppBar(title: Text(l10n.profilesTitle)),
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
                          l10n.proposedBanner,
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

              Text(l10n.selectProfile, style: theme.textTheme.titleMedium),
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
                          title: Text(profileLabel(l10n, profile).name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                profileLabel(l10n, profile).basis,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.profileAngles(
                                  '${profile.fajrAngle}',
                                  '${profile.ishaAngle}',
                                  '${profile.asrShadowFactor}',
                                ),
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
              Text(l10n.compareProfiles, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.compareSubtitle, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<PrayerProfile>(
                      initialValue: _profileA,
                      // Full-width so long profile names can never push the
                      // field outside its half of the row at large text sizes.
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.profileALabel,
                      ),
                      items: PrayerProfiles.all
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                profileLabel(l10n, p).name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
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
                      // Full-width so long profile names can never push the
                      // field outside its half of the row at large text sizes.
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.profileBLabel,
                      ),
                      items: PrayerProfiles.all
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                profileLabel(l10n, p).name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
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
                    columns: [
                      DataColumn(label: Text(l10n.tablePrayer)),
                      const DataColumn(label: Text('A')),
                      const DataColumn(label: Text('B')),
                      DataColumn(label: Text(l10n.tableDiffHeader)),
                    ],
                    rows: _prayerRows.map((prayer) {
                      final a = timesA.timeFor(prayer);
                      final b = timesB.timeFor(prayer);
                      return DataRow(
                        cells: [
                          DataCell(Text(_rowLabel(l10n, prayer))),
                          DataCell(Text(_hhmm(a))),
                          DataCell(Text(_hhmm(b))),
                          DataCell(Text(_diffMinutes(l10n, a, b))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.compareFootnote, style: theme.textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
