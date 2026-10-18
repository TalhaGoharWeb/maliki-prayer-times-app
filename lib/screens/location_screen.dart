import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/region_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/services/timezone_service.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/widgets/region_suggestion_dialog.dart';

/// Location picker: the active horizon card, famous Maliki city presets,
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

  /// Optional: when supplied, a newly set location may trigger the one-time
  /// "Recommended settings" regional-preset suggestion dialog
  /// (region_service.dart). When null the dialog is skipped.
  final SettingsService? settings;

  const LocationScreen(
      {super.key, required this.locationService, this.settings});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

/// A famous Maliki city the user can adopt with one tap: the timetable is
/// computed with the city's exact coordinates, in the city's IANA zone.
class _Preset {
  final String name;
  final double latitude;
  final double longitude;
  final IconData icon;
  final String timeZoneId;
  final String Function(AppLocalizations) description;

  const _Preset(this.name, this.latitude, this.longitude, this.icon,
      this.timeZoneId, this.description);
}

// Famous Maliki cities. Descriptions are localized, so this cannot be
// `const`. Zone ids are the cities' IANA zones (factual, from the tz
// database); elevations are left unset (sea-level horizon) rather than
// approximated.
final _presets = [
  _Preset('Fez (al-Qarawiyyin)', 34.033, -5.000, Icons.star,
      'Africa/Casablanca', (l) => l.presetFezDesc),
  _Preset('Cairo (al-Azhar / Fustat)', 30.045, 31.262, Icons.mosque,
      'Africa/Cairo', (l) => l.presetCairoDesc),
  _Preset('Kairouan (Mosque of Uqba)', 35.679, 10.103, Icons.account_balance,
      'Africa/Tunis', (l) => l.presetKairouanDesc),
  _Preset('Cordoba (Great Mosque)', 37.879, -4.779, Icons.history_edu,
      'Europe/Madrid', (l) => l.presetCordobaDesc),
  _Preset('Nouakchott', 18.073, -15.958, Icons.wb_sunny, 'Africa/Nouakchott',
      (l) => l.presetNouakchottDesc),
];

