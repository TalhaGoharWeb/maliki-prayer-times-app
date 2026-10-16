import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Re-schedules prayer notifications after a device reboot (REL-03).
///
/// `flutter_local_notifications` schedules do not survive a restart, so the
/// native `BootReceiver` (see `android/app/src/main/kotlin/.../BootReceiver.kt`,
/// registered for `BOOT_COMPLETED` in `AndroidManifest.xml`) runs
/// [rescheduleOnBoot] in a headless FlutterEngine on reboot.
///
/// ## Honest-delivery caveats
/// * Exact timing after a reboot depends on the OS actually delivering
///   `BOOT_COMPLETED` (some OEMs delay it) and on the Doze/battery state —
///   this restores parity with the pre-reboot schedule on a best-effort
///   basis, consistent with the app's existing delivery notes.
/// * Notification texts use [NotificationTexts.fallback] (plain English):
///   localizations are unavailable this early in the boot path.
/// * A real device-reboot test remains a manual QA step — it cannot be
///   covered by unit tests (see `test/boot_reschedule_test.dart`, which
///   covers the input reconstruction and the resulting schedule instead).
typedef BootRescheduleInputs = ({
  Coordinates coords,
  PrayerProfile profile,
  Duration timeZoneOffset,
});

/// Namespace for the boot-reschedule entrypoint and its input reconstruction.
abstract final class BootReschedule {
  /// SharedPreferences keys. These are the same literals
  /// [NotificationService.rescheduleAll] persists its inputs under (its
  /// `_lastLatKey` etc. are library-private, so they are duplicated here —
  /// keep them in sync with `notification_service.dart`).
  static const String latKey = 'notifications_last_lat';
  static const String lonKey = 'notifications_last_lon';
  static const String profileKey = 'notifications_last_profile_id';
  static const String offsetMinutesKey = 'notifications_last_offset_minutes';

  /// Channel the native boot receiver listens on; the entrypoint invokes
  /// `done` on it when the Dart work finishes so the receiver can tear the
  /// headless engine down. Must match the literal in `BootReceiver.kt`.
  static const MethodChannel doneChannel = MethodChannel(
    'com.talhagohar.malikiprayertimes/boot_reschedule',
  );

  /// Reconstructs the [NotificationService.rescheduleAll] inputs from raw
  /// SharedPreferences values. Returns `null` when no schedule was ever
  /// persisted (missing latitude, longitude, or profile id) so the caller
  /// can skip quietly. Pure and unit-testable: it never touches plugins.
  ///
  /// A missing offset falls back to the current device offset; an unknown
  /// profile id falls back to [PrayerProfiles.defaultProfile].
  static BootRescheduleInputs? bootInputsFromPrefs(
      Map<String, Object?> values) {
    final lat = values[latKey];
    final lon = values[lonKey];
    final profileId = values[profileKey];
    if (lat is! double || lon is! double || profileId is! String) {
      return null;
    }
    final offsetMinutes = values[offsetMinutesKey];
    final offset = offsetMinutes is int
        ? Duration(minutes: offsetMinutes)
        : DateTime.now().timeZoneOffset;
    final profile = PrayerProfiles.all.firstWhere(
      (p) => p.id == profileId,
      orElse: () => PrayerProfiles.defaultProfile,
    );
    return (
      coords: Coordinates(lat, lon),
      profile: profile,
      timeZoneOffset: offset,
    );
  }
}

/// Headless entrypoint invoked by the native `BootReceiver` after reboot.
/// Rebuilds the [NotificationService] and re-runs the last persisted
/// schedule. Kept minimal and fast: the OS only grants a brief window after
/// `BOOT_COMPLETED`.
///
/// The `@pragma('vm:entry-point')` keeps this from being tree-shaken: it is
/// only referenced from native code, never from Dart.
@pragma('vm:entry-point')
Future<void> rescheduleOnBoot() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final service =
        NotificationService(scheduler: PluginNotificationScheduler());
    // Localizations need a BuildContext; the fallback is the same plain
    // English used for a pre-UI timezone-change reschedule.
    final texts = NotificationTexts.fallback();
    await service.init(texts: texts);
    final prefs = await SharedPreferences.getInstance();
    final inputs = BootReschedule.bootInputsFromPrefs(<String, Object?>{
      BootReschedule.latKey: prefs.getDouble(BootReschedule.latKey),
      BootReschedule.lonKey: prefs.getDouble(BootReschedule.lonKey),
      BootReschedule.profileKey: prefs.getString(BootReschedule.profileKey),
      BootReschedule.offsetMinutesKey:
          prefs.getInt(BootReschedule.offsetMinutesKey),
    });
    // Never scheduled before this reboot: nothing to restore.
    if (inputs == null) return;
    final settings = await SettingsService.load();
    // Match the in-app schedule: apply the user's ihtiyat choice to the
    // persisted profile id, exactly as the UI path passes
    // `settings.effectiveProfile`.
    final profile = inputs.profile.id == settings.activeProfileId
        ? settings.effectiveProfile
        : inputs.profile;
    await service.rescheduleAll(
      coords: inputs.coords,
      profile: profile,
      settings: settings,
      timeZoneOffset: inputs.timeZoneOffset,
      texts: texts,
    );
  } finally {
    // Signal the native receiver so it can destroy the headless engine.
    // Best-effort: the receiver also gives up after its own timeout.
    try {
      await BootReschedule.doneChannel.invokeMethod('done');
    } catch (_) {
      // No native listener (e.g. under test): ignore.
    }
  }
}
