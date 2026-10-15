/// Fiqh-rule layer for the Maliki prayer-times app.
///
/// This file is PURE Dart presentation logic over the computed times: it
/// contains NO astronomical math. It maps each prayer to its Maliki
/// two-tier description (waqt al-ikhtiyar — the time of choice, and waqt
/// al-darura — the time of necessity) per the jurisprudential rule matrix
/// (deliverable 04).
///
/// Every band states whether its boundary is a COMPUTED clock time or an
/// INFORMATIONAL label. Informational bands (isfar, isfirar, the Maghrib
/// ~15-20 minute band, the midnight Isha alternative) are never presented
/// as adhan times and must never drive a countdown.
///
/// Nothing here is a ruling issued by this app; the calculation profile is
/// PROPOSED and pending scholarly review.
library;

import 'package:malikiprayertimes/engine/prayer_times.dart';

/// One prayer's two-tier fiqh display description.
class PrayerBand {
  /// Display name, e.g. "Subh".
  final String prayerName;

  /// Arabic name, e.g. "الصبح".
  final String arabicName;

  /// Preferred (ikhtiyari) boundary text, with a computed time embedded
  /// when [ikhtiyariIsComputed] is true.
  final String ikhtiyariText;

  /// True when the ikhtiyari boundary is a computed clock time; false when
  /// it is an informational band with no clock time.
  final bool ikhtiyariIsComputed;

  /// Necessity (daruri) absolute-end text, with a computed time embedded
  /// when [daruriIsComputed] is true.
  final String daruriText;

  /// True when the daruri end is a computed clock time; false when it is
  /// an informational label (e.g. "next true dawn", not computed here).
  final bool daruriIsComputed;

  const PrayerBand({
    required this.prayerName,
    required this.arabicName,
    required this.ikhtiyariText,
    required this.ikhtiyariIsComputed,
    required this.daruriText,
    required this.daruriIsComputed,
  });
}

String _hhmm(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// The Maliki two-tier bands for one day's computed times.
///
/// Mapping per the jurisprudential rule matrix (deliverable 04):
/// * Subh: ikhtiyari ends at isfar — INFORMATIONAL, never a clock time;
///   daruri ends at sunrise — computed.
/// * Dhuhr: ikhtiyari ends where Asr begins (first mithl) — computed;
///   daruri ends at sunset — computed.
/// * Asr: ikhtiyari ends at isfirar (yellowing) — INFORMATIONAL band;
///   daruri ends at sunset — computed.
/// * Maghrib: mukhtar is narrow, ~15-20 minutes — INFORMATIONAL band,
///   never an adhan time; daruri runs to true dawn — informational here
///   (the next dawn belongs to the following day's times).
/// * Isha: ikhtiyari ends at the first third of the night — computed;
///   the midnight variant is the labeled Ibn Habib alternative — computed
///   but informational; daruri runs to true dawn — informational here.
List<PrayerBand> malikiPrayerBands(PrayerTimes times) {
  return [
    PrayerBand(
      prayerName: 'Subh',
      arabicName: 'الصبح',
      ikhtiyariText:
          'Preferred until isfar (clear brightening of the horizon) — informational band; no clock time is assigned to it.',
      ikhtiyariIsComputed: false,
      daruriText: 'Absolute end (for those with excuse): sunrise, '
          '${_hhmm(times.sunrise)}.',
      daruriIsComputed: true,
    ),
    PrayerBand(
      prayerName: 'Dhuhr',
      arabicName: 'الظهر',
      ikhtiyariText: 'Preferred until Asr begins (first mithl), '
          '${_hhmm(times.asr)}.',
      ikhtiyariIsComputed: true,
      daruriText: 'Absolute end (for those with excuse): sunset, '
          '${_hhmm(times.maghrib)}.',
      daruriIsComputed: true,
    ),
    PrayerBand(
      prayerName: 'Asr',
      arabicName: 'العصر',
      ikhtiyariText:
          'Preferred until isfirar (yellowing of the sun) — informational band; shown approximately, never an adhan time.',
      ikhtiyariIsComputed: false,
      daruriText: 'Absolute end (for those with excuse): sunset, '
          '${_hhmm(times.maghrib)}.',
      daruriIsComputed: true,
    ),
    PrayerBand(
      prayerName: 'Maghrib',
      arabicName: 'المغرب',
      ikhtiyariText:
          'Preferred window is narrow — about 15-20 minutes after sunset '
          '(until ${_hhmm(times.maghribPreferredEnd)}). Informational band; '
          'not an adhan time.',
      ikhtiyariIsComputed: false,
      daruriText: 'Absolute end (for those with excuse): true dawn — '
          'not computed on this screen.',
      daruriIsComputed: false,
    ),
    PrayerBand(
      prayerName: 'Isha',
      arabicName: 'العشاء',
      ikhtiyariText: 'Preferred until the first third of the night, '
          '${_hhmm(times.ishaPreferredEnd)}. Labeled alternative: the Ibn '
          'Habib view extends the preferred time to midnight, '
          '${_hhmm(times.ishaMidnightVariant)}.',
      ikhtiyariIsComputed: true,
      daruriText: 'Absolute end (for those with excuse): true dawn — '
          'not computed on this screen.',
      daruriIsComputed: false,
    ),
  ];
}
