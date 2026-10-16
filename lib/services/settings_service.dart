import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing settings: the active calculation profile, per-prayer minute
/// adjustments, and the precautionary-delay (ihtiyat) switch.
///
/// Persisted with shared_preferences; [load] tolerates missing or corrupt
/// values by falling back to defaults and never throws. Every profile exposed
/// here is PROPOSED — pending scholarly review — never a settled method.
class SettingsService extends ChangeNotifier {
  static const _activeProfileKey = 'active_profile_id';
  static const _adjustmentsKey = 'adjustments';
  static const _ihtiyatKey = 'ihtiyat_enabled';
  static const _languageCodeKey = 'language_code';
  static const _notificationTogglesKey = 'notification_toggles';
  static const _reminderOffsetKey = 'reminder_offset_minutes';
  static const _regionSuggestionShownKey = 'region_suggestion_shown';

  /// Language codes the app can be switched to. `null` means "system
  /// default" and is always allowed.
  static const List<String> supportedLanguageCodes = ['en', 'ur', 'ar', 'fr'];

  /// Pre-prayer reminder offsets (minutes before the prayer) the user can
  /// pick from. 0 means "notify at the prayer time, no early reminder".
  static const List<int> allowedReminderOffsets = [0, 5, 10, 15];

  /// Per-prayer adjustments are clamped to ±60 minutes.
  static const int maxAdjustmentMinutes = 60;

  /// Id of the active calculation profile.
  String activeProfileId = PrayerProfiles.defaultProfile.id;

  /// UI language code ('en', 'ur', 'ar', 'fr'), or `null` for the system
  /// default. Defaults to `null`.
  String? _languageCode;

  final Map<Prayer, int> _adjustments = {
    for (final p in Prayer.values) p: 0,
  };

  bool _ihtiyatEnabled = true;

  /// Per-prayer notification toggles. Defaults to true for every prayer
  /// (including sunrise, which is a timetable marker — the user can switch
  /// it off).
  final Map<Prayer, bool> _notificationToggles = {
    for (final p in Prayer.values) p: true,
  };

  /// Minutes before each prayer time at which a reminder notification fires.
  /// One of [allowedReminderOffsets]; 0 = no early reminder.
  int _reminderOffsetMinutes = 0;

  /// Whether the one-time regional-preset suggestion dialog ("Recommended
  /// settings") has already been shown on this install. Once true it is
  /// never shown again — the dialog never nags.
  bool _regionSuggestionShown = false;

  /// The active profile; falls back to the default when the stored id does
  /// not match a known profile.
  PrayerProfile get activeProfile {
    for (final p in PrayerProfiles.all) {
      if (p.id == activeProfileId) return p;
    }
    return PrayerProfiles.defaultProfile;
  }

  /// [activeProfile], with the precautionary Dhuhr/Maghrib delays zeroed when
  /// [ihtiyatEnabled] is false. Profiles are immutable engine constants, so a
  /// copy with changed fields is constructed; the profile is never modified.
  PrayerProfile get effectiveProfile {
    if (_ihtiyatEnabled) return activeProfile;
    final p = activeProfile;
    return PrayerProfile(
      id: p.id,
      name: p.name,
      basis: p.basis,
      fajrAngle: p.fajrAngle,
      ishaAngle: p.ishaAngle,
      asrShadowFactor: p.asrShadowFactor,
      solarDepression: p.solarDepression,
      dhuhrIhtiyatMinutes: 0,
      maghribIhtiyatMinutes: 0,
    );
  }

  /// Per-prayer minute adjustments, each in −60..60 (unmodifiable view).
  Map<Prayer, int> get adjustments => Map.unmodifiable(_adjustments);

  /// Whether the precautionary Dhuhr/Maghrib delay applies. Defaults to true.
  bool get ihtiyatEnabled => _ihtiyatEnabled;

  /// Per-prayer notification toggles, each defaulting to true
  /// (unmodifiable view).
  Map<Prayer, bool> get notificationToggles =>
      Map.unmodifiable(_notificationToggles);

  /// Minutes before each prayer time at which a reminder fires.
  /// One of [allowedReminderOffsets]; 0 = no early reminder.
  int get reminderOffsetMinutes => _reminderOffsetMinutes;

  /// The UI language code, or `null` for the system default.
  String? get languageCode => _languageCode;

  /// Whether the one-time regional-preset suggestion dialog has been shown
  /// on this install. Defaults to false.
  bool get regionSuggestionShown => _regionSuggestionShown;

  /// The user-visible time for [prayer]: the computed engine time shifted by
  /// the stored per-prayer adjustment.
  DateTime adjustedTime(Prayer prayer, DateTime computed) {
    return computed.add(Duration(minutes: _adjustments[prayer] ?? 0));
  }

  /// Loads settings from shared_preferences. Missing or corrupt values yield
  /// defaults; this never throws.
  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final service = SettingsService();

