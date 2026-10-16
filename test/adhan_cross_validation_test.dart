import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';

/// Phase 6 — independent cross-validation of the app's engine against
/// `adhan_dart` 2.0.1 (pub.dev; MIT license verified in-repo — see
/// ATTRIBUTION.md).
///
/// `adhan_dart` is a dev_dependency ONLY (test path); it is never imported
/// by lib/ and never ships in the app. Agreement with another engine is a
/// math-consistency signal, never fiqh proof (D6 §8.2).
///
/// ## Parameter mapping (verified against the adhan_dart 2.0.1 source)
/// - App side: [_crossValidationProfile] — Fajr 18°, Isha 17°, Asr t=1,
///   horizon −0.833°, nearest-minute rounding. ihtiyat is DISABLED on the
///   app side (0/0) because adhan_dart cannot express per-profile ihtiyat
///   offsets (task requirement: disable the inexpressible parameter on the
///   app side and say so — done here).
/// - adhan_dart side: `CalculationMethodParameters.muslimWorldLeague()`,
///   which presets fajrAngle 18 / ishaAngle 17 (the same institutional
///   convention — NOT a Maliki ruling); `Madhab.shafi` is the default
///   madhab with `shadowLength == 1`, the adhan-engine equivalent of the
///   Maliki first-mithl rule t=1 (D6 §2.1: "Asr factor 1 = Madhab.shafi
///   semantics"); SolarTime uses −50/60° (−0.833°) for sunrise/sunset,
///   matching the app's `solarDepression`; `Rounding.nearest` matches the
///   app's rounding. The MWL preset's built-in `methodAdjustments`
///   (dhuhr +1 min) is zeroed so both sides compare RAW astronomical times.
/// - `precision: true` is set on the adhan_dart side (its documented
///   high-accuracy mode).
/// - adhan_dart returns UTC-kind DateTimes; the app returns wall-clock in
///   a UTC-kind DateTime. Comparison adds the test offset to the
///   adhan_dart instants.
///
/// ## Tolerance
/// ±2 min per event. Justification: two independent Meeus-family
/// implementations — D5 documents ±1 min between its own Meeus and NOAA
/// reference implementations; the app's engine is a third implementation
/// (PrayTimes-style low-accuracy solar math) and measures a consistent
/// ≈+1 min bias against adhan_dart on the probe set (2026-10-16), so ±2
/// keeps the real agreement while leaving one minute of headroom. Any
/// event drifting beyond ±2 is a defect in one of the two engines.
///
/// ## Tromsø (persistent twilight)
/// adhan_dart's fallback machinery (HighLatitudeRule) and the app's
/// per-event-night fallback anchoring are DIFFERENT conventions for the
/// same D5 §3.7 rule family — numeric equality is not expected (D5 §5 E3:
/// fallback choice is a convention). The Tromsø test therefore asserts
/// STRUCTURAL agreement: the app flags the fallback and names the method,
/// and adhan_dart computes finite fallback times. The ±20 min band there
/// is a gross-breakage guard only, justified in the test comment.
const PrayerProfile _crossValidationProfile = PrayerProfile(
  id: 'cross-validation',
  name: 'Cross-validation (ihtiyat off)',
  basis: 'Fajr 18°, Isha 17°, Asr t=1, horizon -0.833°, nearest-minute '
      'rounding; ihtiyat disabled because adhan_dart cannot express it. '
      'Conventions, not rulings.',
  fajrAngle: 18.0,
  ishaAngle: 17.0,
  asrShadowFactor: 1.0,
  solarDepression: 0.833,
  dhuhrIhtiyatMinutes: 0,
  maghribIhtiyatMinutes: 0,
);

/// One cross-validation case: same inputs to both engines.
class _Case {
  final String name;
  final double lat;
  final double lon;
  final Duration offset;
  const _Case(this.name, this.lat, this.lon, this.offset);
}

const _cases = [
  // D5 vector locations where both engines compute astronomically.
  _Case('Nouakchott', 18.0858, -15.9785, Duration.zero),
  _Case('Fez', 34.02, -5.0, Duration.zero),
  _Case('Karachi', 24.86, 67.01, Duration(hours: 5)),
  _Case('Jakarta', -6.20, 106.85, Duration(hours: 7)),
];

PrayerTimes _appTimes(_Case c, int year, int month, int day) {
  final result = calculatePrayerTimes(
    coordinates: Coordinates(c.lat, c.lon),
    date: DateTime.utc(year, month, day),
    timeZoneOffset: c.offset,
    profile: _crossValidationProfile,
  );
  return (result as PrayerTimesComputed).times;
}

adhan.PrayerTimes _adhanTimes(_Case c, int year, int month, int day) {
  final params = adhan.CalculationMethodParameters.muslimWorldLeague();
  // Zero the MWL preset's dhuhr +1 method adjustment: raw comparison.
  params.methodAdjustments = {adhan.Prayer.dhuhr: 0};
  return adhan.PrayerTimes(
    coordinates: adhan.Coordinates(c.lat, c.lon),
    date: DateTime.utc(year, month, day),
    calculationParameters: params,
    precision: true,
  );
}

