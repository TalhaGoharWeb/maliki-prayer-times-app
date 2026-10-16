/// "Why this time?" bottom sheet for the home timetable.
///
/// Tapping a prayer row opens this sheet: the prayer's name and its time
/// rendered prominently, the Maliki rule-registry explanation as the body,
/// and the registry note as small secondary text at the bottom.
///
/// The explanation strings come verbatim from docs/MALIKI_RULES.md (surfaced
/// via l10n) — this file never invents or rewords fiqh content. Palette and
/// fonts follow the app's Stitch light-mode tokens through
/// [Theme.of(context)] / [AppFonts]: in English and French the title renders
/// in Source Serif 4 and the body in Manrope; Arabic and Urdu pick up their
/// per-locale families (Amiri / Nafees Nastaleeq) automatically.
library;

import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/prayer_names.dart';

/// Shows the "Why this time?" sheet for [prayer] with its [timeLabel].
Future<void> showWhyTimeSheet({
  required BuildContext context,
  required Prayer prayer,
  required String timeLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => WhyTimeSheet(prayer: prayer, timeLabel: timeLabel),
  );
}

/// "Why this time?" bottom sheet: prayer name + time up top, the
/// rule-registry explanation as the body, the registry note at the bottom.
class WhyTimeSheet extends StatelessWidget {
  final Prayer prayer;
  final String timeLabel;

  const WhyTimeSheet({super.key, required this.prayer, required this.timeLabel});

  /// The rule-registry explanation for [prayer], verbatim from
  /// docs/MALIKI_RULES.md (via l10n). Static so it stays unit-testable.
  static String bodyFor(Prayer prayer, AppLocalizations l10n) {
    switch (prayer) {
      case Prayer.fajr:
        return l10n.whyFajr;
      case Prayer.sunrise:
        return l10n.whySunrise;
      case Prayer.dhuhr:
        return l10n.whyDhuhr;
      case Prayer.asr:
        return l10n.whyAsr;
      case Prayer.maghrib:
        return l10n.whyMaghrib;
      case Prayer.isha:
        return l10n.whyIsha;
    }
  }

  /// The timetable's display name for [prayer] (localized label).
  static String labelFor(Prayer prayer, AppLocalizations l10n) {
    switch (prayer) {
      case Prayer.fajr:
        return l10n.prayerFajr;
      case Prayer.sunrise:
        return l10n.prayerSunrise;
      case Prayer.dhuhr:
        return l10n.prayerDhuhr;
      case Prayer.asr:
        return l10n.prayerAsr;
      case Prayer.maghrib:
        return l10n.prayerMaghrib;
      case Prayer.isha:
        return l10n.prayerIsha;
    }
  }

  /// The timetable's Arabic companion name for [prayer].
  static String arabicFor(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
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
              l10n.whySheetTitle.toUpperCase(),
              style: AppFonts.eyebrow(context).copyWith(
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 12),
            // Prayer name + its time, prominently: large serif pair.
            Row(
              children: [
                Expanded(
                  child: Text(
                    pairedPrayerName(
                        context, labelFor(prayer, l10n), arabicFor(prayer)),
                    style: theme.textTheme.displaySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  timeLabel,
                  style: AppFonts.timeLabel(context).copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Gold rule between the header pair and the explanation.
            Divider(height: 1, color: scheme.tertiaryFixedDim),
            const SizedBox(height: 12),
            Text(
              bodyFor(prayer, l10n),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.whySheetNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
