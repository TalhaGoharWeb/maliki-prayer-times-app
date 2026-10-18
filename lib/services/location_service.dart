import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coarse permission outcome tracked by [LocationService].
enum LocationPermissionState {
  /// Nothing is known yet (initial state).
  unknown,

  /// Location permission is available and usable.
  granted,

  /// The user denied the request; asking again may show the system dialog.
  denied,

  /// The user denied permanently; only the system settings can change it.
  deniedForever,

  /// The device's location service (GPS toggle) is switched off.
  serviceDisabled,
}

/// Machine-readable kind of the latest location failure, so the UI can show
/// a localized message via the ARB templates instead of the English
/// [LocationService.errorMessage] fallback.
enum LocationErrorKind {
  /// No error.
  none,

  /// The device's location service (GPS toggle) is switched off.
  serviceDisabled,

  /// Permission permanently denied; only system settings can change it.
  permissionDeniedForever,

  /// Permission denied; the system dialog may be shown again.
  permissionDenied,

  /// No GPS fix could be determined (during the device-location flow).
  positionUnknown,

  /// Refresh attempted without a usable permission.
  reauthorizeNeeded,

  /// No GPS fix could be determined (during a refresh).
  refreshPositionUnknown,

  /// Unexpected failure in [LocationService.useDeviceLocation]; the
  /// exception text is in [LocationService.errorDetail].
  unexpectedUse,

  /// Unexpected failure in [LocationService.refreshDeviceLocation]; the
  /// exception text is in [LocationService.errorDetail].
  unexpectedRefresh,
}

/// One GPS fix with platform-reported quality metadata.
///
/// `accuracyMeters` is the platform's accuracy radius (smaller is better);
/// `timestamp` is when the fix was taken. Both are nullable: the platform
/// may not report them, in which case the UI shows "unknown" honestly
/// instead of fabricating values.
class GpsFix {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime? timestamp;

  const GpsFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.timestamp,
  });
}

/// Reads a single GPS fix. Returns `null` when no position could be
/// determined. The production implementation uses the geolocator plugin;
/// tests inject a fake.
abstract class GpsReader {
  Future<GpsFix?> readPosition();
}

/// The real [GpsReader] backed by the geolocator plugin. Never throws:
/// any platform error surfaces as `null` so the permission flow in
/// [LocationService] can report it gracefully.
///
/// The fix request carries a [gpsTimeLimit]: when no fix arrives in time
/// (indoors, poor sky view) geolocator throws [TimeoutException], which is
/// caught below and surfaces as `null`, so the service reports
/// [LocationErrorKind.positionUnknown] instead of hanging forever.
class GeolocatorGpsReader implements GpsReader {
  const GeolocatorGpsReader();

  /// Longest we wait for a single GPS fix. Test fakes mirror this timeout
  /// so the no-hang contract is covered without a device.
  static const gpsTimeLimit = Duration(seconds: 25);

  @override
  Future<GpsFix?> readPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: gpsTimeLimit,
        ),
      );
      return GpsFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Resolves GPS coordinates to a human place name (city/locality).
/// Returns `null` when no name could be determined. The production
/// implementation uses the geocoding plugin; tests inject a fake.
abstract class PlaceNamer {
  Future<String?> nameFor(double latitude, double longitude);
}

/// The real [PlaceNamer] backed by the geocoding plugin (MIT, Baseflow).
/// Never throws: any platform or network failure surfaces as `null` so the
/// UI falls back to the localized "Device location" label.
class GeocodingPlaceNamer implements PlaceNamer {
  const GeocodingPlaceNamer();

