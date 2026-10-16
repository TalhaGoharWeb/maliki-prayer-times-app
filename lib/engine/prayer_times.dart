import 'dart:math' as math;

import 'coordinates.dart';
import 'prayer_profile.dart';

/// The five daily prayers plus sunrise (a timetable marker, not a prayer).
enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

/// One day's computed prayer times.
///
/// ## Time frame
/// All [DateTime] values are **wall-clock times in the frame of the
/// [timeZoneOffset] passed to [calculatePrayerTimes]**: the engine computes
/// each solar event as a UTC instant, adds the offset, rounds to the nearest
/// minute, and returns the result as a UTC-kind [DateTime] whose fields
/// (hour, minute, …) are the wall-clock values. Differences and orderings
/// between returned times are exact; to recover true UTC instants, subtract
/// the offset. Times may fall on the adjacent civil date (e.g. an Isha that
/// lands after midnight belongs to the night that began on [date]'s Maghrib).
/// Pass `now` to [nextPrayer] in the same frame, e.g.
/// `DateTime.now().toUtc().add(offset)`.
///
/// ## Profile status
/// The calculation profile is PROPOSED — pending scholarly review.
class PrayerTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  /// First third of the night (Maliki ikhtiyari end of Isha):
  /// sunset + (tomorrowFajr − sunset) / 3, anchored on the RAW solar sunset —
  /// never on the ihtiyat-shifted Maghrib — so the fiqh boundary does not
  /// move when the user toggles the operational ihtiyat convention.
  /// Informational marker.
  final DateTime ishaPreferredEnd;

  /// Ibn Habib midnight variant (spec section 3.8):
  /// sunset + (sunrise − sunset) / 2 — the midpoint between today's sunset
  /// and tomorrow's sunrise. Labeled alternative — never an adhan time.
  final DateTime ishaMidnightVariant;

  /// Raw sunset + 20 minutes informational band — NOT an adhan time.
  /// Anchored on the raw solar sunset (no ihtiyat) so the displayed end
  /// matches the "about 15-20 minutes after sunset" band text.
  final DateTime maghribPreferredEnd;

  /// True when any high-latitude fallback approximation was used; the affected
  /// times are rule-applied estimates and must be labeled as such in the UI.
  final bool highLatitudeFallback;

  final PrayerProfile profile;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.ishaPreferredEnd,
    required this.ishaMidnightVariant,
    required this.maghribPreferredEnd,
    required this.highLatitudeFallback,
    required this.profile,
  });

  DateTime timeFor(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return fajr;
      case Prayer.sunrise:
        return sunrise;
      case Prayer.dhuhr:
        return dhuhr;
      case Prayer.asr:
        return asr;
      case Prayer.maghrib:
        return maghrib;
      case Prayer.isha:
        return isha;
    }
  }

  /// The next prayer strictly after [now] (sunrise is not a prayer, so it is
  /// skipped). Wraps to [Prayer.fajr] when no prayer remains today; the caller
  /// computes the next day's times for the clock time. [now] must be in the
  /// same wall-clock frame as the returned times.
  Prayer nextPrayer(DateTime now) {
    for (final p in const [
      Prayer.fajr,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ]) {
      if (timeFor(p).isAfter(now)) return p;
    }
    return Prayer.fajr;
  }
}

// ---------------------------------------------------------------------------
// Solar mathematics (standard formulation: Meeus, Astronomical Algorithms,
// as formulated by the adhan libraries — see ATTRIBUTION.md).
// ---------------------------------------------------------------------------

double _toRad(double degrees) => degrees * math.pi / 180.0;
double _toDeg(double radians) => radians * 180.0 / math.pi;
double _sinDeg(double d) => math.sin(_toRad(d));
double _cosDeg(double d) => math.cos(_toRad(d));
double _tanDeg(double d) => math.tan(_toRad(d));
double _asinDeg(double x) => _toDeg(math.asin(x.clamp(-1.0, 1.0)));
double _acosDeg(double x) => _toDeg(math.acos(x.clamp(-1.0, 1.0)));
double _atanDeg(double x) => _toDeg(math.atan(x));
double _atan2Deg(double y, double x) => _toDeg(math.atan2(y, x));

double _norm360(double v) {
  var r = v % 360.0;
  if (r < 0) r += 360.0;
  return r;
}

