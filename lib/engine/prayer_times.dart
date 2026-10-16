import 'dart:math' as math;

import 'coordinates.dart';
import 'high_latitude.dart';
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

  /// Raw solar sunset on the (dip-corrected) horizon — informational
  /// marker, like [sunrise]. The displayed Maghrib adds the profile's
  /// ihtiyat on top of this instant.
  final DateTime sunset;
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

  /// The fallback method in effect when [highLatitudeFallback] is true;
  /// null on a fully computed day. The UI must NAME this method wherever
  /// fallback times are shown — the default is never applied silently.
  final HighLatitudeFallback? fallbackMethod;

  /// When [fallbackMethod] is [HighLatitudeFallback.nearestDay], the civil
  /// date the displayed times were borrowed from. Null otherwise. The UI
  /// must show this date next to the borrowed times.
  final DateTime? nearestDaySourceDate;

  final PrayerProfile profile;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.sunset,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.ishaPreferredEnd,
    required this.ishaMidnightVariant,
    required this.maghribPreferredEnd,
    required this.highLatitudeFallback,
    required this.profile,
    this.fallbackMethod,
    this.nearestDaySourceDate,
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

/// Dip of the visible horizon below the geometric horizontal, in degrees,
/// for an observer [elevationMeters] above sea level.
///
/// Standard astronomical dip formula: `dip = 0.0293 × √h` (h in meters),
/// accounting for mean atmospheric refraction. A higher observer sees the
/// sun rise earlier and set later; the horizon zenith grows from the
/// profile's `solarDepression` (0.833°) by this dip. Twilight (Fajr/Isha)
/// angles and the Asr shadow rule are unaffected: they reference the sun's
/// depression below the geometric horizon, not the visible one.
///
/// Negative elevations (below sea level) are clamped to zero — the formula
/// has no meaning there and the sea-level horizon is the honest default.
double elevationDipDegrees(double elevationMeters) {
  if (elevationMeters <= 0 || elevationMeters.isNaN) return 0.0;
  return 0.0293 * math.sqrt(elevationMeters);
}

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

_SolarEvents _solarEvents(Coordinates coordinates, PrayerProfile profile,
    DateTime date, double elevationMeters) {
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

  // Horizon events (sunrise/sunset) use the dip-corrected zenith: the
  // profile's solar depression (0.833° = upper limb + refraction) plus the
  // observer-elevation dip. Twilight and shadow events are unaffected.
  final horizonDepression = profile.solarDepression +
      elevationDipDegrees(elevationMeters);

  return _SolarEvents(
    declinationDeg: decl,
    fajrUtc: eventUtc(-profile.fajrAngle, true),
    sunriseUtc: eventUtc(-horizonDepression, true),
    noonUtc: noon,
    asrUtc: eventUtc(asrAltitudeDeg, false),
    sunsetUtc: eventUtc(-horizonDepression, false),
    ishaUtc: eventUtc(-profile.ishaAngle, false),
  );
}

/// True when the sun stays above the horizon all day (polar day) rather
/// than below it (polar night): the transit altitude decides, not a guess.
bool _isPolarDay(
    double latitudeDeg, double declinationDeg, double horizonDepression) {
  // Altitude at transit: 90° − |φ − δ|.
  final transitAltitude = 90.0 - (latitudeDeg - declinationDeg).abs();
  return transitAltitude > -horizonDepression;
}

/// The nearest civil date within ±183 days on which every solar event has
/// a solution (sunrise, sunset, Fajr, Isha all non-null). The half-year
/// window is deliberate: at high latitudes twilight can be unsolvable for
/// months (e.g. Tromsø in summer), so a ±30-day window would almost never
/// find a day where the convention is actually needed. Past days are
/// preferred on equidistant ties. Null when nothing is found (the poles,
/// where no day ever has a solution).
DateTime? _nearestSolvableDay(Coordinates coordinates, PrayerProfile profile,
    DateTime base, double elevationMeters) {
  for (var d = 1; d <= 183; d++) {
    for (final date in [
      base.subtract(Duration(days: d)),
      base.add(Duration(days: d)),
    ]) {
      final events =
          _solarEvents(coordinates, profile, date, elevationMeters);
      if (events.sunriseUtc != null &&
          events.sunsetUtc != null &&
          events.fajrUtc != null &&
          events.ishaUtc != null) {
        return DateTime(date.year, date.month, date.day);
      }
    }
  }
  return null;
}

