import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/services/location_service.dart';

/// Lets the user pick the location used for prayer-time calculation:
/// either the device GPS fix or a manually entered name + coordinates.
///
/// The screen listens to [LocationService] and pops itself on a successful
/// choice so the caller immediately sees the updated location.
///
/// Failure messages come from [LocationService.errorKind] rendered through
/// the localized ARB templates; the service's English `errorMessage` is only
/// a fallback that is never shown here.
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

  String? _deviceLocationBlockReason(AppLocalizations l10n) {
    switch (_service.permissionState) {
      case LocationPermissionState.deniedForever:
        return l10n.errorDeniedForever;
      case LocationPermissionState.serviceDisabled:
        return l10n.errorServiceDisabled;
      case LocationPermissionState.unknown:
      case LocationPermissionState.granted:
      case LocationPermissionState.denied:
        return null;
    }
  }

  /// The localized text for the service's latest failure, or `null` when
  /// there is none.
  String? _localizedError(AppLocalizations l10n) {
    final detail = _service.errorDetail ?? '';
    return switch (_service.errorKind) {
      LocationErrorKind.none => null,
      LocationErrorKind.serviceDisabled => l10n.errorServiceDisabled,
      LocationErrorKind.permissionDeniedForever => l10n.errorDeniedForever,
      LocationErrorKind.permissionDenied => l10n.errorDenied,
      LocationErrorKind.positionUnknown => l10n.errorPositionUnknown,
      LocationErrorKind.reauthorizeNeeded => l10n.errorReauthorize,
      LocationErrorKind.refreshPositionUnknown =>
        l10n.errorRefreshPositionUnknown,
      LocationErrorKind.unexpectedUse => l10n.errorUnexpectedUse(detail),
      LocationErrorKind.unexpectedRefresh => l10n.errorUnexpectedRefresh(
          detail,
        ),
    };
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

  String? _validateName(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.validateName;
    }
    return null;
  }

  String? _validateLatitude(AppLocalizations l10n, String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return l10n.validateNumberExample;
    }
    if (parsed < -90 || parsed > 90) {
      return l10n.validateLatitudeRange;
    }
    return null;
  }

  String? _validateLongitude(AppLocalizations l10n, String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return l10n.validateNumberExample;
    }
    if (parsed < -180 || parsed > 180) {
      return l10n.validateLongitudeRange;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final current = _service.current;
        final blockedReason = _deviceLocationBlockReason(l10n);
        final errorText = _localizedError(l10n);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.locationTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.currentLocation, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                current == null
                    ? l10n.noLocationChosen
                    : l10n.currentLocationValue(
                        current.isDevice
                            ? l10n.deviceLocationName
                            : current.name,
                        '${current.latitude.toStringAsFixed(5)}, '
                        '${current.longitude.toStringAsFixed(5)}',
                        current.isDevice ? l10n.deviceLocationSuffix : '',
                      ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Device location.
              Text(
                l10n.deviceLocationSection,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              if (blockedReason != null) ...[
                Text(blockedReason, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: Geolocator.openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: Text(l10n.openSystemSettings),
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
                    : Text(l10n.useDeviceLocation),
              ),
              if (errorText != null && _service.current?.isDevice != true) ...[
                const SizedBox(height: 8),
                Text(
                  errorText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Manual entry.
              Text(l10n.enterManually, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.fieldName,
                        hintText: l10n.hintName,
                      ),
                      validator: (v) => _validateName(l10n, v),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _latitudeController,
                      decoration: InputDecoration(
                        labelText: l10n.fieldLatitude,
                        hintText: l10n.hintLatitude,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      validator: (v) => _validateLatitude(l10n, v),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _longitudeController,
                      decoration: InputDecoration(
                        labelText: l10n.fieldLongitude,
                        hintText: l10n.hintLongitude,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      validator: (v) => _validateLongitude(l10n, v),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _manualBusy ? null : _saveManualLocation,
                      child: _manualBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.saveLocation),
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
