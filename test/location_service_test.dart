import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test double for [GpsReader]: returns a fixed fix (or `null`).
class FakeGpsReader implements GpsReader {
  GpsFix? fix;

  FakeGpsReader([this.fix]);

  @override
  Future<GpsFix?> readPosition() async => fix;
}

/// Test double for [LocationPermissionGateway]: every permission outcome
/// is scripted through public fields.
class FakePermissionGateway implements LocationPermissionGateway {
  bool serviceEnabled = true;
  LocationPermissionState checked = LocationPermissionState.granted;
  LocationPermissionState requested = LocationPermissionState.granted;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionState> checkPermission() async => checked;

  @override
  Future<LocationPermissionState> requestPermission() async => requested;
}

/// Test double for [PlaceNamer]: returns a scripted place name (or `null`,
/// or throws to simulate a geocoding failure).
class FakePlaceNamer implements PlaceNamer {
  String? placeName;
  bool throws = false;

  FakePlaceNamer([this.placeName]);

  @override
  Future<String?> nameFor(double latitude, double longitude) async {
    if (throws) throw Exception('geocoding unavailable');
    return placeName;
  }
}

/// Test double for [GpsReader] whose fix never arrives on its own: the
/// timeout converts the hang into `null`, mirroring how
/// [GeolocatorGpsReader]'s [LocationSettings.timeLimit] surfaces a
/// [TimeoutException] as `null`. The production 25 s value is pinned by the
/// test below; the short timeout here keeps the suite fast.
class TimeoutGpsReader implements GpsReader {
  @override
  Future<GpsFix?> readPosition() =>
      Completer<GpsFix?>().future.timeout(
            const Duration(milliseconds: 50),
            onTimeout: () => null,
          );
}

/// Test double for [PlaceNamer] that never resolves, simulating a platform
/// geocoder hanging on a flaky network. The service's own 10 s timeout
/// must bound it.
class HangingPlaceNamer implements PlaceNamer {
  @override
  Future<String?> nameFor(double latitude, double longitude) =>
      Completer<String?>().future;
}

/// Test double for [PlaceNamer] whose answer is gated by a completer, so
/// the test controls exactly when the name arrives.
class GatedPlaceNamer implements PlaceNamer {
  final Completer<String?> gate = Completer<String?>();

  @override
  Future<String?> nameFor(double latitude, double longitude) =>
      gate.future;
}

