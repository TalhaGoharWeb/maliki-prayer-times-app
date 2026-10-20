import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/services/timezone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Stable id base for pre-prayer reminder notifications. Ids are laid out
/// in per-day blocks (see [NotificationService.rescheduleAll]): the at-time
/// notification for day-offset `d` and prayer `p` uses id
/// `d * atTimeDayStride + p.index` (0–65), and its reminder uses
/// `reminderIdBase + d * reminderDayStride + p.index` (1000–1605). The
/// blocks stay clear of the sun–qibla reminder (950), the test
/// notification (999) and the qada reminder (2000).
const int reminderIdBase = 1000;

/// Days of prayer notifications kept armed ahead of time. Scheduling only
/// the single next occurrence per prayer (the pre-1.3.4 model) meant the
/// chain silently ended whenever the user did not open the app (or reboot)
/// on a given day; a week of armed alarms survives ordinary use.
const int scheduleDaysAhead = 7;

/// Per-day id stride for at-time prayer notifications.
const int atTimeDayStride = 10;

/// Per-day id stride inside the reminder block.
const int reminderDayStride = 100;

/// One scheduled notification, as recorded by [FakeNotificationScheduler].
@immutable
class ScheduledNotification {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledUtc;
  final bool exact;

  /// True when this notification was routed to the adhan-sound channel
  /// (at-time prayer notifications). Reminders and other alerts use the
  /// default sound.
  final bool adhanSound;

  const ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledUtc,
    required this.exact,
    this.adhanSound = false,
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
  /// [adhanSound], when true, plays the adhan recording instead of the
  /// default notification sound (Android: separate notification channel,
  /// since the sound belongs to the channel on Android 8+).
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledUtc,
    required bool exact,
    bool adhanSound = false,
  });

  /// Cancels the notification with [id].
  Future<void> cancel(int id);

  /// Cancels every notification scheduled by this app.
  Future<void> cancelAll();

  /// How many notifications are currently armed with the platform. Shown
  /// in Settings as a delivery diagnostic: after a reschedule it should
  /// be in the dozens (a week of prayers); zero means scheduling itself
  /// is broken, while a healthy count with no delivery points at the
  /// phone's battery manager.
  Future<int> pendingCount();
}

/// Real [NotificationScheduler] backed by `flutter_local_notifications`.
class PluginNotificationScheduler implements NotificationScheduler {
  /// Raw resource name (`res/raw/<name>.mp3`) of the user-supplied Tunisian
  /// adhan recording played for at-time prayer notifications.
  static const adhanSoundResource = 'tunisi_adhan';

  /// iOS bundle file (≤30 s platform cap) of the trimmed adhan excerpt,
  /// wired into the Xcode project under `ios/Runner/adhan/`.
  static const iosAdhanSoundFile = 'tunisi_adhan_30s.mp3';

  static const _adhanSound =
      RawResourceAndroidNotificationSound(adhanSoundResource);

  /// At-time prayer notifications: announced with the adhan.
  static const _channel = AndroidNotificationChannel(
    'prayer_times',
    'Prayer times',
    description: 'Prayer-time notifications, announced with the adhan.',
    importance: Importance.high,
    sound: _adhanSound,
  );