void main() {
  group('Cross-validation: app engine vs adhan_dart (MWL 18/17, Asr t=1)',
      () {
    test('madhab mapping precondition: adhan_dart defaults to Shafi t=1',
        () {
      // Guards the mapping the whole file rests on: if a future
      // adhan_dart changed its default madhab, every comparison below
      // would silently compare different Asr rules.
      final params = adhan.CalculationMethodParameters.muslimWorldLeague();
      expect(params.madhab, adhan.Madhab.shafi,
          reason: 'Parameter mapping: Madhab.shafi (shadowLength 1) is the '
              'adhan-engine equivalent of the app Asr t=1.');
      expect(adhan.Madhab.shafi.shadowLength, 1);
      expect(params.fajrAngle, 18.0);
      expect(params.ishaAngle, 17.0);
    });

    for (final date in [
      DateTime.utc(2026, 10, 16),
      DateTime.utc(2026, 6, 21),
    ]) {
      for (final c in _cases) {
        test('${c.name} ${date.year}-${date.month}-${date.day}: '
            'agrees within ±2 min', () {
          final app = _appTimes(c, date.year, date.month, date.day);
          final ref = _adhanTimes(c, date.year, date.month, date.day);
          final pairs = {
            Prayer.fajr: (app.fajr, ref.fajr),
            Prayer.sunrise: (app.sunrise, ref.sunrise),
            Prayer.dhuhr: (app.dhuhr, ref.dhuhr),
            Prayer.asr: (app.asr, ref.asr),
            Prayer.maghrib: (app.maghrib, ref.maghrib),
            Prayer.isha: (app.isha, ref.isha),
          };
          expect(app.highLatitudeFallback, isFalse,
              reason: '${c.name}: this case must be astronomically '
                  'computed on both sides.');
          for (final entry in pairs.entries) {
            final adhanWall = entry.value.$2.add(c.offset);
            final delta =
                entry.value.$1.difference(adhanWall).inMinutes.abs();
            expect(delta, lessThanOrEqualTo(2),
                reason: '${c.name} ${entry.key.name}: app vs adhan_dart '
                    'Δ $delta min exceeds the ±2 min cross-validation '
                    'tolerance.');
          }
        });
      }
    }

    test('Fez 2026-09-22 (equinox, UTC+0 per tzdata 2026c)', () {
      // Extra seasonal point on a D5 vector date.
      final c = const _Case('Fez', 34.02, -5.0, Duration.zero);
      final app = _appTimes(c, 2026, 9, 22);
      final ref = _adhanTimes(c, 2026, 9, 22);
      for (final pair in [
        (app.fajr, ref.fajr),
        (app.sunrise, ref.sunrise),
        (app.dhuhr, ref.dhuhr),
        (app.asr, ref.asr),
        (app.maghrib, ref.maghrib),
        (app.isha, ref.isha),
      ]) {
        final delta = pair.$1.difference(pair.$2).inMinutes.abs();
        expect(delta, lessThanOrEqualTo(2),
            reason: 'Fez equinox cross-validation Δ $delta min > ±2.');
      }
    });

    test('Tromsø 2026-05-15 persistent twilight: fallback-regime '
        'agreement', () {
      // Both engines see a night too short for 18°/17° twilight.
      // The app must FLAG the fallback and NAME the method (D5 §3.7);
      // adhan_dart must produce finite times under its own
      // middleOfTheNight convention. Numeric equality is NOT expected:
      // the app anchors each event to its own solar night while
      // adhan_dart uses a single night fraction — different conventions
      // for the same rule family (D5 §5 E3). The ±20 min band catches
      // gross breakage only.
      const c = _Case(
          'Tromsø', 69.65, 18.96, Duration(hours: 2));
      final result = calculatePrayerTimes(
        coordinates: Coordinates(c.lat, c.lon),
        date: DateTime.utc(2026, 5, 15),
        timeZoneOffset: c.offset,
        profile: _crossValidationProfile,
        fallback: HighLatitudeFallback.middleOfNight,
      );
      final app = (result as PrayerTimesComputed).times;
      expect(app.highLatitudeFallback, isTrue,
          reason: 'Fallback must be flagged, never silent (D5 §3.7).');
      expect(app.fallbackMethod, HighLatitudeFallback.middleOfNight,
          reason: 'The method in effect must be named.');

      final params = adhan.CalculationMethodParameters.muslimWorldLeague();
      params.methodAdjustments = {adhan.Prayer.dhuhr: 0};
      params.highLatitudeRule = adhan.HighLatitudeRule.middleOfTheNight;
      final ref = adhan.PrayerTimes(
        coordinates: adhan.Coordinates(c.lat, c.lon),
        date: DateTime.utc(2026, 5, 15),
        calculationParameters: params,
        precision: true,
      );
      for (final pair in [(app.fajr, ref.fajr), (app.isha, ref.isha)]) {
        final delta = pair.$1.difference(pair.$2.add(c.offset)).inMinutes.abs();
        expect(delta, lessThanOrEqualTo(20),
            reason: 'Tromsø fallback-regime sanity: Δ $delta min > ±20 '
                'suggests one side stopped applying its fallback.');
      }
    });

    test('Tromsø 2026-06-21 polar day: comparison not expressible in '
        'adhan_dart (documented)', () {
      // adhan_dart's default PolarCircleResolution.unresolved leaves polar
      // times invalid, while the app returns a typed NoSolution — the two
      // "no fabrication" behaviors are not numerically comparable, so no
      // numeric assertion is made. The app-side honesty is pinned by the
      // golden vectors test (D5 §4.3 c1).
      final result = calculatePrayerTimes(
        coordinates: const Coordinates(69.65, 18.96),
        date: DateTime.utc(2026, 6, 21),
        timeZoneOffset: const Duration(hours: 2),
        profile: _crossValidationProfile,
      );
      expect(result, isA<PrayerTimesNoSolution>());
    });
  });
}
