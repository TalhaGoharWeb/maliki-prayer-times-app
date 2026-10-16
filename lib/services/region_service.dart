import 'package:malikiprayertimes/l10n/app_localizations.dart';

/// Coarse region guess from coordinates for the "Recommended settings"
/// auto-adapt (trust program Part A §2.5).
///
/// The guess comes from a small built-in table of approximate country
/// bounding boxes — rectangles, not borders. It is deliberately coarse:
/// a point near a box edge (or in an unlisted country) gets no suggestion
/// rather than a confident wrong one. First match wins where boxes
/// overlap; the table order is documented below.
///
/// Suggested profile ids are stable [PrayerProfile.id] values; `null`
/// means the region is recognized but no preset maps to it (Spain), so the
/// dialog stays silent. Points outside every box return `null` (uncertain —
/// offer no suggestion).
///
/// Nothing here is a fiqh mapping: suggestions are named institutional
/// presets, and the user always confirms before anything switches.
class RegionService {
  const RegionService._();

  /// Stable region codes.
  static const String maghreb = 'maghreb';
  static const String westAfrica = 'west-africa';
  static const String egypt = 'egypt';
  static const String france = 'france';
  static const String spain = 'spain';

  static const _boxes = <_RegionBox>[
    // Maghreb → Morocco Habous (19/17). Listed before Mali so southern
    // Algeria resolves to Algeria, not Mali.
    _RegionBox(
      regionCode: maghreb,
      suggestedProfileId: 'maliki-morocco-habous',
      minLat: 27.6,
      maxLat: 35.9,
      minLon: -13.2,
      maxLon: -0.9,
    ), // Morocco
    _RegionBox(
      regionCode: maghreb,
      suggestedProfileId: 'maliki-morocco-habous',
      minLat: 19.0,
      maxLat: 37.1,
      minLon: -8.7,
      maxLon: 12.0,
    ), // Algeria
    _RegionBox(
      regionCode: maghreb,
      suggestedProfileId: 'maliki-morocco-habous',
      minLat: 30.2,
      maxLat: 37.4,
      minLon: 7.5,
      maxLon: 11.6,
    ), // Tunisia
    _RegionBox(
      regionCode: maghreb,
      suggestedProfileId: 'maliki-morocco-habous',
      minLat: 19.5,
      maxLat: 33.2,
      minLon: 9.3,
      maxLon: 25.0,
    ), // Libya
    // West Africa → MWL West Africa (18/17).
    _RegionBox(
      regionCode: westAfrica,
      suggestedProfileId: 'maliki-mwl-west-africa',
      minLat: 14.7,
      maxLat: 27.3,
      minLon: -17.1,
      maxLon: -4.8,
    ), // Mauritania
    _RegionBox(
      regionCode: westAfrica,
      suggestedProfileId: 'maliki-mwl-west-africa',
      minLat: 12.3,
      maxLat: 16.7,
      minLon: -17.6,
      maxLon: -11.3,
    ), // Senegal
    _RegionBox(
      regionCode: westAfrica,
      suggestedProfileId: 'maliki-mwl-west-africa',
      minLat: 10.1,
      maxLat: 25.0,
      minLon: -12.3,
      maxLon: 4.3,
    ), // Mali
    _RegionBox(
      regionCode: westAfrica,
      suggestedProfileId: 'maliki-mwl-west-africa',
      minLat: 11.7,
      maxLat: 23.5,
      minLon: 0.2,
      maxLon: 16.0,
    ), // Niger
    // Egypt → Egyptian (19.5/17.5).
    _RegionBox(
      regionCode: egypt,
      suggestedProfileId: 'maliki-egyptian',
      minLat: 22.0,
      maxLat: 31.7,
      minLon: 24.9,
      maxLon: 36.0,
    ), // Egypt
    // France (metropolitan) → UOIF (12/12). The suggestion always shows
    // the preset's disputed badge; the user confirms.
    _RegionBox(
      regionCode: france,
      suggestedProfileId: 'maliki-uoif',
      minLat: 41.3,
      maxLat: 51.1,
      minLon: -5.1,
      maxLon: 8.3,
    ), // France
    // Spain: recognized, but no preset maps to it — no suggestion.
    // Listed last so the Pyrenees overlap resolves to France.
    _RegionBox(
      regionCode: spain,
      suggestedProfileId: null,
      minLat: 35.9,
      maxLat: 43.8,
      minLon: -9.3,
      maxLon: 3.3,
    ), // Spain
  ];

  /// The region guess for [latitude]/[longitude], or `null` when the point
  /// falls outside every box (uncertain — offer no suggestion).
  static RegionGuess? guessFor(double latitude, double longitude) {
    for (final box in _boxes) {
      if (latitude >= box.minLat &&
          latitude <= box.maxLat &&
          longitude >= box.minLon &&
          longitude <= box.maxLon) {
        return RegionGuess(
          regionCode: box.regionCode,
          suggestedProfileId: box.suggestedProfileId,
        );
      }
    }
    return null;
  }
}

/// One approximate bounding box with its region code and the profile it
/// suggests (or `null` for "recognized, no preset").
class _RegionBox {
  final String regionCode;
  final String? suggestedProfileId;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const _RegionBox({
    required this.regionCode,
    required this.suggestedProfileId,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });
}

/// A coarse region guess. [suggestedProfileId] is `null` when the region is
/// recognized but no preset maps to it — the caller must stay silent then.
class RegionGuess {
  final String regionCode;
  final String? suggestedProfileId;

  const RegionGuess({
    required this.regionCode,
    required this.suggestedProfileId,
  });

  /// Localized region name for the suggestion dialog.
  String name(AppLocalizations l10n) => switch (regionCode) {
        RegionService.maghreb => l10n.regionNameMaghreb,
        RegionService.westAfrica => l10n.regionNameWestAfrica,
        RegionService.egypt => l10n.regionNameEgypt,
        RegionService.france => l10n.regionNameFrance,
        RegionService.spain => l10n.regionNameSpain,
        _ => regionCode,
      };
}
