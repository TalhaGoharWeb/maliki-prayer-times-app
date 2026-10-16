import 'package:flutter/material.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';

/// Compact gold-tinted notice shown while travel mode is on: Dhuhr, Asr and
/// Isha are 2 rak'ahs (Maliki qasr). Prayer times do not change.
///
/// Pure presentational widget: the parent decides when to show it.
class TravelBanner extends StatelessWidget {
  const TravelBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: scheme.tertiaryFixed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.flight_takeoff_outlined,
              size: 20,
              color: scheme.onTertiaryFixedVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.travelBanner,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onTertiaryFixed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
