import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/services/travel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kilometres per degree of longitude at the equator (2 * pi * 6371 / 360).
const _kmPerDegree = 111.19492664455873;

void main() {
  group('TravelService', () {
    test('haversine sanity: (0,0) to (0,1) is ~111.19 km', () {
      expect(TravelService.haversineKm(0, 0, 0, 1), closeTo(111.19, 0.01));
    });

    test('haversine sanity: same point is 0 km', () {
      expect(
        TravelService.haversineKm(24.86, 67.0, 24.86, 67.0),
        closeTo(0.0, 1e-9),
      );
    });

    test('disabled by default, no home', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = TravelService();
      await svc.load();

      expect(svc.isEnabled, isFalse);
      expect(svc.homeLat, isNull);
      expect(svc.homeLng, isNull);
    });

    test('first enable stores the passed home coords', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = TravelService();
      await svc.load();

      await svc.setEnabled(true, homeLat: 33.6, homeLng: 73.0);
      expect(svc.isEnabled, isTrue);
      expect(svc.homeLat, 33.6);
      expect(svc.homeLng, 73.0);

      final reloaded = TravelService();
      await reloaded.load();
      expect(reloaded.isEnabled, isTrue);
      expect(reloaded.homeLat, 33.6);
      expect(reloaded.homeLng, 73.0);
    });

    test('later toggles keep the stored home', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = TravelService();
      await svc.load();

      await svc.setEnabled(true, homeLat: 33.6, homeLng: 73.0);
      await svc.setEnabled(false);
      expect(svc.isEnabled, isFalse);
      await svc.setEnabled(true, homeLat: 1.0, homeLng: 2.0);

      expect(svc.homeLat, 33.6);
      expect(svc.homeLng, 73.0);
    });

    test('enabling without home keeps the suggestion dormant', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = TravelService();
      await svc.load();

      await svc.setEnabled(true);
      expect(svc.isEnabled, isTrue);
      expect(svc.homeLat, isNull);

      await svc.setEnabled(false);
      // Even far away, no home means no suggestion.
      expect(svc.shouldSuggestTravel(0.0, 100.0), isFalse);
    });

    test('suggest boundary: 79.9 km off, 80.1 km on', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = TravelService();
      await svc.load();

      await svc.setEnabled(true, homeLat: 0.0, homeLng: 0.0);
      await svc.setEnabled(false);

      final nearLng = 79.9 / _kmPerDegree;
      final farLng = 80.1 / _kmPerDegree;
      expect(
        svc.shouldSuggestTravel(0.0, nearLng),
        isFalse,
        reason: '79.9 km from home must not suggest travel mode',
      );
      expect(
        svc.shouldSuggestTravel(0.0, farLng),
        isTrue,
        reason: '80.1 km from home must suggest travel mode',
      );
    });

    test('no suggestion while travel mode is already on', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = TravelService();
      await svc.load();

      await svc.setEnabled(true, homeLat: 0.0, homeLng: 0.0);
      expect(svc.shouldSuggestTravel(0.0, 80.1 / _kmPerDegree), isFalse);
    });

    test('disable persists across reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = TravelService();
      await svc.load();

      await svc.setEnabled(true, homeLat: 33.6, homeLng: 73.0);
      await svc.setEnabled(false);

      final reloaded = TravelService();
      await reloaded.load();
      expect(reloaded.isEnabled, isFalse);
      expect(reloaded.homeLat, 33.6);
    });
  });
}
