import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/high_latitude.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/screens/home_screen.dart';
import 'package:malikiprayertimes/screens/monthly_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 5 tests: the high-latitude fallback chooser and typed no-solution
/// semantics.
///
/// Reference vectors: D5 §4.3 (Tromsø 69.65°N, 18.96°E):
/// - c1: 2026-06-21 polar day — Fajr cosH = −2.1374, sunrise/sunset no
///   solution → typed NoSolution.
/// - c2: 2026-05-15 persistent twilight — sunset 23:43 → sunrise 01:37
///   (CEST), N = 113.8 min; middleOfNight 00:40/00:40, oneSeventh
///   01:21/23:59, angleBased(15°) 01:08/00:12. All are conventions, never
///   Maliki rulings.

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _supportedLocales = [
  Locale('en'),
  Locale('ur'),
  Locale('ar'),
  Locale('fr'),
];

const _tromso = Coordinates(69.6496, 18.9560);
const _cest = Duration(hours: 2);

PrayerTimesResult _raw(
  double lat,
  double lon,
  DateTime date,
  Duration offset, {
  HighLatitudeFallback fallback = HighLatitudeFallback.middleOfNight,
  PrayerProfile? profile,
}) =>
    calculatePrayerTimes(
      coordinates: Coordinates(lat, lon),
      date: date,
      timeZoneOffset: offset,
      profile: profile ?? PrayerProfiles.defaultProfile,
      fallback: fallback,
    );

PrayerTimes _computed(
  double lat,
  double lon,
  DateTime date,
  Duration offset, {
  HighLatitudeFallback fallback = HighLatitudeFallback.middleOfNight,
  PrayerProfile? profile,
}) =>
    (_raw(lat, lon, date, offset, fallback: fallback, profile: profile)
            as PrayerTimesComputed)
        .times;

/// Minutes between a wall-clock [time] and an HH:MM expectation.
int _deltaMinutes(DateTime time, int hour, int minute) =>
    (time.hour * 60 + time.minute - (hour * 60 + minute)).abs();

/// A profile with 15°/15° twilight angles, matching D5's angleBased(15°)
/// worked example (max solar depression at Tromsø on 2026-05-15 is ≈
/// −8–9°, so even 15° has no solution and the fallback engages).
PrayerProfile _fifteenDegreeProfile() {
  const base = PrayerProfiles.malikiMwlWestAfrica;
  return PrayerProfile(
    id: 'test-fifteen-degree',
    name: 'test 15/15',
    basis: 'test-only profile reproducing the D5 angleBased(15°) vector',
    fajrAngle: 15.0,
    ishaAngle: 15.0,
    asrShadowFactor: base.asrShadowFactor,
    solarDepression: base.solarDepression,
    dhuhrIhtiyatMinutes: 0,
    maghribIhtiyatMinutes: 0,
  );
}

