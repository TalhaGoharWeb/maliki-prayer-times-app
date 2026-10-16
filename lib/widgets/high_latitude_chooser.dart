import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Localized display name for a high-latitude fallback method.
String highLatitudeFallbackName(
        AppLocalizations l10n, HighLatitudeFallback method) =>
    switch (method) {
      HighLatitudeFallback.middleOfNight => l10n.highLatMethodMiddleOfNight,
      HighLatitudeFallback.oneSeventhOfNight => l10n.highLatMethodOneSeventh,
      HighLatitudeFallback.angleBased => l10n.highLatMethodAngleBased,
      HighLatitudeFallback.nearestDay => l10n.highLatMethodNearestDay,
    };

/// Localized one-line description of what a fallback method does.
String highLatitudeFallbackDescription(
        AppLocalizations l10n, HighLatitudeFallback method) =>
    switch (method) {
      HighLatitudeFallback.middleOfNight => l10n.highLatDescMiddleOfNight,
      HighLatitudeFallback.oneSeventhOfNight => l10n.highLatDescOneSeventh,
      HighLatitudeFallback.angleBased => l10n.highLatDescAngleBased,
      HighLatitudeFallback.nearestDay => l10n.highLatDescNearestDay,
    };

/// Opens the high-latitude fallback chooser as a bottom sheet.
///
/// The four methods are each labeled "convention, not a Maliki ruling"
/// with a one-line description. Tapping a method persists it via
/// [SettingsService.setHighLatitudeFallback] (listeners recompute the
/// visible timetable) and closes the sheet. Nothing here presents a
/// convention as a fiqh ruling.
Future<void> showHighLatitudeChooser(
    BuildContext context, SettingsService settings) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final scheme = theme.colorScheme;
      final l10n = AppLocalizations.of(sheetContext)!;
      return ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.highLatSectionTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.highLatSectionNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: RadioGroup<HighLatitudeFallback>(
                      groupValue: settings.highLatitudeFallback,
                      onChanged: (method) async {
                        if (method == null) return;
                        await settings.setHighLatitudeFallback(method);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final method in HighLatitudeFallback.values)
                            _MethodOption(
                              method: method,
                              selected: settings.highLatitudeFallback ==
                                  method,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Tappable high-latitude fallback indicator shared by the home timetable
/// and the monthly day sheet: names the method in effect, carries the
/// "convention, not a Maliki ruling" label (and the borrowed date for
/// nearest-day), and opens the chooser on tap. The default method is never
/// applied silently — it stays visible wherever fallback times are shown.
class HighLatitudeIndicator extends StatelessWidget {
  final PrayerTimes times;
  final VoidCallback onTap;

  const HighLatitudeIndicator(
      {super.key, required this.times, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final method = times.fallbackMethod;
    final borrowed = times.nearestDaySourceDate;
    // A self-contained Material surface: the indicator is tappable
    // (InkWell) and must not depend on an ancestor Material — it sits
    // directly in scroll views.
    return Material(
      color: scheme.tertiaryFixed,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: scheme.onTertiaryFixed),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method == null
                          ? l10n.highLatitudeNote
                          : l10n.highLatIndicatorTitle(
                              highLatitudeFallbackName(l10n, method)),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onTertiaryFixed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.highLatConventionBadge,
                      style: AppFonts.eyebrow(context).copyWith(
                        color: scheme.onTertiaryFixedVariant,
                      ),
                    ),
                    if (borrowed != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.nearestDayFrom(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(borrowed),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryFixed,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.highLatIndicatorAction,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onTertiaryFixed,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One fallback method option: radio, name, one-line description, and the
/// "convention, not a Maliki ruling" label on every option. Selection
/// state comes from the enclosing [RadioGroup]; [selected] only drives
/// the highlight visuals.
class _MethodOption extends StatelessWidget {
  final HighLatitudeFallback method;
  final bool selected;

  const _MethodOption({
    required this.method,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? scheme.primaryContainer : null,
      child: RadioListTile<HighLatitudeFallback>(
        value: method,
        // groupValue/onChanged are inherited from the RadioGroup ancestor
        // (the post-3.32 API) — no deprecated members here.
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          highLatitudeFallbackName(l10n, method),
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              highLatitudeFallbackDescription(l10n, method),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 12, color: scheme.secondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l10n.highLatConventionBadge,
                    style: AppFonts.eyebrow(context).copyWith(
                      color: scheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        secondary: selected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : null,
      ),
    );
  }
}
