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

/// Source of live compass headings.
///
/// Emits heading degrees 0-360, or null when the compass is unavailable
/// (no magnetometer, sensor error, or no readings within a few seconds).
/// Never throws.
abstract class CompassService {
  Stream<double?> get headings;
  void dispose();
}

/// Real implementation backed by `sensors_plus`.
class SensorCompassService implements CompassService {
  final StreamController<double?> _out =
      StreamController<double?>.broadcast();
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
    _out.add(tiltCompensatedHeading(a.x, a.y, a.z, m.x, m.y, m.z));
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
  }
}
