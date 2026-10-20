import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/qada_reminders.dart';
import 'package:malikiprayertimes/services/timezone_service.dart';

/// A wall-clock slot safely away from "now" (minutes since midnight) so the
/// before/after clock reads in a test cannot straddle the daily boundary
/// mid-run.
int _slotMinutesAhead(int aheadMinutes) {
  final now = DateTime.now();
  return (now.hour * 60 + now.minute + aheadMinutes) % (24 * 60);
}

void main() {
  group('id and key conventions', () {
    test('notificationId collides with no existing notification id', () {
      // Prayer notifications live in per-day blocks across the armed week:
      // at-time 0–65, reminders 1000–1605.
      final prayerIds = [
        for (var d = 0; d < scheduleDaysAhead; d++)
          for (final p in Prayer.values) d * atTimeDayStride + p.index,
      ];
      final reminderIds = [
        for (var d = 0; d < scheduleDaysAhead; d++)
          for (final p in Prayer.values)
            reminderIdBase + d * reminderDayStride + p.index,
      ];
      expect(prayerIds, everyElement(isNot(QadaReminders.notificationId)));
      expect(reminderIds, everyElement(isNot(QadaReminders.notificationId)));
      expect(QadaReminders.notificationId,
          isNot(NotificationService.sunReminderId));
      expect(QadaReminders.notificationId,
          isNot(NotificationService.testNotificationId));
    });

    test('minutesKey is the agreed Worker B literal', () {
      expect(QadaReminders.minutesKey, 'qada_reminder_minutes');
    });

    test('fallback strings are generic: no counts, no sensitive content', () {
      expect(QadaReminders.fallbackTitle, 'Qada reminder');
      expect(
          QadaReminders.fallbackBody, 'Time for your planned make-up prayers.');
      expect(QadaReminders.fallbackBody, isNot(contains(RegExp(r'\d'))));
    });
  });

  group('nextFireUtc', () {
    test('fires today when the slot is still ahead', () {
      // nowUtc 2026-10-19 12:00Z, offset +5:00 -> wall 17:00; slot 20:00.
      final fire = QadaReminders.nextFireUtc(
        minutesSinceMidnight: 20 * 60,
        nowUtc: DateTime.utc(2026, 10, 19, 12, 0),
        zoneOffset: const Duration(hours: 5),
      );
      expect(fire, DateTime.utc(2026, 10, 19, 15, 0));
    });

    test('rolls to tomorrow when today\'s slot passed', () {
      // wall 17:00; slot 08:00 -> tomorrow 08:00+05:00 = 03:00Z.
      final fire = QadaReminders.nextFireUtc(
        minutesSinceMidnight: 8 * 60,
        nowUtc: DateTime.utc(2026, 10, 19, 12, 0),
        zoneOffset: const Duration(hours: 5),
      );
      expect(fire, DateTime.utc(2026, 10, 20, 3, 0));
    });

    test('a slot exactly at now rolls to tomorrow', () {
      // Scheduling a slot exactly at "now" would fire immediately, so it
      // rolls like any passed slot: tomorrow 17:00+05:00 = 12:00Z.
      final fire = QadaReminders.nextFireUtc(
        minutesSinceMidnight: 17 * 60,
        nowUtc: DateTime.utc(2026, 10, 19, 12, 0),
        zoneOffset: const Duration(hours: 5),
      );
      expect(fire, DateTime.utc(2026, 10, 20, 12, 0));
    });

    test('offset-parametric: same wall slot, different fixed offsets', () {
      // Half-hour zone: nowUtc 12:00Z, offset +5:30 -> wall 17:30.
      final fire = QadaReminders.nextFireUtc(
        minutesSinceMidnight: 20 * 60,
        nowUtc: DateTime.utc(2026, 10, 19, 12, 0),
        zoneOffset: const Duration(hours: 5, minutes: 30),
      );
      expect(fire, DateTime.utc(2026, 10, 19, 14, 30));
      // Negative offset: nowUtc 12:00Z, offset -4:00 -> wall 08:00.
      final fireWest = QadaReminders.nextFireUtc(
        minutesSinceMidnight: 20 * 60,
        nowUtc: DateTime.utc(2026, 10, 19, 12, 0),
        zoneOffset: const Duration(hours: -4),
      );
      expect(fireWest, DateTime.utc(2026, 10, 20, 0, 0));
    });

    test('DST-ish: the same wall slot maps differently per offset frame',
        () {
      // The per-date refinement in scheduleDaily relies on this: the helper
      // itself is purely offset-parametric. Slot 02:30 with now at wall
      // 17:00 rolls to tomorrow in both frames, but lands on different
      // instants.
      final firePlus5 = QadaReminders.nextFireUtc(
        minutesSinceMidnight: 2 * 60 + 30,
        nowUtc: DateTime.utc(2026, 10, 19, 12, 0),
        zoneOffset: const Duration(hours: 5),
      );
      final firePlus6 = QadaReminders.nextFireUtc(
        minutesSinceMidnight: 2 * 60 + 30,
        nowUtc: DateTime.utc(2026, 10, 19, 12, 0),
        zoneOffset: const Duration(hours: 6),
      );
      expect(firePlus5, DateTime.utc(2026, 10, 19, 21, 30));
      expect(firePlus6, DateTime.utc(2026, 10, 19, 20, 30));
    });
  });

  group('scheduleDaily', () {
    test('records one id-2000 notification at the next fire instant',
        () async {
      final fake = FakeNotificationScheduler();
      final minutes = _slotMinutesAhead(180);
      final before = DateTime.now().toUtc();
      await QadaReminders.scheduleDaily(
        minutesSinceMidnight: minutes,
        title: 'Qada reminder',
        body: 'Time for your planned make-up prayers.',
        scheduler: fake,
      );
      final after = DateTime.now().toUtc();
      final offset = TimezoneService.deviceOffsetForDate(DateTime.now());
      final expectedBefore = QadaReminders.nextFireUtc(
        minutesSinceMidnight: minutes,
        nowUtc: before,
        zoneOffset: offset,
      );
      final expectedAfter = QadaReminders.nextFireUtc(
        minutesSinceMidnight: minutes,
        nowUtc: after,
        zoneOffset: offset,
      );
      expect(expectedBefore, expectedAfter,
          reason: 'test crossed the daily slot boundary mid-run');
      expect(fake.scheduled, hasLength(1));
      final scheduled = fake.scheduled.single;
      expect(scheduled.id, QadaReminders.notificationId);
      expect(scheduled.title, 'Qada reminder');
      expect(scheduled.body, 'Time for your planned make-up prayers.');
      expect(scheduled.scheduledUtc, expectedBefore);
      expect(scheduled.scheduledUtc.isAfter(after), isTrue);
      // The fake grants exact alarms: the pass-through must be honored.
      expect(scheduled.exact, isTrue);
    });

    test('uses each fire day\'s own offset (simulated DST transition)',
        () async {
      final fake = FakeNotificationScheduler();
      final now = DateTime.now();
      final realToday = DateTime(now.year, now.month, now.day);
      final realTomorrow = realToday.add(const Duration(days: 1));
      // Simulated zone: +5:00 through today, +6:00 from tomorrow on
      // (spring forward overnight), keyed on civil dates exactly as
      // TimezoneService.deviceOffsetForDate is.
      Duration fakeZone(DateTime date) {
        final d = DateTime(date.year, date.month, date.day);
        return d.isBefore(realTomorrow)
            ? const Duration(hours: 5)
            : const Duration(hours: 6);
      }
      // 00:00 always rolls to the next day (a slot exactly at "now" rolls
      // too), so the fire day deterministically falls in the +6:00 frame:
      // the first offset read (today) is +5:00, the fire day's is +6:00.
      await QadaReminders.scheduleDaily(
        minutesSinceMidnight: 0,
        title: 't',
        body: 'b',
        scheduler: fake,
        offsetForDate: fakeZone,
      );
      final fireUtc = fake.scheduled.single.scheduledUtc;
      // The fire day's own (+6:00) offset was applied: 00:00 wall time in
      // the +6 frame, on a day after today.
      final wallPlus6 = fireUtc.add(const Duration(hours: 6));
      expect(wallPlus6.hour * 60 + wallPlus6.minute, 0);
      expect(
        DateTime(wallPlus6.year, wallPlus6.month, wallPlus6.day)
            .isAfter(realToday),
        isTrue,
      );
      // ...and the pre-transition (+5:00) offset was NOT used: in the +5
      // frame the same instant is 23:00 the previous day, never 00:00.
      final wallPlus5 = fireUtc.add(const Duration(hours: 5));
      expect(wallPlus5.hour * 60 + wallPlus5.minute, isNot(0));
    });

    test('re-scheduling cancels the previous id-2000 notification first',
        () async {
      final fake = FakeNotificationScheduler();
      await QadaReminders.scheduleDaily(
        minutesSinceMidnight: _slotMinutesAhead(60),
        title: 't',
        body: 'b',
        scheduler: fake,
      );
      await QadaReminders.scheduleDaily(
        minutesSinceMidnight: _slotMinutesAhead(120),
        title: 't',
        body: 'b',
        scheduler: fake,
      );
      // One cancel per schedule, always before the new schedule lands: the
      // platform therefore holds exactly one qada reminder.
      expect(fake.cancelledIds,
          [QadaReminders.notificationId, QadaReminders.notificationId]);
      expect(fake.scheduled.map((s) => s.id),
          [QadaReminders.notificationId, QadaReminders.notificationId]);
    });

    test('rejects out-of-range minutes', () async {
      final fake = FakeNotificationScheduler();
      await expectLater(
        QadaReminders.scheduleDaily(
          minutesSinceMidnight: -1,
          title: 't',
          body: 'b',
          scheduler: fake,
        ),
        throwsRangeError,
      );
      await expectLater(
        QadaReminders.scheduleDaily(
          minutesSinceMidnight: 24 * 60,
          title: 't',
          body: 'b',
          scheduler: fake,
        ),
        throwsRangeError,
      );
      expect(fake.scheduled, isEmpty);
      expect(fake.cancelledIds, isEmpty);
    });
  });

  group('cancel', () {
    test('cancels the id-2000 notification', () async {
      final fake = FakeNotificationScheduler();
      await QadaReminders.scheduleDaily(
        minutesSinceMidnight: _slotMinutesAhead(60),
        title: 't',
        body: 'b',
        scheduler: fake,
      );
      await QadaReminders.cancel(fake);
      expect(
          fake.cancelledIds.last, QadaReminders.notificationId);
    });
  });

  group('restoreOnBoot', () {
    test('enabled: re-schedules with the plain-English fallback strings',
        () async {
      final fake = FakeNotificationScheduler();
      await QadaReminders.restoreOnBoot(
        minutesSinceMidnight: 8 * 60,
        scheduler: fake,
      );
      expect(fake.scheduled, hasLength(1));
      final scheduled = fake.scheduled.single;
      expect(scheduled.id, QadaReminders.notificationId);
      expect(scheduled.title, QadaReminders.fallbackTitle);
      expect(scheduled.body, QadaReminders.fallbackBody);
      expect(scheduled.scheduledUtc.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('disabled (null minutes): no-ops without touching the scheduler',
        () async {
      final fake = FakeNotificationScheduler();
      await QadaReminders.restoreOnBoot(
        minutesSinceMidnight: null,
        scheduler: fake,
      );
      expect(fake.scheduled, isEmpty);
      expect(fake.cancelledIds, isEmpty);
    });
  });
}
