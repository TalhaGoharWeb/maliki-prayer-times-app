/// A named geographic point used to compute prayer times.
///
/// `isDevice` marks a location that came from the device GPS, so the UI
/// knows it can be refreshed on demand. `placeName` holds the
/// reverse-geocoded human place name (city/locality) for device locations;
/// it is cached alongside the coordinates in prefs and refreshed on each
/// new GPS fix. It is `null` when geocoding failed or has not run yet.
class SavedLocation {
  final String name;
  final double latitude;
  final double longitude;
  final bool isDevice;
  final String? placeName;

  const SavedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.isDevice = false,
    this.placeName,
  });

  /// Name shown in the UI: for device locations the reverse-geocoded place
  /// name when available, otherwise the localized [deviceFallback]
  /// ("Device location"); manual and preset locations show [name].
  String displayName(String deviceFallback) =>
      isDevice ? (placeName ?? deviceFallback) : name;

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'isDevice': isDevice,
        'placeName': placeName,
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isDevice: json['isDevice'] as bool? ?? false,
      placeName: json['placeName'] as String?,
    );
  }
}