class _LocationScreenState extends State<LocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _elevationController = TextEditingController();

  /// IANA zone id chosen for the manual location, or null for the device
  /// wall clock (the default — the picker lets the user change it). Null
  /// is the honest default: the platform rarely reports a usable IANA id
  /// (real phones say "PKT", not "Asia/Karachi"), and defaulting to a
  /// hardcoded zone would render the wrong times.
  String? _selectedZoneId;

  bool _deviceBusy = false;
  bool _manualBusy = false;
  bool _presetBusy = false;
  bool _refreshBusy = false;
  bool _savePlaceBusy = false;

  LocationService get _service => widget.locationService;

  @override
  void initState() {
    super.initState();
    // Null = device wall clock (see [_selectedZoneId]).
    _selectedZoneId = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _elevationController.dispose();
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
      await _maybeSuggestRegion();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _usePreset(_Preset preset) async {
    setState(() => _presetBusy = true);
    await _service.useManualLocation(SavedLocation(
      name: preset.name,
      latitude: preset.latitude,
      longitude: preset.longitude,
      timeZoneId: preset.timeZoneId,
    ));
    if (!mounted) return;
    setState(() => _presetBusy = false);
    await _maybeSuggestRegion();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _saveManualLocation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _manualBusy = true);
    final elevationText = _elevationController.text.trim();
    final location = SavedLocation(
      name: _nameController.text.trim(),
      latitude: double.parse(_latitudeController.text.trim()),
      longitude: double.parse(_longitudeController.text.trim()),
      timeZoneId: _selectedZoneId,
      elevationMeters:
          elevationText.isEmpty ? null : double.parse(elevationText),
    );
    await _service.useManualLocation(location);
    if (!mounted) return;
    setState(() => _manualBusy = false);
    await _maybeSuggestRegion();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Opens the searchable IANA zone picker; the chosen zone id becomes the
  /// manual location's time zone, or null for the device wall clock.
  /// Dismissing keeps the previous choice — the button is never dead. The
  /// picker pops '' for the device-wall-clock entry, which maps to null.
  Future<void> _pickTimeZone() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          _TimeZonePickerDialog(selectedZoneId: _selectedZoneId),
    );
    if (picked != null && mounted) {
      setState(() => _selectedZoneId = picked.isEmpty ? null : picked);
    }
  }

  Future<void> _refreshDeviceLocation() async {
    setState(() => _refreshBusy = true);
    await _service.refreshDeviceLocation();
    if (!mounted) return;
    setState(() => _refreshBusy = false);
  }

  Future<void> _saveCurrentPlace() async {
    setState(() => _savePlaceBusy = true);
    await _service.saveCurrentAsPlace();
    if (!mounted) return;
    setState(() => _savePlaceBusy = false);
  }

  Future<void> _usePlace(SavedLocation place) async {
    await _service.usePlace(place);
    if (!mounted) return;
    await _maybeSuggestRegion();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// One-time "Recommended settings" suggestion (trust program Part A §2.5).
  ///
  /// After a location is set: the coarse region guess (region_service.dart)
  /// may map to a preset. The dialog shows only when the guess maps to a
  /// preset, the preset differs from the active profile, and the dialog has
  /// not been shown on this install yet. Showing marks it shown (dismissed
  /// counts as shown — the dialog never nags). The user confirms: nothing
  /// switches silently. Uncertain guesses (outside every box, or a region
  /// with no mapped preset) stay silent.
  Future<void> _maybeSuggestRegion() async {
    final settings = widget.settings;
    if (settings == null || settings.regionSuggestionShown) return;
    final current = _service.current;
    if (current == null) return;
    final guess =
        RegionService.guessFor(current.latitude, current.longitude);
    final suggestedId = guess?.suggestedProfileId;
    if (suggestedId == null) return;
    if (suggestedId == settings.activeProfileId) return;
    if (!PrayerProfiles.all.any((p) => p.id == suggestedId)) return;
    await settings.setRegionSuggestionShown();
    if (!mounted) return;
    final profile =
        PrayerProfiles.all.firstWhere((p) => p.id == suggestedId);
    final confirmed = await showRegionSuggestionDialog(
      context: context,
      guess: guess!,
      profile: profile,
    );
    if (confirmed == true && mounted) {
      await settings.setActiveProfile(suggestedId);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                l10n.profileApplied(profileLabel(l10n, profile).name)),
          ),
        );
      }
    }
  }

  Future<void> _deletePlace(
      AppLocalizations l10n, SavedLocation place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deletePlaceTitle),
        content: Text(l10n.deletePlaceMessage(place.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.removePlace(place);
    }
  }

  String? _validateName(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.validateName;
    }
    return null;
  }

  String? _validateLatitude(AppLocalizations l10n, String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    // Reject NaN/infinity: double.parse accepts "NaN"/"Infinity", and the
    // engine would silently collapse every time to solar noon.
    if (parsed == null || parsed.isNaN || !parsed.isFinite) {
      return l10n.validateNumberExample;
    }
    if (parsed < -90 || parsed > 90) {
      return l10n.validateLatitudeRange;
    }
    return null;
  }

  String? _validateLongitude(AppLocalizations l10n, String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed.isNaN || !parsed.isFinite) {
      return l10n.validateNumberExample;
    }
    if (parsed < -180 || parsed > 180) {
      return l10n.validateLongitudeRange;
    }
    return null;
  }

  /// Elevation is optional (empty = sea-level horizon); when given it must
  /// be a finite number within the plausible inhabited range.
  String? _validateElevation(AppLocalizations l10n, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed.isNaN || !parsed.isFinite) {
      return l10n.validateNumberExample;
    }
    if (parsed < -500 || parsed > 9000) {
      return l10n.validateElevationRange;
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
                            // Screen readers get the un-uppercased string.
                            semanticsLabel: l10n.locationTitle,
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
                // Refresh is only meaningful for a device-derived location:
                // it re-reads the GPS fix (and its accuracy/timestamp)
                // without going through the permission flow again.
                if (current?.isDevice == true) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _refreshBusy ? null : _refreshDeviceLocation,
                      icon: _refreshBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(l10n.refreshLocation),
                    ),
                  ),
                ],
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
                      const SizedBox(height: 10),
                      // Optional elevation: adjusts the sunrise/sunset
                      // horizon via the dip correction. Empty = sea level.
                      TextFormField(
                        controller: _elevationController,
                        decoration: InputDecoration(
                          labelText: l10n.fieldElevation,
                          hintText: l10n.hintElevation,
                          prefixIcon: const Icon(Icons.terrain),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        validator: (v) => _validateElevation(l10n, v),
                      ),
                      const SizedBox(height: 10),
                      // Time zone: the location's IANA zone, so times render
                      // in the location's wall clock instead of the device's.
                      // Defaults to the device wall clock (null).
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.public),
                          title: Text(l10n.fieldTimeZone),
                          subtitle: Text(
                            _selectedZoneId ?? l10n.deviceTimeZoneOption,
                            // Zone ids are Latin-script data: pin the Latin
                            // font so they never misrender in Nastaleeq.
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.latinSans,
                            ),
                          ),
                          trailing:
                              const Icon(Icons.chevron_right),
                          onTap: _pickTimeZone,
                        ),
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
                const SizedBox(height: 20),

                // Saved places: named snapshots for quick switching.
                _SectionHeader(
                    icon: Icons.bookmark_border,
                    title: l10n.savedPlacesTitle),
                const SizedBox(height: 8),
                if (_service.savedPlaces.isEmpty)
                  Text(
                    l10n.noSavedPlaces,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.secondary,
                    ),
                  )
                else
                  ..._service.savedPlaces.map((place) {
                    final isCurrent = current != null &&
                        (current.latitude - place.latitude).abs() < 1e-9 &&
                        (current.longitude - place.longitude).abs() < 1e-9;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SavedPlaceRow(
                        place: place,
                        isCurrent: isCurrent,
                        onTap: () => _usePlace(place),
                        onDelete: () => _deletePlace(l10n, place),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (current == null || _savePlaceBusy)
                        ? null
                        : _saveCurrentPlace,
                    icon: _savePlaceBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    label: Text(l10n.saveCurrentPlace),
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
            // Screen readers get the un-uppercased string.
            semanticsLabel: title,
            style: AppFonts.eyebrow(context).copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The active horizon card: current location with coordinates, datum,
/// time zone, elevation, GPS quality, and verification badges. Empty state
/// when nothing is chosen.
class _ActiveHorizonCard extends StatelessWidget {
  final SavedLocation? current;

  const _ActiveHorizonCard({required this.current});

  /// Formats a [Duration] offset as "UTC+5:00" / "UTC-4:00".
  static String _formatUtcOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = totalMinutes ~/ 60;
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final scheme = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final loc = current;

    // One icon+text row of the card's metadata list.
    Widget metaRow(IconData icon, String text, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon,
                size: 14, color: color ?? scheme.onInverseSurface),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color ?? scheme.onInverseSurface,
                  // Zone ids, offsets and numbers are Latin-script data:
                  // pin the Latin font so they never misrender in
                  // Nastaleeq.
                  fontFamily: AppFonts.latinSans,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }

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
                          // Screen readers get the un-uppercased string.
                          semanticsLabel: l10n.activeNow,
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
                    loc.displayName(l10n.deviceLocationName),
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
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            '${loc.latitude.toStringAsFixed(5)}°  ·  '
                            '${loc.longitude.toStringAsFixed(5)}°',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onInverseSurface,
                              // Latin-script data: pin the Latin font so "."
                              // never misrenders in Nastaleeq.
                              fontFamily: AppFonts.latinSans,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  metaRow(
                    Icons.layers_outlined,
                    '${l10n.datumLabel}: ${l10n.wgs84Datum}',
                  ),
                  // Time zone this location's times render in (the stored
                  // zone for manual locations, the device wall clock
                  // otherwise — never a fake zone, never UTC).
                  Builder(builder: (context) {
                    final String? zoneId =
                        TimezoneService.effectiveZoneIdFor(loc);
                    final offset = zoneId != null
                        ? TimezoneService.offsetFor(zoneId, DateTime.now())
                        : DateTime.now().timeZoneOffset;
                    return metaRow(
                      Icons.public,
                      '${l10n.timeZoneLabel}: '
                      '${zoneId ?? l10n.deviceTimeZoneOption} '
                      '(${_formatUtcOffset(offset)})',
                    );
                  }),
                  // Elevation, when set: the horizon dip correction applies
                  // to sunrise/sunset.
                  if (loc.elevationMeters != null)
                    metaRow(
                      Icons.terrain,
                      '${l10n.fieldElevation}: ${l10n.elevationValue(localizeDigits('${loc.elevationMeters!.round()}', lang))}',
                    ),
                  // GPS quality for device locations: accuracy radius and
                  // fix timestamp; unknown values are shown as unknown,
                  // never fabricated.
                  if (loc.isDevice) ...[
                    metaRow(
                      Icons.gps_fixed,
                      '${l10n.gpsAccuracyLabel}: '
                      '${loc.accuracyMeters == null ? l10n.gpsAccuracyUnknown : l10n.gpsAccuracyValue(localizeDigits('${loc.accuracyMeters!.round()}', lang))}',
                    ),
                    Builder(builder: (context) {
                      final updatedAt = loc.updatedAt;
                      if (updatedAt == null) {
                        return metaRow(
                          Icons.update,
                          l10n.locationUpdatedUnknown,
                        );
                      }
                      final when =
                          '${materialL10n.formatMediumDate(updatedAt)} '
                          '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt))}';
                      return metaRow(
                        Icons.update,
                        l10n.locationUpdatedAt(when),
                      );
                    }),
                    // Stale-fix honesty: a fix over a day old is flagged
                    // instead of being presented as current.
                    if (loc.updatedAt != null &&
                        DateTime.now()
                                .difference(loc.updatedAt!)
                                .inHours >=
                            24)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.history,
                                size: 14, color: scheme.onInverseSurface),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                l10n.locationStaleNote,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onInverseSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// One preset city row: icon medallion, name + coords + description,
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
class _NoticeCard extends StatelessWidget {  final IconData icon;
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

/// One saved place row: name, coordinates + zone, select-on-tap and a
/// delete button. Tapping the row makes the place current and pops the
/// screen; delete asks for confirmation first.
class _SavedPlaceRow extends StatelessWidget {
  final SavedLocation place;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SavedPlaceRow({
    required this.place,
    required this.isCurrent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final String? zoneId = TimezoneService.effectiveZoneIdFor(place);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
                child: Icon(Icons.bookmark,
                    size: 22, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${place.latitude.toStringAsFixed(3)}°, '
                      '${place.longitude.toStringAsFixed(3)}° · '
                      '${zoneId ?? l10n.deviceTimeZoneOption}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.secondary,
                        // Latin-script data: pin the Latin font so it never
                        // misrenders in Nastaleeq.
                        fontFamily: AppFonts.latinSans,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Icon(Icons.check_circle, color: scheme.primary, size: 24)
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searchable IANA time-zone picker dialog.
///
/// Lists every zone in the bundled tz database (~600 ids) with its current
/// UTC offset for today, filtered by the search field. Returns the chosen
/// zone id, or null when dismissed (the caller's previous choice stands).
class _TimeZonePickerDialog extends StatefulWidget {
  /// Currently selected zone id, or null for the device wall clock.
  final String? selectedZoneId;

  const _TimeZonePickerDialog({required this.selectedZoneId});

  @override
  State<_TimeZonePickerDialog> createState() => _TimeZonePickerDialogState();
}

class _TimeZonePickerDialogState extends State<_TimeZonePickerDialog> {
  final _searchController = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = TimezoneService.zoneIds;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    setState(() {
      _filtered = TimezoneService.searchZones(_searchController.text);
    });
  }

  String _offsetLabel(String zoneId) {
    try {
      final offset = TimezoneService.offsetFor(zoneId, DateTime.now());
      final sign = offset.isNegative ? '-' : '+';
      final totalMinutes = offset.inMinutes.abs();
      final hours = totalMinutes ~/ 60;
      final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
      return 'UTC$sign$hours:$minutes';
    } catch (_) {
      return '';
    }
  }

  String _deviceOffsetLabel() {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = totalMinutes ~/ 60;
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560, maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The honest default: the device wall clock (pops '' → null).
            // Pinned above the search results so it is always reachable.
            ListTile(
              dense: true,
              selected: widget.selectedZoneId == null,
              selectedTileColor: scheme.secondaryContainer,
              leading: const Icon(Icons.smartphone),
              title: Text(
                l10n.deviceTimeZoneOption,
                style: theme.textTheme.bodyMedium,
              ),
              trailing: Text(
                _deviceOffsetLabel(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.secondary,
                  fontFamily: AppFonts.latinSans,
                ),
              ),
              onTap: () => Navigator.of(context).pop(''),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.timeZonePickerTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.timeZoneSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.timeZoneNoResults,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.secondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final zoneId = _filtered[i];
                        final selected = zoneId == widget.selectedZoneId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: scheme.secondaryContainer,
                          title: Text(
                            zoneId,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: AppFonts.latinSans,
                            ),
                          ),
                          trailing: Text(
                            _offsetLabel(zoneId),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.secondary,
                              fontFamily: AppFonts.latinSans,
                            ),
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(zoneId),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
