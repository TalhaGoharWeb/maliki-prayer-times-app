/// Live compass heading from the device accelerometer + magnetometer.
///
/// The heading math is pure Dart ([tiltCompensatedHeading]) and unit-tested;
/// the sensor plumbing lives behind [CompassService] so widget tests inject a
/// fake and never touch platform channels.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Tilt-compensated compass heading in degrees, 0 = magnetic north,
/// clockwise (90 = east). Returns null when the reading is degenerate
/// (zero vectors or accelerometer parallel to the magnetic field).
///
/// Vector method: U = normalized accelerometer (points up when stationary),
/// E = normalize(M x U) points east, N = U x E points to horizontal north.
/// Heading = atan2(E.y, N.y), i.e. the clockwise angle of the device's +y
/// axis (top of the phone) from magnetic north.
double? tiltCompensatedHeading(
  double ax,
  double ay,
  double az,
  double mx,
  double my,
  double mz,
) {
  final normA = math.sqrt(ax * ax + ay * ay + az * az);
  if (normA < 1e-9) return null;
  final ux = ax / normA, uy = ay / normA, uz = az / normA;

  // East = M x U.
  var ex = my * uz - mz * uy;
  var ey = mz * ux - mx * uz;
  var ez = mx * uy - my * ux;
  final normE = math.sqrt(ex * ex + ey * ey + ez * ez);
  if (normE < 1e-9) return null;
  ex /= normE;
  ey /= normE;
  ez /= normE;

  // Horizontal north = U x E (only the y component is needed for the
  // clockwise heading from the device's +y axis).
  final ny = uz * ex - ux * ez;

  var heading = math.atan2(ey, ny) * 180.0 / math.pi;
  heading = (heading + 360.0) % 360.0;
  return heading;
}

/// Quality of the magnetometer data behind a heading.
///
/// The phone's magnetometer needs periodic calibration (the figure-8
/// motion); a miscalibrated sensor silently reports a wrong heading. This
/// assessment lets the UI say so instead of showing a confident wrong
/// arrow. It is a heuristic over the raw field, never a claim about true
/// north — magnetic declination stays deliberately unmodeled.
enum CompassQuality {
  /// The field looks sane; the heading is as trustworthy as the sensor gets.
  ok,

  /// The field magnitude is far outside Earth's 25–65 µT range, or the
  /// heading is jumping erratically — the user should recalibrate.
  suspect,

  /// Not enough data yet (or no magnetometer at all).
  unknown,
}

/// Earth's surface magnetic field strength, in microteslas. Values far
/// outside this band mean the sensor is miscalibrated or sitting next to a
/// magnet — either way the heading cannot be trusted.
const double kEarthFieldMinUt = 25.0;
const double kEarthFieldMaxUt = 65.0;

/// A single heading jump larger than this is implausible for a hand-held
/// phone and counts toward the erratic-reading detector.
const double kImplausibleJumpDegrees = 45.0;

/// Consecutive implausible jumps before the quality flips to suspect.
const int kSuspectJumpStreak = 3;

/// Stateful, pure-Dart assessment of magnetometer health.
///
/// Feed each magnetometer sample (with the heading computed from it);
/// [addSample] returns the current quality. No platform channels, fully
/// unit-testable.
class CompassQualityTracker {
  double? _lastHeading;
  int _jumpStreak = 0;

  /// Assess one sample. [mx], [my], [mz] are the raw magnetometer axes in
  /// µT; [heading] is the tilt-compensated heading in degrees (null when
  /// the heading itself was degenerate).
  CompassQuality addSample(double mx, double my, double mz, double? heading) {
    final magnitude = math.sqrt(mx * mx + my * my + mz * mz);
    if (magnitude < kEarthFieldMinUt || magnitude > kEarthFieldMaxUt) {
      return CompassQuality.suspect;
    }
    if (heading != null) {
      final last = _lastHeading;
      if (last != null) {
        var jump = (heading - last).abs() % 360.0;
        if (jump > 180.0) jump = 360.0 - jump;
        _jumpStreak = jump > kImplausibleJumpDegrees ? _jumpStreak + 1 : 0;
      }
      _lastHeading = heading;
    }
    if (_jumpStreak >= kSuspectJumpStreak) return CompassQuality.suspect;
    return CompassQuality.ok;
  }

  /// Forget all history (e.g. when the sensor stream restarts).
  void reset() {
    _lastHeading = null;
    _jumpStreak = 0;
  }
}

