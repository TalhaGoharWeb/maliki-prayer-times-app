import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';

/// Phase 2 tests: the elevation dip correction on the sunrise/sunset
/// horizon. The acceptance criterion is that the measured shift matches
/// the dip formula (0.0293 × √h) within rounding.
///
/// The end-to-end tests run at the equator on the March equinox, where the
/// sun crosses the horizon at ~15°/hour vertically, so the expected shift
/// is exactly `dipDegrees × 4` minutes — an independent geometric check,
/// not a restatement of the engine code.
void main() {
  group('elevationDipDegrees', () {
    test('sea level, negative and NaN elevations give zero dip', () {
      expect(elevationDipDegrees(0), 0.0);
      expect(elevationDipDegrees(-100), 0.0);
      expect(elevationDipDegrees(double.nan), 0.0);
    });

    test('matches the 0.0293 × √h formula', () {
      expect(elevationDipDegrees(1500),
          closeTo(0.0293 * math.sqrt(1500), 1e-9));
      expect(elevationDipDegrees(100), closeTo(0.293, 1e-9));
      expect(elevationDipDegrees(8849),
          closeTo(0.0293 * math.sqrt(8849), 1e-9));
    });
  });

  group('elevation-aware horizon (engine)', () {
    final coords = Coordinates(0.0, 0.0);
    final date = DateTime(2026, 3, 20);

    PrayerTimes at(double elevationMeters) => calculatePrayerTimes(
          coordinates: coords,
          date: date,
          timeZoneOffset: Duration.zero,
          profile: PrayerProfiles.defaultProfile,
          elevationMeters: elevationMeters,
        );

    test(
        'ACCEPTANCE: 1500 m moves sunrise earlier and sunset later, '
        'delta matches the dip formula within rounding', () {
      final sea = at(0.0);
      final high = at(1500.0);
      // Independent expectation: dip ≈ 1.1348°, sun moves 15°/h vertically
      // at the equator on the equinox → ~4.54 min shift each way.
      final expectedMinutes = elevationDipDegrees(1500.0) * 4.0;

      final sunriseDelta = sea.sunrise.difference(high.sunrise).inMinutes;
      final sunsetDelta = high.sunset.difference(sea.sunset).inMinutes;

      expect(sunriseDelta, greaterThan(0),
          reason: 'higher observer sees sunrise earlier');
      expect(sunsetDelta, greaterThan(0),
          reason: 'higher observer sees sunset later');
      expect((sunriseDelta - expectedMinutes).abs(), lessThanOrEqualTo(1.0),
          reason:
              'sunrise delta ($sunriseDelta min) matches the dip formula '
              '($expectedMinutes min) within rounding');
      expect((sunsetDelta - expectedMinutes).abs(), lessThanOrEqualTo(1.0),
          reason:
              'sunset delta ($sunsetDelta min) matches the dip formula '
              '($expectedMinutes min) within rounding');
    });

    test('elevation does not move fajr, dhuhr, asr or isha', () {
      final sea = at(0.0);
      final high = at(1500.0);
      expect(high.fajr, sea.fajr,
          reason: 'twilight depression is geometric, not visible-horizon');
      expect(high.dhuhr, sea.dhuhr, reason: 'solar noon is unaffected');
      expect(high.asr, sea.asr, reason: 'shadow rule is unaffected');
      expect(high.isha, sea.isha,
          reason: 'twilight depression is geometric, not visible-horizon');
    });

    test('maghrib shifts with the dipped sunset', () {
      final sea = at(0.0);
      final high = at(1500.0);
      // Maghrib = dipped sunset + ihtiyat: it must move with the horizon
      // (later, like the sunset itself).
      expect(high.maghrib.difference(sea.maghrib).inMinutes, greaterThan(0));
    });

    test('default elevation is the sea-level horizon', () {
      final explicit = at(0.0);
      final implicit = calculatePrayerTimes(
        coordinates: coords,
        date: date,
        timeZoneOffset: Duration.zero,
        profile: PrayerProfiles.defaultProfile,
      );
      expect(implicit.sunrise, explicit.sunrise);
      expect(implicit.sunset, explicit.sunset);
    });

    test('small elevation produces a small shift (sanity)', () {
      final sea = at(0.0);
      final roof = at(30.0); // ~10-storey building
      final dip = elevationDipDegrees(30.0); // ~0.16°
      expect(dip, closeTo(0.16, 0.01));
      // ~0.64 min shift: rounds to 0 or 1 minute, never more.
      final delta = sea.sunrise.difference(roof.sunrise).inMinutes.abs();
      expect(delta, lessThanOrEqualTo(1));
    });
  });
}
