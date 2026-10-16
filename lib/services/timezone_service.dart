import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// IANA time-zone database access for the app (Phase 2: location exactness).
///
/// The database comes from `package:timezone`'s **latest_all** variant
/// (full IANA coverage: 598 zones, tzdata 2026e), initialized once at app
/// boot via [ensureInitialized]. It is bundled with the app: daily
/// calculation works with zero connectivity (offline-first).
///
/// Variant note: the task's first draft named `latest_10y` (~85 KB), but
/// that variant is a curated 345-zone SUBSET, not a time-window trim — it
/// drops real zones including `Africa/Nouakchott`, one of this app's own
/// preset cities. A zone picker that cannot represent Nouakchott breaks
/// Phase 2's purpose ("a Maliki in Nouakchott, Paris, or Jakarta"), so the
/// full variant is used; the size cost (~1 MB in a ~73 MB APK) is
/// immaterial next to correctness. The notification path previously used
/// `latest_all` too, so the whole app shares one database.
///
/// Key architectural fact: `package:timezone` provides the zone *database*,
/// not lat/lon → zone reverse-geocoding. When the user sets a manual
/// location, the app presents a searchable zone picker (see
/// [zoneIds]/[searchZones]) defaulting to the device zone, and stores the
/// chosen zone id on the location. Times are then rendered in the
/// *location's* zone, not the phone's — this closes the previous
/// device-timezone-frame limitation. GPS-derived locations keep the device
/// zone (documented in [effectiveZoneIdFor]).
abstract final class TimezoneService {
  static bool _initialized = false;

  /// Initializes the bundled tz database. Idempotent: safe to call any
  /// number of times, from app boot, widget tests, or lazily (every public
  /// method below calls it first, so tests never need explicit setup).
  static void ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  /// True after the first successful [ensureInitialized].
  static bool get isInitialized => _initialized;

  /// Every IANA zone id in the bundled database, sorted ascending.
  /// Populates the manual-location zone picker.
  static List<String> get zoneIds {
    ensureInitialized();
    final ids = tz.timeZoneDatabase.locations.keys.toList()..sort();
    return ids;
  }

  /// The device's zone id when the platform reports an IANA name the
  /// database knows; 'Etc/UTC' otherwise.
  ///
  /// The fallback matters on systems whose platform zone name is not an
  /// IANA id (this sandbox reports 'UTC', which the database does not
  /// carry — 'Etc/UTC' is the equivalent entry, offset identically zero).
  /// Real Android/iOS devices report IANA names and never hit the fallback.
  /// If a platform ever reported an unknown name with a NON-zero offset,
  /// this fallback would be wrong by that offset — an honest documented
  /// limit, not a silent invention (no zone is guessed from the offset).
  static String get deviceZoneId {
    ensureInitialized();
    final name = DateTime.now().timeZoneName;
    if (tz.timeZoneDatabase.locations.containsKey(name)) return name;
    return 'Etc/UTC';
  }

  /// True when [zoneId] names a zone in the bundled database.
  static bool isKnownZone(String zoneId) {
    ensureInitialized();
    return tz.timeZoneDatabase.locations.containsKey(zoneId);
  }

  /// Case-insensitive substring search over [zoneIds] for the zone picker.
  /// An empty/blank query returns the full list.
  static List<String> searchZones(String query) {
    final q = query.trim().toLowerCase();
    final ids = zoneIds;
    if (q.isEmpty) return ids;
    return ids.where((id) => id.toLowerCase().contains(q)).toList();
  }

  /// The UTC offset of [zoneId] on the civil [date] — DST-correct per date,
  /// so a DST transition between two computed days is honored for each day
  /// instead of pinning every date to "today's" offset.
  ///
  /// Throws [tz.TimeZoneNotFoundException] for an unknown [zoneId];
  /// callers should resolve the zone through [effectiveZoneIdFor] (which
  /// only ever returns known zones) rather than calling this directly with
  /// user input.
  static Duration offsetFor(String zoneId, DateTime date) {
    ensureInitialized();
    final location = tz.getLocation(zoneId);
    // Sample at noon: offsets change in the small hours, so noon always
    // lands on the date's prevailing offset.
    return tz.TZDateTime(location, date.year, date.month, date.day, 12)
        .timeZoneOffset;
  }

  /// The zone whose wall clock a location's times are rendered in.
  ///
  /// * GPS-device locations (`isDevice`) always use the device zone — the
  ///   phone travels with the user, so the device zone IS the location's
  ///   zone (documented limitation: none — this is correct behavior).
  /// * Manual locations use their stored [SavedLocation.timeZoneId] when it
  ///   names a known zone.
  /// * Anything else (legacy locations saved before Phase 2, unknown zone
  ///   ids) falls back to the device zone — exactly the pre-Phase-2
  ///   behavior, never a crash.
  static String effectiveZoneIdFor(SavedLocation? location) {
    ensureInitialized();
    final id = location?.timeZoneId;
    if (location != null &&
        !location.isDevice &&
        id != null &&
        isKnownZone(id)) {
      return id;
    }
    return deviceZoneId;
  }

  /// Renders a UTC [instant] as a wall-clock [DateTime] in [zoneId]
  /// (TZDateTime whose fields read as the zone's local time).
  ///
  /// Conversion helper for the regression test and any future UI that must
  /// display an instant in a non-device zone. The engine's own output frame
  /// (UTC-kind DateTimes whose fields are wall-clock values) is produced by
  /// passing [offsetFor] into `calculatePrayerTimes`.
  static tz.TZDateTime zoneWallTime(DateTime instant, String zoneId) {
    ensureInitialized();
    return tz.TZDateTime.from(instant.toUtc(), tz.getLocation(zoneId));
  }
}
