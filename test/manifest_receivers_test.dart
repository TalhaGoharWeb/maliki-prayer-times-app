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
}
