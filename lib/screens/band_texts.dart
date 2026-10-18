library;

/// Localized text for the Maliki two-tier fiqh bands.
///
/// `malikiPrayerBands()` (in `lib/fiqh/maliki_rules.dart`) is pure Dart and
/// carries English text; these helpers build the localized equivalents for
/// the home and monthly screens from the ARB templates, embedding the same
/// computed clock times. Bands are identified by their Arabic name
/// (`PrayerBand.arabicName`: الصبح، الظهر، العصر، المغرب، العشاء), which is
/// stable regardless of band order. An unrecognized band falls back to the
/// band's own English text so the UI never renders blank.

import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/utils/digits.dart';

/// Prayer-time rendering shared with the rest of the app: 12/24-hour
/// per the user's setting, locale digits via [formatPrayerTime].
String _hhmm(AppLocalizations l10n, DateTime t, bool use24Hour) =>
    formatPrayerTime(t, l10n.localeName, use24Hour: use24Hour);

/// Localized display name for a band (e.g. "Subh" / "صبح" / "الصبح").
String bandDisplayName(AppLocalizations l10n, String arabicName) =>
    switch (arabicName) {
      'الصبح' => l10n.bandNameSubh,
      'الظهر' => l10n.bandNameDhuhr,
      'العصر' => l10n.bandNameAsr,
      'المغرب' => l10n.bandNameMaghrib,
      'العشاء' => l10n.bandNameIsha,
      _ => arabicName,
    };

/// Localized ikhtiyari (preferred/choice-time) band text, with the band's
/// computed clock time embedded where the band is computable.
String bandIkhtiyariText(AppLocalizations l10n, String arabicName,
        PrayerTimes times,
        {required bool use24Hour}) =>
    switch (arabicName) {
      'الصبح' => l10n.subhPreferredInfo,
      'الظهر' => l10n.dhuhrPreferred(_hhmm(l10n, times.asr, use24Hour)),
      'العصر' => l10n.asrPreferredInfo,
      'المغرب' =>
        l10n.maghribPreferred(_hhmm(l10n, times.maghribPreferredEnd, use24Hour)),
      'العشاء' => l10n.ishaPreferred(
          _hhmm(l10n, times.ishaPreferredEnd, use24Hour),
          _hhmm(l10n, times.ishaMidnightVariant, use24Hour)),
      _ => '',
    };

/// Localized daruri (necessity-time) band text, with the band's computed
/// clock time embedded where the band is computable.
String bandDaruriText(AppLocalizations l10n, String arabicName,
        PrayerTimes times,
        {required bool use24Hour}) =>
    switch (arabicName) {
      'الصبح' => l10n.subhNecessityEnd(_hhmm(l10n, times.sunrise, use24Hour)),
      'الظهر' => l10n.dhuhrNecessityEnd(_hhmm(l10n, times.maghrib, use24Hour)),
      'العصر' => l10n.asrNecessityEnd(_hhmm(l10n, times.maghrib, use24Hour)),
      'المغرب' => l10n.maghribNecessityInfo,
      'العشاء' => l10n.ishaNecessityInfo,
      _ => '',
    };
