import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/calculation_changelog_screen.dart';
import 'package:malikiprayertimes/screens/learn_screen.dart';
import 'package:malikiprayertimes/screens/methodology_screen.dart';
import 'package:malikiprayertimes/screens/review_record_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/services/travel_service.dart';
import 'package:malikiprayertimes/services/update_service.dart';
import 'package:malikiprayertimes/utils/app_info.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/prayer_names.dart';
import 'package:malikiprayertimes/widgets/notification_settings.dart';
import 'package:url_launcher/url_launcher.dart';

/// User settings: app language, per-prayer time adjustments, the
/// precautionary-delay (ihtiyat) switch, adjustment reset, travel mode
/// (Maliki qasr), fonts note, app version, and the notification section.
class SettingsScreen extends StatelessWidget {
  final SettingsService settings;
  final Coordinates coordinates;
  final Duration timeZoneOffset;

  /// IANA zone id the notification schedule renders in. When non-null,
  /// per-date offsets resolve from the zone; when null the legacy
  /// constructor-offset behavior is used.
  final String? zoneId;

  /// Observer elevation in meters for the horizon dip correction.
  final double elevationMeters;

  /// When null, the notification section is hidden (e.g. in widget tests).
  final NotificationService? notifications;

  /// Update checker for the "Check for updates" row; injectable in tests.
  /// When null, a production [AppUpdateService] is used.
  final AppUpdateService? updateService;

  /// Travel mode (Maliki qasr) state for the Travel section. When null the
  /// section is hidden (e.g. in widget tests).
  final TravelService? travelService;

  /// Source of the saved home location seeded into [TravelService] on the
  /// first enable. When null (or no location saved), enabling travel stores
  /// no home and the travel suggestion stays dormant.
  final LocationService? locationService;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.coordinates,
    required this.timeZoneOffset,
    this.zoneId,
    this.elevationMeters = 0.0,
    this.notifications,
    this.updateService,
    this.travelService,
    this.locationService,
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
    final travel = travelService;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // (1) Language & localization.
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

            // (2) Per-prayer adjustments.
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

            // (3) Precautionary delay (ihtiyat).
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

            // (3b) Method, review & changes (Phase 1C): entries opening the
            // Methodology screen, the review record, and the calculation
            // changelog — every screen opens; there are no dead entries.
            // (Phase 4) the Learn teaching section sits alongside them.
            _SectionHeader(
                icon: Icons.library_books, title: l10n.methodReviewSection),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _SettingsNavRow(
                    icon: Icons.calculate_outlined,
                    title: l10n.settingsMethodologyTitle,
                    onTap: () => MethodologyScreen.open(context),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingsNavRow(
                    icon: Icons.school_outlined,
                    title: l10n.learnTitle,
                    onTap: () => LearnScreen.open(context),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingsNavRow(
                    icon: Icons.rate_review_outlined,
                    title: l10n.settingsReviewTitle,
                    onTap: () => ReviewRecordScreen.open(context),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingsNavRow(
                    icon: Icons.history_outlined,
                    title: l10n.settingsChangelogTitle,
                    onTap: () => CalculationChangelogScreen.open(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // (4) Travel mode (Maliki qasr).
            if (travel != null) ...[
              ListenableBuilder(
                listenable: travel,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                        icon: Icons.flight_takeoff_outlined,
                        title: l10n.travelToggle),
                    const SizedBox(height: 8),
                    Card(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        title: Text(l10n.travelToggle,
                            style: theme.textTheme.titleSmall),
                        subtitle: Text(
                          l10n.travelToggleDesc,
                          style: theme.textTheme.bodySmall,
                        ),
                        value: travel.isEnabled,
                        onChanged: (v) async {
                          // Seed the stored home from the saved location on
                          // first enable; TravelService keeps it afterwards.
                          final saved = locationService?.current;
                          await travel.setEnabled(
                            v,
                            homeLat: v ? saved?.latitude : null,
                            homeLng: v ? saved?.longitude : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: scheme.tertiaryFixed,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.flight_takeoff_outlined,
                                    size: 18,
                                    color: scheme.onTertiaryFixedVariant),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.travelQasrInfo,
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onTertiaryFixed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.travelJamNote,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onTertiaryFixed,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.travelDistanceNote,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onTertiaryFixed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

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
                zoneId: zoneId,
                elevationMeters: elevationMeters,
              ),
              const SizedBox(height: 20),
            ],

            // (7) About the app.
            _SectionHeader(
                icon: Icons.info_outline, title: l10n.aboutAppSection),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutAppBody,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    _UpdateCheckRow(
                      service: updateService ?? AppUpdateService(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // (8) About the developer.
            _SectionHeader(
                icon: Icons.person_outline,
                title: l10n.aboutDeveloperSection),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutDeveloperName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.mail_outline,
                            size: 16, color: scheme.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.aboutDeveloperContact,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // (9) Version + footer.
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.appVersion(kAppVersion),
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
            // Screen readers get the un-uppercased string: all caps can
            // degrade pronunciation in en/fr.
            semanticsLabel: title,
            style: AppFonts.eyebrow(context).copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One tappable settings navigation entry: icon, title, chevron.
/// Every entry pushes its screen — no dead buttons (Urdu-first rule).
class _SettingsNavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsNavRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ),
      ),
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
    final lang = Localizations.localeOf(context).languageCode;
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
                            style: TextStyle(
                              fontFamily: AppFonts.arabic,
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
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
                // Digit-localized for `ar` (Arabic-Indic) so the stepper
                // never shows raw Western digits.
                localizeDigits('${value >= 0 ? '+' : ''}$value', lang),
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

/// "Check for updates" row inside the About-the-app card.
///
/// Taps [AppUpdateService.check] (injectable) and reports the outcome inline:
/// up-to-date, available (with a Download button opening the release URL),
/// or a graceful failure note. Never blocks the UI; the service never throws.
class _UpdateCheckRow extends StatefulWidget {
  final AppUpdateService service;

  const _UpdateCheckRow({required this.service});

  @override
  State<_UpdateCheckRow> createState() => _UpdateCheckRowState();
}

class _UpdateCheckRowState extends State<_UpdateCheckRow> {
  bool _checking = false;
  UpdateCheckResult? _result;

  Future<void> _runCheck() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    final result = await widget.service.check();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
    });
  }

  Future<void> _openDownload(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    Widget status;
    if (_checking) {
      status = Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.updateChecking)),
        ],
      );
    } else if (_result != null) {
      switch (_result!.outcome) {
        case UpdateCheckOutcome.upToDate:
          status = Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 18, color: scheme.secondary),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.updateUpToDate)),
            ],
          );
        case UpdateCheckOutcome.available:
          status = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.system_update,
                      size: 18, color: scheme.tertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.updateAvailable(
                          _result!.latestTag ?? ''),
                    ),
                  ),
                ],
              ),
              if (_result!.downloadUrl != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: () => _openDownload(_result!.downloadUrl!),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(l10n.updateDownload),
                  ),
                ),
              ],
            ],
          );
        case UpdateCheckOutcome.unknown:
          status = Row(
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 18, color: scheme.outline),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.updateCheckFailed)),
            ],
          );
      }
    } else {
      status = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _checking ? null : _runCheck,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(Icons.system_update,
                    size: 20, color: scheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.checkForUpdates,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.outline),
              ],
            ),
          ),
        ),
        if (_checking || _result != null) ...[
          const SizedBox(height: 4),
          status,
        ],
      ],
    );
  }
}