void main() {
  group('typed no-solution (never fabricated times)', () {
    test('Tromsø 2026-06-21 (polar day) is a typed NoSolution', () {
      final r = _raw(
          _tromso.latitude, _tromso.longitude, DateTime(2026, 6, 21), _cest);
      // The assertion is on the TYPE: no DateTime is produced at all.
      expect(r, isA<PrayerTimesNoSolution>());
      expect(r, isNot(isA<PrayerTimesComputed>()));
      expect((r as PrayerTimesNoSolution).reason, NoSolutionReason.polarDay);
    });

    test('Tromsø 2026-12-21 (polar night) is a typed NoSolution', () {
      final r = _raw(
          _tromso.latitude, _tromso.longitude, DateTime(2026, 12, 21), _cest);
      expect(r, isA<PrayerTimesNoSolution>());
      expect((r as PrayerTimesNoSolution).reason, NoSolutionReason.polarNight);
    });

    test('no-solution holds for every non-nearest-day method', () {
      for (final m in [
        HighLatitudeFallback.middleOfNight,
        HighLatitudeFallback.oneSeventhOfNight,
        HighLatitudeFallback.angleBased,
      ]) {
        final r = _raw(_tromso.latitude, _tromso.longitude,
            DateTime(2026, 6, 21), _cest,
            fallback: m);
        expect(r, isA<PrayerTimesNoSolution>(),
            reason: '$m must not fabricate times on a polar day');
      }
    });
  });

  group('persistent-twilight fallback math (D5 §4.3 c2 vectors)', () {
    final date = DateTime(2026, 5, 15);
    const lat = 69.6496;
    const lon = 18.9560;

    // TOLERANCE NOTE on the D5 comparisons below: the residual (≤ 6 min)
    // is the engine's solar-position model, NOT the fallback math. The
    // engine evaluates δ/eot at 0h UTC (δ = 18.8179° on this date) while
    // D5's reference script evaluates full Meeus ch.25 at noon UTC
    // (δ = 18.9386°) — near the solstice at 69.65°N the sun's path is
    // nearly horizontal, so 0.12° of declination moves sunrise/sunset by
    // ~6 min. The fallback FORMULAS are exact against the engine's own
    // night frame — asserted precisely in 'D5 formulas hold exactly'.
    test('middleOfNight → D5 00:40 / 00:40', () {
      final t = _computed(lat, lon, date, _cest);
      expect(t.highLatitudeFallback, isTrue);
      expect(t.fallbackMethod, HighLatitudeFallback.middleOfNight);
      expect(_deltaMinutes(t.fajr, 0, 40), lessThanOrEqualTo(6),
          reason: 'D5 documents fajr 00:40, got ${t.fajr}');
      expect(_deltaMinutes(t.isha, 0, 40), lessThanOrEqualTo(6),
          reason: 'D5 documents isha 00:40, got ${t.isha}');
    });

    test('oneSeventhOfNight → D5 01:21 / 23:59', () {
      final t = _computed(lat, lon, date, _cest,
          fallback: HighLatitudeFallback.oneSeventhOfNight);
      expect(t.fallbackMethod, HighLatitudeFallback.oneSeventhOfNight);
      expect(_deltaMinutes(t.fajr, 1, 21), lessThanOrEqualTo(6),
          reason: 'D5 documents fajr 01:21, got ${t.fajr}');
      expect(_deltaMinutes(t.isha, 23, 59), lessThanOrEqualTo(6),
          reason: 'D5 documents isha 23:59, got ${t.isha}');
    });

    test('angleBased(15°) → D5 01:08 / 00:12', () {
      final t = _computed(lat, lon, date, _cest,
          fallback: HighLatitudeFallback.angleBased,
          profile: _fifteenDegreeProfile());
      expect(t.fallbackMethod, HighLatitudeFallback.angleBased);
      expect(_deltaMinutes(t.fajr, 1, 8), lessThanOrEqualTo(6),
          reason: 'D5 documents fajr 01:08, got ${t.fajr}');
      expect(_deltaMinutes(t.isha, 0, 12), lessThanOrEqualTo(6),
          reason: 'D5 documents isha 00:12, got ${t.isha}');
    });

    test('D5 formulas hold exactly against the engine night frame', () {
      // The real night frame around the fallback day: 05-14 sunset →
      // 05-15 sunrise → 05-16 sunrise (all genuine events).
      final prev = _computed(lat, lon, DateTime(2026, 5, 14), _cest);
      final next = _computed(lat, lon, DateTime(2026, 5, 16), _cest);
      final mid = _computed(lat, lon, date, _cest);
      final seventh = _computed(lat, lon, date, _cest,
          fallback: HighLatitudeFallback.oneSeventhOfNight);
      final angled = _computed(lat, lon, date, _cest,
          fallback: HighLatitudeFallback.angleBased,
          profile: _fifteenDegreeProfile());

      int nightFajrMin() => mid.sunrise.difference(prev.sunset).inMinutes;
      int nightIshaMin() => next.sunrise.difference(mid.sunset).inMinutes;

      // middleOfNight: fajr = sunrise − N/2, isha = sunset + N/2.
      final midFajrExpect = mid.sunrise
          .subtract(Duration(minutes: (nightFajrMin() / 2).round()));
      final midIshaExpect =
          mid.sunset.add(Duration(minutes: (nightIshaMin() / 2).round()));
      expect(mid.fajr.difference(midFajrExpect).inMinutes.abs(),
          lessThanOrEqualTo(1),
          reason: 'fajr must be the night midpoint');
      expect(mid.isha.difference(midIshaExpect).inMinutes.abs(),
          lessThanOrEqualTo(1),
          reason: 'isha must be the night midpoint');

      // oneSeventh: fajr = sunrise − N/7, isha = sunset + N/7.
      final sevFajrExpect = seventh.sunrise
          .subtract(Duration(minutes: (nightFajrMin() / 7).round()));
      final sevIshaExpect =
          seventh.sunset.add(Duration(minutes: (nightIshaMin() / 7).round()));
      expect(seventh.fajr.difference(sevFajrExpect).inMinutes.abs(),
          lessThanOrEqualTo(1));
      expect(seventh.isha.difference(sevIshaExpect).inMinutes.abs(),
          lessThanOrEqualTo(1));

      // angleBased(15°): fraction = 15/60 of the night from each end.
      final angFajrExpect = angled.sunrise.subtract(
          Duration(minutes: ((15 / 60) * nightFajrMin()).round()));
      final angIshaExpect = angled.sunset
          .add(Duration(minutes: ((15 / 60) * nightIshaMin()).round()));
      expect(angled.fajr.difference(angFajrExpect).inMinutes.abs(),
          lessThanOrEqualTo(1));
      expect(angled.isha.difference(angIshaExpect).inMinutes.abs(),
          lessThanOrEqualTo(1));
    });

    test('ordering invariant holds on every fallback method', () {
      for (final m in HighLatitudeFallback.values) {
        final r = _raw(_tromso.latitude, _tromso.longitude, date, _cest,
            fallback: m,
            profile: m == HighLatitudeFallback.angleBased
                ? _fifteenDegreeProfile()
                : null);
        final t = (r as PrayerTimesComputed).times;
        expect(t.fajr.isBefore(t.sunrise), isTrue, reason: '$m fajr < sunrise');
        expect(t.sunrise.isBefore(t.dhuhr), isTrue);
        expect(t.dhuhr.isBefore(t.asr), isTrue);
        expect(t.asr.isBefore(t.maghrib), isTrue);
        expect(t.maghrib.isBefore(t.isha), isTrue, reason: '$m maghrib < isha');
      }
    });

    test('nearestDay borrows a labeled, fully-solved day', () {
      final r = _raw(_tromso.latitude, _tromso.longitude, date, _cest,
          fallback: HighLatitudeFallback.nearestDay);
      expect(r, isA<PrayerTimesComputed>());
      final t = (r as PrayerTimesComputed).times;
      expect(t.fallbackMethod, HighLatitudeFallback.nearestDay);
      expect(t.nearestDaySourceDate, isNotNull);
      expect(t.nearestDaySourceDate, isNot(DateTime(2026, 5, 15)));
      // The borrowed day is a genuinely solvable day: recomputing it
      // yields real times, not a no-solution. (Its own fallback flag may
      // still be set by adjacent-day markers — e.g. tomorrow's fajr — but
      // the day itself computes.)
      final src = t.nearestDaySourceDate!;
      final srcResult = _raw(lat, lon, src, _cest);
      expect(srcResult, isA<PrayerTimesComputed>());
    });

    test('nearestDay on a polar day borrows instead of failing', () {
      final r = _raw(_tromso.latitude, _tromso.longitude,
          DateTime(2026, 6, 21), _cest,
          fallback: HighLatitudeFallback.nearestDay);
      expect(r, isA<PrayerTimesComputed>(),
          reason: 'explicit nearest-day choice is honored on polar days');
      final t = (r as PrayerTimesComputed).times;
      expect(t.fallbackMethod, HighLatitudeFallback.nearestDay);
      expect(t.nearestDaySourceDate, isNotNull,
          reason: 'the borrowed date must be recorded for the UI');
    });

    test('switching the method changes the output', () {
      final a = _computed(_tromso.latitude, _tromso.longitude, date, _cest);
      final b = _computed(_tromso.latitude, _tromso.longitude, date, _cest,
          fallback: HighLatitudeFallback.oneSeventhOfNight);
      expect(a.fajr == b.fajr && a.isha == b.isha, isFalse,
          reason: 'the setting must change the computed times');
    });

    test('the default is middle-of-night', () {
      final implicit = _computed(
          _tromso.latitude, _tromso.longitude, date, _cest);
      final explicit = _computed(_tromso.latitude, _tromso.longitude, date,
          _cest,
          fallback: HighLatitudeFallback.middleOfNight);
      expect(implicit.fajr, explicit.fajr);
      expect(implicit.isha, explicit.isha);
      expect(implicit.fallbackMethod, HighLatitudeFallback.middleOfNight);
    });

    test('normal days are untouched: no fallback, no method', () {
      final t = _computed(
          18.08581, -15.9785, DateTime(2026, 10, 15), Duration.zero);
      expect(t.highLatitudeFallback, isFalse);
      expect(t.fallbackMethod, isNull);
      expect(t.nearestDaySourceDate, isNull);
    });
  });

  group('fallback preference (SettingsService)', () {
    test('defaults to middle-of-night', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();
      expect(s.highLatitudeFallback, HighLatitudeFallback.middleOfNight);
    });

    test('persists across loads', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();
      await s.setHighLatitudeFallback(HighLatitudeFallback.nearestDay);
      expect(s.highLatitudeFallback, HighLatitudeFallback.nearestDay);
      final reloaded = await SettingsService.load();
      expect(reloaded.highLatitudeFallback, HighLatitudeFallback.nearestDay);
    });

    test('a corrupt stored value falls back to the default', () async {
      SharedPreferences.setMockInitialValues(
          {'high_latitude_fallback': 'not-a-method'});
      final s = await SettingsService.load();
      expect(s.highLatitudeFallback, HighLatitudeFallback.middleOfNight);
    });
  });

  group('home honest states (widget)', () {
    Future<(SettingsService, LocationService)> services() async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final location = await LocationService.load();
      await location.useManualLocation(const SavedLocation(
          name: 'Tromsø', latitude: 69.6496, longitude: 18.9560));
      return (settings, location);
    }

    Widget wrap(Widget home) => MediaQuery(
          data: const MediaQueryData(),
          child: MaterialApp(
            localizationsDelegates: _delegates,
            supportedLocales: _supportedLocales,
            theme: AppFonts.themeFor(const Locale('en'), seedColor: Colors.teal),
            home: home,
          ),
        );

    testWidgets('Tromsø polar day: honest empty state + chooser',
        (tester) async {
      final (settings, location) = await services();
      await tester.pumpWidget(wrap(HomeScreen(
        settings: settings,
        location: location,
        nowForTesting: DateTime(2026, 6, 21, 12, 0),
      )));
      // Home runs a 1-second countdown timer: pump manually instead of
      // pumpAndSettle (which would time out on the periodic timer).
      await tester.pump(const Duration(milliseconds: 200));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Honest empty state — no fabricated times anywhere.
      expect(find.text(l10n.noTimesTitle), findsOneWidget);
      expect(find.text(l10n.noTimesPolarDay), findsOneWidget);
      expect(find.text(l10n.noTimesChooseMethod), findsOneWidget);

      // The chooser lists all four methods, each labeled a convention.
      await tester.tap(find.text(l10n.noTimesChooseMethod));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (final m in HighLatitudeFallback.values) {
        expect(find.text(_methodName(l10n, m)), findsOneWidget);
      }
      expect(find.text(l10n.highLatConventionBadge), findsNWidgets(4));

      // Choosing nearest-day applies the explicit convention: borrowed
      // times appear, named, with the source date.
      await tester.tap(find.text(l10n.highLatMethodNearestDay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.noTimesTitle), findsNothing);
      expect(
          find.text(l10n
              .highLatIndicatorTitle(l10n.highLatMethodNearestDay)),
          findsOneWidget,
          reason: 'the indicator must name the method in effect');
      expect(find.text(l10n.highLatConventionBadge), findsOneWidget);
    });

    testWidgets('fallback indicator names the default method', (tester) async {
      final (settings, location) = await services();
      await tester.pumpWidget(wrap(HomeScreen(
        settings: settings,
        location: location,
        nowForTesting: DateTime(2026, 5, 15, 12, 0),
      )));
      await tester.pump(const Duration(milliseconds: 200));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The default (middle-of-night) is VISIBLE, not silent.
      expect(
          find.text(l10n.highLatIndicatorTitle(
              l10n.highLatMethodMiddleOfNight)),
          findsOneWidget);
      expect(find.text(l10n.highLatConventionBadge), findsOneWidget);

      // The change affordance opens the chooser; picking another method
      // renames the indicator.
      await tester.tap(find.text(l10n.highLatIndicatorAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(l10n.highLatMethodOneSeventh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
          find.text(
              l10n.highLatIndicatorTitle(l10n.highLatMethodOneSeventh)),
          findsOneWidget);
      expect(settings.highLatitudeFallback,
          HighLatitudeFallback.oneSeventhOfNight);
    });
  });

  group('monthly honest states (widget)', () {
    testWidgets('polar month: honest cells and day sheet', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(),
        child: MaterialApp(
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          theme:
              AppFonts.themeFor(const Locale('en'), seedColor: Colors.teal),
          home: MonthlyScreen(
            coordinates: _tromso,
            profile: PrayerProfiles.defaultProfile,
            timeZoneOffset: _cest,
            settings: settings,
            initialMonth: DateTime(2026, 6),
          ),
        ),
      ));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Every June day at Tromsø is a polar day: honest cells, no times.
      expect(find.text(l10n.noTimesCell), findsWidgets);

      // Tapping a day opens the honest sheet with the chooser affordance.
      await tester.tap(find.text(l10n.noTimesCell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.noTimesTitle), findsOneWidget);
      expect(find.text(l10n.noTimesChooseMethod), findsOneWidget);
    });
  });
}

/// Localized display names without depending on the widget helpers.
String _methodName(AppLocalizations l10n, HighLatitudeFallback m) =>
    switch (m) {
      HighLatitudeFallback.middleOfNight => l10n.highLatMethodMiddleOfNight,
      HighLatitudeFallback.oneSeventhOfNight => l10n.highLatMethodOneSeventh,
      HighLatitudeFallback.angleBased => l10n.highLatMethodAngleBased,
      HighLatitudeFallback.nearestDay => l10n.highLatMethodNearestDay,
    };
