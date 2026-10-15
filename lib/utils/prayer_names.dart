/// Helpers for displaying prayer names alongside their Arabic form.
///
/// Throughout the UI a prayer is shown as "localized name + Arabic name"
/// (e.g. "Asr  العصر"). In the Arabic locale the localized name already IS
/// the Arabic name, so rendering both would double it ("العصر العصر").
library;

import 'package:flutter/widgets.dart';

/// True when the current locale's prayer names are already Arabic, so the
/// standalone Arabic companion text must be omitted.
bool omitArabicCompanion(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

/// Single-string form of a "localized + Arabic" name pair. Returns just the
/// localized name in the Arabic locale.
String pairedPrayerName(
        BuildContext context, String localized, String arabic) =>
    omitArabicCompanion(context) ? localized : '$localized  $arabic';
