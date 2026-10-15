import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Stable id offset for pre-prayer reminder notifications: the reminder for
/// [Prayer] `p` uses id `reminderIdBase + p.index`, while the at-time
/// notification uses `p.index`.
const int reminderIdBase = 1000;

/// One scheduled notification, as recorded by [FakeNotificationScheduler].
@immutable
class ScheduledNotification {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledUtc;
  final bool exact;

  const ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledUtc,
    required this.exact,
  });
}

/// Injectable seam between [NotificationService] and the platform
/// notification plugin. The real implementation wraps
/// `flutter_local_notifications`; [FakeNotificationScheduler] records calls
/// for tests so no real notification is ever scheduled in tests.
abstract class NotificationScheduler {
  /// Prepares the plugin (initialization settings, notification channel).
  /// The timezone database must be initialized before scheduling; the real
  /// implementation calls `tz.initializeTimeZones()` here.
  Future<void> initialize();

  /// True when the app may currently post notifications (prompted on first
  /// call where the platform requires it).
  Future<bool> areNotificationsEnabled();

  /// Asks the user for notification permission. Returns true when granted.
  Future<bool> requestPermissions();

  /// Android only: true when the app may schedule exact alarms. Always true
  /// on iOS. When false, notifications are scheduled inexact (they may
  /// arrive late) — the UI must say so honestly.
  Future<bool> canScheduleExactAlarms();

  /// Android only: opens the system screen where the user can grant exact
  /// alarms. No-op elsewhere.
  Future<void> openExactAlarmSettings();

  /// Schedules one notification at the UTC instant [scheduledUtc].
  /// [exact] selects an exact vs inexact Android schedule mode.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledUtc,
    required bool exact,
  });

  /// Cancels the notification with [id].
  Future<void> cancel(int id);

  /// Cancels every notification scheduled by this app.
  Future<void> cancelAll();
}

/// Real [NotificationScheduler] backed by `flutter_local_notifications`.
class PluginNotificationScheduler implements NotificationScheduler {
  static const _channel = AndroidNotificationChannel(
    'prayer_times',
    'Prayer times',
    description: 'Prayer-time and pre-prayer reminder notifications.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          true;
    }
    // iOS offers no non-prompting status check; treat a previous grant as
    // the state and let requestPermissions() establish it.
    return true;
  }

  @override
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        false;
  }

  @override
  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledUtc,
    required bool exact,
  }) async {
    final when = tz.TZDateTime.from(scheduledUtc.toUtc(), tz.UTC);
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Test double for [NotificationScheduler]: records every schedule/cancel
/// call and never touches the platform. Permission and exact-alarm answers
/// are controllable fields.
class FakeNotificationScheduler implements NotificationScheduler {
  final List<ScheduledNotification> scheduled = [];
  final List<int> cancelledIds = [];
  int cancelAllCount = 0;
  int initializeCount = 0;
  int openExactAlarmSettingsCount = 0;

  bool notificationsEnabledResult = true;
  bool permissionResult = true;
  bool exactAlarmsResult = true;

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<bool> areNotificationsEnabled() async => notificationsEnabledResult;

  @override
  Future<bool> requestPermissions() async => permissionResult;

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmsResult;

  @override
  Future<void> openExactAlarmSettings() async {
    openExactAlarmSettingsCount++;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledUtc,
    required bool exact,
  }) async {
    scheduled.add(ScheduledNotification(
      id: id,
      title: title,
      body: body,
      scheduledUtc: scheduledUtc.toUtc(),
      exact: exact,
    ));
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }
}

/// Localized strings for prayer notifications. The coordinator builds these
/// from the app localizations (which need a [BuildContext]) and hands them
/// to [NotificationService].
@immutable
class NotificationTexts {
  final String Function(Prayer prayer) titleFor;
  final String Function(Prayer prayer) bodyFor;
  final String Function(Prayer prayer, int minutesBefore) reminderTitleFor;
  final String Function(Prayer prayer, int minutesBefore) reminderBodyFor;

  const NotificationTexts({
    required this.titleFor,
    required this.bodyFor,
    required this.reminderTitleFor,
    required this.reminderBodyFor,
  });

  /// Plain English fallback, used only when no localizations are available
  /// (e.g. a timezone-change reschedule fired before the UI builds).
  factory NotificationTexts.fallback() => NotificationTexts(
        titleFor: (p) => '${_englishName(p)} time',
        bodyFor: (p) => 'It is now time for ${_englishName(p)}.',
        reminderTitleFor: (p, m) => '${_englishName(p)} in $m minutes',
        reminderBodyFor: (p, m) =>
            '${_englishName(p)} begins in $m minutes.',
      );

  static String _englishName(Prayer p) => switch (p) {
        Prayer.fajr => 'Fajr',
        Prayer.sunrise => 'Sunrise',
        Prayer.dhuhr => 'Dhuhr',
        Prayer.asr => 'Asr',
        Prayer.maghrib => 'Maghrib',
        Prayer.isha => 'Isha',
      };
}

