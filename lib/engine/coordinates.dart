/// Geographic coordinates of the observer, in degrees.
///
/// * [latitude]: degrees north of the equator, range −90..90.
/// * [longitude]: degrees east of Greenwich, range −180..180 (east positive).
class Coordinates {
  /// Degrees north of the equator, −90..90.
  final double latitude;

  /// Degrees east of Greenwich, −180..180 (east positive).
  final double longitude;

  const Coordinates(this.latitude, this.longitude);
}
