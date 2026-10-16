import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';

/// Convenience wrapper around [calculatePrayerTimes]. Unwraps the typed
/// result; a no-solution day fails loudly here — tests that expect
/// [PrayerTimesNoSolution] assert on the raw result instead.
PrayerTimes times(
  double lat,
  double lon,
  int year,
  int month,
  int day,
  Duration offset, [
  PrayerProfile? profile,
  HighLatitudeFallback fallback = HighLatitudeFallback.middleOfNight,
]) {
  final result = calculatePrayerTimes(
    coordinates: Coordinates(lat, lon),
    date: DateTime(year, month, day),
    timeZoneOffset: offset,
    profile: profile ?? PrayerProfiles.defaultProfile,
    fallback: fallback,
  );
  return (result as PrayerTimesComputed).times;
}

/// Universal ordering invariant:
/// fajr < sunrise < dhuhr < asr < maghrib < isha,
/// ishaPreferredEnd > isha, maghribPreferredEnd > maghrib.
void expectOrdering(PrayerTimes t) {
  expect(t.fajr.isBefore(t.sunrise), isTrue, reason: 'fajr < sunrise');
  expect(t.sunrise.isBefore(t.dhuhr), isTrue, reason: 'sunrise < dhuhr');
  expect(t.dhuhr.isBefore(t.asr), isTrue, reason: 'dhuhr < asr');
  expect(t.asr.isBefore(t.maghrib), isTrue, reason: 'asr < maghrib');
  expect(t.maghrib.isBefore(t.isha), isTrue, reason: 'maghrib < isha');
  expect(t.isha.isBefore(t.ishaPreferredEnd), isTrue,
      reason: 'isha < ishaPreferredEnd');
  expect(t.maghrib.isBefore(t.maghribPreferredEnd), isTrue,
      reason: 'maghrib < maghribPreferredEnd');
}

void expectRounded(PrayerTimes t) {
  for (final dt in [
    t.fajr,
    t.sunrise,
    t.dhuhr,
    t.asr,
    t.maghrib,
    t.isha,
    t.ishaPreferredEnd,
    t.ishaMidnightVariant,
    t.maghribPreferredEnd,
  ]) {
    expect(dt.second, 0, reason: 'seconds stripped: $dt');
    expect(dt.millisecond, 0, reason: 'millis stripped: $dt');
    expect(dt.microsecond, 0, reason: 'micros stripped: $dt');
  }
}

