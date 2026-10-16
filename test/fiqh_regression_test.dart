import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/fiqh/maliki_rules.dart';
import 'package:malikiprayertimes/screens/methodology_texts.dart';

/// Phase 6 — fiqh regression guards per D6 §8.2.
///
/// For every verified rule and profile, a test carrying the legal source,
/// the legal interpretation, the expected behavior, and the calculation
/// convention. These are REGRESSION GUARDS: if a future change alters a
/// fiqh mapping, the failing test's name + comment says which rule broke.
///
/// Integrity boundary (plan Part B rule 2): software conventions
/// (18°/17°, −0.833°, high-latitude fallbacks, ihtiyat, rounding) are NEVER
/// presented as Maliki rulings — in code, comments, UI strings, or these
/// tests. The angles approximate legal SIGNS (true dawn, red-twilight
/// disappearance); the classical texts define signs, never degrees
/// (D1 Strand A, key answers ii–iii).
///
/// D6 §8.2 examples that do NOT map to app code (documented, not invented):
/// - "combining mode offers taqdim only": the app has NO combining mode.
///   Travel mode is a qasr-only display preference (see TravelService) and
///   never changes computation. No test is fabricated for a feature that
///   does not exist.
/// - "no adhan before its computed legal beginning (first-adhan
///   last-sixth-of-night exception)": the app has no first-adhan feature;
///   notification scheduling consumes the computed times directly.
/// - The Mauritanian ministry methodology and the "Maliki — Mauritanian
///   Scholarly Profile" remain investigative-only (D6 §5.2) and must not
///   appear as selectable profiles — pinned by the profile-list test below.

PrayerTimes _day({
  double lat = 18.0858,
  double lon = -15.9785,
  PrayerProfile profile = PrayerProfiles.malikiMwlWestAfrica,
}) {
  final result = calculatePrayerTimes(
    coordinates: Coordinates(lat, lon),
    date: DateTime.utc(2026, 10, 16),
    timeZoneOffset: Duration.zero,
    profile: profile,
  );
  return (result as PrayerTimesComputed).times;
}

