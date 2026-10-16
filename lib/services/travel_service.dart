import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Travel mode (Maliki qasr) state, persisted in shared_preferences.
///
/// Travel mode is a display preference only: it never changes prayer-time
/// computation. When enabled, the UI notes that Dhuhr, Asr and Isha are
/// shortened to 2 rak'ahs under Maliki rules; prayer times do not change.
class TravelService extends ChangeNotifier {
  /// Distance in kilometres at (or beyond) which the app suggests enabling
  /// travel mode: the Maliki travel distance is four barid (48 miles,
  /// approx. 80 km — the classical measure is in barid, so the kilometre
  /// figure is an approximation used only for the auto-suggest, never
  /// presented as a ruling).
  static const double kTravelSuggestKm = 80.0;

  static const _enabledKey = 'travel_mode_enabled';
  static const _homeLatKey = 'travel_home_lat';
  static const _homeLngKey = 'travel_home_lng';

  bool _enabled = false;
  double? _homeLat;
  double? _homeLng;

  /// Whether travel mode is currently on.
  bool get isEnabled => _enabled;

  /// The stored home coordinates, or `null` when none was ever stored.
  double? get homeLat => _homeLat;

  /// The stored home coordinates, or `null` when none was ever stored.
  double? get homeLng => _homeLng;

  /// Loads persisted state. Missing or corrupt values yield defaults;
  /// this never throws.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      final lat = prefs.getDouble(_homeLatKey);
      final lng = prefs.getDouble(_homeLngKey);
      _homeLat = (lat != null && lat.isFinite) ? lat : null;
      _homeLng = (lng != null && lng.isFinite) ? lng : null;
    } catch (_) {
      // Corrupt storage: fall back to defaults.
      _enabled = false;
      _homeLat = null;
      _homeLng = null;
    }
    notifyListeners();
  }

  /// Enables or disables travel mode. On the first enable, the passed home
  /// coordinates are stored; later toggles keep the stored home. When no
  /// coordinates are passed (or none could be stored), the home stays
  /// unknown and the travel suggestion stays dormant.
  Future<void> setEnabled(bool v, {double? homeLat, double? homeLng}) async {
    _enabled = v;
    if (v && _homeLat == null && _homeLng == null) {
      if (homeLat != null &&
          homeLat.isFinite &&
          homeLng != null &&
          homeLng.isFinite) {
        _homeLat = homeLat;
        _homeLng = homeLng;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _enabled);
    if (_homeLat != null && _homeLng != null) {
      await prefs.setDouble(_homeLatKey, _homeLat!);
      await prefs.setDouble(_homeLngKey, _homeLng!);
    }
    notifyListeners();
  }

  /// Great-circle distance between two points, in kilometres.
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return 2 * earthRadiusKm * asin(sqrt(a.clamp(0.0, 1.0)));
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;

  /// Whether the app should suggest enabling travel mode for the given
  /// current position: travel mode is off, a home is known, and the current
  /// position is at least [kTravelSuggestKm] from home.
  bool shouldSuggestTravel(double curLat, double curLng) {
    if (_enabled) return false;
    final lat = _homeLat;
    final lng = _homeLng;
    if (lat == null || lng == null) return false;
    return haversineKm(lat, lng, curLat, curLng) >= kTravelSuggestKm;
  }
}
