import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nouakchott, Mauritania — UTC+0, so wall-clock fields equal UTC instants.
const _nouakchott = Coordinates(18.0858, -15.9785);
const _offset = Duration.zero;

NotificationTexts _texts() => NotificationTexts(
      titleFor: (p) => 'title-${p.name}',
      bodyFor: (p) => 'body-${p.name}',
      reminderTitleFor: (p, m) => 'rem-title-${p.name}-$m',
      reminderBodyFor: (p, m) => 'rem-body-${p.name}-$m',
    );

/// Expected fire instants (UTC) per notification id, computed straight from
/// the engine through [SettingsService.adjustedTime]: the next upcoming
/// occurrence per enabled prayer (today when still future, else tomorrow) —
/// the same contract [NotificationService.rescheduleAll] must honor.
Map<int, DateTime> _expected({
  required SettingsService settings,
  required DateTime nowUtc,
}) {
  final result = <int, DateTime>{};
  final nowWall = nowUtc.add(_offset);
  final todayWall = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
  final tomorrowWall = todayWall.add(const Duration(days: 1));
  final reminder = settings.reminderOffsetMinutes;

  DateTime prayerUtcFor(Prayer p, DateTime date) {
    final times = (calculatePrayerTimes(
      coordinates: _nouakchott,
      date: date,
      timeZoneOffset: _offset,
      profile: PrayerProfiles.defaultProfile,
    ) as PrayerTimesComputed)
        .times;
    return settings.adjustedTime(p, times.timeFor(p)).subtract(_offset);
  }

  for (final p in Prayer.values) {
    if (!(settings.notificationToggles[p] ?? false)) continue;
    var fireUtc = prayerUtcFor(p, todayWall);
    if (!fireUtc.isAfter(nowUtc)) fireUtc = prayerUtcFor(p, tomorrowWall);
    if (!fireUtc.isAfter(nowUtc)) continue;
    result[p.index] = fireUtc;
    if (reminder > 0) {
      final reminderUtc = fireUtc.subtract(Duration(minutes: reminder));
      if (reminderUtc.isAfter(nowUtc)) {
        result[reminderIdBase + p.index] = reminderUtc;
      }
    }
  }
  return result;
}

