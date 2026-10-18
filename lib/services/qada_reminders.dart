import 'package:flutter/foundation.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/timezone_service.dart';

/// Optional daily Qada (make-up prayer) reminders.
///
/// A single daily notification — notification id
/// [QadaReminders.notificationId] — fires at the device-local time the user
/// chose ([minutesKey] in SharedPreferences, minutes since midnight; an
/// absent key means the reminder is disabled). The reminder is a nudge, not
/// a completion: scheduling it never creates or modifies qada records.
///
/// ## Scheduling model
/// Exactly one upcoming occurrence is scheduled at a time, following the
/// same architecture as [NotificationService.rescheduleAll]: the in-app
/// layer calls [scheduleDaily] on app start and whenever the reminder time
/// changes, and the boot path restores it via [restoreOnBoot]. The OS does
/// not repeat the notification on its own — each scheduling pass computes
/// the NEXT fire time in the device wall-clock frame and lets the OS deliver
/// it; the next pass (app open, settings change, reboot) schedules the one
/// after that. [scheduleDaily] is cancel-then-schedule on a stable id, so
/// there is never more than one qada reminder pending.
///
/// ## Privacy
/// Title and body stay generic — no prayer counts, no health-related
/// content (the OS may show them on the lock screen). [restoreOnBoot] uses
/// the plain-English [fallbackTitle]/[fallbackBody] because localizations
/// are unavailable in the headless boot path.
///
/// ## Timezones
/// Fire times are built with [TimezoneService.deviceOffsetForDate] — the
/// device wall-clock offset for each target civil date, DST-correct per
/// date — the corrected path that replaced the deleted
/// `TimezoneService.deviceZoneId` (2026-10-18). The per-date offset is an
/// injectable [offsetForDate] (device default) so DST transitions are
/// unit-testable, mirroring [NotificationService.rescheduleAll].
abstract final class QadaReminders {
  /// Stable notification id for the daily qada reminder. Kept clear of every
  /// other id the app uses: at-time prayer notifications use
  /// [Prayer.index] (0–5), pre-prayer reminders use
  /// [reminderIdBase] + [Prayer.index] (1000–1005), and the sun–qibla
  /// reminder uses [NotificationService.sunReminderId] (950).
  static const int notificationId = 2000;

  /// SharedPreferences key holding the reminder time as minutes since
  /// midnight in the device wall-clock frame. Shared with Worker B's
  /// QadaService: a missing key means the reminder is disabled.
  static const String minutesKey = 'qada_reminder_minutes';

  /// Plain-English fallback title for the headless boot path, where
  /// localizations are unavailable. Generic by design: the OS may show it
  /// on the lock screen.
  static const String fallbackTitle = 'Qada reminder';

  /// Plain-English fallback body for the headless boot path. Same privacy
  /// rule as [fallbackTitle]: no counts, no health-related content.
  static const String fallbackBody = 'Time for your planned make-up prayers.';

