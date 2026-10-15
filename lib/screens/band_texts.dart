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

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
String bandIkhtiyariText(
    AppLocalizations l10n, String arabicName, PrayerTimes times) =>
    switch (arabicName) {
      'الصبح' => l10n.subhPreferredInfo,
      'الظهر' => l10n.dhuhrPreferred(_hhmm(times.asr)),
      'العصر' => l10n.asrPreferredInfo,
      'المغرب' => l10n.maghribPreferred(_hhmm(times.maghribPreferredEnd)),
      'العشاء' => l10n.ishaPreferred(
          _hhmm(times.ishaPreferredEnd), _hhmm(times.ishaMidnightVariant)),
      _ => '',
    };

/// Localized daruri (necessity-time) band text, with the band's computed
/// clock time embedded where the band is computable.
String bandDaruriText(
    AppLocalizations l10n, String arabicName, PrayerTimes times) =>
    switch (arabicName) {
      'الصبح' => l10n.subhNecessityEnd(_hhmm(times.sunrise)),
      'الظهر' => l10n.dhuhrNecessityEnd(_hhmm(times.maghrib)),
      'العصر' => l10n.asrNecessityEnd(_hhmm(times.maghrib)),
      'المغرب' => l10n.maghribNecessityInfo,
      'العشاء' => l10n.ishaNecessityInfo,
      _ => '',
    };
