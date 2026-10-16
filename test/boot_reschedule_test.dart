import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/services/boot_reschedule.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A prefs map in the shape the boot entrypoint builds from
/// SharedPreferences, with the values a previous in-app schedule persisted.
Map<String, Object?> _prefsMap({
  Object? lat = 18.0858,
  Object? lon = -15.9785,
  Object? profileId = 'maliki-egyptian',
  Object? offsetMinutes = 0,
}) =>
    {
      BootReschedule.latKey: lat,
      BootReschedule.lonKey: lon,
      BootReschedule.profileKey: profileId,
      BootReschedule.offsetMinutesKey: offsetMinutes,
    };

/// Expected at-time fire instants (UTC) per notification id, computed straight
/// from the engine: the next upcoming occurrence per prayer (today when still
/// future, else tomorrow) — the contract rescheduleAll honors for enabled
/// prayers when no reminder offset is set.
Map<int, DateTime> _expectedAtTimes({
  required Coordinates coords,
  required PrayerProfile profile,
  required Duration offset,
  required DateTime nowUtc,
}) {
  final result = <int, DateTime>{};
  final nowWall = nowUtc.add(offset);
  final today = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
  final tomorrow = today.add(const Duration(days: 1));

  DateTime utcFor(Prayer prayer, DateTime date) {
    final times = (calculatePrayerTimes(
      coordinates: coords,
      date: date,
      timeZoneOffset: offset,
      profile: profile,
    ) as PrayerTimesComputed)
        .times;
    // Default settings apply no adjustments, so adjustedTime is identity and
    // the true instant is the wall fields minus the date's offset.
    return times.timeFor(prayer).subtract(offset);
  }

  for (final prayer in Prayer.values) {
    var fire = utcFor(prayer, today);
    if (!fire.isAfter(nowUtc)) fire = utcFor(prayer, tomorrow);
    if (fire.isAfter(nowUtc)) result[prayer.index] = fire;
  }
  return result;
}

void main() {
  group('bootInputsFromPrefs', () {
    test('known values reconstruct the reschedule inputs', () {
      final inputs = BootReschedule.bootInputsFromPrefs(_prefsMap());
      expect(inputs, isNotNull);
      expect(inputs!.coords.latitude, 18.0858);
      expect(inputs.coords.longitude, -15.9785);
      expect(inputs.profile.id, 'maliki-egyptian');
      expect(inputs.timeZoneOffset, Duration.zero);
    });

    test('unknown profile id falls back to the default profile', () {
      final inputs = BootReschedule.bootInputsFromPrefs(
        _prefsMap(profileId: 'no-such-profile'),
      );
      expect(inputs, isNotNull);
      expect(inputs!.profile.id, PrayerProfiles.defaultProfile.id);
    });

    test('missing or mistyped keys return null so boot skips quietly', () {
      expect(BootReschedule.bootInputsFromPrefs({}), isNull);
      expect(
          BootReschedule.bootInputsFromPrefs(_prefsMap(lat: null)), isNull);
      expect(
          BootReschedule.bootInputsFromPrefs(_prefsMap(lon: null)), isNull);
      expect(
        BootReschedule.bootInputsFromPrefs(_prefsMap(profileId: null)),
        isNull,
      );
      expect(
        BootReschedule.bootInputsFromPrefs(_prefsMap(lat: '18.0858')),
        isNull,
      );
    });

    test('missing offset key falls back to the device offset', () {
      final deviceOffset = DateTime.now().timeZoneOffset;
      final inputs = BootReschedule.bootInputsFromPrefs(
        _prefsMap(offsetMinutes: null),
      );
      expect(inputs, isNotNull);
      expect(inputs!.timeZoneOffset, deviceOffset);
    });
  });

  group('boot reschedule drives rescheduleAll', () {
    test('persisted inputs schedule the expected notifications', () async {
      // Simulate the prefs left behind by a previous in-app schedule.
      SharedPreferences.setMockInitialValues({
        'notifications_last_lat': 18.0858,
        'notifications_last_lon': -15.9785,
        'notifications_last_profile_id': 'maliki-egyptian',
        'notifications_last_offset_minutes': 0,
      });
      // Read back exactly the way the boot entrypoint does.
      final prefs = await SharedPreferences.getInstance();
      final inputs = BootReschedule.bootInputsFromPrefs(<String, Object?>{
        BootReschedule.latKey: prefs.getDouble(BootReschedule.latKey),
        BootReschedule.lonKey: prefs.getDouble(BootReschedule.lonKey),
        BootReschedule.profileKey: prefs.getString(BootReschedule.profileKey),
        BootReschedule.offsetMinutesKey:
            prefs.getInt(BootReschedule.offsetMinutesKey),
      });
      expect(inputs, isNotNull);

      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);
      final settings = await SettingsService.load();
      final now = DateTime.utc(2026, 10, 15, 10, 0);
      await service.rescheduleAll(
        coords: inputs!.coords,
        profile: inputs.profile,
        settings: settings,
        timeZoneOffset: inputs.timeZoneOffset,
        timeZoneOffsetForDate: (_) => inputs.timeZoneOffset,
        texts: NotificationTexts.fallback(),
        now: now,
      );

      expect(fake.cancelAllCount, 1);
      final expected = _expectedAtTimes(
        coords: inputs.coords,
        profile: inputs.profile,
        offset: inputs.timeZoneOffset,
        nowUtc: now,
      );
      expect(expected, isNotEmpty);
      expect(
        fake.scheduled.map((s) => s.id).toSet(),
        expected.keys.toSet(),
      );
      for (final s in fake.scheduled) {
        expect(s.scheduledUtc, expected[s.id], reason: 'id ${s.id}');
      }
      // The boot path has no localizations; the plain-English fallback texts
      // are used for the re-created schedule.
      final fajr =
          fake.scheduled.firstWhere((s) => s.id == Prayer.fajr.index);
      expect(fajr.title, 'Fajr time');
      expect(fajr.body, 'It is now time for Fajr.');
    });
  });
}