  @override
  Future<String?> nameFor(double latitude, double longitude) async {
    try {
      final placemarks = await geocoding.Geocoding()
          .placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      for (final candidate in [
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea,
        p.country,
      ]) {
        if (candidate != null && candidate.isNotEmpty) return candidate;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Permission and service-state queries for location, separated from
/// [GpsReader] so tests can drive every denial path without a device.
abstract class LocationPermissionGateway {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermissionState> checkPermission();
  Future<LocationPermissionState> requestPermission();
}

/// The real [LocationPermissionGateway] backed by the geolocator plugin.
class GeolocatorPermissionGateway implements LocationPermissionGateway {
  const GeolocatorPermissionGateway();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionState> checkPermission() async =>
      _mapPermission(await Geolocator.checkPermission());

  @override
  Future<LocationPermissionState> requestPermission() async =>
      _mapPermission(await Geolocator.requestPermission());

  LocationPermissionState _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.granted;
      case LocationPermission.denied:
        return LocationPermissionState.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.unknown;
    }
  }
}

/// Holds the chosen location, its permission state, and persistence.
///
/// The chosen location survives restarts via `shared_preferences` under the
/// key `'saved_location'`. Every failure path of [useDeviceLocation] sets
/// [permissionState] and [errorMessage] and leaves [current] untouched, so
/// the UI can offer manual entry instead of losing what the user already had.
class LocationService extends ChangeNotifier {
  /// Key under which the location is persisted in shared_preferences.
  static const String storageKey = 'saved_location';

  /// Longest we wait for the platform reverse-geocoder before falling back
  /// to the generic "Device location" label. The name is cosmetic; the fix
  /// itself is persisted before this wait starts.
  static const Duration _placeNameTimeout = Duration(seconds: 10);

  /// Key under which the saved-places list is persisted.
  static const String savedPlacesKey = 'saved_places';

  /// The currently chosen location, or `null` until one is chosen.
  SavedLocation? current;

  /// Named places the user saved for quick switching. Persisted under
  /// [savedPlacesKey] as a JSON list; never contains the [current]
  /// location object itself by identity (snapshots are stored).
  List<SavedLocation> savedPlaces = const [];

  /// The last known permission/service outcome.
  LocationPermissionState permissionState = LocationPermissionState.unknown;

  /// Human-readable explanation of the latest failure, or `null`.
  ///
  /// Kept in English as a fallback; the UI prefers the localized template
  /// selected by [errorKind].
  String? errorMessage;

  /// Machine-readable kind of the latest failure; [LocationErrorKind.none]
  /// when there is no error. Always set alongside [errorMessage].
  LocationErrorKind errorKind = LocationErrorKind.none;

  /// Detail for [LocationErrorKind.unexpectedUse] /
  /// [LocationErrorKind.unexpectedRefresh]: the caught exception's text.
  String? errorDetail;

  final GpsReader _gpsReader;
  final LocationPermissionGateway _permissionGateway;
  final PlaceNamer _placeNamer;

  LocationService._(this._gpsReader, this._permissionGateway, this._placeNamer);

  /// Loads the service, restoring any previously persisted location.
  /// A missing or malformed entry falls back to a `null` [current];
  /// it never throws.
  static Future<LocationService> load({
    GpsReader? gpsReader,
    LocationPermissionGateway? permissionGateway,
    PlaceNamer? placeNamer,
  }) async {
    final service = LocationService._(
      gpsReader ?? const GeolocatorGpsReader(),
      permissionGateway ?? const GeolocatorPermissionGateway(),
      placeNamer ?? const GeocodingPlaceNamer(),
    );
    await service._restorePersisted();
    await service._restoreSavedPlaces();
    return service;
  }

  Future<void> _restorePersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) {
        current = null;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        current = null;
        return;
      }
      current = SavedLocation.fromJson(decoded);
    } catch (_) {
      // Malformed or unexpected persisted data: start with no location.
      current = null;
    }
  }

  Future<void> _persist(SavedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(location.toJson()));
  }

  Future<void> _restoreSavedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(savedPlacesKey);
      if (raw == null || raw.isEmpty) {
        savedPlaces = const [];
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        savedPlaces = const [];
        return;
      }
      savedPlaces = [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>) SavedLocation.fromJson(entry),
      ];
    } catch (_) {
      savedPlaces = const [];
    }
  }

  Future<void> _persistSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      savedPlacesKey,
      jsonEncode([for (final p in savedPlaces) p.toJson()]),
    );
  }

  /// Snapshots the [current] location into the saved-places list.
  ///
  /// A device location is snapshotted as a manual-style place: `isDevice`
  /// becomes false and the current device zone id is frozen as its
  /// [SavedLocation.timeZoneId], so the saved place keeps rendering in the
  /// zone it was saved in even after the phone travels. Coordinates that
  /// already have a saved place are not duplicated. Returns true when a
  /// new place was added. Does nothing (returns false) when no location is
  /// currently chosen.
  Future<bool> saveCurrentAsPlace() async {
    final loc = current;
    if (loc == null) return false;
    for (final p in savedPlaces) {
      if ((p.latitude - loc.latitude).abs() < 1e-9 &&
          (p.longitude - loc.longitude).abs() < 1e-9) {
        return false;
      }
    }
    final snapshot = SavedLocation(
      name: loc.isDevice ? (loc.placeName ?? 'Device location') : loc.name,
      latitude: loc.latitude,
      longitude: loc.longitude,
      isDevice: false,
      placeName: loc.isDevice ? loc.placeName : null,
      // A device-location snapshot keeps the device wall-clock frame
      // (null): pinning the platform's zone abbreviation (e.g. "PKT") as a
      // zone id would be wrong, and 'Etc/UTC' was the 2026-10-18 bug.
      timeZoneId: loc.isDevice ? null : loc.timeZoneId,
      elevationMeters: loc.elevationMeters,
    );
    savedPlaces = [...savedPlaces, snapshot];
    await _persistSavedPlaces();
    notifyListeners();
    return true;
  }

  /// Makes a saved place the current location.
  Future<void> usePlace(SavedLocation place) async {
    errorMessage = null;
    errorKind = LocationErrorKind.none;
    errorDetail = null;
    await _persist(place);
    current = place;
    notifyListeners();
  }

  /// Removes a saved place. The current location is unaffected even when it
  /// happens to match the removed place.
  Future<void> removePlace(SavedLocation place) async {
    savedPlaces = [
      for (final p in savedPlaces)
        if (!_samePlace(p, place)) p,
    ];
    await _persistSavedPlaces();
    notifyListeners();
  }

  static bool _samePlace(SavedLocation a, SavedLocation b) =>
      a.name == b.name &&
      (a.latitude - b.latitude).abs() < 1e-9 &&
      (a.longitude - b.longitude).abs() < 1e-9;

  /// One-shot device position for the travel-mode auto-suggest. Returns null
  /// when permission is not already granted or the service is off — this
  /// never triggers a permission prompt.
  Future<(double, double)?> currentPositionIfPermitted() async {
    if (await _permissionGateway.checkPermission() !=
        LocationPermissionState.granted) {
      return null;
    }
    if (!await _permissionGateway.isLocationServiceEnabled()) return null;
    final fix = await _gpsReader.readPosition();
    if (fix == null) return null;
    return (fix.latitude, fix.longitude);
  }

  /// Runs the device-location flow: checks the location service, asks for
  /// permission when needed, then reads one GPS fix and persists it as the
  /// current location. Never throws; on any failure it records
  /// [permissionState] and [errorMessage] and leaves [current] unchanged.
  Future<void> useDeviceLocation() async {
    errorMessage = null;
    errorKind = LocationErrorKind.none;
    errorDetail = null;
    try {
      if (!await _permissionGateway.isLocationServiceEnabled()) {
        permissionState = LocationPermissionState.serviceDisabled;
        errorKind = LocationErrorKind.serviceDisabled;
        errorMessage =
            'Location services are turned off. Turn them on in the device '
            'settings, or enter your location manually below.';
        notifyListeners();
        return;
      }

      var state = await _permissionGateway.checkPermission();
      if (state != LocationPermissionState.granted) {
        state = await _permissionGateway.requestPermission();
      }

      if (state != LocationPermissionState.granted) {
        permissionState = state;
        errorKind = state == LocationPermissionState.deniedForever
            ? LocationErrorKind.permissionDeniedForever
            : LocationErrorKind.permissionDenied;
        errorMessage = state == LocationPermissionState.deniedForever
            ? 'Location permission is permanently denied. Open the system '
                'settings to allow location access, or enter your location '
                'manually below.'
            : 'Location permission was denied. You can try again, or enter '
                'your location manually below.';
        notifyListeners();
        return;
      }

      permissionState = LocationPermissionState.granted;
      final fix = await _gpsReader.readPosition();
      if (fix == null) {
        errorKind = LocationErrorKind.positionUnknown;
        errorMessage =
            'Could not determine your position. Please try again, or enter '
            'your location manually below.';
        notifyListeners();
        return;
      }

      // Persist the fix FIRST: the coordinates are the point of this flow.
      // The human-readable place name is cosmetic and resolves afterwards
      // (with its own timeout), updating the saved entry if one arrives, so
      // a slow platform geocoder can never delay or lose the fix.
      // The platform's accuracy radius and the fix timestamp travel with
      // the location so the UI can show GPS quality honestly.
      var location = SavedLocation(
        name: 'Device location',
        latitude: fix.latitude,
        longitude: fix.longitude,
        isDevice: true,
        accuracyMeters: fix.accuracyMeters,
        updatedAt: fix.timestamp,
      );
      await _persist(location);
      current = location;
      notifyListeners();

      final placeName = await _resolvePlaceName(fix.latitude, fix.longitude);
      if (placeName != null && placeName.isNotEmpty) {
        location = SavedLocation(
          name: 'Device location',
          latitude: fix.latitude,
          longitude: fix.longitude,
          isDevice: true,
          placeName: placeName,
          accuracyMeters: fix.accuracyMeters,
          updatedAt: fix.timestamp,
        );
        await _persist(location);
        current = location;
        notifyListeners();
      }
    } catch (e) {
      errorKind = LocationErrorKind.unexpectedUse;
      errorDetail = '$e';
      errorMessage = 'Could not use the device location ($e). You can try '
          'again, or enter your location manually below.';
    }
    notifyListeners();
  }

  /// Stores a manually entered location as the current location.
  /// Clears any previous error state: a successful save means there is no
  /// longer a failure to report.
  Future<void> useManualLocation(SavedLocation location) async {
    errorMessage = null;
    errorKind = LocationErrorKind.none;
    errorDetail = null;
    await _persist(location);
    current = location;
    notifyListeners();
  }

  /// Re-reads the GPS fix when the current location came from the device.
  /// Does nothing when the current location is manual or unset.
  Future<void> refreshDeviceLocation() async {
    if (current?.isDevice != true) return;
    errorMessage = null;
    errorKind = LocationErrorKind.none;
    errorDetail = null;
    try {
      if (permissionState != LocationPermissionState.granted) {
        errorKind = LocationErrorKind.reauthorizeNeeded;
        errorMessage =
            'Location permission is no longer available. Use the device '
            'location again to re-authorize, or enter your location manually.';
        notifyListeners();
        return;
      }
      final fix = await _gpsReader.readPosition();
      if (fix == null) {
        errorKind = LocationErrorKind.refreshPositionUnknown;
        errorMessage =
            'Could not determine your position. Please try again, or enter '
            'your location manually.';
        notifyListeners();
        return;
      }
      final location = SavedLocation(
        name: 'Device location',
        latitude: fix.latitude,
        longitude: fix.longitude,
        isDevice: true,
        placeName: await _resolvePlaceName(fix.latitude, fix.longitude),
        accuracyMeters: fix.accuracyMeters,
        updatedAt: fix.timestamp,
      );
      await _persist(location);
      current = location;
    } catch (e) {
      errorKind = LocationErrorKind.unexpectedRefresh;
      errorDetail = '$e';
      errorMessage = 'Could not refresh the device location ($e).';
    }
    notifyListeners();
  }

  /// Reverse-geocodes a fix to a human place name. Never throws: any
  /// failure (sync or async) yields `null` and the UI falls back to
  /// "Device location". Bounded by [_placeNameTimeout] so a hanging
  /// platform geocoder can delay the cosmetic name but never the fix.
  Future<String?> _resolvePlaceName(double latitude, double longitude) async {
    try {
      return await _placeNamer
          .nameFor(latitude, longitude)
          .timeout(_placeNameTimeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }
}
