import 'package:flutter/material.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// What kind of adjustment a chip discloses.
///
/// - [manual]: a per-prayer minute offset the user set in Settings
///   (clamped to ±60 minutes).
/// - [ihtiyat]: the profile's precautionary Dhuhr/Maghrib delay, applied by
///   the engine when ihtiyat is enabled. A software convention, never a
///   fiqh ruling — the word on the chip names it as such.
enum AdjustmentKind { manual, ihtiyat }

/// A small disclosure chip naming an adjustment applied to a displayed
/// time — the "never silently adjust" requirement (program Part A §2.3).
///
/// Manual offsets render as e.g. "+5 min"; the precautionary delay as
/// e.g. "ihtiyat +1 min". Zero adjustments never render: callers only build
/// this chip when an adjustment actually applies.
class AdjustmentChip extends StatelessWidget {
  /// Signed whole minutes of the adjustment.
  final int minutes;

  /// Whether this is a user-set manual offset or the ihtiyat convention.
  final AdjustmentKind kind;

  const AdjustmentChip({
    super.key,
    required this.minutes,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;

    final sign = minutes >= 0 ? '+' : '-';
    final digits = localizeDigits('$sign${minutes.abs()}', lang);
    final label = kind == AdjustmentKind.ihtiyat
        ? '${l10n.adjustmentIhtiyatWord} $digits ${l10n.adjustmentUnitMin}'
        : '$digits ${l10n.adjustmentUnitMin}';

    // Manual offsets get the gold tertiary treatment; ihtiyat gets the
    // green secondary one. The distinction is carried by the label text,
    // never by color alone.
    final background = kind == AdjustmentKind.ihtiyat
        ? scheme.secondaryContainer
        : scheme.tertiaryFixed;
    final foreground = kind == AdjustmentKind.ihtiyat
        ? scheme.onSecondaryContainer
        : scheme.onTertiaryFixed;

    // Shrink-to-fit: at large text sizes the chip scales down instead of
    // pushing its row into overflow (same pattern as the band chips).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppFonts.badgeLabel(context).copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
