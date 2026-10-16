import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';

/// Phase 6 golden vectors — executed worked examples from D5
/// (Deliverable 5, "Calculation Specification"), §4.
///
/// SOURCE: the values below were produced by running
/// `~/workspace/maliki-prayer-times/scratch/calc_d5.py` on 2026-10-16 with
/// TWO independent solar-position implementations (Meeus ch.25 and the NOAA
/// Fourier series); raw JSON in `d5_results.json` in the same directory.
/// The "Meeus" column is the expected value; the NOAA column is the
/// independent cross-check. Per D5 §4, the two implementations agree within
/// ±1 minute on the worked examples; per-event exceptions are documented
/// below with their D5 basis.
///
/// Tolerances:
/// - Default ±1 min per event (D5 §4 cross-check envelope).
/// - Fez-equinox Isha ±2 min: D5's own two implementations give 19:35
///   (Meeus) vs 19:37 (NOAA) for this event — the ±2 spread is IN the D5
///   table itself, so this tolerance is documented, not loosened.
/// - Tromsø persistent-twilight fallback table ±8 min: the D5 §4.3 prose
///   values apply the §3.7 single-night formula to an approximate
///   23:43→01:37 night frame, while the app engine computes its own
///   night frame from its own sunrise/sunset and anchors each event to its
///   own solar night (see lib/engine/prayer_times.dart). The test pins the
///   fallback REGIME (flagged, method named, night-midpoint-class values),
///   not the minute.
///
/// Offsets: the engine takes a raw [Duration] (the IANA resolution lives in
/// the service layer, tested in timezone_service_test.dart). The offsets
/// below are what the D5 script's ZoneInfo("...") resolved on 2026-10-16
/// (verified against IANA tzdata 2026c): Africa/Casablanca is UTC+0 on
/// 2026-09-22 and 2026-12-21 (the September 2026 +01→+00 transition is real
/// per this tzdata) and UTC+1 on 2026-06-21; Europe/Oslo +02/+01;
/// America/Guayaquil −05; Africa/Johannesburg +02; Africa/Nouakchott +00.
///
/// Integrity boundary: nothing here is a Maliki ruling. Angles are
/// institutional/software conventions (D5 §6.1); the Asr t=1 mapping is
/// fiqh-based (D5 §6.2). A failing vector means the ENGINE, the PROFILE, or
/// an INVARIANT is wrong — fix the cause, never edit the expected values
/// (D6 §3.5).
///
/// Omitted from D5 as executed vectors (documented here per the task brief):
/// - DST transitions (D5 §5 E8/E9), the date-line rule (E7), and invalid
///   coordinates (E12) are RULE ROWS in D5 §5, not executed vectors with
///   numbers — no expected value exists to encode. DST resolution itself is
///   covered in test/timezone_service_test.dart. E7's "instant-based
///   computation is date-line agnostic" IS encodable as an exact engine
///   invariant (D5 §2.2: transit = 720 − 4λ − EoT), and is tested below.
/// - Tromsø polar-night partial-day question (D5 §5 E5): mathematically
///   Fajr/Isha are solvable, but the engine policy is suppress-and-flag
///   pending scholarly review — the test pins that policy.
/// - The Mauritanian ministry comparison (D5 §4.1) is INFORMATIONAL: the
///   ministry publishes no methodology, so it is a consistency check
///   (±2 min), never validation of the engine.
///
/// Profile note: D5 §4 applies dhuhr +2 min and maghrib +1 min ihtiyat.
/// [_goldenProfile] reproduces exactly that D5 configuration.
const PrayerProfile _goldenProfile = PrayerProfile(
  id: 'golden-d5',
  name: 'D5 golden profile',
  basis: 'D5 §4: Fajr 18°, Isha 17°, Asr t=1, horizon -0.833°, '
      'dhuhr ihtiyat +2, maghrib ihtiyat +1. Conventions, not rulings.',
  fajrAngle: 18.0,
  ishaAngle: 17.0,
  asrShadowFactor: 1.0,
  solarDepression: 0.833,
  dhuhrIhtiyatMinutes: 2,
  maghribIhtiyatMinutes: 1,
);

/// Computes [calculatePrayerTimes] with the D5 golden configuration and
/// unwraps the typed result; a no-solution day fails loudly unless the
/// test expects [PrayerTimesNoSolution].
PrayerTimes _goldenTimes(
  double lat,
  double lon,
  int year,
  int month,
  int day,
  Duration offset,
) {
  final result = calculatePrayerTimes(
    coordinates: Coordinates(lat, lon),
    date: DateTime.utc(year, month, day),
    timeZoneOffset: offset,
    profile: _goldenProfile,
  );
  return (result as PrayerTimesComputed).times;
}

