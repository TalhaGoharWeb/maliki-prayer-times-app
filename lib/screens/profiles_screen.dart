import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/services/timezone_service.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Calculation profiles: the juristic presets, selection, and a
/// two-profile comparison of today's computed times.
///
/// Profiles are immutable engine constants. Tapping a preset marks it
/// pending; "Apply Active Profile" commits the pending choice to
/// [SettingsService].
class ProfilesScreen extends StatefulWidget {
  final SettingsService settings;
  final Coordinates coordinates;
  final Duration timeZoneOffset;

  /// IANA zone id the comparison renders in. When non-null, today's civil
  /// day and offset resolve from the zone (DST-correct); when null the
  /// constructor-supplied offset is used (legacy).
  final String? zoneId;

  /// Observer elevation in meters for the horizon dip correction.
  final double elevationMeters;

  const ProfilesScreen({
    super.key,
    required this.settings,
    required this.coordinates,
    required this.timeZoneOffset,
    this.zoneId,
    this.elevationMeters = 0.0,
  });

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late String _pendingId;
  late PrayerProfile _profileA;
  late PrayerProfile _profileB;

  static const _prayerRows = [
    Prayer.fajr,
    Prayer.sunrise,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  @override
  void initState() {
    super.initState();
    _pendingId = widget.settings.activeProfileId;
    _profileA = PrayerProfiles.all[0];
    _profileB = PrayerProfiles.all[1];
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Today's offset: the zone's offset for today when [zoneId] is set,
  /// otherwise the constructor-supplied offset (legacy).
  Duration _offsetForToday() {
    final zoneId = widget.zoneId;
    if (zoneId != null) {
      try {
        return TimezoneService.offsetFor(zoneId, DateTime.now());
      } catch (_) {
        // Fall through to the constructor offset.
      }
    }
    return widget.timeZoneOffset;
  }

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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    // Today's civil day in the location zone's wall-clock frame (or the
    // constructor offset's frame when no zone was supplied).
    final offset = _offsetForToday();
    final now = DateTime.now().toUtc().add(offset);
    final day = DateTime(now.year, now.month, now.day);
    PrayerTimes? timesFor(PrayerProfile p) {
      final result = calculatePrayerTimes(
        coordinates: widget.coordinates,
        date: day,
        timeZoneOffset: offset,
        profile: p,
        elevationMeters: widget.elevationMeters,
        fallback: widget.settings.highLatitudeFallback,
      );
      // A no-solution day (polar day/night) has no comparable times —
      // the compare rows show an honest label instead.
      return result is PrayerTimesComputed ? result.times : null;
    }
    final timesA = timesFor(_profileA);
    final timesB = timesFor(_profileB);

    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final activeId = widget.settings.activeProfileId;
        final pendingChanged = _pendingId != activeId;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Juristic presets header.
            Text(
              l10n.juristicPresets.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.profilesTitle,
                    style: theme.textTheme.displaySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                // Shrink-to-fit: the pill must never push the Row into
                // overflow at large text sizes.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.methodsAvailable(
                            '${PrayerProfiles.all.length}'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preset radio cards.
            RadioGroup<String>(
              groupValue: _pendingId,
              onChanged: (id) {
                if (id != null) setState(() => _pendingId = id);
              },
              child: Column(
                children: [
                  ...PrayerProfiles.all.map((profile) {
                    final isActive = profile.id == activeId;
                    final isPending = profile.id == _pendingId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PresetCard(
                        profile: profile,
                        isActive: isActive,
                        isPending: isPending,
                        onSelect: () =>
                            setState(() => _pendingId = profile.id),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Apply button.
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: pendingChanged
                    ? () async {
                        await widget.settings.setActiveProfile(_pendingId);
                        if (context.mounted) {
                          final name = profileLabel(
                            l10n,
                            PrayerProfiles.all.firstWhere(
                              (p) => p.id == _pendingId,
                            ),
                          ).name;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.profileApplied(name)),
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.save),
                label: Text(l10n.applyActiveProfile),
              ),
            ),
            const SizedBox(height: 20),

            // Methodology analysis / compare.
            Text(
              l10n.compareProfiles.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.compareSubtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ProfileDropdown(
                    label: l10n.profileALabel,
                    value: _profileA,
                    onChanged: (p) =>
                        setState(() => _profileA = p),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfileDropdown(
                    label: l10n.profileBLabel,
                    value: _profileB,
                    onChanged: (p) =>
                        setState(() => _profileB = p),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: AppFonts.eyebrow(context).copyWith(
                    color: scheme.secondary,
                  ),
                  dataTextStyle: theme.textTheme.bodyMedium,
                  columns: [
                    DataColumn(label: Text(l10n.tablePrayer.toUpperCase())),
                    DataColumn(label: Text(l10n.profileALabel)),
                    DataColumn(label: Text(l10n.profileBLabel)),
                    DataColumn(
                        label: Text(l10n.tableDiffHeader.toUpperCase())),
                  ],
                  rows: _prayerRows.map((prayer) {
                    final a = timesA?.timeFor(prayer);
                    final b = timesB?.timeFor(prayer);
                    // A no-solution day (polar day/night) has no comparable
                    // times — the row says so honestly instead of showing
                    // fabricated times.
                    if (a == null || b == null) {
                      return DataRow(
                        cells: [
                          DataCell(Text(_rowLabel(l10n, prayer))),
                          DataCell(Text(l10n.noTimesCell)),
                          DataCell(Text(l10n.noTimesCell)),
                          const DataCell(Text('—')),
                        ],
                      );
                    }
                    return DataRow(
                      cells: [
                        DataCell(Text(_rowLabel(l10n, prayer))),
                        DataCell(
                            Text(localizeDigits(_hhmm(a), lang))),
                        DataCell(
                            Text(localizeDigits(_hhmm(b), lang))),
                        DataCell(Text(_diffMinutes(l10n, a, b))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: scheme.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.compareFootnote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// One preset card: radio, name + Active badge, basis, angle spec chips.
class _PresetCard extends StatelessWidget {
  final PrayerProfile profile;
  final bool isActive;
  final bool isPending;
  final VoidCallback onSelect;

  const _PresetCard({
    required this.profile,
    required this.isActive,
    required this.isPending,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final labels = profileLabel(l10n, profile);
    final disputed = profileAnglesDisputed(profile);

    // Per-parameter spec chips, each carrying its D9 evidence-status badge:
    // angles are provisional conventions, institutional presets, or
    // disputed; Asr ×1 is fiqh-derived (Maliki first mithl).
    final paramSpecs = [
      ('Fajr ${profile.fajrAngle}°', ProfileParam.fajrAngle),
      ('Isha ${profile.ishaAngle}°', ProfileParam.ishaAngle),
      ('Asr ×${profile.asrShadowFactor}', ProfileParam.asrShadowFactor),
    ];

    return Card(
      color: isPending ? scheme.secondaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPending
            ? BorderSide(color: scheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: labels.name,
                checked: isPending,
                child: Radio<String>(
                  value: profile.id,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            labels.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.activeBadge.toUpperCase(),
                              style: AppFonts.badgeLabel(context).copyWith(
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Profile-level evidence badge (D9 vocabulary): the
                    // preset's standing — provisional convention,
                    // institutional preset, or disputed. Never color alone:
                    // the text carries the status.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profileEvidenceBadge(l10n, profile),
                        style: AppFonts.badgeLabel(context).copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels.basis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (value, param) in paramSpecs)
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  value,
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                parameterEvidenceBadge(
                                    l10n, profile, param),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.secondary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // The UOIF disputed label (D1 trap register), surfaced
                    // honestly — never softened.
                    if (disputed) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: scheme.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.evidenceDisputedDetail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Dropdown for choosing a comparison profile.
class _ProfileDropdown extends StatelessWidget {
  final String label;
  final PrayerProfile value;
  final ValueChanged<PrayerProfile> onChanged;

  const _ProfileDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Material ancestor for the dropdown's ink effects (the screen itself
    // has no Scaffold).
    return Material(
      type: MaterialType.transparency,
      child: DropdownButtonFormField<PrayerProfile>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: PrayerProfiles.all
          .map(
            (p) => DropdownMenuItem(
              value: p,
              child: Text(
                profileLabel(l10n, p).name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
          .toList(),
      onChanged: (p) {
        if (p != null) onChanged(p);
      },
      ),
    );
  }
}