double _norm24(double v) {
  var r = v % 24.0;
  if (r < 0) r += 24.0;
  return r;
}

/// Normalize an equation-of-time value to (−12, 12] hours.
double _normEqt(double v) {
  var r = v % 24.0;
  if (r <= -12.0) {
    r += 24.0;
  } else if (r > 12.0) {
    r -= 24.0;
  }
  return r;
}

/// Raw solar events for one civil date. Values are UTC hours measured from
/// 00:00 UTC of [date]; they may spill outside [0, 24). A null event means the
/// sun never reaches that altitude on this date (high latitude).
class _SolarEvents {
  final double declinationDeg;
  final double? fajrUtc;
  final double? sunriseUtc;
  final double noonUtc;
  final double? asrUtc;
  final double? sunsetUtc;
  final double? ishaUtc;

  const _SolarEvents({
    required this.declinationDeg,
    required this.fajrUtc,
    required this.sunriseUtc,
    required this.noonUtc,
    required this.asrUtc,
    required this.sunsetUtc,
    required this.ishaUtc,
  });
}

_SolarEvents _solarEvents(
    Coordinates coordinates, PrayerProfile profile, DateTime date) {
  final latitude = coordinates.latitude;

  // Julian date at 0h UTC of `date`.
  final jd = DateTime.utc(date.year, date.month, date.day)
              .millisecondsSinceEpoch /
          86400000.0 +
      2440587.5;
  final d = jd - 2451545.0;

  final g = _norm360(357.529 + 0.98560028 * d); // mean anomaly
  final q = _norm360(280.459 + 0.98564736 * d); // mean longitude
  final l = _norm360(
      q + 1.915 * _sinDeg(g) + 0.020 * _sinDeg(2 * g)); // ecliptic longitude
  final e = 23.439 - 0.00000036 * d; // obliquity of the ecliptic
  final raHours =
      _norm360(_atan2Deg(_cosDeg(e) * _sinDeg(l), _cosDeg(l))) / 15.0;
  final decl = _asinDeg(_sinDeg(e) * _sinDeg(l));
  final eqt = _normEqt(q / 15.0 - raHours); // equation of time, hours

  // Solar noon in UTC hours.
  final noon = _norm24(12.0 - eqt - coordinates.longitude / 15.0);

  final sinLat = _sinDeg(latitude);
  final cosLat = _cosDeg(latitude);
  final sinDecl = _sinDeg(decl);
  final cosDecl = _cosDeg(decl);

  /// UTC hour of the moment the sun's center reaches [altitudeDeg]
  /// (negative = below horizon); morning side if [morning], else evening.
  /// Returns null when the event does not occur on this date.
  double? eventUtc(double altitudeDeg, bool morning) {
    final denom = cosLat * cosDecl;
    if (denom == 0.0) return null;
    final cosH = (_sinDeg(altitudeDeg) - sinLat * sinDecl) / denom;
    // A small epsilon keeps events that just graze the horizon computable.
    if (cosH > 1.0 + 1e-9 || cosH < -1.0 - 1e-9) return null;
    final h = _acosDeg(cosH) / 15.0; // hour angle, hours
    return morning ? noon - h : noon + h;
  }

  // Asr altitude from the shadow rule: altitude = arccot(t + tan(|lat − decl|)).
  final asrAltitudeDeg =
      _atanDeg(1.0 / (profile.asrShadowFactor + _tanDeg((latitude - decl).abs())));

  return _SolarEvents(
    declinationDeg: decl,
    fajrUtc: eventUtc(-profile.fajrAngle, true),
    sunriseUtc: eventUtc(-profile.solarDepression, true),
    noonUtc: noon,
    asrUtc: eventUtc(asrAltitudeDeg, false),
    sunsetUtc: eventUtc(-profile.solarDepression, false),
    ishaUtc: eventUtc(-profile.ishaAngle, false),
  );
}

