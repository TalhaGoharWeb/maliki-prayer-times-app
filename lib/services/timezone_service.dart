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

  /// The device's IANA zone id, or null when the platform does not report
  /// one.
  ///
  /// Real Android phones report an ABBREVIATION here (`timeZoneName` =
  /// "PKT", "EST", …), not an IANA id — so this returns null on them.
  /// Callers must treat null as "the device wall clock" resolved from the
  /// OS offset ([deviceOffsetForDate]), never as UTC and never as a guess.
  /// The previous implementation returned the fake id 'Etc/UTC' on such
  /// devices, rendering every prayer time in UTC (5 hours behind in
  /// Pakistan) — fixed 2026-10-18. [platformZoneName] is a test seam for
  /// the real `DateTime.now().timeZoneName`.
  static String? deviceIanaZoneId({String? platformZoneName}) {
    ensureInitialized();
    final name = platformZoneName ?? DateTime.now().timeZoneName;
    if (tz.timeZoneDatabase.locations.containsKey(name)) return name;
    return null;
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
  /// returns null or a known zone) and use [offsetForLocation] rather than
  /// calling this directly with user input.
  static Duration offsetFor(String zoneId, DateTime date) {
    ensureInitialized();
    final location = tz.getLocation(zoneId);
    // Sample at noon: offsets change in the small hours, so noon always
    // lands on the date's prevailing offset.
    return tz.TZDateTime(location, date.year, date.month, date.day, 12)
        .timeZoneOffset;
  }

  /// The zone whose wall clock a location's times are rendered in, or
  /// null for "the device wall clock".
  ///
  /// * Manual locations use their stored [SavedLocation.timeZoneId] when it
  ///   names a known zone.
  /// * GPS-device locations ALWAYS return null — the phone travels with the
  ///   user, so the device wall clock (OS per-date offset) IS the location's
  ///   zone. No IANA lookup is attempted: real phones report abbreviations
  ///   like "PKT", and mapping those to a fake zone id was the 2026-10-18
  ///   UTC bug.
  /// * Legacy locations saved before Phase 2, or unknown zone ids, also
  ///   return null — exactly the pre-Phase-2 behavior, never a crash and
  ///   never UTC.
  static String? effectiveZoneIdFor(SavedLocation? location) {
    ensureInitialized();
    final id = location?.timeZoneId;
    if (location != null &&
        !location.isDevice &&
        id != null &&
        isKnownZone(id)) {
      return id;
    }
    return null;
  }

  /// The OS wall-clock offset for the civil [date] — DST-correct per date
  /// because it asks the platform for that date's offset, not "today's".
  /// This is the offset used whenever [effectiveZoneIdFor] returns null.
  static Duration deviceOffsetForDate(DateTime date) =>
      DateTime(date.year, date.month, date.day).timeZoneOffset;

  /// The UTC offset a location's times render with on [date]: the stored
  /// IANA zone's offset for manual locations, the device wall-clock offset
  /// otherwise. A device location can never resolve to 'Etc/UTC' through
  /// this path — the IANA database is consulted only for stored zone ids.
  static Duration offsetForLocation(SavedLocation? location, DateTime date) {
    ensureInitialized();
    final zoneId = effectiveZoneIdFor(location);
    if (zoneId != null) return offsetFor(zoneId, date);
    return deviceOffsetForDate(date);
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