/// Schedules prayer-time notifications from the calculation engine.
///
/// ## Scheduling model
/// [rescheduleAll] cancels everything, then schedules each enabled prayer's
/// next at-time notification (id = [Prayer.index]) and, when a reminder
/// offset is set, its pre-prayer reminder (id = [reminderIdBase] +
/// [Prayer.index]): today's time when still upcoming, otherwise tomorrow's.
/// Ids are stable per prayer, so exactly one upcoming occurrence exists per
/// prayer. Times come from the same [SettingsService.adjustedTime] logic the
/// UI shows, minus the reminder offset. Times already past are skipped so
/// nothing fires immediately.
///
/// The app is expected to call [rescheduleAll] whenever it starts and
/// whenever the location, profile, adjustments, toggles, or reminder offset
/// change — scheduled notifications do not refresh themselves.
///
/// ## Timezone changes
/// The last known [DateTime.now().timeZoneName] is persisted. On [init], if
/// it differs, the stored location/profile are rescheduled with the new
/// system offset. Delivery itself is best-effort: Android Doze and aggressive
/// battery optimization can delay or drop notifications, and iOS background
/// limits apply — the settings UI says this plainly.
class NotificationService {
  final NotificationScheduler _scheduler;

  static const _lastTimeZoneKey = 'notifications_last_tz_name';
  static const _lastLatKey = 'notifications_last_lat';
  static const _lastLonKey = 'notifications_last_lon';
  static const _lastProfileKey = 'notifications_last_profile_id';
  static const _lastOffsetMinutesKey = 'notifications_last_offset_minutes';

  NotificationService({required this._scheduler});

  /// Initializes the plugin, the timezone database, and the notification
  /// channel, then reschedules if the device timezone changed since the last
  /// run. [texts] localizes the notifications scheduled by the
  /// timezone-change path.
  Future<void> init({required NotificationTexts texts}) async {
    await _scheduler.initialize();
    await _syncTimeZone(texts: texts);
  }

  /// True when the app may currently post notifications.
  Future<bool> areNotificationsEnabled() =>
      _scheduler.areNotificationsEnabled();

  /// Asks the user for notification permission. Returns true when granted.
  Future<bool> requestPermissions() => _scheduler.requestPermissions();

  /// Android: whether exact alarms are allowed. When false, notifications are
  /// scheduled inexact and may arrive late.
  Future<bool> canScheduleExactAlarms() =>
      _scheduler.canScheduleExactAlarms();

  /// Android: opens the system exact-alarm settings. No-op elsewhere.
  Future<void> openExactAlarmSettings() =>
      _scheduler.openExactAlarmSettings();

  /// Cancels every notification scheduled by this app.
  Future<void> cancelAll() => _scheduler.cancelAll();

  /// One-time notification id reserved for the Qibla sun-alignment reminder.
  /// Kept clear of the prayer ids ([Prayer.index]) and the reminder block
  /// ([reminderIdBase] + [Prayer.index]).
  static const int sunReminderId = 950;
  static const _sunReminderUtcKey = 'sun_reminder_utc';
  static const _sunReminderTitleKey = 'sun_reminder_title';
  static const _sunReminderBodyKey = 'sun_reminder_body';

  /// Schedules a one-time reminder for the sun–qibla alignment moment.
  /// Persisted so [rescheduleAll] (which cancels everything first) restores
  /// it while its fire time is still in the future.
  Future<void> scheduleSunReminder({
    required DateTime scheduledUtc,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _sunReminderUtcKey, scheduledUtc.toIso8601String());
    await prefs.setString(_sunReminderTitleKey, title);
    await prefs.setString(_sunReminderBodyKey, body);
    final exact = await _scheduler.canScheduleExactAlarms();
    await _scheduler.schedule(
      id: sunReminderId,
      title: title,
      body: body,
      scheduledUtc: scheduledUtc,
      exact: exact,
    );
  }

