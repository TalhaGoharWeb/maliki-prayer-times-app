import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression test for the "no notification ever appears" bug (2026-10-19).
///
/// flutter_local_notifications v22 does NOT declare its broadcast receivers
/// in its own library manifest — the app's AndroidManifest.xml must. Without
/// `ScheduledNotificationReceiver`, every `zonedSchedule()` call succeeds but
/// the AlarmManager broadcast is delivered to an unregistered receiver, so
/// nothing ever appears: test button, prayer times, reminders — all
/// silently dead. This test pins the required declarations so a future
/// manifest edit cannot reintroduce the bug unnoticed.
void main() {
  test('AndroidManifest declares the plugin notification receivers', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue,
        reason: 'AndroidManifest.xml must exist at the expected path');
    final xml = manifest.readAsStringSync();
    expect(
      xml.contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver'),
      isTrue,
      reason:
          'ScheduledNotificationReceiver must be declared: without it, scheduled notifications never appear',
    );
    expect(
      xml.contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver'),
      isTrue,
      reason:
          'ScheduledNotificationBootReceiver must be declared: without it, schedules do not survive reboot',
    );
    // The alarm receiver must not be exported: it only receives the app's
    // own PendingIntent broadcasts.
    final receiverTag = RegExp(
      r'<receiver[^>]*ScheduledNotificationReceiver"[^>]*>',
    ).firstMatch(xml);
    expect(receiverTag, isNotNull);
    expect(receiverTag!.group(0)!.contains('android:exported="false"'), isTrue,
        reason: 'ScheduledNotificationReceiver must not be exported');
  });

  // Regression tests for the "test notification works, prayer times never
  // fire" saga (Oct 2026). v1.3.3 declared BOTH SCHEDULE_EXACT_ALARM and
  // USE_EXACT_ALARM uncapped: on Android 14+, with both declared,
  // exact-alarm capability is judged by the SCHEDULE_EXACT_ALARM app-op,
  // denied by default on fresh installs — every prayer alarm was
  // scheduled inexact and Doze/OEM battery managers deferred or dropped
  // them. v1.3.4 removed SCHEDULE_EXACT_ALARM entirely (correct on
  // Android 13+, where USE_EXACT_ALARM is granted at install) — but
  // USE_EXACT_ALARM does not exist on Android 12 (API 31–32), where
  // SCHEDULE_EXACT_ALARM is the only route and is default-granted.
  // v1.3.5 therefore declares it capped at API 32: present exactly where
  // it is needed and grantable, absent wherever it could shadow.
  test('AndroidManifest: USE_EXACT_ALARM uncapped; SCHEDULE_EXACT_ALARM '
      'capped at API 32', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final xml = manifest.readAsStringSync();
    expect(
      xml.contains('android.permission.USE_EXACT_ALARM'),
      isTrue,
      reason: 'USE_EXACT_ALARM must be declared for exact prayer alarms',
    );
    final tag = RegExp(r'<uses-permission[^>]*SCHEDULE_EXACT_ALARM[^>]*/?>')
        .firstMatch(xml);
    expect(tag, isNotNull,
        reason:
            'SCHEDULE_EXACT_ALARM must be declared for Android 12 (API 31–32), the only exact-alarm route there');
    expect(
      tag!.group(0)!.contains('android:maxSdkVersion="32"'),
      isTrue,
      reason:
          'SCHEDULE_EXACT_ALARM must be capped at API 32 so it never shadows the USE_EXACT_ALARM install-time grant on Android 13+',
    );
    expect(
      xml.contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
      isTrue,
      reason:
          'The battery-exemption request intent needs its permission declared',
    );
  });
}
