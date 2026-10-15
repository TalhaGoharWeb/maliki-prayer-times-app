import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/prayer_names.dart';
import 'package:malikiprayertimes/widgets/notification_settings.dart';

/// User settings: active calculation profile, app language, per-prayer time
/// adjustments, the precautionary-delay (ihtiyat) switch, adjustment reset,
/// fonts note, app version, and the notification section.
///
/// The active profile is PROPOSED — pending scholarly review — and the
/// profile row says so.
class SettingsScreen extends StatelessWidget {
  final SettingsService settings;
  final Coordinates coordinates;
  final Duration timeZoneOffset;

  /// When null, the notification section is hidden (e.g. in widget tests).
  final NotificationService? notifications;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.coordinates,
    required this.timeZoneOffset,
    this.notifications,
  });

  static const _adjustablePrayers = [
    Prayer.fajr,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  String _prayerLabel(AppLocalizations l10n, Prayer p) => switch (p) {
        Prayer.fajr => l10n.prayerFajr,
        Prayer.sunrise => l10n.prayerSunrise,
        Prayer.dhuhr => l10n.prayerDhuhr,
        Prayer.asr => l10n.prayerAsr,
        Prayer.maghrib => l10n.prayerMaghrib,
        Prayer.isha => l10n.prayerIsha,
      };

  String _prayerArabic(Prayer p) => switch (p) {
        Prayer.fajr => 'الفجر',
        Prayer.sunrise => 'الشروق',
        Prayer.dhuhr => 'الظهر',
        Prayer.asr => 'العصر',
        Prayer.maghrib => 'المغرب',
        Prayer.isha => 'العشاء',
      };

  /// Short scholarly descriptor per prayer (template flavor, honest).
  String _prayerDescriptor(AppLocalizations l10n, Prayer p) => switch (p) {
        Prayer.fajr => l10n.prayerDescFajr,
        Prayer.sunrise => l10n.timetableMarkerNote,
        Prayer.dhuhr => l10n.prayerDescDhuhr,
        Prayer.asr => l10n.prayerDescAsr,
        Prayer.maghrib => l10n.prayerDescMaghrib,
        Prayer.isha => l10n.prayerDescIsha,
      };

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

  /// Language options: `null` = system default, then the four supported
  /// locales shown by their endonyms (standard practice).
  List<DropdownMenuItem<String?>> _languageItems(AppLocalizations l10n) {
    // Item labels ellipsize: at large text sizes the selected value must
    // never push the field outside its card.
    Widget item(String text) => Text(text, overflow: TextOverflow.ellipsis);
    return [
      DropdownMenuItem<String?>(value: null, child: item(l10n.systemDefault)),
      DropdownMenuItem<String?>(value: 'en', child: item('English')),
      DropdownMenuItem<String?>(value: 'ur', child: item('اردو')),
      DropdownMenuItem<String?>(value: 'ar', child: item('العربية')),
      DropdownMenuItem<String?>(value: 'fr', child: item('Français')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // (1) Jurisprudential profile.
            _SectionHeader(
                icon: Icons.menu_book,
                title: l10n.calculationProfileSection),
            const SizedBox(height: 8),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openProfiles(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.tertiaryFixed,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.menu_book,
                            color: scheme.onTertiaryFixed, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profileLabel(l10n, settings.activeProfile).name,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.proposedStatus.toUpperCase(),
                                style: AppFonts.badgeLabel(context).copyWith(
                                  color: scheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: scheme.outline),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // (2) Language & localization.
            _SectionHeader(
                icon: Icons.translate, title: l10n.languageSection),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String?>(
                  initialValue: settings.languageCode,
                  // Full-width so the selected value can never push the
                  // field outside its card at large text sizes.
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  items: _languageItems(l10n),
                  onChanged: (code) => settings.setLanguageCode(code),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // (3) Per-prayer adjustments.
            _SectionHeader(
                icon: Icons.history_edu, title: l10n.adjustmentsSection),
            const SizedBox(height: 4),
            _SectionNote(icon: Icons.info_outline, text: l10n.sunriseNoAdjustmentNote),
            const SizedBox(height: 6),
            _SectionNote(icon: Icons.tune, text: l10n.adjustmentsSectionNote),
            const SizedBox(height: 8),
            ..._adjustablePrayers.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AdjustmentCard(
                  prayer: p,
                  label: _prayerLabel(l10n, p),
                  arabic: _prayerArabic(p),
                  descriptor: _prayerDescriptor(l10n, p),
                  value: settings.adjustments[p] ?? 0,
                  max: SettingsService.maxAdjustmentMinutes,
                  earlierTooltip: l10n.tooltipEarlier,
                  laterTooltip: l10n.tooltipLater,
                  onChanged: (v) => settings.setAdjustment(p, v),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(l10n.resetAdjustments),
                onPressed: () async {
                  await settings.resetAdjustments();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.adjustmentsReset)),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // (4) Precautionary delay (ihtiyat).
            _SectionHeader(
                icon: Icons.verified, title: l10n.ihtiyatSection),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(l10n.applyIhtiyat,
                    style: theme.textTheme.titleSmall),
                subtitle: Text(
                  l10n.ihtiyatSubtitle,
                  style: theme.textTheme.bodySmall,
                ),
                value: settings.ihtiyatEnabled,
                onChanged: settings.setIhtiyatEnabled,
              ),
            ),
            const SizedBox(height: 20),

            // (5) Fonts.
            _SectionHeader(
                icon: Icons.text_fields, title: l10n.fontsSection),
            const SizedBox(height: 8),
            Card(
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.text_fields,
                        size: 18, color: scheme.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.fontsNote,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // (6) Prayer notifications (Track A widget; hidden when no
            // NotificationService is provided, e.g. in widget tests).
            if (notifications != null) ...[
              NotificationSettingsSection(
                notifications: notifications!,
                settings: settings,
                coordinates: coordinates,
                timeZoneOffset: timeZoneOffset,
              ),
              const SizedBox(height: 20),
            ],

            // (7) Version + footer.
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.appVersion('1.0.0'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.footerNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

/// Small icon + note line used for section-level explanations.
class _SectionNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Section header: small icon + eyebrow title.
class _SectionHeader extends StatelessWidget {  final IconData icon;
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

/// One per-prayer adjustment card: name, stepper, value.
/// The "what adjustments do" explanation lives once at section level.
class _AdjustmentCard extends StatelessWidget {
  final Prayer prayer;
  final String label;
  final String arabic;
  final String descriptor;
  final int value;
  final int max;
  final String earlierTooltip;
  final String laterTooltip;
  final ValueChanged<int> onChanged;

  const _AdjustmentCard({
    required this.prayer,
    required this.label,
    required this.arabic,
    required this.descriptor,
    required this.value,
    required this.max,
    required this.earlierTooltip,
    required this.laterTooltip,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                          label,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (!omitArabicCompanion(context)) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            arabic,
                            style: const TextStyle(
                              fontFamily: AppFonts.arabic,
                              fontSize: 14,
                              color: Color(0xFF404944),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    descriptor,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.secondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: earlierTooltip,
              onPressed: value > -max ? () => onChanged(value - 1) : null,
            ),
            Container(
              width: 76,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${value >= 0 ? '+' : ''}$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: laterTooltip,
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}