  /// Schedules the next occurrence of the daily reminder at
  /// [minutesSinceMidnight] device-local time, replacing any existing
  /// qada-reminder notification (cancel-then-schedule on [notificationId]).
  ///
  /// [title]/[body] are caller-localized; the body must stay generic —
  /// never include prayer counts or health-related content.
  ///
  /// [offsetForDate] resolves the device wall-clock offset for a civil
  /// date; it defaults to [TimezoneService.deviceOffsetForDate] and exists
  /// so tests can inject a DST-transitioning fake zone.
  ///
  /// Throws [RangeError] when [minutesSinceMidnight] is outside 0–1439.
  static Future<void> scheduleDaily({
    required int minutesSinceMidnight,
    required String title,
    required String body,
    required NotificationScheduler scheduler,
    @visibleForTesting Duration Function(DateTime date)? offsetForDate,
  }) async {
    if (minutesSinceMidnight < 0 || minutesSinceMidnight >= 24 * 60) {
      throw RangeError.range(
        minutesSinceMidnight,
        0,
        24 * 60 - 1,
        'minutesSinceMidnight',
      );
    }
    // Cancel-then-schedule: the id is stable, so scheduling replaces any
    // existing qada reminder — exactly one is ever pending.
    await scheduler.cancel(notificationId);
    final resolveOffset =
        offsetForDate ?? TimezoneService.deviceOffsetForDate;
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final todayWall = DateTime(now.year, now.month, now.day);
    final todayOffset = resolveOffset(todayWall);
    var fireUtc = nextFireUtc(
      minutesSinceMidnight: minutesSinceMidnight,
      nowUtc: nowUtc,
      zoneOffset: todayOffset,
    );
    // [nextFireUtc] rolls to tomorrow when today's slot passed. Resolve the
    // fire day's own offset so a DST transition overnight does not pin the
    // fire time to today's offset — the same per-date convention
    // NotificationService.rescheduleAll uses.
    final fireDayWall = fireUtc.add(todayOffset);
    final fireDay =
        DateTime(fireDayWall.year, fireDayWall.month, fireDayWall.day);
    if (fireDay.isAfter(todayWall)) {
      final fireDayOffset = resolveOffset(fireDay);
      if (fireDayOffset != todayOffset) {
        fireUtc = nextFireUtc(
          minutesSinceMidnight: minutesSinceMidnight,
          nowUtc: nowUtc,
          zoneOffset: fireDayOffset,
        );
      }
    }
    final exact = await scheduler.canScheduleExactAlarms();
    await scheduler.schedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledUtc: fireUtc,
      exact: exact,
    );
  }

  /// Cancels the qada reminder. The UI layer calls this when the user
  /// disables the reminder (null minutes); the boot path needs no explicit
  /// cancel because it runs after [NotificationService.rescheduleAll]'s
  /// `cancelAll()`.
  static Future<void> cancel(NotificationScheduler scheduler) =>
      scheduler.cancel(notificationId);

  /// Headless-boot helper for [rescheduleOnBoot] in `boot_reschedule.dart`:
  /// re-schedules the reminder when [minutesSinceMidnight] is non-null
  /// (enabled), no-ops when null (disabled). Never throws — an optional
  /// reminder must not break the boot path. Kept separate from the
  /// entrypoint so it is unit-testable (the real entrypoint needs a
  /// headless engine and cannot run under `flutter test`).
  static Future<void> restoreOnBoot({
    required int? minutesSinceMidnight,
    required NotificationScheduler scheduler,
  }) async {
    try {
      final minutes = minutesSinceMidnight;
      if (minutes == null) return;
      await scheduleDaily(
        minutesSinceMidnight: minutes,
        title: fallbackTitle,
        body: fallbackBody,
        scheduler: scheduler,
      );
    } catch (_) {
      // Boot path: silence. No sensitive data is logged here by design.
    }
  }

  /// Next fire time as a UTC instant for a daily wall-clock time in an
  /// offset frame: today's occurrence when it is still strictly in the
  /// future, otherwise tomorrow's. Pure and unit-testable with fixed
  /// offsets, so DST-ish boundaries can be exercised without a device.
  ///
  /// [minutesSinceMidnight] is the daily time in the wall-clock frame
  /// [zoneOffset] describes; [nowUtc] is the current instant. A slot
  /// exactly at "now" rolls to tomorrow — scheduling it today would fire
  /// immediately.
  static DateTime nextFireUtc({
    required int minutesSinceMidnight,
    required DateTime nowUtc,
    required Duration zoneOffset,
  }) {
    final nowWall = nowUtc.add(zoneOffset);
    final hour = minutesSinceMidnight ~/ 60;
    final minute = minutesSinceMidnight % 60;
    DateTime wallFor(DateTime day) => DateTime.utc(
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        );
    final todayWall = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    var fireWall = wallFor(todayWall);
    if (!fireWall.isAfter(nowWall)) {
      fireWall = wallFor(todayWall.add(const Duration(days: 1)));
    }
    return fireWall.subtract(zoneOffset);
  }
}
