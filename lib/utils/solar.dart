/// Public solar-position math for the Qibla sun-alignment feature.
///
/// The engine's solar routines are private; this file re-implements the same
/// low-precision solar algorithm (mean anomaly / ecliptic longitude /
//  obliquity — identical constants to `lib/engine/prayer_times.dart`) as a
/// public utility so the Qibla screen can scan the day for the moment the
/// sun's azimuth equals the qibla bearing.
library;

import 'dart:math' as math;

double _toRad(double d) => d * math.pi / 180.0;
double _toDeg(double r) => r * 180.0 / math.pi;
double _sinDeg(double d) => math.sin(_toRad(d));
double _cosDeg(double d) => math.cos(_toRad(d));

double _norm360(double v) {
  var r = v % 360.0;
  if (r < 0) r += 360.0;
  return r;
}

double _normEqt(double v) {
  var r = v;
  if (r <= -12.0) {
    r += 24.0;
  } else if (r > 12.0) {
    r -= 24.0;
  }
  return r;
}

/// Solar declination in degrees for [date] (civil date, any time of day).
double solarDeclinationDeg(DateTime date) {
  final jd =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch /
              86400000.0 +
          2440587.5;
  final d = jd - 2451545.0;
  final g = _norm360(357.529 + 0.98560028 * d);
  final q = _norm360(280.459 + 0.98564736 * d);
  final l = _norm360(q + 1.915 * _sinDeg(g) + 0.020 * _sinDeg(2 * g));
  final e = 23.439 - 0.00000036 * d;
  return _toDeg(math.asin((_sinDeg(e) * _sinDeg(l)).clamp(-1.0, 1.0)));
}

/// Equation of time in hours for [date].
double equationOfTimeHours(DateTime date) {
  final jd =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch /
              86400000.0 +
          2440587.5;
  final d = jd - 2451545.0;
  final g = _norm360(357.529 + 0.98560028 * d);
  final q = _norm360(280.459 + 0.98564736 * d);
  final l = _norm360(q + 1.915 * _sinDeg(g) + 0.020 * _sinDeg(2 * g));
  final e = 23.439 - 0.00000036 * d;
  final raHours =
      _norm360(_toDeg(math.atan2(_cosDeg(e) * _sinDeg(l), _cosDeg(l)))) / 15.0;
  return _normEqt(q / 15.0 - raHours);
}

/// Solar noon as UTC hours for ([latitude], [longitude]) on [date].
double solarNoonUtcHours(
    double latitude, double longitude, DateTime date) {
  return (12.0 - equationOfTimeHours(date) - longitude / 15.0) % 24.0;
}

/// Sun azimuth in degrees clockwise from true north at [utcHours] (UTC hours
/// on [date]) for the observer. Returns null when the sun is below the
/// horizon (azimuth of a set sun is not useful for shadow alignment).
double? sunAzimuthDeg(double latitude, double longitude, DateTime date,
    double utcHours) {
  final decl = solarDeclinationDeg(date);
  final noon = solarNoonUtcHours(latitude, longitude, date);
  final hDeg = (utcHours - noon) * 15.0; // hour angle, degrees
  final latR = _toRad(latitude);
  final sinAlt = math.sin(latR) * _sinDeg(decl) +
      math.cos(latR) * _cosDeg(decl) * math.cos(_toRad(hDeg));
  if (sinAlt <= 0) return null; // sun below horizon
  var az = _toDeg(math.atan2(
        math.sin(_toRad(hDeg)),
        math.cos(_toRad(hDeg)) * math.sin(latR) -
            math.tan(_toRad(decl)) * math.cos(latR),
      )) +
      180.0;
  az = _norm360(az);
  return az;
}

/// Finds the UTC hour on [date] when the sun's azimuth crosses
/// [targetBearingDeg] (the qibla bearing), scanning in 2-minute steps while
/// the sun is up. Returns null when no crossing occurs (e.g. the bearing is
/// never matched while the sun is above the horizon).
///
/// The returned value is UTC hours; callers convert to the wall-clock frame.
double? sunAlignmentUtcHours(double latitude, double longitude,
    DateTime date, double targetBearingDeg) {
  double? prevAz;
  double prevT = 0.0;
  for (var t = 0.0; t < 24.0; t += 2.0 / 60.0) {
    final az = sunAzimuthDeg(latitude, longitude, date, t);
    if (az == null) {
      prevAz = null;
      continue;
    }
    if (prevAz != null) {
      // Detect a crossing of the target bearing between prevT and t,
      // handling the 0/360 wrap.
      var a0 = (prevAz - targetBearingDeg + 540.0) % 360.0 - 180.0;
      var a1 = (az - targetBearingDeg + 540.0) % 360.0 - 180.0;
      if (a0 == 0) return prevT;
      if (a0 * a1 < 0) {
        // Linear interpolation of the crossing point.
        final f = a0.abs() / (a0.abs() + a1.abs());
        return prevT + f * (t - prevT);
      }
    }
    prevAz = az;
    prevT = t;
  }
  return null;
}
