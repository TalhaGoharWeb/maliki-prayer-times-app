import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/services/location_service.dart';

/// Lets the user pick the location used for prayer-time calculation:
/// either the device GPS fix or a manually entered name + coordinates.
///
/// The screen listens to [LocationService] and pops itself on a successful
/// choice so the caller immediately sees the updated location.
class LocationScreen extends StatefulWidget {
  final LocationService locationService;

  const LocationScreen({super.key, required this.locationService});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _deviceBusy = false;
  bool _manualBusy = false;

  LocationService get _service => widget.locationService;

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  /// The device-location button is disabled only when another attempt
  /// cannot change anything (denied forever or service off): in those
  /// states the system settings must be used instead.
  bool get _deviceLocationBlocked =>
      _service.permissionState == LocationPermissionState.deniedForever ||
      _service.permissionState == LocationPermissionState.serviceDisabled;

  String? get _deviceLocationBlockReason {
    switch (_service.permissionState) {
      case LocationPermissionState.deniedForever:
        return 'Location permission is permanently denied. Allow location '
            'access in the system settings, or enter your location manually.';
      case LocationPermissionState.serviceDisabled:
        return 'Location services are turned off. Turn them on in the '
            'system settings, or enter your location manually.';
      case LocationPermissionState.unknown:
      case LocationPermissionState.granted:
      case LocationPermissionState.denied:
        return null;
    }
  }

  Future<void> _useDeviceLocation() async {
    setState(() => _deviceBusy = true);
    await _service.useDeviceLocation();
    if (!mounted) return;
    setState(() => _deviceBusy = false);
    if (_service.errorMessage == null && _service.current?.isDevice == true) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveManualLocation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _manualBusy = true);
    final location = SavedLocation(
      name: _nameController.text.trim(),
      latitude: double.parse(_latitudeController.text.trim()),
      longitude: double.parse(_longitudeController.text.trim()),
    );
    await _service.useManualLocation(location);
    if (!mounted) return;
    setState(() => _manualBusy = false);
    Navigator.of(context).pop();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name for this location.';
    }
    return null;
  }

  String? _validateLatitude(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return 'Please enter a number, e.g. 18.09.';
    }
    if (parsed < -90 || parsed > 90) {
      return 'Latitude must be between -90 and 90.';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return 'Please enter a number, e.g. -15.98.';
    }
    if (parsed < -180 || parsed > 180) {
      return 'Longitude must be between -180 and 180.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final current = _service.current;
        final blockedReason = _deviceLocationBlockReason;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Location'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Current location', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                current == null
                    ? 'No location chosen yet.'
                    : '${current.name}\n'
                        '${current.latitude.toStringAsFixed(5)}, '
                        '${current.longitude.toStringAsFixed(5)}'
                        '${current.isDevice ? ' (from device)' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Device location.
              Text('Device location', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              if (blockedReason != null) ...[
                Text(blockedReason, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: Geolocator.openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open system settings'),
                ),
              ],
              FilledButton(
                onPressed: (_deviceBusy || _deviceLocationBlocked)
                    ? null
                    : _useDeviceLocation,
                child: _deviceBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Use device location'),
              ),
              if (_service.errorMessage != null &&
                  _service.current?.isDevice != true) ...[
                const SizedBox(height: 8),
                Text(
                  _service.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Manual entry.
              Text('Enter manually', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Nouakchott',
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: '-90 to 90',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      validator: _validateLatitude,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: '-180 to 180',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      validator: _validateLongitude,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _manualBusy ? null : _saveManualLocation,
                      child: _manualBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save this location'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