/// Computes one day of prayer times.
///
/// * [coordinates] — observer location.
/// * [date] — the local calendar day; only year/month/day are used.
/// * [timeZoneOffset] — added to every UTC solar instant to obtain the
///   wall-clock frame (e.g. [Duration.zero] for Nouakchott, UTC+0).
/// * [profile] — calculation profile (PROPOSED — pending scholarly review).
///
/// High-latitude fallback ([HighLatitudeRule.middleOfNight]): when Fajr or
/// Isha never occur (the sun never reaches the configured depression), they
/// are estimated from the night portions — fajr = sunrise − night/2,
/// isha = sunset + night/2 — and [PrayerTimes.highLatitudeFallback] is set.
/// When the sun never reaches the horizon at all (polar day/night: sunrise
/// or sunset null), the horizon is estimated as noon±6 and the WHOLE day is
/// forced onto this coherent estimate path — real twilight crossings are
/// never mixed with synthetic horizon times. Fallback times are always
/// finite and keep the day ordering sane; they must be labeled as estimates
/// wherever displayed.
PrayerTimes calculatePrayerTimes({
  required Coordinates coordinates,
  required DateTime date,
  required Duration timeZoneOffset,
  PrayerProfile profile = PrayerProfiles.defaultProfile,
}) {
  final base = DateTime.utc(date.year, date.month, date.day);
  final today = _solarEvents(coordinates, profile, base);
  final tomorrow =
      _solarEvents(coordinates, profile, base.add(const Duration(days: 1)));
  final yesterday =
      _solarEvents(coordinates, profile, base.subtract(const Duration(days: 1)));

  // All values below are UTC hours on ONE absolute timeline measured from
  // `base` (00:00 UTC of `date`). `_solarEvents` returns hours relative to
  // its own date's 00:00, so yesterday's events shift by −24 and tomorrow's
  // by +24. Mixing raw per-date hours here would corrupt every night
  // interval that crosses a civil-date boundary.
  var highLatitudeFallback = false;

  // Day-boundary events. If the sun never reaches the horizon (polar
  // day/night), estimate around solar noon and flag the fallback.
  double sunriseUtc;
  if (today.sunriseUtc != null) {
    sunriseUtc = today.sunriseUtc!;
  } else {
    highLatitudeFallback = true;
    sunriseUtc = today.noonUtc - 6.0;
  }
  double sunsetUtc;
  if (today.sunsetUtc != null) {
    sunsetUtc = today.sunsetUtc!;
  } else {
    highLatitudeFallback = true;
    sunsetUtc = today.noonUtc + 6.0;
  }

  // E-01: when the sun never reaches the horizon (polar day/night), the
  // horizon times above are synthetic (noon±6) and the whole day must use
  // the coherent estimate path. Real twilight crossings (Fajr/Isha) must
  // never be mixed with synthetic horizon times — that chimera misorders
  // the day (e.g. 80°N in December: Fajr 08:03 after "sunrise" 05:58).
  // The shadow-based Asr is likewise undefined when the sun never rises,
  // so it takes the midpoint estimate on this path too.
  final polarDay = today.sunriseUtc == null || today.sunsetUtc == null;

  final dhuhrUtc = today.noonUtc + profile.dhuhrIhtiyatMinutes / 60.0;
  final maghribUtc = sunsetUtc + profile.maghribIhtiyatMinutes / 60.0;

  // Fajr: middle-of-night fallback when the dawn depression never occurs —
  // or on the polar path, where even a real twilight crossing is ignored in
  // favour of the coherent estimate (see above).
  double fajrUtc;
  if (today.fajrUtc != null && !polarDay) {
    fajrUtc = today.fajrUtc!;
  } else {
    highLatitudeFallback = true;
    final prevSunsetAbs = yesterday.sunsetUtc == null
        ? sunriseUtc - 12.0
        : yesterday.sunsetUtc! - 24.0;
    var night = sunriseUtc - prevSunsetAbs;
    if (night <= 0 || night.isNaN) night = 12.0;
    fajrUtc = sunriseUtc - night / 2.0;
  }

  // Asr: midpoint fallback if the shadow altitude is never reached — or on
  // the polar path, where the shadow formula has no real sun to work with.
  double asrUtc;
  if (!polarDay &&
      today.asrUtc != null &&
      today.asrUtc! > dhuhrUtc &&
      today.asrUtc! < maghribUtc) {
    asrUtc = today.asrUtc!;
  } else {
    highLatitudeFallback = true;
    asrUtc = (dhuhrUtc + maghribUtc) / 2.0;
  }

  // The night interval (maghrib → next true dawn) anchors the Isha markers.
  // Tomorrow's events are shifted +24 onto the absolute timeline.
  //
  // ANCHOR RULE (E-05): the fiqh night is measured from the RAW solar sunset
  // (sunsetUtc), never from the ihtiyat-shifted maghribUtc. Ihtiyat is a
  // user-toggleable operational convention; fiqh boundaries (third of night,
  // midnight variant) must not shift when it is toggled. The displayed
  // Maghrib itself keeps the ihtiyat — that is disclosed in settings.
  double tomorrowFajrUtc;
  if (tomorrow.fajrUtc != null) {
    tomorrowFajrUtc = tomorrow.fajrUtc! + 24.0;
  } else {
    highLatitudeFallback = true;
    if (tomorrow.sunriseUtc == null) {
      tomorrowFajrUtc = maghribUtc + 12.0;
    } else {
      final tomorrowSunriseAbs = tomorrow.sunriseUtc! + 24.0;
      var night = tomorrowSunriseAbs - sunsetUtc;
      if (night <= 0 || night.isNaN) night = 12.0;
      tomorrowFajrUtc = tomorrowSunriseAbs - night / 2.0;
    }
  }
  var night = tomorrowFajrUtc - sunsetUtc;
  if (night <= 0 || night.isNaN) night = 12.0;

  double ishaUtc;
  if (today.ishaUtc != null && !polarDay) {
    ishaUtc = today.ishaUtc!;
  } else {
    highLatitudeFallback = true;
    ishaUtc = sunsetUtc + night / 2.0;
  }

  var ishaPreferredEndUtc = sunsetUtc + night / 3.0;
  if (ishaPreferredEndUtc <= ishaUtc) {
    // Can only happen on the fallback path: the estimated Isha sits at/after
    // the third-of-night marker. Keep the marker after the estimated Isha so
    // the day's ordering stays sane.
    ishaPreferredEndUtc = ishaUtc + 30.0 / 60.0;
    if (ishaPreferredEndUtc >= tomorrowFajrUtc) {
      ishaPreferredEndUtc = (ishaUtc + tomorrowFajrUtc) / 2.0;
    }
  }
  // Ibn Habib midnight variant (spec section 3.8): the midpoint between
  // today's sunset and tomorrow's sunrise. (An earlier draft used
  // maghrib + (tomorrowFajr − maghrib) / 2; corrected to the spec formula.)
  double ishaMidnightVariantUtc;
  if (tomorrow.sunriseUtc != null) {
    final tomorrowSunriseAbs = tomorrow.sunriseUtc! + 24.0;
    ishaMidnightVariantUtc =
        sunsetUtc + (tomorrowSunriseAbs - sunsetUtc) / 2.0;
  } else {
    highLatitudeFallback = true;
    ishaMidnightVariantUtc = sunsetUtc + 6.0;
  }
  // E-04: the ~15-20 minute Maghrib band is measured from the raw sunset,
  // so the displayed end is sunset + 20 min (previously it stacked the
  // +20 min on the ihtiyat-shifted Maghrib, showing sunset + 21 min).
  final maghribPreferredEndUtc = sunsetUtc + 20.0 / 60.0;

  // UTC instant → wall clock in the offset frame → nearest minute.
  DateTime wall(double utcHours) {
    final instantMs =
        base.millisecondsSinceEpoch + (utcHours * 3600000.0).round();
    final wallMs = instantMs + timeZoneOffset.inMilliseconds;
    final roundedMinutes = (wallMs / 60000.0).round();
    return DateTime.fromMillisecondsSinceEpoch(roundedMinutes * 60000,
        isUtc: true);
  }

  return PrayerTimes(
    fajr: wall(fajrUtc),
    sunrise: wall(sunriseUtc),
    dhuhr: wall(dhuhrUtc),
    asr: wall(asrUtc),
    maghrib: wall(maghribUtc),
    isha: wall(ishaUtc),
    ishaPreferredEnd: wall(ishaPreferredEndUtc),
    ishaMidnightVariant: wall(ishaMidnightVariantUtc),
    maghribPreferredEnd: wall(maghribPreferredEndUtc),
    highLatitudeFallback: highLatitudeFallback,
    profile: profile,
  );
}