void main() {
  group('Fiqh regression: Asr first mithl (t=1)', () {
    test('default profile pins Asr factor 1 — Khalil «بِغَيْرِ ظِلِّ الزَّوَالِ»',
        () {
      // Legal source: Mukhtasar Khalil «لِآخِرِ الْقَامَةِ بِغَيْرِ ظِلِّ
      // الزَّوَالِ»; Risala «بعد ظل نصف النهار»; corroborated across all six
      // classical texts (D1 Strand A, key answer i). Interpretation: Asr
      // begins when the shadow grown SINCE TRANSIT equals one object-height;
      // the noon (zawal) shadow is EXCLUDED. Expected: the profile encodes
      // t=1 and the engine solves α = atan(1/(1 + tan(|φ−δ|))) (D5 §3.4).
      expect(PrayerProfiles.defaultProfile.asrShadowFactor, 1.0);
      expect(PrayerProfiles.defaultProfile.id, 'maliki-mwl-west-africa');
    });

    test('no shipped profile uses t=2 (Hanafi comparison factor)', () {
      // asrShadowFactor 2 exists only as a labeled non-Maliki comparison
      // (D6 §5.1); shipping a t=2 default would mislabel the Maliki rule.
      for (final p in PrayerProfiles.all) {
        expect(p.asrShadowFactor, 1.0,
            reason: 'Profile ${p.id} changed Asr factor — the Maliki '
                'first-mithl mapping (Khalil) broke.');
      }
    });

    test('Asr t=1 strictly precedes t=2 at all probed latitudes', () {
      // D5 §3.8 gate #4. If a refactor ever made the t=2 event earlier or
      // equal, the shadow-rule encoding changed.
      for (final (lat, lon) in [
        (18.0858, -15.9785), // Nouakchott
        (34.02, -5.0), // Fez
        (-0.18, -78.47), // Quito (equator)
        (-33.92, 18.42), // Cape Town (southern)
      ]) {
        final t1 = _day(lat: lat, lon: lon);
        final t2result = calculatePrayerTimes(
          coordinates: Coordinates(lat, lon),
          date: DateTime.utc(2026, 10, 16),
          timeZoneOffset: Duration.zero,
          profile: const PrayerProfile(
            id: 't2-probe',
            name: 't=2 probe',
            basis: 'Comparison only.',
            fajrAngle: 18.0,
            ishaAngle: 17.0,
            asrShadowFactor: 2.0,
            solarDepression: 0.833,
            dhuhrIhtiyatMinutes: 0,
            maghribIhtiyatMinutes: 0,
          ),
        ) as PrayerTimesComputed;
        expect(t1.asr.isBefore(t2result.times.asr), isTrue,
            reason: 'Asr t=1 must precede t=2 at ($lat, $lon).');
      }
    });

    test('methodology keeps the first-mithl definition text', () {
      // The "Why this time?" / methodology row must keep attributing Asr to
      // the first mithl with the zawal shadow excluded — if the wording
      // drifts to a generic "mid-afternoon", the fiqh mapping is obscured.
      final row = methodologyText('en', 'asr-start');
      expect(row.parameter.toLowerCase(), contains('mithl'));
      expect(row.value.toLowerCase(), contains('zawal'));
      expect(row.detail, contains('t = 1'));
    });
  });

  group('Fiqh regression: Isha from the red twilight', () {
    test('methodology keeps red-shafaq, never white, as the Maliki sign',
        () {
      // Legal source: Risala 8.5b «ولا ينظر إلى البياض»; Khalil «مِنْ
      // غُرُوبِ حُمْرَةِ الشَّفَقِ» (D1 Strand A, key answer iii).
      // Interpretation: the DEGREES (17°) are the institutional convention;
      // the RED twilight is the fiqh-verified Maliki position. A future
      // edit must never present white-twilight disappearance as Maliki.
      final row = methodologyText('en', 'isha-sign');
      expect(row.parameter.toLowerCase(), contains('red'));
      expect(row.value.toLowerCase(), contains('whiteness'));
      expect(row.detail.toLowerCase(), contains('redness'));
    });

    test('Isha angle row labels the degrees a proxy, not the ruling', () {
      final row = methodologyText('en', 'isha-angle');
      expect(row.detail.toLowerCase(), contains('not the ruling'),
          reason: 'D6 §4.1 — the 17° angle must stay labeled a convention '
              'approximating red-twilight disappearance.');
    });
  });

  group('Fiqh regression: Fajr angle is a convention, not a ruling', () {
    test('methodology keeps the 18°-as-institutional-estimate wording', () {
      // D5 §6.1: no classical text gives an angle; 18° = MWL 1986 decision.
      final row = methodologyText('en', 'fajr-angle');
      expect(row.detail, contains('NOT a Maliki ruling'));
      expect(row.value, contains('1986'));
    });
  });

  group('Fiqh regression: Maghrib mashhur narrow window', () {
    test('minority qawl noted but NOT computed until scholars rule', () {
      // Aqrab «بِقَدْرِ فِعْلِهَا بَعْدَ شُرُوطِهَا» (mashhur, narrow);
      // al-Baji's extension to red-twilight disappearance is a recognized
      // disagreement (D4 §6.1). Interpretation: the app shows the mashhur
      // band and NOTES the minority qawl — it must never silently compute
      // the extension as the default.
      final row = methodologyText('en', 'maghrib-mukhtar');
      expect(row.parameter.toLowerCase(), contains('mashhur'));
      expect(row.detail.toLowerCase(), contains('minority'));
      expect(row.detail.toLowerCase(), contains('not computed'));
    });

    test('Maghrib band is informational — anchored on raw sunset', () {
      // The ~15–20 min quantification is a modern explanatory gloss
      // (malikifiqhqa.com), not matn (D6 §5.3); the band must never become
      // an adhan time. Engine rule E-04: anchored on the RAW solar sunset.
      final t = _day();
      final bands = malikiPrayerBands(t);
      final maghrib = bands.firstWhere((b) => b.prayerName == 'Maghrib');
      expect(maghrib.ikhtiyariIsComputed, isFalse,
          reason: 'Maghrib mukhtar band must stay informational, never a '
              'computed adhan time.');
      expect(t.maghribPreferredEnd.difference(t.sunset).inMinutes, 20,
          reason: 'E-04 — band is raw sunset + 20 min, never stacked on '
              'the ihtiyat-shifted Maghrib.');
    });
  });

  group('Fiqh regression: ikhtiyari/daruri two-tier bands', () {
    test('isfar and isfirar stay informational, never clock times', () {
      // D4 §7e / D6 §4.1: no fiqh source gives isfar or isfirar as a clock
      // offset. Subh ikhtiyari ends at isfar; Asr ikhtiyari ends at
      // isfirar — both informational bands.
      final t = _day();
      final bands = malikiPrayerBands(t);
      final subh = bands.firstWhere((b) => b.prayerName == 'Subh');
      final asr = bands.firstWhere((b) => b.prayerName == 'Asr');
      expect(subh.ikhtiyariIsComputed, isFalse,
          reason: 'isfar has no clock-time treatment (D4 §7e).');
      expect(asr.ikhtiyariIsComputed, isFalse,
          reason: 'isfirar has no clock-time treatment (D4 §7e).');
      expect(subh.daruriIsComputed, isTrue,
          reason: 'Subh daruri ends at sunrise (Khalil) — computed.');
      expect(subh.daruriText, contains('sunrise'));
    });

    test('Isha ikhtiyari default is first-third of night; Ibn Habib '
        'midnight stays a labeled alternative', () {
      // Aqrab «لِلثُّلُثِ الْأَوَّل» (default); Ibn Habib midnight is the
      // recognized disagreement (D4 §6.2) — selectable as labeled text,
      // never the default adhan boundary.
      final t = _day();
      final bands = malikiPrayerBands(t);
      final isha = bands.firstWhere((b) => b.prayerName == 'Isha');
      expect(isha.ikhtiyariIsComputed, isTrue);
      expect(isha.ikhtiyariText, contains('first third'));
      expect(isha.ikhtiyariText, contains('Ibn Habib'),
          reason: 'The midnight alternative must stay labeled as the Ibn '
              'Habib view, never silently become the default.');
      expect(t.ishaPreferredEnd.isAfter(t.isha), isTrue);
    });

    test('Dhuhr starts at transit + ihtiyat only — offset stays a '
        'convention, not fiqh', () {
      // Risala 8.2a / Khalil «مِنْ زَوَالِ الشَّمْسِ»; the +1–2 min is
      // precaution, not part of the definition (D6 §4.1).
      final row = methodologyText('en', 'ihtiyat');
      expect(row.detail.toLowerCase(), contains('not part of the fiqh'));
      final t = _day();
      expect(t.dhuhr.difference(t.sunrise).inMinutes,
          greaterThan(60 * 4), // sanity: transit well after sunrise
          reason: 'Dhuhr is a transit-derived time.');
    });
  });

  group('Fiqh regression: profiles carry honest labels', () {
    test('Habous 19/17 stays labeled institutional, never a fiqh ruling',
        () {
      // D6 §5.3: closest Maliki-majority institutional preset; methodology
      // unpublished (D1 negative finding). If the basis text ever drops the
      // institutional labeling, the convention-vs-ruling boundary broke.
      final p = PrayerProfiles.malikiMoroccoHabous;
      expect(p.fajrAngle, 19.0);
      expect(p.ishaAngle, 17.0);
      expect(p.asrShadowFactor, 1.0,
          reason: 'Habous is a Maliki-majority preset: Asr stays t=1.');
      expect(p.basis, contains('NOT a fiqh ruling'));
    });

    test('default profile keeps the Maliki MWL West Africa identity', () {
      final p = PrayerProfiles.defaultProfile;
      expect(p.id, 'maliki-mwl-west-africa');
      expect(p.fajrAngle, 18.0);
      expect(p.ishaAngle, 17.0);
      expect(p.basis.toLowerCase(), contains('convention'));
      expect(p.basis.toLowerCase(), contains('not fiqh rulings'));
    });

    test('Mauritanian investigative profile is not a selectable profile',
        () {
      // D6 §5.2: investigation only — parameters unverified, must not
      // appear in the app's selectable profiles.
      final ids = PrayerProfiles.all.map((p) => p.id);
      expect(ids, isNot(contains('maliki-mauritanian')));
      expect(ids, isNot(contains('mauritanian-scholarly')));
    });
  });

  group('Fiqh regression: no silent fallbacks', () {
    test('high-latitude fallback is always flagged with a named method',
        () {
      // D5 §3.7 / D6 §3.4: every substitution is a labeled convention;
      // silent substitution is a release-blocking defect.
      final result = calculatePrayerTimes(
        coordinates: const Coordinates(69.65, 18.96),
        date: DateTime.utc(2026, 5, 15),
        timeZoneOffset: const Duration(hours: 2),
        fallback: HighLatitudeFallback.oneSeventhOfNight,
      ) as PrayerTimesComputed;
      expect(result.times.highLatitudeFallback, isTrue);
      expect(result.times.fallbackMethod,
          HighLatitudeFallback.oneSeventhOfNight);
    });

    test('a no-solution day never fabricates times', () {
      // D5 §3.9 / §5.8.6: NoSolution propagates as a flagged absence.
      final result = calculatePrayerTimes(
        coordinates: const Coordinates(69.65, 18.96),
        date: DateTime.utc(2026, 6, 21),
        timeZoneOffset: const Duration(hours: 2),
      );
      expect(result, isA<PrayerTimesNoSolution>());
    });
  });
}