/// The raw result (for no-solution assertions).
PrayerTimesResult _goldenResult(
  double lat,
  double lon,
  int year,
  int month,
  int day,
  Duration offset, [
  HighLatitudeFallback fallback = HighLatitudeFallback.middleOfNight,
]) {
  return calculatePrayerTimes(
    coordinates: Coordinates(lat, lon),
    date: DateTime.utc(year, month, day),
    timeZoneOffset: offset,
    profile: _goldenProfile,
    fallback: fallback,
  );
}

void _expectWithin(
  DateTime actual,
  DateTime expected,
  int toleranceMinutes,
  String what,
  String basis,
) {
  final delta = actual.difference(expected).inMinutes.abs();
  expect(delta, lessThanOrEqualTo(toleranceMinutes),
      reason: '$what: expected ${expected.hour.toString().padLeft(2, '0')}:'
          '${expected.minute.toString().padLeft(2, '0')}, got '
          '${actual.hour.toString().padLeft(2, '0')}:'
          '${actual.minute.toString().padLeft(2, '0')} '
          '(Δ $delta min, tolerance ±$toleranceMinutes). $basis');
}

void _expectVector(
  String name,
  double lat,
  double lon,
  int year,
  int month,
  int day,
  Duration offset,
  Map<String, String> expectedHhmm, {
  int ishaTolerance = 1,
}) {
  final t = _goldenTimes(lat, lon, year, month, day, offset);
  DateTime at(String hhmm) {
    final parts = hhmm.split(':');
    return DateTime.utc(year, month, day, int.parse(parts[0]),
        int.parse(parts[1]));
  }

  // D5 §3.8 sanity gate #3 — monotonic ordering on every vector.
  expect(t.fajr.isBefore(t.sunrise), isTrue, reason: '$name: fajr < sunrise');
  expect(t.sunrise.isBefore(t.dhuhr), isTrue, reason: '$name: sunrise < dhuhr');
  expect(t.dhuhr.isBefore(t.asr), isTrue, reason: '$name: dhuhr < asr');
  expect(t.asr.isBefore(t.maghrib), isTrue, reason: '$name: asr < maghrib');
  expect(t.maghrib.isBefore(t.isha), isTrue, reason: '$name: maghrib < isha');

  _expectWithin(t.fajr, at(expectedHhmm['fajr']!), 1, '$name Fajr',
      'D5 §4 Meeus column.');
  _expectWithin(t.sunrise, at(expectedHhmm['sunrise']!), 1, '$name Sunrise',
      'D5 §4 Meeus column.');
  _expectWithin(t.dhuhr, at(expectedHhmm['dhuhr']!), 1, '$name Dhuhr',
      'D5 §4 dhuhr_display(+2 ihtiyat).');
  _expectWithin(t.asr, at(expectedHhmm['asr']!), 1, '$name Asr t=1',
      'D5 §4 Meeus column.');
  _expectWithin(t.maghrib, at(expectedHhmm['maghrib']!), 1, '$name Maghrib',
      'D5 §4 maghrib_display(+1 ihtiyat).');
  _expectWithin(t.isha, at(expectedHhmm['isha']!), ishaTolerance, '$name Isha',
      'D5 §4 Meeus column.');
  // Raw solar sunset anchors the fiqh night (D5 §3.6 / engine E-05): it
  // carries no ihtiyat, so it is pinned separately.
  _expectWithin(t.sunset, at(expectedHhmm['sunset']!), 1, '$name raw sunset',
      'D5 §4 sunset (raw, before ihtiyat).');
}