  /// Pre-prayer reminders and other alerts: default notification sound.
  /// (On Android 8+ the sound belongs to the channel, so the adhan and the
  /// default sound need separate channels.)
  static const _reminderChannel = AndroidNotificationChannel(
    'prayer_times_reminders',
    'Prayer reminders',
    description: 'Pre-prayer reminders and other alerts.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    // The tz database is owned by TimezoneService (bundled latest_10y);
    // this only ensures it is initialized before scheduling.
    TimezoneService.ensureInitialized();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Channels are immutable once created: delete first so an upgrade from
    // an earlier app version picks up the adhan sound (no-op on fresh
    // installs).
    await android?.deleteNotificationChannel(channelId: _channel.id);
    await android?.deleteNotificationChannel(channelId: _reminderChannel.id);
    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_reminderChannel);
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
    bool adhanSound = false,
  }) async {
    final when = tz.TZDateTime.from(scheduledUtc.toUtc(), tz.UTC);
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          adhanSound ? _channel.id : _reminderChannel.id,
          adhanSound ? _channel.name : _reminderChannel.name,
          channelDescription: adhanSound
              ? _channel.description
              : _reminderChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          sound: adhanSound ? _adhanSound : null,
        ),
        iOS: DarwinNotificationDetails(
          sound: adhanSound ? iosAdhanSoundFile : null,
        ),
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

  @override
  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;
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
    bool adhanSound = false,
  }) async {
    scheduled.add(ScheduledNotification(
      id: id,
      title: title,
      body: body,
      scheduledUtc: scheduledUtc.toUtc(),
      exact: exact,
      adhanSound: adhanSound,
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

  @override
  Future<int> pendingCount() async => scheduled.length;
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

/// Derives the UTC offset for a local civil [date] from the device
/// timezone. Used as the default [NotificationService.rescheduleAll]
/// per-date offset so a DST transition between today and tomorrow schedules
/// each day in its own frame instead of pinning every date to today's
/// offset.
Duration _deviceOffsetForDate(DateTime date) =>
    DateTime(date.year, date.month, date.day).timeZoneOffset;

/// Schedules prayer-time notifications from the calculation engine.
///
/// ## Scheduling model
/// [rescheduleAll] cancels everything, then arms a week of notifications:
/// for each of the next [scheduleDaysAhead] civil days, each enabled
/// prayer's at-time notification (id = day-offset block + [Prayer.index])
/// and, when a reminder offset is set, its pre-prayer reminder (id =
/// [reminderIdBase] + day-offset block + [Prayer.index]). Times come from
/// the same [SettingsService.adjustedTime] logic the UI shows, minus the
/// reminder offset. Times already past are skipped so nothing fires
/// immediately. Arming a week ahead means delivery no longer depends on
/// the user opening the app every day.
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

  /// Whether the first-launch permission rationale (v2) has been shown.
  /// v1 fired the system dialog directly from initState, which users could
  /// miss or dismiss without noticing; v2 shows an in-app rationale first
  /// and the flag key is bumped so it is offered again.
  static const _permissionRationaleKey = 'notif_permission_asked_v2';

  Future<bool> permissionRationaleShown() async =>
      (await SharedPreferences.getInstance())
          .getBool(_permissionRationaleKey) ??
      false;

  /// Records that the v2 permission rationale was shown (whether the user
  /// proceeded to the system prompt or not), so it is offered exactly once.
  Future<void> markPermissionRationaleShown() async =>
      (await SharedPreferences.getInstance())
          .setBool(_permissionRationaleKey, true);

  /// Android: whether exact alarms are allowed. When false, notifications are
  /// scheduled inexact and may arrive late.
  Future<bool> canScheduleExactAlarms() =>
      _scheduler.canScheduleExactAlarms();

  /// Android: opens the system exact-alarm settings. No-op elsewhere.
  Future<void> openExactAlarmSettings() =>
      _scheduler.openExactAlarmSettings();

  /// Cancels every notification scheduled by this app.
  Future<void> cancelAll() => _scheduler.cancelAll();

  /// How many notifications are currently armed with the platform (the
  /// Settings delivery diagnostic; see [NotificationScheduler.pendingCount]).
  Future<int> pendingScheduledCount() => _scheduler.pendingCount();

  /// One-time notification id reserved for the Qibla sun-alignment reminder.
  /// Kept clear of the at-time prayer blocks (0–65) and the reminder
  /// blocks (1000–1605).
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

  /// One-time test notification id. Kept clear of the at-time prayer
  /// blocks (0–65), the reminder blocks (1000–1605), the sun–qibla
  /// reminder ([sunReminderId]) and the qada reminder (2000).
  static const int testNotificationId = 999;

  /// Schedules a one-shot test notification ~5 s in the future that plays
  /// the adhan sound, so the user can verify notifications and the adhan
  /// audio end to end without waiting for a prayer time.
  Future<void> sendTestNotification({
    required String title,
    required String body,
    DateTime? now,
  }) async {
    final exact = await _scheduler.canScheduleExactAlarms();
    await _scheduler.schedule(
      id: testNotificationId,
      title: title,
      body: body,
      scheduledUtc:
          (now ?? DateTime.now()).toUtc().add(const Duration(seconds: 5)),
      exact: exact,
      adhanSound: true,
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
  /// adjusted times the UI shows. A week of occurrences is armed
  /// ([scheduleDaysAhead] days) with per-day id blocks, so delivery does not
  /// depend on the app being opened daily. A reminder whose fire time
  /// already passed is skipped while its at-time notification is still
  /// scheduled.
  ///
  /// [now] is the current instant (UTC or local); it defaults to
  /// [DateTime.now] and exists so tests can use a fixed clock.
  ///
  /// [timeZoneOffsetForDate] derives the UTC offset for each target civil
  /// date. It defaults to the device timezone's offset for that date (so a
  /// DST transition between today and tomorrow is honored per date); tests
  /// inject a fake zone here. [timeZoneOffset] still frames "today" and is
  /// what gets persisted under the last-offset key.
  ///
  /// [elevationMeters] applies the horizon dip correction to sunrise/sunset
  /// (same as the UI path) so scheduled notifications match the timetable.
  Future<void> rescheduleAll({
    required Coordinates coords,
    required PrayerProfile profile,
    required SettingsService settings,
    required Duration timeZoneOffset,
    required NotificationTexts texts,
    Duration Function(DateTime date)? timeZoneOffsetForDate,
    double elevationMeters = 0.0,
    DateTime? now,
  }) async {
    await _scheduler.cancelAll();

    final nowUtc = (now ?? DateTime.now()).toUtc();
    final nowWall = nowUtc.add(timeZoneOffset);
    final todayWall =
        DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    final reminderMinutes = settings.reminderOffsetMinutes;
    final exact = await _scheduler.canScheduleExactAlarms();
    final offsetForDate = timeZoneOffsetForDate ?? _deviceOffsetForDate;

    DateTime? prayerUtcFor(Prayer prayer, DateTime date) {
      // Each target date is computed in its own offset frame, so a DST
      // transition overnight does not pin tomorrow to today's offset.
      final offset = offsetForDate(date);
      final result = calculatePrayerTimes(
        coordinates: coords,
        date: date,
        timeZoneOffset: offset,
        profile: profile,
        elevationMeters: elevationMeters,
        fallback: settings.highLatitudeFallback,
      );
      // A no-solution day (polar day/night) has nothing to schedule: a
      // calculation failure never produces a plausible-but-unsupported
      // time, so the notification is skipped, not guessed.
      if (result is! PrayerTimesComputed) return null;
      // `adjustedTime` returns a UTC-kind DateTime whose fields are
      // wall-clock values; subtract the date's own offset to recover the
      // true instant.
      return settings.adjustedTime(prayer, result.times.timeFor(prayer)).subtract(
            offset,
          );
    }

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
    // Arm a full week ahead: every enabled prayer's occurrence on each of
    // the next [scheduleDaysAhead] civil days whose fire time is still in
    // the future. (Pre-1.3.4 only the single next occurrence per prayer
    // was armed, so a day without an app launch or reboot silently ended
    // the chain.) Ids are per-day blocks: at-time
    // `dayOffset * atTimeDayStride + prayer.index`, reminder
    // `reminderIdBase + dayOffset * reminderDayStride + prayer.index`.
    for (var dayOffset = 0; dayOffset < scheduleDaysAhead; dayOffset++) {
      final date = todayWall.add(Duration(days: dayOffset));
      for (final prayer in Prayer.values) {
        if (!(settings.notificationToggles[prayer] ?? false)) continue;
        final fireUtc = prayerUtcFor(prayer, date);
        if (fireUtc == null || !fireUtc.isAfter(nowUtc)) continue;
        // The adhan announces the five prayers; sunrise is not a salat, so
        // its notification keeps the default sound.
        await _scheduler.schedule(
          id: dayOffset * atTimeDayStride + prayer.index,
          title: texts.titleFor(prayer),
          body: texts.bodyFor(prayer),
          scheduledUtc: fireUtc,
          exact: exact,
          adhanSound: prayer != Prayer.sunrise,
        );
        if (reminderMinutes > 0) {
          final reminderUtc =
              fireUtc.subtract(Duration(minutes: reminderMinutes));
          if (reminderUtc.isAfter(nowUtc)) {
            await _scheduler.schedule(
              id: reminderIdBase +
                  dayOffset * reminderDayStride +
                  prayer.index,
              title: texts.reminderTitleFor(prayer, reminderMinutes),
              body: texts.reminderBodyFor(prayer, reminderMinutes),
              scheduledUtc: reminderUtc,
              exact: exact,
            );
          }
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