/// Computes one day of prayer times.
///
/// Returns [PrayerTimesComputed] on success or [PrayerTimesNoSolution] when
/// the date/location has no solar frame (polar day/night) and no usable
/// fallback is selected. A calculation failure NEVER produces a
/// plausible-but-unsupported time.
///
/// * [coordinates] — observer location.
/// * [date] — the local calendar day; only year/month/day are used.
/// * [timeZoneOffset] — added to every UTC solar instant to obtain the
///   wall-clock frame (e.g. [Duration.zero] for Nouakchott, UTC+0).
/// * [profile] — calculation profile (PROPOSED — pending scholarly review).
/// * [elevationMeters] — observer elevation above sea level, in meters.
///   Applies the horizon dip correction to sunrise/sunset only (the zenith
///   grows by `0.0293 × √h` degrees); Fajr/Isha twilight angles, Dhuhr, and
///   the Asr shadow rule are unaffected. Defaults to 0 (sea-level horizon).
/// * [fallback] — the high-latitude fallback method applied when a twilight
///   event has no solution. Default [HighLatitudeFallback.middleOfNight]
///   (per adhan `recommended()`). Every method is a software/institutional
///   convention — NEVER a Maliki ruling — and the caller must surface
///   [PrayerTimes.fallbackMethod] wherever fallback times are shown.
///
/// High-latitude behavior (D5 §3.7):
/// * Persistent twilight (a real night exists but the twilight angle never
///   occurs): Fajr/Isha are estimated from the night frame with the chosen
///   method; [PrayerTimes.highLatitudeFallback] is set and the method is
///   named on [PrayerTimes.fallbackMethod].
/// * No night frame at all (polar day/night): the day has no solution and
///   the result is [PrayerTimesNoSolution] — UNLESS [fallback] is
///   [HighLatitudeFallback.nearestDay], in which case the whole day is
///   borrowed from the nearest solvable day and the source date is
///   recorded on [PrayerTimes.nearestDaySourceDate] for the UI to show.
PrayerTimesResult calculatePrayerTimes({
  required Coordinates coordinates,
  required DateTime date,
  required Duration timeZoneOffset,
  PrayerProfile profile = PrayerProfiles.defaultProfile,
  double elevationMeters = 0.0,
  HighLatitudeFallback fallback = HighLatitudeFallback.middleOfNight,
}) {
  final base = DateTime.utc(date.year, date.month, date.day);
  final today = _solarEvents(coordinates, profile, base, elevationMeters);
  final tomorrow = _solarEvents(
      coordinates, profile, base.add(const Duration(days: 1)), elevationMeters);
  final yesterday = _solarEvents(coordinates, profile,
      base.subtract(const Duration(days: 1)), elevationMeters);

  // All values below are UTC hours on ONE absolute timeline measured from
  // `base` (00:00 UTC of `date`). `_solarEvents` returns hours relative to
  // its own date's 00:00, so yesterday's events shift by −24 and tomorrow's
  // by +24. Mixing raw per-date hours here would corrupt every night
  // interval that crosses a civil-date boundary.

  // --- No night frame: the sun never reaches the horizon (polar day/night).
  // No fallback can be constructed from a nonexistent sunset/sunrise, so
  // the honest result is a typed no-solution — unless the user explicitly
  // chose the nearest-day convention.
  if (today.sunriseUtc == null || today.sunsetUtc == null) {
    final horizonDepression =
        profile.solarDepression + elevationDipDegrees(elevationMeters);
    final reason = _isPolarDay(coordinates.latitude, today.declinationDeg,
            horizonDepression)
        ? NoSolutionReason.polarDay
        : NoSolutionReason.polarNight;
    if (fallback == HighLatitudeFallback.nearestDay) {
      final src =
          _nearestSolvableDay(coordinates, profile, base, elevationMeters);
      if (src != null) {
        return _borrowedDay(
          coordinates: coordinates,
          sourceDate: src,
          timeZoneOffset: timeZoneOffset,
          profile: profile,
          elevationMeters: elevationMeters,
        );
      }
    }
    return PrayerTimesNoSolution(reason);
  }

  final sunriseUtc = today.sunriseUtc!;
  final sunsetUtc = today.sunsetUtc!;
  final dhuhrUtc = today.noonUtc + profile.dhuhrIhtiyatMinutes / 60.0;
  final maghribUtc = sunsetUtc + profile.maghribIhtiyatMinutes / 60.0;

  // The solar night each twilight event belongs to (D5 §3.7): Fajr's night
  // ends at today's sunrise; Isha's night starts at today's sunset.
  final prevSunsetAbs = yesterday.sunsetUtc == null
      ? sunriseUtc - 12.0
      : yesterday.sunsetUtc! - 24.0;
  var nightForFajr = sunriseUtc - prevSunsetAbs;
  if (nightForFajr <= 0 || nightForFajr.isNaN) nightForFajr = 12.0;
  final tomorrowSunriseAbs =
      tomorrow.sunriseUtc == null ? null : tomorrow.sunriseUtc! + 24.0;
  var nightForIsha = (tomorrowSunriseAbs ?? (sunsetUtc + 12.0)) - sunsetUtc;
  if (nightForIsha <= 0 || nightForIsha.isNaN) nightForIsha = 12.0;

  final fajrMissing = today.fajrUtc == null;
  final ishaMissing = today.ishaUtc == null;

  // Nearest-day is a whole-day convention: when any twilight event is
  // missing, borrow the entire day from the nearest solvable one. When no
  // solvable day exists within ±183 days (the poles), the default
  // middle-of-night convention stands in — still named honestly as the
  // method in effect.
  var effectiveFallback = fallback;
  if (fallback == HighLatitudeFallback.nearestDay &&
      (fajrMissing || ishaMissing)) {
    final src = _nearestSolvableDay(coordinates, profile, base, elevationMeters);
    if (src != null) {
      return _borrowedDay(
        coordinates: coordinates,
        sourceDate: src,
        timeZoneOffset: timeZoneOffset,
        profile: profile,
        elevationMeters: elevationMeters,
      );
    }
    effectiveFallback = HighLatitudeFallback.middleOfNight;
  }

  var highLatitudeFallback = false;
  HighLatitudeFallback? methodInEffect;

  double fajrUtc;
  double ishaUtc;
  if (fajrMissing || ishaMissing) {
    highLatitudeFallback = true;
    methodInEffect = effectiveFallback;
    switch (effectiveFallback) {
      case HighLatitudeFallback.middleOfNight:
        fajrUtc =
            fajrMissing ? sunriseUtc - nightForFajr / 2.0 : today.fajrUtc!;
        ishaUtc =
            ishaMissing ? sunsetUtc + nightForIsha / 2.0 : today.ishaUtc!;
      case HighLatitudeFallback.oneSeventhOfNight:
        fajrUtc =
            fajrMissing ? sunriseUtc - nightForFajr / 7.0 : today.fajrUtc!;
        ishaUtc =
            ishaMissing ? sunsetUtc + nightForIsha / 7.0 : today.ishaUtc!;
      case HighLatitudeFallback.angleBased:
        fajrUtc = fajrMissing
            ? sunriseUtc - (profile.fajrAngle / 60.0) * nightForFajr
            : today.fajrUtc!;
        ishaUtc = ishaMissing
            ? sunsetUtc + (profile.ishaAngle / 60.0) * nightForIsha
            : today.ishaUtc!;
      case HighLatitudeFallback.nearestDay:
        // Handled above: either borrowed already or degraded to
        // middle-of-night. Unreachable.
        fajrUtc = today.fajrUtc ?? (sunriseUtc - nightForFajr / 2.0);
        ishaUtc = today.ishaUtc ?? (sunsetUtc + nightForIsha / 2.0);
    }
  } else {
    fajrUtc = today.fajrUtc!;
    ishaUtc = today.ishaUtc!;
  }

  // Asr: midpoint fallback if the shadow altitude is never reached (or
  // falls outside the Dhuhr–Maghrib window). A separate software
  // convention — it does not change the named twilight method.
  double asrUtc;
  if (today.asrUtc != null &&
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
    if (tomorrowSunriseAbs == null) {
      tomorrowFajrUtc = maghribUtc + 12.0;
    } else {
      var night = tomorrowSunriseAbs - sunsetUtc;
      if (night <= 0 || night.isNaN) night = 12.0;
      tomorrowFajrUtc = tomorrowSunriseAbs - night / 2.0;
    }
  }
  // The night anchoring the first-third marker: sunset → true dawn when
  // tomorrow's Fajr is real; otherwise the solar night (sunset →
  // tomorrow's sunrise) is the honest proxy. The estimated fajr midpoint
  // must NOT be used here: on the fallback path it coincides with the
  // estimated Isha (both are night midpoints), which would collapse the
  // marker onto Isha and break the day ordering.
  final markerNightEndUtc = tomorrow.fajrUtc != null
      ? tomorrowFajrUtc
      : (tomorrowSunriseAbs ?? (sunsetUtc + 12.0));
  var night = markerNightEndUtc - sunsetUtc;
  if (night <= 0 || night.isNaN) night = 12.0;

  var ishaPreferredEndUtc = sunsetUtc + night / 3.0;
  if (ishaPreferredEndUtc <= ishaUtc) {
    // Can only happen on the fallback path: the estimated Isha sits at/after
    // the third-of-night marker. Keep the marker after the estimated Isha so
    // the day's ordering stays sane.
    ishaPreferredEndUtc = ishaUtc + 30.0 / 60.0;
    if (ishaPreferredEndUtc >= markerNightEndUtc) {
      ishaPreferredEndUtc = (ishaUtc + markerNightEndUtc) / 2.0;
    }
  }
  // Ibn Habib midnight variant (spec section 3.8): the midpoint between
  // today's sunset and tomorrow's sunrise. (An earlier draft used
  // maghrib + (tomorrowFajr − maghrib) / 2; corrected to the spec formula.)
  double ishaMidnightVariantUtc;
  if (tomorrowSunriseAbs != null) {
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

  return PrayerTimesComputed(PrayerTimes(
    fajr: wall(fajrUtc),
    sunrise: wall(sunriseUtc),
    sunset: wall(sunsetUtc),
    dhuhr: wall(dhuhrUtc),
    asr: wall(asrUtc),
    maghrib: wall(maghribUtc),
    isha: wall(ishaUtc),
    ishaPreferredEnd: wall(ishaPreferredEndUtc),
    ishaMidnightVariant: wall(ishaMidnightVariantUtc),
    maghribPreferredEnd: wall(maghribPreferredEndUtc),
    highLatitudeFallback: highLatitudeFallback,
    profile: profile,
    fallbackMethod: methodInEffect,
  ));
}

/// Borrows a whole computed day from [sourceDate] — the nearest-day
/// fallback. The source date passed [_nearestSolvableDay], so the inner
/// call always computes (it cannot hit the polar branch). The borrowed
/// times render in the displayed date's offset frame — a documented
/// engineering convention, and the source date is recorded so the UI can
/// show it next to the borrowed times.
PrayerTimesComputed _borrowedDay({
  required Coordinates coordinates,
  required DateTime sourceDate,
  required Duration timeZoneOffset,
  required PrayerProfile profile,
  required double elevationMeters,
}) {
  final inner = calculatePrayerTimes(
    coordinates: coordinates,
    date: sourceDate,
    timeZoneOffset: timeZoneOffset,
    profile: profile,
    elevationMeters: elevationMeters,
  );
  final t = (inner as PrayerTimesComputed).times;
  return PrayerTimesComputed(PrayerTimes(
    fajr: t.fajr,
    sunrise: t.sunrise,
    sunset: t.sunset,
    dhuhr: t.dhuhr,
    asr: t.asr,
    maghrib: t.maghrib,
    isha: t.isha,
    ishaPreferredEnd: t.ishaPreferredEnd,
    ishaMidnightVariant: t.ishaMidnightVariant,
    maghribPreferredEnd: t.maghribPreferredEnd,
    highLatitudeFallback: true,
    profile: profile,
    fallbackMethod: HighLatitudeFallback.nearestDay,
    nearestDaySourceDate: sourceDate,
  ));
}
