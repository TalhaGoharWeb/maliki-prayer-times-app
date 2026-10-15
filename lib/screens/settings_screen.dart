import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/widgets/notification_settings.dart';

/// User settings: active calculation profile, app language, per-prayer time
/// adjustments, the precautionary-delay (ihtiyat) switch, adjustment reset,
/// and a fonts note.
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

  String _adjustmentExplanation(AppLocalizations l10n, Prayer p) =>
      l10n.adjustmentExplanation(_prayerLabel(l10n, p));

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

  Widget _adjustmentRow(
    BuildContext context,
    AppLocalizations l10n,
    SettingsService settings,
    Prayer prayer,
  ) {
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
                    _prayerLabel(l10n, prayer),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: l10n.tooltipEarlier,
                  onPressed: value > -SettingsService.maxAdjustmentMinutes
                      ? () => settings.setAdjustment(prayer, value - 1)
                      : null,
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    l10n.adjustmentValue('${value >= 0 ? '+' : ''}$value'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.tooltipLater,
                  onPressed: value < SettingsService.maxAdjustmentMinutes
                      ? () => settings.setAdjustment(prayer, value + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _adjustmentExplanation(l10n, prayer),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // (1) Active profile.
              Text(
                l10n.calculationProfileSection,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Card(
                child: ListTile(
                  title: Text(profileLabel(l10n, settings.activeProfile).name),
                  subtitle: Text(
                    l10n.proposedStatus,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openProfiles(context),
                ),
              ),
              const SizedBox(height: 16),

              // (2) App language.
              Text(l10n.languageSection, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: DropdownButtonFormField<String?>(
                    initialValue: settings.languageCode,
                    // Full-width so the selected value can never push the
                    // field outside its card at large text sizes.
                    isExpanded: true,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: _languageItems(l10n),
                    onChanged: (code) => settings.setLanguageCode(code),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // (3) Per-prayer adjustments.
              Text(l10n.adjustmentsSection, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                l10n.sunriseNoAdjustmentNote,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              ..._adjustablePrayers.map(
                (p) => _adjustmentRow(context, l10n, settings, p),
              ),
              const SizedBox(height: 16),

              // (4) Precautionary delay (ihtiyat).
              Text(l10n.ihtiyatSection, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Card(
                child: SwitchListTile(
                  title: Text(l10n.applyIhtiyat),
                  subtitle: Text(l10n.ihtiyatSubtitle),
                  value: settings.ihtiyatEnabled,
                  onChanged: settings.setIhtiyatEnabled,
                ),
              ),
              const SizedBox(height: 16),

              // (5) Reset adjustments.
              TextButton.icon(
                icon: const Icon(Icons.restart_alt),
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
              const SizedBox(height: 16),

              // (6) Fonts: known pending item — no font files are bundled
              // (Jameel Noori Nastaleeq redistribution rights unverified).
              Text(l10n.fontsSection, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.fontsNote, style: theme.textTheme.bodySmall),
                ),
              ),

              // (7) Prayer notifications (Track A widget; hidden when no
              // NotificationService is provided, e.g. in widget tests).
              if (notifications != null) ...[
                const SizedBox(height: 16),
                NotificationSettingsSection(
                  notifications: notifications!,
                  settings: settings,
                  coordinates: coordinates,
                  timeZoneOffset: timeZoneOffset,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
