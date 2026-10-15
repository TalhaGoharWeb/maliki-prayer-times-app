import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Location picker: the active horizon card, historical reference presets,
/// device GPS, and manual coordinate entry.
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

/// A historical reference horizon: a canonical Maliki-astronomy meridian
/// the user can adopt with one tap.
class _Preset {
  final String name;
  final double latitude;
  final double longitude;
  final IconData icon;
  final String Function(AppLocalizations) description;

  const _Preset(
      this.name, this.latitude, this.longitude, this.icon, this.description);
}

// Historical presets cannot be `const`: their descriptions are localized.
final _presets = [
  _Preset('Fez (al-Qarawiyyin)', 34.033, -5.000, Icons.star,
      (l) => l.presetFezDesc),
  _Preset('Cairo (al-Azhar / Fustat)', 30.045, 31.262, Icons.mosque,
      (l) => l.presetCairoDesc),
  _Preset('Kairouan (Mosque of Uqba)', 35.679, 10.103, Icons.account_balance,
      (l) => l.presetKairouanDesc),
  _Preset('Cordoba (Andalusian Meridian)', 37.879, -4.779, Icons.history_edu,
      (l) => l.presetCordobaDesc),
  _Preset('Nouakchott (Desert Horizon)', 18.073, -15.958, Icons.wb_sunny,
      (l) => l.presetNouakchottDesc),
];

class _LocationScreenState extends State<LocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _deviceBusy = false;
  bool _manualBusy = false;
  bool _presetBusy = false;

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

  Future<void> _usePreset(_Preset preset) async {
    setState(() => _presetBusy = true);
    await _service.useManualLocation(SavedLocation(
      name: preset.name,
      latitude: preset.latitude,
      longitude: preset.longitude,
    ));
    if (!mounted) return;
    setState(() => _presetBusy = false);
    Navigator.of(context).pop();
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

  bool _isActivePreset(SavedLocation? current, _Preset preset) {
    if (current == null || current.isDevice) return false;
    return current.name == preset.name &&
        (current.latitude - preset.latitude).abs() < 1e-9 &&
        (current.longitude - preset.longitude).abs() < 1e-9;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final current = _service.current;
        final blockedReason = _deviceLocationBlockReason(l10n);
        final errorText = _localizedError(l10n);
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Header: back + titles.
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.locationTitle.toUpperCase(),
                            style: AppFonts.eyebrow(context).copyWith(
                              color: scheme.secondary,
                            ),
                          ),
                          Text('Geodesic Hub',
                              style: theme.textTheme.displaySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Active horizon card.
                _SectionHeader(
                    icon: Icons.compass_calibration,
                    title: l10n.activeHorizon),
                const SizedBox(height: 8),
                _ActiveHorizonCard(current: current),
                const SizedBox(height: 20),

                // Historical reference horizons.
                _SectionHeader(
                    icon: Icons.auto_stories, title: l10n.presetHeader),
                const SizedBox(height: 4),
                Text(l10n.presetSub, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                ..._presets.map((preset) {
                  final active = _isActivePreset(current, preset);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PresetRow(
                      preset: preset,
                      active: active,
                      busy: _presetBusy,
                      onTap: () => _usePreset(preset),
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // Device GPS.
                _SectionHeader(
                    icon: Icons.my_location, title: l10n.deviceGpsTitle),
                const SizedBox(height: 4),
                Text(l10n.deviceGpsSub, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                if (blockedReason != null) ...[
                  _NoticeCard(
                    icon: Icons.settings,
                    text: blockedReason,
                    actionLabel: l10n.openSystemSettings,
                    onAction: Geolocator.openAppSettings,
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_deviceBusy || _deviceLocationBlocked)
                        ? null
                        : _useDeviceLocation,
                    icon: _deviceBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(l10n.useDeviceLocation),
                  ),
                ),
                if (errorText != null &&
                    _service.current?.isDevice != true) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Manual entry.
                _SectionHeader(
                    icon: Icons.edit_location_alt,
                    title: l10n.enterManually),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.fieldName,
                          hintText: l10n.hintName,
                          prefixIcon: const Icon(Icons.pin_drop),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => _validateName(l10n, v),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latitudeController,
                              decoration: InputDecoration(
                                labelText: l10n.fieldLatitude,
                                hintText: l10n.hintLatitude,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                signed: true,
                                decimal: true,
                              ),
                              validator: (v) => _validateLatitude(l10n, v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _longitudeController,
                              decoration: InputDecoration(
                                labelText: l10n.fieldLongitude,
                                hintText: l10n.hintLongitude,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                signed: true,
                                decimal: true,
                              ),
                              validator: (v) => _validateLongitude(l10n, v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: scheme.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.validateNumberExample,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              _manualBusy ? null : _saveManualLocation,
                          icon: _manualBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(l10n.saveCompute),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Section header: small icon + eyebrow title.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: AppFonts.eyebrow(context).copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The active horizon card: current location with coordinates, datum, and
/// verification badges. Empty state when nothing is chosen.
class _ActiveHorizonCard extends StatelessWidget {
  final SavedLocation? current;

  const _ActiveHorizonCard({required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final loc = current;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: loc == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.noLocationChosen,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.chooseLocationBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.activeNow.toUpperCase(),
                          style: AppFonts.eyebrow(context).copyWith(
                            color: scheme.inversePrimary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.tertiaryFixed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified,
                                    size: 12,
                                    color: scheme.onTertiaryFixed),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.verifiedZenith,
                                  style: AppFonts.badgeLabel(context).copyWith(
                                    color: scheme.onTertiaryFixed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.isDevice ? l10n.deviceLocationName : loc.name,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.pin_drop,
                          size: 14, color: scheme.onInverseSurface),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${loc.latitude.toStringAsFixed(5)}°  ·  '
                            '${loc.longitude.toStringAsFixed(5)}°',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 14, color: scheme.onInverseSurface),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.datumLabel}: ${l10n.wgs84Datum}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// One historical preset row: icon medallion, name + coords + description,
/// active check when adopted.
class _PresetRow extends StatelessWidget {
  final _Preset preset;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  const _PresetRow({
    required this.preset,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final lat = preset.latitude;
    final lon = preset.longitude;
    final latStr =
        '${lat.toStringAsFixed(3)}° ${lat >= 0 ? 'N' : 'S'}';
    final lonStr =
        '${lon.abs().toStringAsFixed(3)}° ${lon >= 0 ? 'E' : 'W'}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(preset.icon,
                    size: 22, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '$latStr · $lonStr',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.secondary,
                      ),
                    ),
                    Text(
                      preset.description(l10n),
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (active)
                Icon(Icons.check_circle,
                    color: scheme.primary, size: 24)
              else
                Icon(Icons.chevron_right,
                    color: scheme.outline, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notice card with an action button (e.g. blocked device location).
class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _NoticeCard({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: scheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
