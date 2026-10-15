/// Helpers for displaying prayer names alongside their Arabic form.
///
/// Throughout the UI a prayer is shown as "localized name + Arabic name"
/// (e.g. "Asr  العصر"). In the Arabic locale the localized name already IS
/// the Arabic name, so rendering both would double it ("العصر العصر").
/// In the Urdu locale the Urdu name plus the Arabic companion reads as the
/// same name twice ("فجر الفجر"), so the companion is omitted there too —
/// user directive 2026-10-15. English/French keep the pair: the
/// transliteration plus the Arabic form is genuinely informative.
library;

import 'package:flutter/widgets.dart';

/// True when the current locale's prayer names make the standalone Arabic
/// companion redundant, so it must be omitted: Arabic (identical) and Urdu
/// (reads as the same name twice).
bool omitArabicCompanion(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return code == 'ar' || code == 'ur';
}

/// Single-string form of a "localized + Arabic" name pair. Returns just the
/// localized name in the Arabic and Urdu locales.
String pairedPrayerName(
        BuildContext context, String localized, String arabic) =>
    omitArabicCompanion(context) ? localized : '$localized  $arabic';
