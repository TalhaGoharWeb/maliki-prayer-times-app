import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test double for [GpsReader]: returns a fixed position (or `null`).
class FakeGpsReader implements GpsReader {
  (double, double)? position;

  FakeGpsReader([this.position]);

  @override
  Future<(double, double)?> readPosition() async => position;
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

Future<LocationService> _loadService({
  FakeGpsReader? gpsReader,
  FakePermissionGateway? gateway,
}) {
  return LocationService.load(
    gpsReader: gpsReader ?? FakeGpsReader(),
    permissionGateway: gateway ?? FakePermissionGateway(),
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
        gpsReader: FakeGpsReader((18.0, -16.0)),
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
        gpsReader: FakeGpsReader((18.0, -16.0)),
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
        gpsReader: FakeGpsReader((24.8607, 67.0011)),
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
      final gpsReader = FakeGpsReader((18.08581, -15.9785));
      final service = await _loadService(gpsReader: gpsReader);
      await service.useDeviceLocation();
      expect(service.current?.latitude, 18.08581);

      gpsReader.position = (19.0, -16.5);
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
        gpsReader: FakeGpsReader((1.0, 2.0)),
      );
      await service.useManualLocation(
        const SavedLocation(name: 'Nouakchott', latitude: 18.0, longitude: -16.0),
      );

      await service.refreshDeviceLocation();

      expect(service.current?.name, 'Nouakchott');
      expect(service.current?.isDevice, isFalse);
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
  });
}
