import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/services/timezone_service.dart';

/// Phase 2 tests: the bundled IANA tz database (latest_10y), per-date DST
/// offset resolution, zone-id plumbing for manual locations, and the
/// regression test proving a manual location in another zone renders that
/// zone's wall-clock times (not the device's).
void main() {
  group('TimezoneService', () {
    test('initializes idempotently', () {
      TimezoneService.ensureInitialized();
      TimezoneService.ensureInitialized();
      expect(TimezoneService.isInitialized, isTrue);
    });

    test('zone database lists the expected zones, sorted', () {
      final ids = TimezoneService.zoneIds;
      expect(ids, contains('Asia/Karachi'));
      expect(ids, contains('America/New_York'));
      expect(ids, contains('Africa/Nouakchott'));
      expect(ids, contains('Africa/Casablanca'));
      expect(ids, contains('Africa/Cairo'));
      expect(ids, contains('Africa/Tunis'));
      expect(ids, contains('Europe/Madrid'));
      expect(ids.length, greaterThan(500),
          reason: 'full IANA coverage (latest_all), not the 345-zone subset');
      final sorted = [...ids]..sort();
      expect(ids, orderedEquals(sorted));
    });

    test('searchZones filters case-insensitively; empty query returns all',
        () {
      final hits = TimezoneService.searchZones('NEW_york');
      expect(hits, contains('America/New_York'));
      expect(
          TimezoneService.searchZones('').length,
          TimezoneService.zoneIds.length);
      expect(TimezoneService.searchZones('zzz-no-such-zone'), isEmpty);
    });

    test('isKnownZone accepts bundled ids and rejects unknown ones', () {
      expect(TimezoneService.isKnownZone('Europe/Paris'), isTrue);
      expect(TimezoneService.isKnownZone('Not/AZone'), isFalse);
    });

    test('offsetFor resolves DST per date (not just "today")', () {
      // America/New_York: EST (UTC-5) in January, EDT (UTC-4) in July.
      expect(
        TimezoneService.offsetFor('America/New_York', DateTime(2026, 1, 15)),
        const Duration(hours: -5),
      );
      expect(
        TimezoneService.offsetFor('America/New_York', DateTime(2026, 7, 15)),
        const Duration(hours: -4),
      );
      // Asia/Karachi has no DST: same offset year-round.
      expect(
        TimezoneService.offsetFor('Asia/Karachi', DateTime(2026, 1, 15)),
        const Duration(hours: 5),
      );
      expect(
        TimezoneService.offsetFor('Asia/Karachi', DateTime(2026, 7, 15)),
        const Duration(hours: 5),
      );
    });

    test('offsetFor honors the DST transition date itself', () {
      // US DST 2026 starts on Sunday 2026-03-08: the day before is EST,
      // the day after is EDT.
      expect(
        TimezoneService.offsetFor('America/New_York', DateTime(2026, 3, 7)),
        const Duration(hours: -5),
      );
      expect(
        TimezoneService.offsetFor('America/New_York', DateTime(2026, 3, 9)),
        const Duration(hours: -4),
      );
    });

    test('effectiveZoneIdFor: manual uses the stored zone', () {
      const manual = SavedLocation(
        name: 'New York',
        latitude: 40.7128,
        longitude: -74.006,
        timeZoneId: 'America/New_York',
      );
      expect(
          TimezoneService.effectiveZoneIdFor(manual), 'America/New_York');
    });

    test(
        'effectiveZoneIdFor: GPS-device locations keep the device zone '
        '(even with a stored id)', () {
      const device = SavedLocation(
        name: 'Device location',
        latitude: 24.86,
        longitude: 67.0,
        isDevice: true,
        timeZoneId: 'America/New_York',
      );
      expect(TimezoneService.effectiveZoneIdFor(device),
          TimezoneService.deviceZoneId);
    });

    test(
        'effectiveZoneIdFor: legacy and unknown zones fall back to the '
        'device zone (never throws)', () {
      const legacy = SavedLocation(
          name: 'Karachi', latitude: 24.86, longitude: 67.0);
      expect(TimezoneService.effectiveZoneIdFor(legacy),
          TimezoneService.deviceZoneId);
      const bogus = SavedLocation(
          name: 'X',
          latitude: 0.0,
          longitude: 0.0,
          timeZoneId: 'Not/AZone');
      expect(TimezoneService.effectiveZoneIdFor(bogus),
          TimezoneService.deviceZoneId);
      expect(TimezoneService.effectiveZoneIdFor(null),
          TimezoneService.deviceZoneId);
    });

    test(
        'REGRESSION: manual New York location renders New York wall-clock '
        'times (not the device frame)', () {
      // Fixed civil date in July (EDT, UTC-4). The wiring under test is
      // exactly what the UI does: effectiveZoneIdFor -> offsetFor -> engine.
      const zoneId = 'America/New_York';
      final date = DateTime(2026, 7, 15);
      final coords = Coordinates(40.7128, -74.0060);

      final effective = TimezoneService.effectiveZoneIdFor(
        const SavedLocation(
          name: 'New York',
          latitude: 40.7128,
          longitude: -74.006,
          timeZoneId: zoneId,
        ),
      );
      expect(effective, zoneId);
      final offset = TimezoneService.offsetFor(effective, date);
      expect(offset, const Duration(hours: -4));

      final times = (calculatePrayerTimes(
        coordinates: coords,
        date: date,
        timeZoneOffset: offset,
        profile: PrayerProfiles.defaultProfile,
      ) as PrayerTimesComputed)
          .times;

      // The engine returns UTC-kind DateTimes whose fields are wall-clock
      // values. Recover each true UTC instant (wall - offset) and re-render
      // it through the tz database: the fields must match the engine's.
      for (final prayer in Prayer.values) {
        final wall = times.timeFor(prayer);
        final instant = wall.subtract(offset);
        final rendered = TimezoneService.zoneWallTime(instant, zoneId);
        expect(rendered.hour, wall.hour,
            reason: '$prayer hour is not the New York wall-clock hour');
        expect(rendered.minute, wall.minute,
            reason: '$prayer minute is not the New York wall-clock minute');
      }

      // The old device-frame behavior (e.g. a phone in Karachi, UTC+5)
      // renders DIFFERENT wall-clock times for the same instants — this is
      // the bug Phase 2 closes.
      final deviceFrameOffset =
          TimezoneService.offsetFor('Asia/Karachi', date);
      final deviceFrameTimes = (calculatePrayerTimes(
        coordinates: coords,
        date: date,
        timeZoneOffset: deviceFrameOffset,
        profile: PrayerProfiles.defaultProfile,
      ) as PrayerTimesComputed)
          .times;
      expect(deviceFrameTimes.fajr, isNot(times.fajr),
          reason: 'device frame must differ from the location zone frame');
    });

    test('REGRESSION: DST transition date uses that date\'s offset', () {
      // The Monday after the 2026 US spring-forward: the day's own offset
      // (EDT) frames the times, not the pre-transition EST offset.
      const zoneId = 'America/New_York';
      final date = DateTime(2026, 3, 9);
      final coords = Coordinates(40.7128, -74.0060);
      final offset = TimezoneService.offsetFor(zoneId, date);
      expect(offset, const Duration(hours: -4));
      final times = (calculatePrayerTimes(
        coordinates: coords,
        date: date,
        timeZoneOffset: offset,
        profile: PrayerProfiles.defaultProfile,
      ) as PrayerTimesComputed)
          .times;
      final wall = times.dhuhr;
      final rendered =
          TimezoneService.zoneWallTime(wall.subtract(offset), zoneId);
      expect(rendered.hour, wall.hour);
      expect(rendered.minute, wall.minute);
    });
  });
}
