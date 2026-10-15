/// Qibla bearing: the great-circle initial bearing from the observer's
/// location to the Kaaba. Pure Dart — no plugins, no compass sensor.
library;

import 'dart:math' as math;

/// Kaaba location used for the bearing, degrees.
const double kaabaLatitude = 21.4225;
const double kaabaLongitude = 39.8262;

/// Great-circle initial bearing from ([latitude], [longitude]) to the Kaaba
/// (21.4225 N, 39.8262 E), in degrees clockwise from true north, 0..360.
///
/// Standard initial-bearing formula:
///   θ = atan2(sin(Δλ), cos(φ1)·tan(φ2) − sin(φ1)·cos(Δλ))
///
/// Verified against published great-circle bearings (checked 2026-10-15,
/// via https://makkahlive.net/en/tools/qibla, which computes the same
/// great-circle initial bearing to the same Kaaba coordinates):
/// * London (51.5074, −0.1278) → 119.0°
/// * New York (40.7128, −74.0060) → 58.5°
/// * Karachi (24.8607, 67.0011) → 267.7°
/// (A second source, https://medium.com/@fr3reza/before-you-arrive-know-which-way-to-pray-the-global-qibla-directory-every-traveling-muslim-needs-d08b19ccd4a2,
/// lists New York ≈ 58° and London ≈ 119°, consistent to the degree.)
double qiblaBearingDegrees(double latitude, double longitude) {
  final lat1 = latitude * math.pi / 180.0;
  final lat2 = kaabaLatitude * math.pi / 180.0;
  final dLon = (kaabaLongitude - longitude) * math.pi / 180.0;

  final y = math.sin(dLon);
  final x = math.cos(lat1) * math.tan(lat2) -
      math.sin(lat1) * math.cos(dLon);
  final bearing = math.atan2(y, x) * 180.0 / math.pi;

  var result = bearing % 360.0;
  if (result < 0) result += 360.0;
  // Guard the exact-Kaaba degenerate case (atan2(0, 0) is 0 on the VM, but
  // NaN is theoretically possible): always return a finite value.
  if (result.isNaN) return 0.0;
  return result;
}
