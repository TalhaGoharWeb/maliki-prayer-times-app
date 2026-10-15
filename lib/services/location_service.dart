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

/// Reads a single GPS fix. Returns `null` when no position could be
/// determined. The production implementation uses the geolocator plugin;
/// tests inject a fake.
abstract class GpsReader {
  Future<(double, double)?> readPosition();
}

/// The real [GpsReader] backed by the geolocator plugin. Never throws:
/// any platform error surfaces as `null` so the permission flow in
/// [LocationService] can report it gracefully.
class GeolocatorGpsReader implements GpsReader {
  const GeolocatorGpsReader();

  @override
  Future<(double, double)?> readPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return (position.latitude, position.longitude);
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

  /// The currently chosen location, or `null` until one is chosen.
  SavedLocation? current;

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
      final position = await _gpsReader.readPosition();
      if (position == null) {
        errorKind = LocationErrorKind.positionUnknown;
        errorMessage =
            'Could not determine your position. Please try again, or enter '
            'your location manually below.';
        notifyListeners();
        return;
      }

      final location = SavedLocation(
        name: 'Device location',
        latitude: position.$1,
        longitude: position.$2,
        isDevice: true,
        placeName: await _resolvePlaceName(position.$1, position.$2),
      );
      await _persist(location);
      current = location;
    } catch (e) {
      errorKind = LocationErrorKind.unexpectedUse;
      errorDetail = '$e';
      errorMessage = 'Could not use the device location ($e). You can try '
          'again, or enter your location manually below.';
    }
    notifyListeners();
  }

  /// Stores a manually entered location as the current location.
  Future<void> useManualLocation(SavedLocation location) async {
    errorMessage = null;
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
      final position = await _gpsReader.readPosition();
      if (position == null) {
        errorKind = LocationErrorKind.refreshPositionUnknown;
        errorMessage =
            'Could not determine your position. Please try again, or enter '
            'your location manually.';
        notifyListeners();
        return;
      }
      final location = SavedLocation(
        name: 'Device location',
        latitude: position.$1,
        longitude: position.$2,
        isDevice: true,
        placeName: await _resolvePlaceName(position.$1, position.$2),
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
  /// "Device location".
  Future<String?> _resolvePlaceName(double latitude, double longitude) async {
    try {
      return await _placeNamer.nameFor(latitude, longitude);
    } catch (_) {
      return null;
    }
  }
}
