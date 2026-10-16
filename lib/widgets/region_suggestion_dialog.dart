import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/services/region_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// One-time "Recommended settings" dialog (trust program Part A §2.5):
/// after a new location is set, the app may suggest the regional preset
/// matching the detected location. The USER confirms — nothing switches
/// silently. Dismissing (or tapping outside) keeps the current profile.
///
/// Returns `true` when the user confirmed the switch, `false` when they
/// chose to keep the current profile, and `null` when dismissed via the
/// barrier. The caller's one-time bookkeeping decides whether this ever
/// shows again; this dialog itself is always dismissible and never nags.
///
/// The suggested profile's evidence badge is always visible — including
/// the UOIF "disputed" badge (D1 trap register), which is never softened.
Future<bool?> showRegionSuggestionDialog({
  required BuildContext context,
  required RegionGuess guess,
  required PrayerProfile profile,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _RegionSuggestionDialog(guess: guess, profile: profile),
  );
}

class _RegionSuggestionDialog extends StatelessWidget {
  final RegionGuess guess;
  final PrayerProfile profile;

  const _RegionSuggestionDialog({
    required this.guess,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final labels = profileLabel(l10n, profile);
    final disputed = profileAnglesDisputed(profile);

    return AlertDialog(
      title: Text(l10n.regionDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.regionDetected(guess.name(l10n)),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.regionSuggestion(labels.name),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Evidence badge: always visible, never color-alone (text).
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            const SizedBox(height: 12),
            Text(
              l10n.regionSwitchQuestion,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.secondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.regionDismiss),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.regionConfirm),
        ),
      ],
    );
  }
}