void main() {
  group('Nouakchott anchor (reference dataset §2.1)', () {
    test('Fajr is 05:45 ± 1 minute on 2026-10-15 (MWL 18/17, UTC+0)', () {
      // Reference point from the research dataset: al-hamdoulillah.com
      // timetable for Nouakchott, 2026-10-15, stated MWL 18/17 method.
      final t = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero);
      final fajrMinutes = t.fajr.hour * 60 + t.fajr.minute;
      expect((fajrMinutes - (5 * 60 + 45)).abs(), lessThanOrEqualTo(1));
      expect(t.highLatitudeFallback, isFalse);
      expectOrdering(t);
    });
  });

  group('ordering invariants across vectors', () {
    test('equator — Quito (0.0, -78.5), 2026-03-20, UTC-5', () {
      final t = times(0.0, -78.5, 2026, 3, 20, const Duration(hours: -5));
      expect(t.highLatitudeFallback, isFalse);
      expectOrdering(t);
    });

    test('London summer — (51.5, -0.12), 2026-06-21, UTC+1', () {
      // At 51.5°N near the solstice the sun never reaches 18°/17° below the
      // horizon (maximum depression ≈ 15°), so the high-latitude fallback
      // correctly applies here too.
      final t = times(51.5, -0.12, 2026, 6, 21, const Duration(hours: 1));
      expect(t.highLatitudeFallback, isTrue);
      expectOrdering(t);
    });

    test('London winter — (51.5, -0.12), 2026-12-21, UTC+0', () {
      final t = times(51.5, -0.12, 2026, 12, 21, Duration.zero);
      expect(t.highLatitudeFallback, isFalse);
      expectOrdering(t);
    });

    test('Reykjavik summer — (64.15, -21.9), 2026-06-21, UTC+0', () {
      final t = times(64.15, -21.9, 2026, 6, 21, Duration.zero);
      expect(t.highLatitudeFallback, isTrue);
      expectOrdering(t);
    });

    test('Reykjavik winter — (64.15, -21.9), 2026-12-21, UTC+0', () {
      final t = times(64.15, -21.9, 2026, 12, 21, Duration.zero);
      expectOrdering(t);
    });

    test('Sydney winter — (-33.87, 151.2), 2026-06-21, UTC+10', () {
      final t = times(-33.87, 151.2, 2026, 6, 21, const Duration(hours: 10));
      expect(t.highLatitudeFallback, isFalse);
      expectOrdering(t);
    });

    test('Nouakchott — (18.08581, -15.9785), 2026-10-15, UTC+0', () {
      final t = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero);
      expect(t.highLatitudeFallback, isFalse);
      expectOrdering(t);
    });
  });

  group('Asr shadow factor', () {
    test('factor 2.0 gives strictly later Asr than factor 1.0', () {
      const base = PrayerProfiles.malikiMwlWestAfrica;
      final f1 = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero, base);
      final factor2 = PrayerProfile(
        id: 'test-asr-factor-2',
        name: 'test copy',
        basis: 'test-only copy of the default profile with factor 2',
        fajrAngle: base.fajrAngle,
        ishaAngle: base.ishaAngle,
        asrShadowFactor: 2.0,
        solarDepression: base.solarDepression,
        dhuhrIhtiyatMinutes: base.dhuhrIhtiyatMinutes,
        maghribIhtiyatMinutes: base.maghribIhtiyatMinutes,
      );
      final f2 =
          times(18.08581, -15.9785, 2026, 10, 15, Duration.zero, factor2);
      expect(f2.asr.isAfter(f1.asr), isTrue);
      // Only the Asr input changed: the other prayers are untouched.
      expect(f2.fajr, f1.fajr);
      expect(f2.dhuhr, f1.dhuhr);
      expect(f2.maghrib, f1.maghrib);
      expect(f2.isha, f1.isha);
    });
  });

  group('high-latitude handling', () {
    test('Reykjavik summer: fallback flagged, ordering holds, all finite',
        () {
      final t = times(64.15, -21.9, 2026, 6, 21, Duration.zero);
      expect(t.highLatitudeFallback, isTrue);
      expectOrdering(t);
      for (final dt in [
        t.fajr,
        t.sunrise,
        t.dhuhr,
        t.asr,
        t.maghrib,
        t.isha,
        t.ishaPreferredEnd,
        t.ishaMidnightVariant,
        t.maghribPreferredEnd,
      ]) {
        expect(dt.millisecondsSinceEpoch.isFinite, isTrue);
        // Sane range: within a day of the requested civil date.
        expect(dt.year, 2026);
        expect(dt.month, 6);
        expect(dt.day >= 20 && dt.day <= 22, isTrue,
            reason: 'day in sane range: $dt');
      }
    });
  });

  group('polar frames are typed no-solutions (Phase 5)', () {
    // The old polar-coherence estimate path (noon±6 synthetic horizons)
    // is gone: when the sun never reaches the horizon, the engine returns
    // a typed no-solution instead of fabricated times. The E-01 chimera
    // regression (mixed real twilight + synthetic horizon) cannot recur
    // because the mixed state is no longer constructible.
    PrayerTimesResult raw(
            double lat, int month, int day, HighLatitudeFallback fb) =>
        calculatePrayerTimes(
          coordinates: Coordinates(lat, 0.0),
          date: DateTime(2026, month, day),
          timeZoneOffset: Duration.zero,
          fallback: fb,
        );

    test('80N on 21 Dec (polar night): NoSolution, not estimates', () {
      final r = raw(80.0, 12, 21, HighLatitudeFallback.middleOfNight);
      expect(r, isA<PrayerTimesNoSolution>());
      expect((r as PrayerTimesNoSolution).reason,
          NoSolutionReason.polarNight);
    });

    test('80N on 21 Jun (polar day): NoSolution, not estimates', () {
      final r = raw(80.0, 6, 21, HighLatitudeFallback.middleOfNight);
      expect(r, isA<PrayerTimesNoSolution>());
      expect((r as PrayerTimesNoSolution).reason, NoSolutionReason.polarDay);
    });

    test('70N on 21 Dec (polar night): NoSolution', () {
      final r = raw(70.0, 12, 21, HighLatitudeFallback.middleOfNight);
      expect(r, isA<PrayerTimesNoSolution>());
    });
  });

  group('Maghrib preferred-band anchor (E-04)', () {
    test('maghribPreferredEnd is exactly raw sunset + 20 minutes', () {
      // Default profile adds +1 min ihtiyat into the displayed Maghrib, so
      // the raw sunset is recovered by subtracting it.
      final t = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero);
      final rawSunset =
          t.maghrib.subtract(const Duration(minutes: 1));
      expect(t.maghribPreferredEnd.difference(rawSunset),
          const Duration(minutes: 20));
    });

    test('with ihtiyat disabled the band end is maghrib + 20 minutes', () {
      const base = PrayerProfiles.malikiMwlWestAfrica;
      final noIhtiyat = PrayerProfile(
        id: 'test-no-ihtiyat',
        name: 'test copy',
        basis: 'test-only copy of the default profile without ihtiyat',
        fajrAngle: base.fajrAngle,
        ishaAngle: base.ishaAngle,
        asrShadowFactor: base.asrShadowFactor,
        solarDepression: base.solarDepression,
        dhuhrIhtiyatMinutes: 0,
        maghribIhtiyatMinutes: 0,
      );
      final t = times(
          18.08581, -15.9785, 2026, 10, 15, Duration.zero, noIhtiyat);
      expect(t.maghribPreferredEnd.difference(t.maghrib),
          const Duration(minutes: 20));
    });
  });

  group('fiqh marker anchors ignore ihtiyat (E-05)', () {
    test('toggling ihtiyat moves Maghrib but not the Isha markers', () {
      const base = PrayerProfiles.malikiMwlWestAfrica;
      final noIhtiyat = PrayerProfile(
        id: 'test-no-ihtiyat',
        name: 'test copy',
        basis: 'test-only copy of the default profile without ihtiyat',
        fajrAngle: base.fajrAngle,
        ishaAngle: base.ishaAngle,
        asrShadowFactor: base.asrShadowFactor,
        solarDepression: base.solarDepression,
        dhuhrIhtiyatMinutes: 0,
        maghribIhtiyatMinutes: 0,
      );
      final withIhtiyat =
          times(18.08581, -15.9785, 2026, 10, 15, Duration.zero, base);
      final withoutIhtiyat = times(
          18.08581, -15.9785, 2026, 10, 15, Duration.zero, noIhtiyat);
      // The operational convention moves the displayed Maghrib…
      expect(
          withIhtiyat.maghrib.difference(withoutIhtiyat.maghrib),
          const Duration(minutes: 1));
      // …but the fiqh boundaries are anchored on the raw solar sunset and
      // must not move.
      expect(withIhtiyat.ishaPreferredEnd, withoutIhtiyat.ishaPreferredEnd);
      expect(withIhtiyat.ishaMidnightVariant,
          withoutIhtiyat.ishaMidnightVariant);
      // Same for the Maghrib preferred-band end (E-04).
      expect(withIhtiyat.maghribPreferredEnd,
          withoutIhtiyat.maghribPreferredEnd);
    });
  });

  group('named profiles', () {
    test('all named profiles produce ordered days for Nouakchott', () {
      for (final p in PrayerProfiles.all) {
        final t = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero, p);
        expectOrdering(t);
        expect(t.profile.id, p.id);
      }
    });

    test('Egyptian (19.5/17.5): Fajr earlier, Isha later than MWL', () {
      final mwl = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero,
          PrayerProfiles.malikiMwlWestAfrica);
      final egyptian = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero,
          PrayerProfiles.malikiEgyptian);
      expect(egyptian.fajr.isBefore(mwl.fajr), isTrue);
      expect(egyptian.isha.isAfter(mwl.isha), isTrue);
    });

    test('UOIF (12/12): Fajr later, Isha earlier than MWL', () {
      final mwl = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero,
          PrayerProfiles.malikiMwlWestAfrica);
      final uoif = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero,
          PrayerProfiles.malikiUoif);
      expect(uoif.fajr.isAfter(mwl.fajr), isTrue);
      expect(uoif.isha.isBefore(mwl.isha), isTrue);
    });
  });

  group('determinism', () {
    test('two identical calls give identical results', () {
      PrayerTimes call() =>
          times(51.5, -0.12, 2026, 6, 21, const Duration(hours: 1));
      final a = call();
      final b = call();
      expect(a.fajr, b.fajr);
      expect(a.sunrise, b.sunrise);
      expect(a.dhuhr, b.dhuhr);
      expect(a.asr, b.asr);
      expect(a.maghrib, b.maghrib);
      expect(a.isha, b.isha);
      expect(a.ishaPreferredEnd, b.ishaPreferredEnd);
      expect(a.ishaMidnightVariant, b.ishaMidnightVariant);
      expect(a.maghribPreferredEnd, b.maghribPreferredEnd);
      expect(a.highLatitudeFallback, b.highLatitudeFallback);
    });
  });

  group('rounding', () {
    test('all returned times have zero seconds/millis/micros', () {
      final vectors = [
        times(18.08581, -15.9785, 2026, 10, 15, Duration.zero),
        times(0.0, -78.5, 2026, 3, 20, const Duration(hours: -5)),
        times(51.5, -0.12, 2026, 6, 21, const Duration(hours: 1)),
        times(64.15, -21.9, 2026, 6, 21, Duration.zero),
        times(-33.87, 151.2, 2026, 6, 21, const Duration(hours: 10)),
      ];
      for (final t in vectors) {
        expectRounded(t);
      }
    });
  });

  group('nextPrayer / timeFor', () {
    test('next prayer strictly after now; wraps to fajr', () {
      final t = times(18.08581, -15.9785, 2026, 10, 15, Duration.zero);
      expect(t.timeFor(Prayer.fajr), t.fajr);
      expect(t.timeFor(Prayer.sunrise), t.sunrise);
      expect(t.timeFor(Prayer.dhuhr), t.dhuhr);
      expect(t.timeFor(Prayer.asr), t.asr);
      expect(t.timeFor(Prayer.maghrib), t.maghrib);
      expect(t.timeFor(Prayer.isha), t.isha);

      // Just before Fajr → Fajr; exactly at Fajr → Dhuhr (strictly after).
      expect(t.nextPrayer(t.fajr.subtract(const Duration(minutes: 1))),
          Prayer.fajr);
      expect(t.nextPrayer(t.fajr), Prayer.dhuhr);
      expect(t.nextPrayer(t.dhuhr), Prayer.asr);
      expect(t.nextPrayer(t.asr), Prayer.maghrib);
      expect(t.nextPrayer(t.maghrib), Prayer.isha);
      // After Isha (and after sunrise, which is skipped) → wraps to Fajr.
      expect(t.nextPrayer(t.isha), Prayer.fajr);
      expect(t.nextPrayer(t.sunrise), Prayer.dhuhr);
    });
  });
}