void main() {
  group('NotificationService with FakeNotificationScheduler', () {
    test('reschedule computes correct times vs the engine', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);

      final now = DateTime.utc(2026, 10, 15, 10, 0);
      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: now,
      );

      expect(fake.cancelAllCount, 1);
      final expected = _expected(settings: settings, nowUtc: now);
      expect(expected, isNotEmpty);
      expect(fake.scheduled.map((s) => s.id).toSet(),
          expected.keys.toSet());
      for (final s in fake.scheduled) {
        expect(s.scheduledUtc, expected[s.id], reason: 'id ${s.id}');
        expect(s.title, 'title-${Prayer.values[s.id].name}');
        expect(s.body, 'body-${Prayer.values[s.id].name}');
        expect(s.exact, isTrue);
      }
    });

    test('each scheduled date uses its own UTC offset across a DST change',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);

      // Fake zone: 2026-10-24 runs at UTC+2, clocks fall back to UTC+1
      // overnight into 2026-10-25.
      final queriedDays = <int>{};
      Duration offsetFor(DateTime date) {
        queriedDays.add(date.day);
        return date.day == 25
            ? const Duration(hours: 1)
            : const Duration(hours: 2);
      }

      // 12:00 UTC on Oct 24 = 14:00 wall in the +2 frame: Isha is still
      // upcoming today (+2) while Fajr has rolled to tomorrow (+1).
      final now = DateTime.utc(2026, 10, 24, 12, 0);
      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: const Duration(hours: 2),
        timeZoneOffsetForDate: offsetFor,
        texts: _texts(),
        now: now,
      );

      // Both civil dates went through the per-date seam: tomorrow is not
      // pinned to today's offset.
      expect(queriedDays, containsAll({24, 25}));

      DateTime prayerUtc(Prayer p, DateTime date, Duration off) {
        final times = (calculatePrayerTimes(
          coordinates: _nouakchott,
          date: date,
          timeZoneOffset: off,
          profile: PrayerProfiles.defaultProfile,
        ) as PrayerTimesComputed)
            .times;
        return settings.adjustedTime(p, times.timeFor(p)).subtract(off);
      }

      DateTime wall(Prayer p, DateTime date, Duration off) {
        final times = (calculatePrayerTimes(
          coordinates: _nouakchott,
          date: date,
          timeZoneOffset: off,
          profile: PrayerProfiles.defaultProfile,
        ) as PrayerTimesComputed)
            .times;
        return settings.adjustedTime(p, times.timeFor(p));
      }

      final byId = {for (final s in fake.scheduled) s.id: s.scheduledUtc};
      final today = DateTime.utc(2026, 10, 24);
      final tomorrow = DateTime.utc(2026, 10, 25);

      // Post-transition date scheduled in its own +1 frame...
      final fajrTomorrow =
          prayerUtc(Prayer.fajr, tomorrow, const Duration(hours: 1));
      expect(byId[Prayer.fajr.index], fajrTomorrow);
      // ...pre-transition date keeps today's +2 frame.
      expect(byId[Prayer.isha.index],
          prayerUtc(Prayer.isha, today, const Duration(hours: 2)));

      // Guard against inconsistent offset application: mixing tomorrow's
      // wall frame with today's offset (or vice versa) would shift the
      // instant by exactly the 1h DST delta.
      final mixedEarly = wall(Prayer.fajr, tomorrow, const Duration(hours: 1))
          .subtract(const Duration(hours: 2));
      final mixedLate = wall(Prayer.fajr, tomorrow, const Duration(hours: 2))
          .subtract(const Duration(hours: 1));
      expect(mixedEarly.difference(fajrTomorrow), const Duration(hours: -1));
      expect(mixedLate.difference(fajrTomorrow), const Duration(hours: 1));
      expect(byId[Prayer.fajr.index], isNot(mixedEarly));
      expect(byId[Prayer.fajr.index], isNot(mixedLate));
    });

    test('past prayer times are skipped, nothing fires immediately', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);

      // 23:00 UTC: every prayer today is past; only tomorrow's six remain.
      final now = DateTime.utc(2026, 10, 15, 23, 0);
      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: now,
      );

      final expected = _expected(settings: settings, nowUtc: now);
      expect(expected.length, 6);
      expect(fake.scheduled.map((s) => s.id).toSet(),
          expected.keys.toSet());
      for (final s in fake.scheduled) {
        expect(s.scheduledUtc.isAfter(now), isTrue);
      }
    });

    test('disabled prayer toggles are respected', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      await settings.setNotificationEnabled(Prayer.asr, false);
      await settings.setNotificationEnabled(Prayer.sunrise, false);

      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);
      final now = DateTime.utc(2026, 10, 15, 10, 0);
      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: now,
      );

      final ids = fake.scheduled.map((s) => s.id).toSet();
      expect(ids.contains(Prayer.asr.index), isFalse);
      expect(ids.contains(Prayer.sunrise.index), isFalse);
      expect(ids.contains(reminderIdBase + Prayer.asr.index), isFalse);
      // Everything else still scheduled.
      final expected = _expected(settings: settings, nowUtc: now);
      expect(ids, expected.keys.toSet());
    });

    test('reminder offset applied with stable +1000 ids', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      await settings.setReminderOffsetMinutes(10);

      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);
      final now = DateTime.utc(2026, 10, 15, 10, 0);
      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: now,
      );

      final expected = _expected(settings: settings, nowUtc: now);
      expect(fake.scheduled.map((s) => s.id).toSet(),
          expected.keys.toSet());
      for (final s in fake.scheduled) {
        if (s.id >= reminderIdBase) {
          final prayer = Prayer.values[s.id - reminderIdBase];
          final main = expected[prayer.index]!;
          expect(s.scheduledUtc, main.subtract(const Duration(minutes: 10)));
          expect(s.title, 'rem-title-${prayer.name}-10');
          expect(s.body, 'rem-body-${prayer.name}-10');
        } else {
          expect(s.scheduledUtc, expected[s.id]);
        }
      }
    });

    test('reminder in the past is skipped, at-time notification kept',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      await settings.setReminderOffsetMinutes(10);

      final times = (calculatePrayerTimes(
        coordinates: _nouakchott,
        date: DateTime.utc(2026, 10, 15),
        timeZoneOffset: _offset,
        profile: PrayerProfiles.defaultProfile,
      ) as PrayerTimesComputed)
          .times;
      final dhuhrUtc =
          settings.adjustedTime(Prayer.dhuhr, times.dhuhr).subtract(_offset);
      // 5 minutes before Dhuhr: its reminder (10 min before) already passed.
      final now = dhuhrUtc.subtract(const Duration(minutes: 5));

      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);
      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: now,
      );

      final ids = fake.scheduled.map((s) => s.id).toSet();
      expect(ids.contains(Prayer.dhuhr.index), isTrue);
      expect(ids.contains(reminderIdBase + Prayer.dhuhr.index), isFalse);
      // Other prayers' reminders are unaffected.
      expect(ids.contains(reminderIdBase + Prayer.asr.index), isTrue);
    });

    test('inexact scheduling when exact alarms are denied', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final fake = FakeNotificationScheduler()..exactAlarmsResult = false;
      final service = NotificationService(scheduler: fake);

      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: DateTime.utc(2026, 10, 15, 10, 0),
      );

      expect(fake.scheduled, isNotEmpty);
      for (final s in fake.scheduled) {
        expect(s.exact, isFalse);
      }
    });

    test('cancelAll clears scheduled notifications', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);

      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: DateTime.utc(2026, 10, 15, 10, 0),
      );
      expect(fake.scheduled, isNotEmpty);

      await service.cancelAll();
      expect(fake.scheduled, isEmpty);
      expect(fake.cancelAllCount, 2);
    });

    test('init on first run does not reschedule', () async {
      SharedPreferences.setMockInitialValues({});
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);

      await service.init(texts: _texts());
      expect(fake.initializeCount, 1);
      expect(fake.scheduled, isEmpty);
      expect(fake.cancelAllCount, 0);
    });

    test('timezone change triggers reschedule with stored params', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);

      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: DateTime.utc(2026, 10, 15, 10, 0),
      );
      final afterFirst = fake.scheduled.length;
      expect(afterFirst, greaterThan(0));

      // Simulate the device moving to a different timezone.
      await service.syncTimeZoneForTest(
        currentName: 'SOME_OTHER_TZ',
        currentOffset: _offset,
        texts: _texts(),
      );
      expect(fake.cancelAllCount, 2);
      expect(fake.scheduled.length, greaterThan(0));

      // Same timezone again: no reschedule.
      final cancelCount = fake.cancelAllCount;
      final scheduledCount = fake.scheduled.length;
      await service.syncTimeZoneForTest(
        currentName: 'SOME_OTHER_TZ',
        currentOffset: _offset,
        texts: _texts(),
      );
      expect(fake.cancelAllCount, cancelCount);
      expect(fake.scheduled.length, scheduledCount);
    });
  });

  group('SettingsService notification settings', () {
    test('defaults: all toggles true, offset 0', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      for (final p in Prayer.values) {
        expect(s.notificationToggles[p], isTrue, reason: 'toggle for $p');
      }
      expect(s.reminderOffsetMinutes, 0);
    });

    test('toggles persist and reload', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      await s.setNotificationEnabled(Prayer.fajr, false);
      await s.setNotificationEnabled(Prayer.sunrise, false);
      expect(s.notificationToggles[Prayer.fajr], isFalse);

      final reloaded = await SettingsService.load();
      expect(reloaded.notificationToggles[Prayer.fajr], isFalse);
      expect(reloaded.notificationToggles[Prayer.sunrise], isFalse);
      expect(reloaded.notificationToggles[Prayer.dhuhr], isTrue);
    });

    test('reminder offset accepts 0/5/10/15, rejects others', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      for (final m in [5, 10, 15, 0]) {
        await s.setReminderOffsetMinutes(m);
        expect(s.reminderOffsetMinutes, m);
      }
      await s.setReminderOffsetMinutes(7);
      expect(s.reminderOffsetMinutes, 0);
      await s.setReminderOffsetMinutes(-5);
      expect(s.reminderOffsetMinutes, 0);

      await s.setReminderOffsetMinutes(15);
      final reloaded = await SettingsService.load();
      expect(reloaded.reminderOffsetMinutes, 15);
    });

    test('corrupt stored toggles fall back to defaults', () async {
      SharedPreferences.setMockInitialValues(
          {'notification_toggles': 'not-json', 'reminder_offset_minutes': 99});
      final s = await SettingsService.load();

      for (final p in Prayer.values) {
        expect(s.notificationToggles[p], isTrue, reason: 'toggle for $p');
      }
      expect(s.reminderOffsetMinutes, 0);
    });
  });

  group('adhan notification sound', () {
    test('at-time prayer notifications use the adhan; reminders do not',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      // Enable a pre-prayer reminder so both notification kinds are scheduled.
      await settings.setReminderOffsetMinutes(15);
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);

      final now = DateTime.utc(2026, 10, 15, 10, 0);
      await service.rescheduleAll(
        coords: _nouakchott,
        profile: PrayerProfiles.defaultProfile,
        settings: settings,
        timeZoneOffset: _offset,
        texts: _texts(),
        now: now,
      );

      final byId = {for (final s in fake.scheduled) s.id: s};
      for (final p in Prayer.values) {
        final s = byId[p.index];
        expect(s, isNotNull, reason: 'at-time for ${p.name}');
        // The adhan announces the five prayers; sunrise is not a salat.
        expect(s!.adhanSound, p != Prayer.sunrise,
            reason: 'adhanSound for ${p.name}');
      }
      final reminders =
          fake.scheduled.where((s) => s.id >= reminderIdBase);
      expect(reminders, isNotEmpty);
      for (final s in reminders) {
        expect(s.adhanSound, isFalse, reason: 'reminder id ${s.id}');
      }
    });

    test('adhan raw resource is bundled and matches the declared name', () {
      expect(PluginNotificationScheduler.adhanSoundResource, 'tunisi_adhan');
      final file = File(
          'android/app/src/main/res/raw/${PluginNotificationScheduler.adhanSoundResource}.mp3');
      expect(file.existsSync(), isTrue, reason: 'raw resource bundled');
      expect(file.lengthSync(), greaterThan(1000000));
      final header = file.openSync().readSync(4);
      // MP3 magic: ID3 tag or an MPEG frame-sync word (0xFF 0xE0 mask).
      final isId3 =
          header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33;
      final isFrameSync = header[0] == 0xFF && (header[1] & 0xE0) == 0xE0;
      expect(isId3 || isFrameSync, isTrue, reason: 'valid MP3 audio');
    });
  });
}
