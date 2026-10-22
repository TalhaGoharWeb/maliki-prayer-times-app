import 'dart:io';

import 'package:flutter/services.dart';

/// Bridge to the `maliki/battery` platform channel (MainActivity.kt):
/// whether the app is exempt from battery optimization, and intents to
/// request the exemption or open the app's system settings page.
///
/// Aggressive OEM battery managers (Transsion/HiOS, Xiaomi/MIUI, Oppo…)
/// freeze background apps; a frozen app's AlarmManager broadcasts are
/// blocked, so prayer alerts never appear even when every alarm was
/// scheduled correctly. The exemption is the user-side cure, and Settings
/// surfaces it next to the other delivery diagnostics.
///
/// Every call is defensive: on non-Android platforms, in widget tests, or
/// if the channel is missing, the status reads as "unknown" (null) and
/// the actions no-op — delivery diagnostics must never crash settings.
abstract final class BatteryService {
  static const _channel = MethodChannel('maliki/battery');

  /// True when the app is exempt from battery optimization, false when
  /// it is not, null when the state cannot be determined (non-Android).
  static Future<bool?> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<bool>(
          'isIgnoringBatteryOptimizations');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Opens the system dialog/screen where the user can exempt the app
  /// from battery optimization.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } on MissingPluginException {
      // No bridge (tests, other platforms): nothing to open.
    } on PlatformException {
      // The native side already falls back through the settings screens.
    }
  }

  /// Opens this app's system settings page (battery/autostart controls
  /// live there on most OEM ROMs).
  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      // No bridge (tests, other platforms): nothing to open.
    } on PlatformException {
      // Nothing further the app can open.
    }
  }
}