  /// Cancels the sun-alignment reminder and clears the persisted record.
  Future<void> cancelSunReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sunReminderUtcKey);
    await prefs.remove(_sunReminderTitleKey);
    await prefs.remove(_sunReminderBodyKey);
    await _scheduler.cancel(sunReminderId);
  }

  /// Recomputes and reschedules notifications from the engine, using the same
  /// adjusted times the UI shows. Notification ids are stable per prayer
  /// ([Prayer.index] for the at-time notification, [reminderIdBase] +
  /// [Prayer.index] for the reminder), so exactly one upcoming occurrence is
  /// scheduled per prayer: today's time when it is still in the future,
  /// otherwise tomorrow's. A reminder whose fire time already passed is
  /// skipped while its at-time notification is still scheduled.
  ///
  /// [now] is the current instant (UTC or local); it defaults to
  /// [DateTime.now] and exists so tests can use a fixed clock.
  Future<void> rescheduleAll({
    required Coordinates coords,
    required PrayerProfile profile,
    required SettingsService settings,
    required Duration timeZoneOffset,
    required NotificationTexts texts,
    DateTime? now,
  }) async {
    await _scheduler.cancelAll();

    final nowUtc = (now ?? DateTime.now()).toUtc();
    final nowWall = nowUtc.add(timeZoneOffset);
    final todayWall =
        DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    final reminderMinutes = settings.reminderOffsetMinutes;
    final exact = await _scheduler.canScheduleExactAlarms();

    DateTime prayerUtcFor(Prayer prayer, DateTime date) {
      final times = calculatePrayerTimes(
        coordinates: coords,
        date: date,
        timeZoneOffset: timeZoneOffset,
        profile: profile,
      );
      // `adjustedTime` returns a UTC-kind DateTime whose fields are
      // wall-clock values; subtract the offset to recover the true instant.
      return settings.adjustedTime(prayer, times.timeFor(prayer)).subtract(
            timeZoneOffset,
          );
    }

    final tomorrowWall = todayWall.add(const Duration(days: 1));
    final prefs = await SharedPreferences.getInstance();
    // A persisted sun–qibla alignment reminder: cancelAll() wiped its
    // schedule above, so restore it while its fire time is still ahead.
    final sunUtc =
        DateTime.tryParse(prefs.getString(_sunReminderUtcKey) ?? '');
    final sunTitle = prefs.getString(_sunReminderTitleKey);
    final sunBody = prefs.getString(_sunReminderBodyKey);
    final bool restoreSun = sunUtc != null &&
        sunUtc.isAfter(nowUtc) &&
        sunTitle != null &&
        sunBody != null;
    if (!restoreSun && sunUtc != null) {
      await prefs.remove(_sunReminderUtcKey);
      await prefs.remove(_sunReminderTitleKey);
      await prefs.remove(_sunReminderBodyKey);
    }
    for (final prayer in Prayer.values) {
      if (!(settings.notificationToggles[prayer] ?? false)) continue;
      var fireUtc = prayerUtcFor(prayer, todayWall);
      if (!fireUtc.isAfter(nowUtc)) {
        fireUtc = prayerUtcFor(prayer, tomorrowWall);
      }
      if (!fireUtc.isAfter(nowUtc)) continue;
      await _scheduler.schedule(
        id: prayer.index,
        title: texts.titleFor(prayer),
        body: texts.bodyFor(prayer),
        scheduledUtc: fireUtc,
        exact: exact,
      );
      if (reminderMinutes > 0) {
        final reminderUtc =
            fireUtc.subtract(Duration(minutes: reminderMinutes));
        if (reminderUtc.isAfter(nowUtc)) {
          await _scheduler.schedule(
            id: reminderIdBase + prayer.index,
            title: texts.reminderTitleFor(prayer, reminderMinutes),
            body: texts.reminderBodyFor(prayer, reminderMinutes),
            scheduledUtc: reminderUtc,
            exact: exact,
          );
        }
      }
    }

    await prefs.setDouble(_lastLatKey, coords.latitude);
    await prefs.setDouble(_lastLonKey, coords.longitude);
    await prefs.setString(_lastProfileKey, profile.id);
    await prefs.setInt(_lastOffsetMinutesKey, timeZoneOffset.inMinutes);
    await prefs.setString(_lastTimeZoneKey, DateTime.now().timeZoneName);
    if (sunUtc != null &&
        sunUtc.isAfter(nowUtc) &&
        sunTitle != null &&
        sunBody != null) {
      // The null checks above promote these final locals to non-null.
      await _scheduler.schedule(
        id: sunReminderId,
        title: sunTitle,
        body: sunBody,
        scheduledUtc: sunUtc,
        exact: exact,
      );
    }
  }

  /// Compares the persisted timezone name with the current one and, when it
  /// changed, reschedules with the new system offset using the stored
  /// location and profile. Exposed for tests with injectable values.
  @visibleForTesting
  Future<void> syncTimeZoneForTest({
    required String currentName,
    required Duration currentOffset,
    required NotificationTexts texts,
  }) =>
      _syncTimeZone(
        texts: texts,
        testName: currentName,
        testOffset: currentOffset,
      );

  Future<void> _syncTimeZone({
    required NotificationTexts texts,
    String? testName,
    Duration? testOffset,
  }) async {
    final currentName = testName ?? DateTime.now().timeZoneName;
    final currentOffset = testOffset ?? DateTime.now().timeZoneOffset;
    final prefs = await SharedPreferences.getInstance();
    final lastName = prefs.getString(_lastTimeZoneKey);
    await prefs.setString(_lastTimeZoneKey, currentName);
    if (lastName == null || lastName == currentName) return;

    final lat = prefs.getDouble(_lastLatKey);
    final lon = prefs.getDouble(_lastLonKey);
    final profileId = prefs.getString(_lastProfileKey);
    if (lat == null || lon == null || profileId == null) return;
    final profile = PrayerProfiles.all.firstWhere(
      (p) => p.id == profileId,
      orElse: () => PrayerProfiles.defaultProfile,
    );
    final settings = await SettingsService.load();
    await rescheduleAll(
      coords: Coordinates(lat, lon),
      profile: profile,
      settings: settings,
      timeZoneOffset: currentOffset,
      texts: texts,
    );
    // rescheduleAll persists DateTime.now().timeZoneName; restore the
    // authoritative value for this sync (identical in production, where the
    // test overrides are absent).
    await prefs.setString(_lastTimeZoneKey, currentName);
  }
}
