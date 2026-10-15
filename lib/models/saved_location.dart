/// A named geographic point used to compute prayer times.
///
/// `isDevice` marks a location that came from the device GPS, so the UI
/// knows it can be refreshed on demand.
class SavedLocation {
  final String name;
  final double latitude;
  final double longitude;
  final bool isDevice;

  const SavedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.isDevice = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'isDevice': isDevice,
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isDevice: json['isDevice'] as bool? ?? false,
    );
  }
}