    final storedId = prefs.getString(_activeProfileKey);
    if (storedId != null &&
        PrayerProfiles.all.any((p) => p.id == storedId)) {
      service.activeProfileId = storedId;
    }

    service._ihtiyatEnabled = prefs.getBool(_ihtiyatKey) ?? true;

    service._regionSuggestionShown =
        prefs.getBool(_regionSuggestionShownKey) ?? false;

    final storedOffset = prefs.getInt(_reminderOffsetKey);
    if (storedOffset != null &&
        allowedReminderOffsets.contains(storedOffset)) {
      service._reminderOffsetMinutes = storedOffset;
    }

    final rawToggles = prefs.getString(_notificationTogglesKey);
    if (rawToggles != null) {
      try {
        final decoded = jsonDecode(rawToggles);
        if (decoded is Map) {
          for (final prayer in Prayer.values) {
            final value = decoded[prayer.name];
            if (value is bool) {
              service._notificationToggles[prayer] = value;
            }
          }
        }
      } catch (_) {
        // Corrupt JSON: keep the defaults.
      }
    }

    final storedLanguage = prefs.getString(_languageCodeKey);
    service._languageCode =
        supportedLanguageCodes.contains(storedLanguage) ? storedLanguage : null;

    final raw = prefs.getString(_adjustmentsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final prayer in Prayer.values) {
            final value = decoded[prayer.name];
            if (value is int) {
              service._adjustments[prayer] =
                  value.clamp(-maxAdjustmentMinutes, maxAdjustmentMinutes);
            }
          }
        }
      } catch (_) {
        // Corrupt JSON: keep the defaults.
      }
    }

    return service;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, activeProfileId);
    await prefs.setString(
      _adjustmentsKey,
      jsonEncode({for (final p in Prayer.values) p.name: _adjustments[p]}),
    );
    await prefs.setBool(_ihtiyatKey, _ihtiyatEnabled);
    await prefs.setInt(_reminderOffsetKey, _reminderOffsetMinutes);
    await prefs.setString(
      _notificationTogglesKey,
      jsonEncode({for (final p in Prayer.values) p.name: _notificationToggles[p]}),
    );
    if (_languageCode == null) {
      await prefs.remove(_languageCodeKey);
    } else {
      await prefs.setString(_languageCodeKey, _languageCode!);
    }
  }

  /// Selects the profile with [id]. Unknown ids are ignored: the current
  /// profile is kept.
  Future<void> setActiveProfile(String id) async {
    if (!PrayerProfiles.all.any((p) => p.id == id)) return;
    if (activeProfileId == id) return;
    activeProfileId = id;
    await _persist();
    notifyListeners();
  }

  /// Sets the per-prayer adjustment in minutes, clamped to ±60.
  Future<void> setAdjustment(Prayer prayer, int minutes) async {
    final clamped = minutes.clamp(-maxAdjustmentMinutes, maxAdjustmentMinutes);
    if (_adjustments[prayer] == clamped) return;
    _adjustments[prayer] = clamped;
    await _persist();
    notifyListeners();
  }

  /// Enables or disables the precautionary Dhuhr/Maghrib delay.
  Future<void> setIhtiyatEnabled(bool value) async {
    if (_ihtiyatEnabled == value) return;
    _ihtiyatEnabled = value;
    await _persist();
    notifyListeners();
  }

  /// Enables or disables the notification for [prayer].
  Future<void> setNotificationEnabled(Prayer prayer, bool value) async {
    if (_notificationToggles[prayer] == value) return;
    _notificationToggles[prayer] = value;
    await _persist();
    notifyListeners();
  }

  /// Sets the pre-prayer reminder offset in minutes. Must be one of
  /// [allowedReminderOffsets]; other values are ignored.
  Future<void> setReminderOffsetMinutes(int minutes) async {
    if (!allowedReminderOffsets.contains(minutes)) return;
    if (_reminderOffsetMinutes == minutes) return;
    _reminderOffsetMinutes = minutes;
    await _persist();
    notifyListeners();
  }

  /// Sets the UI language: one of [supportedLanguageCodes], or `null` for
  /// the system default. Unknown codes are ignored.
  Future<void> setLanguageCode(String? code) async {
    if (code != null && !supportedLanguageCodes.contains(code)) return;
    if (_languageCode == code) return;
    _languageCode = code;
    await _persist();
    notifyListeners();
  }

  /// Marks the one-time regional-preset suggestion dialog as shown on this
  /// install, so it is never shown again (dismissed counts as shown — the
  /// dialog never nags).
  Future<void> setRegionSuggestionShown() async {
    if (_regionSuggestionShown) return;
    _regionSuggestionShown = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_regionSuggestionShownKey, true);
    notifyListeners();
  }

  /// Resets every per-prayer adjustment to zero.
  Future<void> resetAdjustments() async {
    for (final p in Prayer.values) {
      _adjustments[p] = 0;
    }
    await _persist();
    notifyListeners();
  }
}
