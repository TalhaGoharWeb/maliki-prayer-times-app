library;

/// Localized Hijri-date helpers shared by the home and monthly screens.
///
/// The English transliteration names live in `lib/utils/hijri.dart`
/// ([hijriMonthNames]); the ARB files carry the month names for every
/// supported UI locale.

import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/utils/hijri.dart';

/// Localized name of Hijri [month] (1..12).
String hijriMonthName(AppLocalizations l10n, int month) => switch (month) {
      1 => l10n.hijriMonth1,
      2 => l10n.hijriMonth2,
      3 => l10n.hijriMonth3,
      4 => l10n.hijriMonth4,
      5 => l10n.hijriMonth5,
      6 => l10n.hijriMonth6,
      7 => l10n.hijriMonth7,
      8 => l10n.hijriMonth8,
      9 => l10n.hijriMonth9,
      10 => l10n.hijriMonth10,
      11 => l10n.hijriMonth11,
      12 => l10n.hijriMonth12,
      _ => hijriMonthNames[(month - 1).clamp(0, 11)],
    };

/// Localized rendering of [date], e.g. "27 Rabi’ al-Awwal 1447 AH".
String formatHijriDate(AppLocalizations l10n, HijriDate date) =>
    l10n.hijriDateFormat(
        '${date.day}', hijriMonthName(l10n, date.month), '${date.year}');
