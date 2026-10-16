/// A named geographic point used to compute prayer times.
///
/// `isDevice` marks a location that came from the device GPS, so the UI
/// knows it can be refreshed on demand. `placeName` holds the
/// reverse-geocoded human place name (city/locality) for device locations;
/// it is cached alongside the coordinates in prefs and refreshed on each
/// new GPS fix. It is `null` when geocoding failed or has not run yet.
///
/// Phase 2 fields:
/// * `timeZoneId` — the IANA zone id chosen for a *manual* location
///   (e.g. 'America/New_York'), so times render in the location's zone
///   instead of the device's. `null` for GPS-device locations (they always
///   use the device zone) and for locations saved before Phase 2, which
///   keep the legacy device-zone behavior.
/// * `elevationMeters` — optional observer elevation above sea level; the
///   engine applies the horizon dip correction to sunrise/sunset.
/// * `accuracyMeters` / `updatedAt` — GPS fix quality metadata: the
///   accuracy radius reported by the platform and the fix's timestamp.
///   Both are `null` for manual locations (honestly "unknown", never
///   fabricated).
///
/// Persistence is schema-versioned: `schema_version` 2 is the current
/// shape; JSON without the key is treated as version 1 (pre-Phase-2) and
/// reads with the new fields defaulted.
class SavedLocation {
  /// Current persistence schema version written by [toJson].
  static const int schemaVersion = 2;

  final String name;
  final double latitude;
  final double longitude;
  final bool isDevice;
  final String? placeName;
  final String? timeZoneId;
  final double? elevationMeters;
  final double? accuracyMeters;
  final DateTime? updatedAt;

  const SavedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.isDevice = false,
    this.placeName,
    this.timeZoneId,
    this.elevationMeters,
    this.accuracyMeters,
    this.updatedAt,
  });

  /// Name shown in the UI: for device locations the reverse-geocoded place
  /// name when available, otherwise the localized [deviceFallback]
  /// ("Device location"); manual and preset locations show [name].
  String displayName(String deviceFallback) =>
      isDevice ? (placeName ?? deviceFallback) : name;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'isDevice': isDevice,
        'placeName': placeName,
        'timeZoneId': timeZoneId,
        'elevationMeters': elevationMeters,
        'accuracyMeters': accuracyMeters,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    // schema_version 1 (pre-Phase-2) has no new keys: every new field
    // defaults to null, preserving the legacy device-zone, sea-level,
    // unknown-quality behavior. No migration rewrites are needed.
    return SavedLocation(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isDevice: json['isDevice'] as bool? ?? false,
      placeName: json['placeName'] as String?,
      timeZoneId: json['timeZoneId'] as String?,
      elevationMeters: (json['elevationMeters'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}
