import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/utils/qibla.dart';

void main() {
  group('published city bearings (±0.5°)', () {
    // Reference bearings are great-circle initial bearings from the city
    // center to the Kaaba (21.4225 N, 39.8262 E), published at
    // https://makkahlive.net/en/tools/qibla (checked 2026-10-15):
    // London 119.0°, New York 58.5°, Karachi 267.7°.
    // (A second source lists New York ≈ 58° and London ≈ 119°:
    // https://medium.com/@fr3reza/before-you-arrive-know-which-way-to-pray-the-global-qibla-directory-every-traveling-muslim-needs-d08b19ccd4a2)
    test('London (51.5074, -0.1278) ≈ 119.0°', () {
      expect(qiblaBearingDegrees(51.5074, -0.1278), closeTo(119.0, 0.5));
    });

    test('New York (40.7128, -74.0060) ≈ 58.5°', () {
      expect(qiblaBearingDegrees(40.7128, -74.0060), closeTo(58.5, 0.5));
    });

    test('Karachi (24.8607, 67.0011) ≈ 267.7°', () {
      expect(qiblaBearingDegrees(24.8607, 67.0011), closeTo(267.7, 0.5));
    });
  });

  group('range', () {
    test('result is always within 0..360', () {
      for (final (lat, lon) in [
        (0.0, 0.0),
        (90.0, 0.0),
        (-90.0, 0.0),
        (51.5074, -0.1278),
        (-33.8688, 151.2093), // Sydney
        (18.08581, -15.9785), // Nouakchott
      ]) {
        final b = qiblaBearingDegrees(lat, lon);
        expect(b.isFinite, isTrue, reason: 'finite at ($lat, $lon)');
        expect(b, greaterThanOrEqualTo(0.0));
        expect(b, lessThan(360.0));
      }
    });
  });

  group('degenerate points', () {
    test('at the Kaaba itself the bearing is a finite 0..360 value', () {
      final b = qiblaBearingDegrees(kaabaLatitude, kaabaLongitude);
      expect(b.isFinite, isTrue);
      expect(b, greaterThanOrEqualTo(0.0));
      expect(b, lessThan(360.0));
    });

    test('at the antipode of the Kaaba the bearing is finite', () {
      final b = qiblaBearingDegrees(-kaabaLatitude, kaabaLongitude - 180.0);
      expect(b.isFinite, isTrue);
      expect(b, greaterThanOrEqualTo(0.0));
      expect(b, lessThan(360.0));
    });
  });

  group('direction sanity', () {
    test('Nouakchott faces roughly east-northeast', () {
      // The Kaaba (21.4 N, 39.8 E) lies east and slightly north of
      // Nouakchott (18.1 N, 16.0 W), so the bearing must be in the
      // north-east quadrant, closer to east than to north.
      final b = qiblaBearingDegrees(18.08581, -15.9785);
      expect(b, greaterThan(45.0));
      expect(b, lessThan(135.0));
    });

    test('Karachi faces west', () {
      final b = qiblaBearingDegrees(24.8607, 67.0011);
      expect(b, greaterThan(180.0));
      expect(b, lessThan(360.0));
    });
  });
}