/// Fixed-alpha low-pass filter on the heading circle.
///
/// Keeps a smoothed unit vector; each new heading nudges it by [alpha].
/// Operating on the unit circle means the 359°→0° wrap needs no special
/// case. With the default alpha of 0.35 a step settles to within 1° in
/// about 10 samples with no overshoot — at typical sensor rates that is a
/// glide of well under half a second, responsive but jump-free.
class HeadingSmoother {
  /// Per-sample blend factor in (0, 1). Larger = more responsive.
  final double alpha;

  double _x = 1.0;
  double _y = 0.0;
  bool _hasValue = false;

  HeadingSmoother({this.alpha = 0.35})
      : assert(alpha > 0.0 && alpha < 1.0, 'alpha must be in (0, 1)');

  /// Feed a heading in degrees [0, 360); returns the smoothed heading in
  /// the same range. The first sample passes through untouched.
  double update(double headingDegrees) {
    final radians = headingDegrees * math.pi / 180.0;
    final nx = math.cos(radians);
    final ny = math.sin(radians);
    if (!_hasValue) {
      _x = nx;
      _y = ny;
      _hasValue = true;
    } else {
      _x += alpha * (nx - _x);
      _y += alpha * (ny - _y);
    }
    return (math.atan2(_y, _x) * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// The current smoothed value, or null before the first sample.
  double? get value {
    if (!_hasValue) return null;
    return (math.atan2(_y, _x) * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Forget all history; the next sample passes through untouched.
  void reset() {
    _hasValue = false;
  }
}

/// Smallest absolute angle between two headings in degrees, in [0, 180].
double angularDifferenceDegrees(double a, double b) {
  var d = (a - b).abs() % 360.0;
  if (d > 180.0) d = 360.0 - d;
  return d;
}

/// Within this many degrees of the qibla bearing the dial counts as aligned.
const double kQiblaAlignedToleranceDegrees = 2.0;

/// Source of live compass headings.
///
/// Emits heading degrees 0-360, or null when the compass is unavailable
/// (no magnetometer, sensor error, or no readings within a few seconds).
/// Never throws.
abstract class CompassService {
  Stream<double?> get headings;

  /// Magnetometer health behind the headings. Emits values as samples are
  /// assessed; listeners should treat "no event yet" as
  /// [CompassQuality.unknown]. Never throws.
  Stream<CompassQuality> get quality;

  void dispose();
}

/// Real implementation backed by `sensors_plus`.
class SensorCompassService implements CompassService {
  final StreamController<double?> _out =
      StreamController<double?>.broadcast();
  final StreamController<CompassQuality> _qualityOut =
      StreamController<CompassQuality>.broadcast();
  final CompassQualityTracker _qualityTracker = CompassQualityTracker();
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  AccelerometerEvent? _lastAccel;
  MagnetometerEvent? _lastMag;
  bool _started = false;
  bool _emitted = false;
  bool _disposed = false;
  Timer? _timeout;

  @override
  Stream<double?> get headings {
    _ensureStarted();
    return _out.stream;
  }

  @override
  Stream<CompassQuality> get quality {
    _ensureStarted();
    return _qualityOut.stream;
  }

  void _ensureStarted() {
    if (_started || _disposed) return;
    _started = true;
    try {
      _accelSub = accelerometerEventStream().listen(
        (e) {
          _lastAccel = e;
          _maybeEmit();
        },
        onError: (_) => _fail(),
      );
      _magSub = magnetometerEventStream().listen(
        (e) {
          _lastMag = e;
          _maybeEmit();
        },
        onError: (_) => _fail(),
      );
      // No readings within a few seconds: the device has no usable
      // magnetometer (or sensors are blocked). Report unavailable once.
      // The timer is cancelled in dispose() so widget tests (which fail
      // on pending timers) stay green.
      _timeout = Timer(const Duration(seconds: 4), () {
        if (!_disposed && !_emitted && !_out.isClosed) {
          _emitted = true;
          _out.add(null);
        }
      });
    } catch (_) {
      _fail();
    }
  }

  void _maybeEmit() {
    final a = _lastAccel;
    final m = _lastMag;
    if (a == null || m == null || _disposed || _out.isClosed) return;
    _emitted = true;
    final heading = tiltCompensatedHeading(a.x, a.y, a.z, m.x, m.y, m.z);
    _out.add(heading);
    if (!_qualityOut.isClosed) {
      _qualityOut.add(_qualityTracker.addSample(m.x, m.y, m.z, heading));
    }
  }

  void _fail() {
    if (_disposed || _out.isClosed) return;
    _emitted = true;
    _out.add(null);
  }

  @override
  void dispose() {
    _disposed = true;
    _timeout?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _out.close();
    _qualityOut.close();
  }
}
