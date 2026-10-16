import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/models/saved_location.dart';

/// Phase 2 tests: schema-versioned persistence of [SavedLocation] —
/// the new `timeZoneId`, `elevationMeters`, `accuracyMeters` and
/// `updatedAt` fields round-trip, and pre-Phase-2 JSON (no `schema_version`
/// key) reads with the new fields defaulted instead of throwing.
void main() {
  group('SavedLocation persistence', () {
    test('round-trips all Phase 2 fields with schema_version 2', () {
      final updatedAt = DateTime.utc(2026, 10, 16, 10, 30);
      final loc = SavedLocation(
        name: 'New York',
        latitude: 40.7128,
        longitude: -74.006,
        timeZoneId: 'America/New_York',
        elevationMeters: 10.0,
        accuracyMeters: 12.5,
        updatedAt: updatedAt,
      );
      final json = loc.toJson();
      expect(json['schema_version'], SavedLocation.schemaVersion);
      expect(SavedLocation.schemaVersion, 2);

      final back = SavedLocation.fromJson(json);
      expect(back.name, 'New York');
      expect(back.latitude, 40.7128);
      expect(back.longitude, -74.006);
      expect(back.timeZoneId, 'America/New_York');
      expect(back.elevationMeters, 10.0);
      expect(back.accuracyMeters, 12.5);
      expect(back.updatedAt, updatedAt);
      expect(back.isDevice, isFalse);
    });

    test('legacy JSON without schema_version reads with null new fields',
        () {
      final legacy = <String, dynamic>{
        'name': 'Karachi',
        'latitude': 24.86,
        'longitude': 67.0,
        'isDevice': false,
        'placeName': null,
      };
      final loc = SavedLocation.fromJson(legacy);
      expect(loc.name, 'Karachi');
      expect(loc.latitude, 24.86);
      expect(loc.longitude, 67.0);
      expect(loc.timeZoneId, isNull);
      expect(loc.elevationMeters, isNull);
      expect(loc.accuracyMeters, isNull);
      expect(loc.updatedAt, isNull);
    });

    test('legacy device JSON keeps working (device zone behavior default)',
        () {
      final legacy = <String, dynamic>{
        'name': 'Device location',
        'latitude': 18.07,
        'longitude': -15.96,
        'isDevice': true,
        'placeName': 'Nouakchott',
      };
      final loc = SavedLocation.fromJson(legacy);
      expect(loc.isDevice, isTrue);
      expect(loc.placeName, 'Nouakchott');
      expect(loc.displayName('Device location'), 'Nouakchott');
      expect(loc.timeZoneId, isNull);
    });

    test('malformed updatedAt does not throw (reads as null)', () {
      final json = <String, dynamic>{
        'schema_version': 2,
        'name': 'X',
        'latitude': 1.0,
        'longitude': 2.0,
        'updatedAt': 'not-a-date',
      };
      expect(SavedLocation.fromJson(json).updatedAt, isNull);
    });

    test('displayName is unaffected by the new fields', () {
      const manual = SavedLocation(
        name: 'Lahore',
        latitude: 31.5,
        longitude: 74.3,
        timeZoneId: 'Asia/Karachi',
        elevationMeters: 217.0,
      );
      expect(manual.displayName('Device location'), 'Lahore');
    });
  });
}