void main() {
  group('D5 §4.1 — Nouakchott 2026-10-16 (MWL 18/17, Asr t=1)', () {
    // D5 Meeus column; Africa/Nouakchott = UTC+0.
    final expected = {
      'fajr': '05:45',
      'sunrise': '06:57',
      'sunset': '18:41',
      'dhuhr': '12:51',
      'asr': '16:10',
      'maghrib': '18:42',
      'isha': '19:49',
    };
    test('reproduces the D5 Meeus vector within ±1 min', () {
      _expectVector('Nouakchott', 18.0858, -15.9785, 2026, 10, 16,
          Duration.zero, expected);
    });

    test('stays within ±2 min of the Mauritanian ministry times '
        '(informational, D5 §4.1)', () {
      // The ministry publishes daily timetables but NO methodology (D5
      // explicit negative finding) — this is a consistency check against
      // an opaque reference, NOT validation of the engine. The engine must
      // never be tuned to match it.
      final t = _goldenTimes(18.0858, -15.9785, 2026, 10, 16, Duration.zero);
      final ministry = {
        Prayer.fajr: DateTime.utc(2026, 10, 16, 5, 46),
        Prayer.sunrise: DateTime.utc(2026, 10, 16, 6, 57),
        Prayer.dhuhr: DateTime.utc(2026, 10, 16, 12, 51),
        Prayer.asr: DateTime.utc(2026, 10, 16, 16, 11),
        Prayer.maghrib: DateTime.utc(2026, 10, 16, 18, 43),
        Prayer.isha: DateTime.utc(2026, 10, 16, 19, 51),
      };
      for (final p in ministry.keys) {
        _expectWithin(t.timeFor(p), ministry[p]!, 2,
            'Nouakchott ${p.name} vs ministry',
            'D5 §4.1: all six times agree within 2 minutes (informational).');
      }
    });
  });

  group('D5 §4.2 — Fez equinox/solstices', () {
    test('equinox 2026-09-22 reproduces within tolerance', () {
      // Africa/Casablanca = UTC+0 on this date (tzdata 2026c).
      // Isha ±2: D5's own NOAA column reads 19:37 vs Meeus 19:35.
      _expectVector('Fez equinox', 34.02, -5.0, 2026, 9, 22, Duration.zero, {
        'fajr': '04:44',
        'sunrise': '06:08',
        'sunset': '18:17',
        'dhuhr': '12:14',
        'asr': '15:40',
        'maghrib': '18:18',
        'isha': '19:35',
      }, ishaTolerance: 2);
    });

    test('June solstice 2026-06-21 reproduces within ±1 min', () {
      // Africa/Casablanca = UTC+1 on this date (tzdata 2026c).
      _expectVector('Fez June solstice', 34.02, -5.0, 2026, 6, 21,
          const Duration(hours: 1), {
        'fajr': '04:24',
        'sunrise': '06:09',
        'sunset': '20:34',
        'dhuhr': '13:23',
        'asr': '17:07',
        'maghrib': '20:35',
        'isha': '22:12',
      });
    });

    test('December solstice 2026-12-21 reproduces within ±1 min', () {
      // Africa/Casablanca = UTC+0 on this date (tzdata 2026c).
      // D5 prose notes the Asr-altitude swing: 40.1° summer vs 21.3°
      // winter — same t=1 rule, different solar geometry.
      _expectVector('Fez December solstice', 34.02, -5.0, 2026, 12, 21,
          Duration.zero, {
        'fajr': '05:51',
        'sunrise': '07:21',
        'sunset': '17:14',
        'dhuhr': '12:20',
        'asr': '14:56',
        'maghrib': '17:15',
        'isha': '18:39',
      });
    });
  });

  group('D5 §4.4 — edge-case probes', () {
    test('Quito equinox (equator) reproduces within ±1 min', () {
      // America/Guayaquil = UTC−5. Steep Asr geometry (~44.8°), ~12 h day.
      _expectVector('Quito equinox', -0.18, -78.47, 2026, 9, 22,
          const Duration(hours: -5), {
        'fajr': '04:54',
        'sunrise': '06:03',
        'sunset': '18:09',
        'dhuhr': '12:08',
        'asr': '15:07',
        'maghrib': '18:10',
        'isha': '19:14',
      });
    });

    test('Cape Town June (southern winter) reproduces within ±1 min', () {
      // Africa/Johannesburg = UTC+2. Southern-hemisphere inversion is
      // derived from δ and φ, never from a northern template.
      _expectVector('Cape Town June', -33.92, 18.42, 2026, 6, 21,
          const Duration(hours: 2), {
        'fajr': '06:21',
        'sunrise': '07:51',
        'sunset': '17:44',
        'dhuhr': '12:50',
        'asr': '15:27',
        'maghrib': '17:45',
        'isha': '19:09',
      });
    });
  });

  group('D5 §4.3 — Tromsø high latitude', () {
    test('summer solstice (polar day): typed no-solution, no fallback '
        'fabrication', () {
      // D5 §4.3 c1: cosH = −2.1374 (Fajr), −1.2144 (sunrise/sunset) — no
      // night frame exists, so no fallback can be constructed from
      // sunset/sunrise. The adhan nearest-day convention exists but is NOT
      // the default and is not a Maliki ruling.
      final result = _goldenResult(
          69.65, 18.96, 2026, 6, 21, const Duration(hours: 2));
      expect(result, isA<PrayerTimesNoSolution>(),
          reason: 'D5 §4.3 c1 — polar day must surface an honest '
              'unavailable state, never fabricated times.');
      expect((result as PrayerTimesNoSolution).reason,
          NoSolutionReason.polarDay);
    });

    test('winter solstice (polar night): suppress-and-flag default', () {
      // D5 §5 E5: Fajr/Isha are mathematically solvable here, but the
      // solar-day frame is absent, so the honest DEFAULT is to suppress
      // the day pending scholarly review of the partial-day question.
      final result = _goldenResult(
          69.65, 18.96, 2026, 12, 21, const Duration(hours: 1));
      expect(result, isA<PrayerTimesNoSolution>(),
          reason: 'D5 §5 E5 — polar-night suppress-and-flag policy.');
      expect((result as PrayerTimesNoSolution).reason,
          NoSolutionReason.polarNight);
    });

    test('persistent twilight 2026-05-15: fallbacks flagged and named '
        '(D5 §3.7)', () {
      // D5 §4.3 c2 prose table: sunset 23:43 → sunrise 01:37, N = 113.8
      // min; middleOfNight 00:40/00:40, oneSeventh 01:21/23:59,
      // angleBased(15°) 01:08/00:12. ±8 min tolerance documented in the
      // file header (app computes its own night frame).
      final expectations = {
        HighLatitudeFallback.middleOfNight: (
          DateTime.utc(2026, 5, 15, 0, 40),
          DateTime.utc(2026, 5, 16, 0, 40)
        ),
        HighLatitudeFallback.oneSeventhOfNight: (
          DateTime.utc(2026, 5, 15, 1, 21),
          DateTime.utc(2026, 5, 15, 23, 59)
        ),
        HighLatitudeFallback.angleBased: (
          DateTime.utc(2026, 5, 15, 1, 8),
          DateTime.utc(2026, 5, 16, 0, 12)
        ),
      };
      for (final entry in expectations.entries) {
        final method = entry.key;
        final result = _goldenResult(
            69.65, 18.96, 2026, 5, 15, const Duration(hours: 2), method);
        final times = (result as PrayerTimesComputed).times;
        expect(times.highLatitudeFallback, isTrue,
            reason: 'D5 §3.7 — fallback must be flagged, never silent ($method).');
        expect(times.fallbackMethod, method,
            reason: 'D5 §3.7 — the method in effect must be named ($method).');
        _expectWithin(times.fajr, entry.value.$1, 8, 'Tromsø $method Fajr',
            'D5 §4.3 c2 prose table (±8 regime tolerance, see header).');
        _expectWithin(times.isha, entry.value.$2, 8, 'Tromsø $method Isha',
            'D5 §4.3 c2 prose table (±8 regime tolerance, see header).');
      }
    });
  });

  group('D5 §5 E7 — date-line agnosticism (exact engine invariant)', () {
    test('antipodal longitudes render the same solar day, shifted −4 min', () {
      // D5 §2.2: transit_UTC = 720 − 4λ − EoT, so the astronomical instants
      // at λ = +179.5 and λ = −179.5 differ by exactly 4×359 = 1436 min.
      // The engine folds solar transit into [0, 24) of the civil date
      // (`_norm24` in _solarEvents), so the two displayed daily timetables
      // are the SAME local solar day, shifted by 1436 − 1440 = −4 min —
      // exactly, for every event, with no date-line discontinuity. This
      // pins the engine's actual date-line behavior (E7): instant-based
      // computation with civil-date assignment, no special-casing.
      final a = _goldenTimes(10.0, 179.5, 2026, 10, 16, Duration.zero);
      final b = _goldenTimes(10.0, -179.5, 2026, 10, 16, Duration.zero);
      for (final p in Prayer.values) {
        final delta = b.timeFor(p).difference(a.timeFor(p)).inMinutes;
        expect(delta, -4,
            reason: 'D5 §5 E7 — ${p.name} must shift by exactly −4 min '
                'across the date line (got $delta).');
      }
    });
  });

  group('D5 §3.8 — Asr factor gate', () {
    test('Asr(t=1) strictly precedes Asr(t=2) on every vector', () {
      // The Maliki profile pins t=1 (D5 §6.2); a profile change that made
      // t=2 earlier-or-equal would break the mashhur mapping.
      const cases = [
        (18.0858, -15.9785, Duration.zero), // Nouakchott
        (34.02, -5.0, Duration.zero), // Fez
        (-0.18, -78.47, Duration(hours: -5)), // Quito
        (-33.92, 18.42, Duration(hours: 2)), // Cape Town
      ];
      for (final (lat, lon, off) in cases) {
        final t1 = _goldenTimes(lat, lon, 2026, 9, 22, off);
        final withT2 = calculatePrayerTimes(
          coordinates: Coordinates(lat, lon),
          date: DateTime.utc(2026, 9, 22),
          timeZoneOffset: off,
          profile: PrayerProfile(
            id: 't2-probe',
            name: 't=2 probe',
            basis: 'Comparison probe only.',
            fajrAngle: 18.0,
            ishaAngle: 17.0,
            asrShadowFactor: 2.0,
            solarDepression: 0.833,
            dhuhrIhtiyatMinutes: 2,
            maghribIhtiyatMinutes: 1,
          ),
        ) as PrayerTimesComputed;
        expect(t1.asr.isBefore(withT2.times.asr), isTrue,
            reason: 'D5 §3.8 gate #4 — Asr t=1 must precede t=2 '
                'at ($lat, $lon).');
      }
    });
  });
}