Future<LocationService> _loadService({
  GpsReader? gpsReader,
  LocationPermissionGateway? gateway,
  PlaceNamer? placeNamer,
}) {
  return LocationService.load(
    gpsReader: gpsReader ?? FakeGpsReader(),
    permissionGateway: gateway ?? FakePermissionGateway(),
    placeNamer: placeNamer ?? FakePlaceNamer(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService', () {
    test('starts with no location when nothing was persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService();
      expect(service.current, isNull);
      expect(service.permissionState, LocationPermissionState.unknown);
      expect(service.errorMessage, isNull);
    });

    test('manual location persists and reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService();
      await service.useManualLocation(
        const SavedLocation(name: 'Nouakchott', latitude: 18.08581, longitude: -15.9785),
      );
      expect(service.current?.name, 'Nouakchott');
      expect(service.current?.latitude, 18.08581);
      expect(service.current?.longitude, -15.9785);
      expect(service.current?.isDevice, isFalse);

      final reloaded = await _loadService();
      expect(reloaded.current?.name, 'Nouakchott');
      expect(reloaded.current?.latitude, 18.08581);
      expect(reloaded.current?.longitude, -15.9785);
      expect(reloaded.current?.isDevice, isFalse);
    });

    test('malformed persisted JSON falls back to null without crashing', () async {
      SharedPreferences.setMockInitialValues(
        {LocationService.storageKey: 'definitely not json {{{'},
      );
      final service = await _loadService();
      expect(service.current, isNull);
      expect(service.errorMessage, isNull);
    });

    test('persisted JSON of the wrong shape falls back to null', () async {
      SharedPreferences.setMockInitialValues(
        {LocationService.storageKey: '[1, 2, 3]'},
      );
      final service = await _loadService();
      expect(service.current, isNull);
    });

    test('denied permission leaves state and message and does not throw', () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = FakePermissionGateway()
        ..checked = LocationPermissionState.denied
        ..requested = LocationPermissionState.denied;
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 18.0, longitude: -16.0)),
        gateway: gateway,
      );

      await service.useDeviceLocation(); // must not throw

      expect(service.permissionState, LocationPermissionState.denied);
      expect(service.errorMessage, isNotNull);
      expect(service.current, isNull,
          reason: 'a failed attempt must not touch the current location');
    });

    test('deniedForever path records state, message and keeps current', () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = FakePermissionGateway()
        ..checked = LocationPermissionState.denied
        ..requested = LocationPermissionState.deniedForever;
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 18.0, longitude: -16.0)),
        gateway: gateway,
      );
      await service.useManualLocation(
        const SavedLocation(name: 'Nouakchott', latitude: 18.0, longitude: -16.0),
      );

      await service.useDeviceLocation(); // must not throw

      expect(service.permissionState, LocationPermissionState.deniedForever);
      expect(service.errorMessage, contains('system settings'));
      expect(service.current?.name, 'Nouakchott',
          reason: 'existing manual location must be preserved');
    });

    test('disabled location service records serviceDisabled', () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = FakePermissionGateway()..serviceEnabled = false;
      final service = await _loadService(gateway: gateway);

      await service.useDeviceLocation(); // must not throw

      expect(service.permissionState, LocationPermissionState.serviceDisabled);
      expect(service.errorMessage, isNotNull);
      expect(service.current, isNull);
    });

    test('successful device location persists as isDevice', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 24.8607, longitude: 67.0011)),
      );

      await service.useDeviceLocation();

      expect(service.permissionState, LocationPermissionState.granted);
      expect(service.errorMessage, isNull);
      expect(service.current?.name, 'Device location');
      expect(service.current?.latitude, 24.8607);
      expect(service.current?.longitude, 67.0011);
      expect(service.current?.isDevice, isTrue);

      final reloaded = await _loadService();
      expect(reloaded.current?.isDevice, isTrue);
    });

    test('refreshDeviceLocation updates a device location', () async {
      SharedPreferences.setMockInitialValues({});
      final gpsReader = FakeGpsReader(const GpsFix(latitude: 18.08581, longitude: -15.9785));
      final service = await _loadService(gpsReader: gpsReader);
      await service.useDeviceLocation();
      expect(service.current?.latitude, 18.08581);

      gpsReader.fix = const GpsFix(latitude: 19.0, longitude: -16.5);
      await service.refreshDeviceLocation();

      expect(service.current?.latitude, 19.0);
      expect(service.current?.longitude, -16.5);
      expect(service.current?.isDevice, isTrue);

      final reloaded = await _loadService();
      expect(reloaded.current?.latitude, 19.0);
      expect(reloaded.current?.isDevice, isTrue);
    });

    test('refreshDeviceLocation does nothing for a manual location', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 1.0, longitude: 2.0)),
      );
      await service.useManualLocation(
        const SavedLocation(name: 'Nouakchott', latitude: 18.0, longitude: -16.0),
      );

      await service.refreshDeviceLocation();

      expect(service.current?.name, 'Nouakchott');
      expect(service.current?.isDevice, isFalse);
    });

    test('device fix reverse-geocodes a place name and persists it',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 30.4418, longitude: 73.7535)),
        placeNamer: FakePlaceNamer('Lahore'),
      );
      await service.useDeviceLocation();

      expect(service.current?.placeName, 'Lahore');
      expect(service.current?.displayName('Device location'), 'Lahore');

      // The name survives a reload (cached in prefs with the coordinates).
      final reloaded = await _loadService();
      expect(reloaded.current?.placeName, 'Lahore');
    });

    test('geocoding failure falls back to the generic device label',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 30.4418, longitude: 73.7535)),
        placeNamer: FakePlaceNamer(null),
      );
      await service.useDeviceLocation();

      expect(service.current?.placeName, isNull);
      expect(service.current?.displayName('Device location'),
          'Device location');
    });

    test('geocoding exception never breaks the device-location flow',
        () async {
      SharedPreferences.setMockInitialValues({});
      final namer = FakePlaceNamer()..throws = true;
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 30.4418, longitude: 73.7535)),
        placeNamer: namer,
      );
      await service.useDeviceLocation(); // must not throw

      expect(service.current?.placeName, isNull);
      expect(service.current?.latitude, 30.4418);
    });

    test('the GPS fix timeout is 25 seconds', () {
      expect(GeolocatorGpsReader.gpsTimeLimit, const Duration(seconds: 25));
    });

    test('a GPS fix that never arrives ends in positionUnknown, not a hang',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService(
        gpsReader: TimeoutGpsReader(),
        gateway: FakePermissionGateway(),
        placeNamer: FakePlaceNamer(),
      );

      await service.useDeviceLocation(); // must complete, never hang

      expect(service.errorKind, LocationErrorKind.positionUnknown);
      expect(service.errorMessage, isNotNull);
      expect(service.current, isNull,
          reason: 'a failed attempt must not touch the current location');
    });

    test('the GPS fix is persisted before the place name resolves',
        () async {
      SharedPreferences.setMockInitialValues({});
      final namer = GatedPlaceNamer();
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 30.4418, longitude: 73.7535)),
        gateway: FakePermissionGateway(),
        placeNamer: namer,
      );

      final pending = service.useDeviceLocation(); // don't await yet
      // Let the flow run until it parks on the gated geocoder.
      for (var i = 0; i < 100 && service.current == null; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // The name is still unresolved, but the fix is already live and
      // persisted: the name is cosmetic, the coordinates are not.
      expect(service.current, isNotNull);
      expect(service.current?.latitude, 30.4418);
      expect(service.current?.longitude, 73.7535);
      expect(service.current?.isDevice, isTrue);
      expect(service.current?.placeName, isNull);

      // The name arrives later and updates the saved entry.
      namer.gate.complete('Lahore');
      await pending;
      expect(service.current?.placeName, 'Lahore');

      final reloaded = await _loadService();
      expect(reloaded.current?.latitude, 30.4418);
      expect(reloaded.current?.placeName, 'Lahore');
    });

    test('a hanging geocoder is bounded by the place-name timeout',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 30.4418, longitude: 73.7535)),
        gateway: FakePermissionGateway(),
        placeNamer: HangingPlaceNamer(),
      );

      final stopwatch = Stopwatch()..start();
      await service.useDeviceLocation(); // must complete, never hang
      stopwatch.stop();

      // Bounded by the 10 s geocode timeout (generous upper bound so the
      // assertion itself never flakes on a loaded machine).
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
      expect(service.errorKind, LocationErrorKind.none);
      expect(service.current?.latitude, 30.4418);
      expect(service.current?.isDevice, isTrue);
      expect(service.current?.placeName, isNull,
          reason: 'no name arrived; the generic label applies');

      final reloaded = await _loadService();
      expect(reloaded.current?.latitude, 30.4418);
      expect(reloaded.current?.placeName, isNull);
    });

    test('successful manual save clears a stale errorKind', () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = FakePermissionGateway()
        ..checked = LocationPermissionState.denied
        ..requested = LocationPermissionState.denied;
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 18.0, longitude: -16.0)),
        gateway: gateway,
      );

      await service.useDeviceLocation(); // fails: permission denied
      expect(service.errorKind, LocationErrorKind.permissionDenied);
      expect(service.errorMessage, isNotNull);

      await service.useManualLocation(
        const SavedLocation(
            name: 'Nouakchott', latitude: 18.0, longitude: -16.0),
      );

      expect(service.errorKind, LocationErrorKind.none,
          reason: 'a successful save leaves no error to report');
      expect(service.errorMessage, isNull);
      expect(service.errorDetail, isNull);
      expect(service.current?.name, 'Nouakchott');
    });

    test('refresh updates the cached place name on a new fix', () async {
      SharedPreferences.setMockInitialValues({});
      final namer = FakePlaceNamer('Lahore');
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(latitude: 30.4418, longitude: 73.7535)),
        placeNamer: namer,
      );
      await service.useDeviceLocation();
      expect(service.current?.placeName, 'Lahore');

      namer.placeName = 'Kasur';
      await service.refreshDeviceLocation();
      expect(service.current?.placeName, 'Kasur');
    });
  });

  group('SavedLocation', () {
    test('round-trips through JSON', () {
      const original = SavedLocation(
        name: 'Karachi',
        latitude: 24.86,
        longitude: 67.0,
        isDevice: true,
      );
      final restored = SavedLocation.fromJson(original.toJson());
      expect(restored.name, 'Karachi');
      expect(restored.latitude, 24.86);
      expect(restored.longitude, 67.0);
      expect(restored.isDevice, isTrue);
    });

    test('missing isDevice defaults to false', () {
      final restored = SavedLocation.fromJson(
        {'name': 'X', 'latitude': 1.0, 'longitude': 2.0},
      );
      expect(restored.isDevice, isFalse);
    });

    test('placeName round-trips and legacy JSON without it reads as null',
        () {
      const withPlace = SavedLocation(
        name: 'Device location',
        latitude: 30.44,
        longitude: 73.75,
        isDevice: true,
        placeName: 'Lahore',
      );
      expect(SavedLocation.fromJson(withPlace.toJson()).placeName, 'Lahore');

      final legacy = SavedLocation.fromJson({
        'name': 'Device location',
        'latitude': 30.44,
        'longitude': 73.75,
        'isDevice': true,
      });
      expect(legacy.placeName, isNull);
      expect(legacy.displayName('Device location'), 'Device location');
    });

    test('displayName prefers placeName for device locations', () {
      const device = SavedLocation(
        name: 'Device location',
        latitude: 30.44,
        longitude: 73.75,
        isDevice: true,
        placeName: 'Lahore',
      );
      expect(device.displayName('آلے کا مقام'), 'Lahore');

      const manual = SavedLocation(name: 'Fez', latitude: 34.03, longitude: -5.0);
      expect(manual.displayName('Device location'), 'Fez');
    });
  });

  group('Phase 2: GPS quality metadata', () {
    test('device fix persists accuracy and timestamp', () async {
      SharedPreferences.setMockInitialValues({});
      final fixTime = DateTime.utc(2026, 10, 16, 10, 0);
      final service = await _loadService(
        gpsReader: FakeGpsReader(GpsFix(
          latitude: 24.86,
          longitude: 67.0,
          accuracyMeters: 12.0,
          timestamp: fixTime,
        )),
        placeNamer: FakePlaceNamer('Karachi'),
      );
      await service.useDeviceLocation();
      final loc = service.current!;
      expect(loc.accuracyMeters, 12.0);
      expect(loc.updatedAt, fixTime);
    });

    test('fix without quality metadata persists nulls (unknown, never '
        'fabricated)', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService(
        gpsReader: FakeGpsReader(
            const GpsFix(latitude: 24.86, longitude: 67.0)),
      );
      await service.useDeviceLocation();
      final loc = service.current!;
      expect(loc.accuracyMeters, isNull);
      expect(loc.updatedAt, isNull);
    });

    test('refresh updates accuracy and timestamp', () async {
      SharedPreferences.setMockInitialValues({});
      final first = FakeGpsReader(GpsFix(
        latitude: 24.86,
        longitude: 67.0,
        accuracyMeters: 30.0,
        timestamp: DateTime.utc(2026, 10, 16, 9, 0),
      ));
      final service = await _loadService(gpsReader: first);
      await service.useDeviceLocation();
      expect(service.current!.accuracyMeters, 30.0);

      first.fix = GpsFix(
        latitude: 24.87,
        longitude: 67.01,
        accuracyMeters: 8.0,
        timestamp: DateTime.utc(2026, 10, 16, 10, 0),
      );
      await service.refreshDeviceLocation();
      expect(service.current!.accuracyMeters, 8.0);
      expect(service.current!.updatedAt, DateTime.utc(2026, 10, 16, 10, 0));
    });
  });

  group('Phase 2: saved places', () {
    test('saveCurrentAsPlace snapshots the current manual location',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService();
      await service.useManualLocation(const SavedLocation(
        name: 'Fez',
        latitude: 34.033,
        longitude: -5.0,
        timeZoneId: 'Africa/Casablanca',
        elevationMeters: 410.0,
      ));
      expect(await service.saveCurrentAsPlace(), isTrue);
      expect(service.savedPlaces, hasLength(1));
      final place = service.savedPlaces.single;
      expect(place.name, 'Fez');
      expect(place.timeZoneId, 'Africa/Casablanca');
      expect(place.elevationMeters, 410.0);
      expect(place.isDevice, isFalse);
    });

    test('device location snapshot freezes the device zone, clears isDevice',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService(
        gpsReader: FakeGpsReader(const GpsFix(
            latitude: 24.86, longitude: 67.0, accuracyMeters: 10.0)),
        placeNamer: FakePlaceNamer('Karachi'),
      );
      await service.useDeviceLocation();
      expect(await service.saveCurrentAsPlace(), isTrue);
      final place = service.savedPlaces.single;
      expect(place.isDevice, isFalse);
      expect(place.name, 'Karachi');
      // The saved place keeps rendering in the frame it was saved in:
      // the device wall clock (null zone id) — never a fake zone id.
      expect(place.timeZoneId, isNull);
      // GPS quality does not travel into the saved snapshot.
      expect(place.accuracyMeters, isNull);
    });

    test('duplicate coordinates are not saved twice', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService();
      await service.useManualLocation(const SavedLocation(
          name: 'Fez', latitude: 34.033, longitude: -5.0));
      expect(await service.saveCurrentAsPlace(), isTrue);
      expect(await service.saveCurrentAsPlace(), isFalse);
      expect(service.savedPlaces, hasLength(1));
    });

    test('saveCurrentAsPlace does nothing with no current location',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService();
      expect(await service.saveCurrentAsPlace(), isFalse);
      expect(service.savedPlaces, isEmpty);
    });

    test('usePlace makes the saved place current', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService();
      await service.useManualLocation(const SavedLocation(
          name: 'Fez', latitude: 34.033, longitude: -5.0));
      await service.saveCurrentAsPlace();
      await service.useManualLocation(const SavedLocation(
          name: 'Cairo', latitude: 30.045, longitude: 31.262));
      await service.usePlace(service.savedPlaces.single);
      expect(service.current!.name, 'Fez');
    });

    test('removePlace deletes and persists the removal', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService();
      await service.useManualLocation(const SavedLocation(
          name: 'Fez', latitude: 34.033, longitude: -5.0));
      await service.saveCurrentAsPlace();
      final place = service.savedPlaces.single;
      await service.removePlace(place);
      expect(service.savedPlaces, isEmpty);

      final reloaded = await _loadService();
      expect(reloaded.savedPlaces, isEmpty);
    });

    test('saved places survive a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _loadService();
      await service.useManualLocation(const SavedLocation(
        name: 'Nouakchott',
        latitude: 18.073,
        longitude: -15.958,
        timeZoneId: 'Africa/Nouakchott',
      ));
      await service.saveCurrentAsPlace();

      final reloaded = await _loadService();
      expect(reloaded.savedPlaces, hasLength(1));
      expect(reloaded.savedPlaces.single.name, 'Nouakchott');
      expect(reloaded.savedPlaces.single.timeZoneId, 'Africa/Nouakchott');
    });
  });
}
