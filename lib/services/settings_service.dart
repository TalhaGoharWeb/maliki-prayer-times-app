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

  /// Per-prayer adjustments are clamped to ±60 minutes.
  static const int maxAdjustmentMinutes = 60;

  /// Id of the active calculation profile.
  String activeProfileId = PrayerProfiles.defaultProfile.id;

  final Map<Prayer, int> _adjustments = {
    for (final p in Prayer.values) p: 0,
  };

  bool _ihtiyatEnabled = true;

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

  /// Resets every per-prayer adjustment to zero.
  Future<void> resetAdjustments() async {
    for (final p in Prayer.values) {
      _adjustments[p] = 0;
    }
    await _persist();
    notifyListeners();
  }
}
