import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/main.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/screens/settings_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  group('AppLocalizations delegate', () {
    test('all four ARBs load with non-empty spot-checked keys', () async {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        expect(l10n, isNotNull, reason: 'locale $code');
        expect(l10n.navHome, isNotEmpty, reason: '$code navHome');
        expect(l10n.navMonthly, isNotEmpty, reason: '$code navMonthly');
        expect(l10n.navQibla, isNotEmpty, reason: '$code navQibla');
        expect(l10n.navProfiles, isNotEmpty, reason: '$code navProfiles');
        expect(l10n.navSettings, isNotEmpty, reason: '$code navSettings');
        // Placeholders must survive formatting in every locale.
        final inText = l10n.nextPrayerIn('X', '01:02:03');
        expect(inText, contains('X'), reason: '$code nextPrayerIn prayer');
        expect(inText, contains('01:02:03'),
            reason: '$code nextPrayerIn countdown');
        final angles = l10n.profileAngles('18.0', '17.0', '1.0');
        expect(angles, contains('18.0'), reason: '$code profileAngles');
      }
    });

    test('supportedLocales covers en, ur, ar, fr', () {
      final codes =
          AppLocalizations.supportedLocales.map((l) => l.languageCode);
      expect(codes, containsAll(['en', 'ur', 'ar', 'fr']));
    });

    test('no "verified/endorsed/approved" strings in any locale', () async {
      final banned = ['verified', 'endorsed', 'approved'];
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        for (final s in [
          l10n.calculationProfile,
          l10n.compareFootnote,
        ]) {
          for (final word in banned) {
            expect(s.toLowerCase(), isNot(contains(word)),
                reason: '$code contains "$word": $s');
          }
        }
      }
    });

    test('no pending-review labels in any locale', () async {
      // User directive: no "PROPOSED — pending scholarly review" text
      // anywhere in the UI, in any language.
      final banned = [
        'propos', // proposed / PROPOSED / proposé
        'pending scholarly review',
        'no scholar has reviewed',
        'examen par des savants',
        'révision savante',
        'مجوزہ',
        'مقترح',
        'بانتظار المراجعة',
        'المراجعة العلمية',
        'علمی جائزے',
        'علمی جائزہ',
        'شرعی توثیق',
      ];
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        for (final s in [
          l10n.calculationProfile,
          l10n.compareFootnote,
          l10n.aboutProfileText,
          l10n.aboutAppBody,
          l10n.footerNote,
        ]) {
          for (final word in banned) {
            expect(s.toLowerCase(), isNot(contains(word)),
                reason: '$code contains "$word": $s');
          }
        }
      }
    });
  });

  group('SettingsService.languageCode', () {
    test('defaults to null (system default)', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();
      expect(s.languageCode, isNull);
    });

    test('setLanguageCode persists and reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      await s.setLanguageCode('ur');
      expect(s.languageCode, 'ur');

      final reloaded = await SettingsService.load();
      expect(reloaded.languageCode, 'ur');

      // Back to system default removes the stored key.
      await s.setLanguageCode(null);
      expect(s.languageCode, isNull);
      final reloaded2 = await SettingsService.load();
      expect(reloaded2.languageCode, isNull);
    });

    test('unknown language codes are ignored', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      await s.setLanguageCode('xx');
      expect(s.languageCode, isNull);

      await s.setLanguageCode('ar');
      await s.setLanguageCode('xx');
      expect(s.languageCode, 'ar');
    });

    test('corrupt stored language code falls back to null', () async {
      SharedPreferences.setMockInitialValues({'language_code': 'bogus'});
      final s = await SettingsService.load();
      expect(s.languageCode, isNull);
    });
  });

  group('AppFonts', () {
    test('forLocale documents the fallback chain', () {
      // Bundled Nafees Nastaleeq for Urdu (CRULP, redistribution permitted —
      // see ATTRIBUTION.md).
      expect(AppFonts.forLocale(const Locale('ur')), 'Nafees Nastaleeq');
      expect(AppFonts.forLocale(const Locale('ar')), 'Amiri');
      expect(AppFonts.forLocale(const Locale('en')), isNull);
      expect(AppFonts.forLocale(const Locale('fr')), isNull);
      expect(AppFonts.forLocale(null), isNull);
    });

    test('themeFor applies the locale font without changing the design', () {
      final ur = AppFonts.themeFor(const Locale('ur'), seedColor: Colors.teal);
      expect(ur.textTheme.bodyLarge?.fontFamily, 'Nafees Nastaleeq');
      expect(ur.useMaterial3, isTrue);
      final en = AppFonts.themeFor(const Locale('en'), seedColor: Colors.teal);
      // No override → the Material default font (documented fallback chain).
      expect(en.textTheme.bodyLarge?.fontFamily, isNot('Nafees Nastaleeq'));
      // Same seed color → same color scheme regardless of locale.
      expect(ur.colorScheme.primary, en.colorScheme.primary);
    });
  });

  group('screen smoke test under every locale', () {
    testWidgets('all five tabs build without missing-key exceptions',
        (tester) async {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        SharedPreferences.setMockInitialValues({
          'saved_location': jsonEncode({
            'name': 'Nouakchott',
            'latitude': 18.0858,
            'longitude': -15.9785,
            'isDevice': false,
          }),
        });
        final settings = await SettingsService.load();
        final location = await LocationService.load();
        // Exercise the real locale path: saved language → MaterialApp.locale.
        await settings.setLanguageCode(code);

        await tester.pumpWidget(
            MalikiPrayerTimesApp(settings: settings, location: location));
        await tester.pump();

        // Back to the home tab: pumpWidget reuses the element tree across
        // loop iterations, so the tab index may be stale.
        await tester.tap(find.byIcon(Icons.house));
        await tester.pump();

        // Home tab (index 0) renders the timetable with a location set.
        // Arabic uses Arabic-Indic digits; Urdu and others use Western.
        final digitClass = code == 'ar' ? r'[٠-٩]' : r'\d';
        expect(
            find.textContaining(
                RegExp('$digitClass$digitClass:$digitClass$digitClass')),
            findsWidgets,
            reason: '$code home timetable');

        // Walk the remaining tabs.
        for (final icon in [
          Icons.calendar_month,
          Icons.explore,
          Icons.tune,
          Icons.settings,
        ]) {
          await tester.tap(find.byIcon(icon));
          await tester.pump();
        }

        // Spot-check localized content on the last (settings) tab. The
        // title also labels the bottom-nav item, so it appears twice.
        final l10n =
            await AppLocalizations.delegate.load(Locale(code));
        expect(find.text(l10n.settingsTitle), findsWidgets,
            reason: '$code settings title');
      }
    });

    testWidgets('location screen builds under every locale', (tester) async {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        SharedPreferences.setMockInitialValues({});
        final location = await LocationService.load();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(code),
            localizationsDelegates: _delegates,
            supportedLocales: _supportedLocales,
            home: LocationScreen(locationService: location),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // Screen builds without missing-key exceptions under every locale.
        expect(tester.takeException(), isNull,
            reason: '$code location screen build');
        final l10n =
            await AppLocalizations.delegate.load(Locale(code));
        // The device-location button is below the fold in the lazy
        // ListView: scroll it into view first.
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -2000));
        await tester.pump();
        expect(find.text(l10n.useDeviceLocation), findsOneWidget,
            reason: '$code device location button');
      }
    });
  });

  group('arabic locale: no doubled prayer names', () {
    testWidgets('home screen never renders "X X" name pairs in ar',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_location': jsonEncode({
          'name': 'Nouakchott',
          'latitude': 18.0858,
          'longitude': -15.9785,
          'isDevice': false,
        }),
      });
      final settings = await SettingsService.load();
      final location = await LocationService.load();
      await settings.setLanguageCode('ar');

      await tester.pumpWidget(
          MalikiPrayerTimesApp(settings: settings, location: location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll through the whole home screen so lazily-built rows enter
      // the tree, collecting every text fragment.
      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
        seen.addAll(texts);
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -800));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Arabic prayer/band names must never appear doubled ("العصر العصر").
      const arabicNames = [
        'الفجر',
        'الشروق',
        'الظهر',
        'العصر',
        'المغرب',
        'العشاء',
        'الصبح',
      ];
      for (final text in seen) {
        for (final name in arabicNames) {
          expect(text.contains('$name $name'), isFalse,
              reason: 'doubled name "$name" in: "$text"');
          expect(text.contains('$name  $name'), isFalse,
              reason: 'doubled name "$name" in: "$text"');
        }
      }
      expect(seen.any((t) => t.contains('العصر')), isTrue,
          reason: 'sanity: Arabic prayer names are rendered');
    });
  });

  group('urdu locale: no doubled prayer names', () {
    testWidgets('home screen shows each Urdu prayer name once (no Arabic pair)',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_location': jsonEncode({
          'name': 'Nouakchott',
          'latitude': 18.0858,
          'longitude': -15.9785,
          'isDevice': false,
        }),
      });
      final settings = await SettingsService.load();
      final location = await LocationService.load();
      await settings.setLanguageCode('ur');

      await tester.pumpWidget(
          MalikiPrayerTimesApp(settings: settings, location: location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll through the whole home screen so lazily-built rows enter
      // the tree, collecting every text fragment.
      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
        seen.addAll(texts);
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -800));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Urdu name + Arabic companion must never read as a doubled name
      // ("فجر الفجر"); the Urdu locale omits the companion entirely.
      const urduPairs = [
        'فجر الفجر',
        'ظہر الظهر',
        'عصر العصر',
        'مغرب المغرب',
        'عشاء العشاء',
        'صبح الصبح',
      ];
      for (final text in seen) {
        for (final pair in urduPairs) {
          expect(text.contains(pair), isFalse,
              reason: 'doubled name "$pair" in: "$text"');
        }
      }
      expect(seen.any((t) => t.contains('فجر')), isTrue,
          reason: 'sanity: Urdu prayer names are rendered');
    });

    testWidgets('english locale still shows the transliteration + Arabic pair',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_location': jsonEncode({
          'name': 'Nouakchott',
          'latitude': 18.0858,
          'longitude': -15.9785,
          'isDevice': false,
        }),
      });
      final settings = await SettingsService.load();
      final location = await LocationService.load();
      await settings.setLanguageCode('en');

      await tester.pumpWidget(
          MalikiPrayerTimesApp(settings: settings, location: location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
        seen.addAll(texts);
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -800));
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Timetable rows render the pair as one string ("Asr  العصر"); the
      // hero renders them as sibling Texts. Either form proves en keeps
      // the transliteration + Arabic pair.
      final pairPattern = RegExp(r'^(Fajr|Dhuhr|Asr|Maghrib|Isha)  ');
      final hasRowPair = seen.any((t) =>
          pairPattern.hasMatch(t) &&
          ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']
              .any(t.contains));
      final hasHeroLabel =
          seen.any((t) => ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].contains(t));
      final hasHeroArabic = seen.any((t) =>
          ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'].contains(t.trim()));
      expect(hasRowPair || (hasHeroLabel && hasHeroArabic), isTrue,
          reason: 'sanity: en keeps the transliteration + Arabic pair');
    });
  });

  group('urdu locale: coordinates render in the Latin font', () {
    testWidgets('home header coords use Manrope so "." never misrenders',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_location': jsonEncode({
          'name': 'Device location',
          'latitude': 30.44180,
          'longitude': 73.75350,
          'isDevice': true,
        }),
      });
      final settings = await SettingsService.load();
      final location = await LocationService.load();
      await settings.setLanguageCode('ur');

      await tester.pumpWidget(
          MalikiPrayerTimesApp(settings: settings, location: location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final coordsTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.data ?? '').contains('30.44180'))
          .toList();
      expect(coordsTexts, isNotEmpty,
          reason: 'sanity: the coordinate line is rendered');
      for (final t in coordsTexts) {
        expect(t.data, contains('.'),
            reason: 'raw coordinate string keeps the decimal point');
        expect(t.style?.fontFamily, 'Manrope',
            reason: 'coords pinned to the Latin font in Urdu UI');
      }
    });
  });

  group('preset locations', () {
    testWidgets('tapping Cordoba saves its exact coordinates', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final location = await LocationService.load();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: LocationScreen(locationService: location),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll the preset into view (ListView lazily builds its window).
      // Small steps: the page is long, so large jumps can overshoot the
      // preset and scroll it out of the built window again.
      final presetFinder = find.text('Cordoba (Great Mosque)');
      for (var i = 0; i < 12 && presetFinder.evaluate().isEmpty; i++) {
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(presetFinder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(presetFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The service must hold the preset's EXACT coordinates.
      final current = location.current;
      expect(current, isNotNull, reason: 'preset saved a location');
      expect(current!.name, 'Cordoba (Great Mosque)');
      expect(current.latitude, 37.879, reason: 'exact preset latitude');
      expect(current.longitude, -4.779, reason: 'exact preset longitude');
      expect(current.isDevice, isFalse);
      // Phase 2: presets carry their IANA zone so times render in the
      // city's wall clock, not the device's.
      expect(current.timeZoneId, 'Europe/Madrid',
          reason: 'preset IANA zone id');
    });
  });

  group('settings adjustments section', () {
    testWidgets('explanation appears once at section level, not per card',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));

      // Tall viewport so every adjustment card builds at once.
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: SettingsScreen(
            settings: settings,
            coordinates: const Coordinates(24.86, 67.0),
            timeZoneOffset: const Duration(hours: 5),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The explanation lives exactly once, above the cards.
      expect(find.text(l10n.adjustmentsSectionNote), findsOneWidget,
          reason: 'section-level note present exactly once');
      // The old per-prayer paragraph ("Moves the displayed Fajr time …")
      // must not appear on any card.
      for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(
            find.textContaining('Moves the displayed $prayer time'),
            findsNothing,
            reason: 'no per-card explanation for $prayer');
      }
    });
  });

  group('settings about sections', () {
    testWidgets('about app + developer sections render; profile card removed',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));

      // Tall viewport so every section builds at once.
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: SettingsScreen(
            settings: settings,
            coordinates: const Coordinates(24.86, 67.0),
            timeZoneOffset: const Duration(hours: 5),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.aboutAppSection.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.aboutAppBody), findsOneWidget);
      expect(
          find.text(l10n.aboutDeveloperSection.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.aboutDeveloperName), findsOneWidget);
      expect(find.textContaining('muhaqqiqcreates@gmail.com'), findsOneWidget);
      // Version is single-sourced from the app-info const.
      expect(find.text(l10n.appVersion(kAppVersion)), findsOneWidget);
      // The redundant profile card (and its section header) are gone.
      expect(find.text('Calculation profile'), findsNothing);
    });
  });

  group('no pending-review labels in the UI', () {
    testWidgets('profiles screen shows no PROPOSED banner', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: ProfilesScreen(
            settings: settings,
            coordinates: const Coordinates(24.86, 67.0),
            timeZoneOffset: const Duration(hours: 5),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining(RegExp('proposed', caseSensitive: false)),
          findsNothing,
          reason: 'no PROPOSED banner on the profiles screen');
      expect(
          find.textContaining(
              RegExp('pending scholarly review', caseSensitive: false)),
          findsNothing,
          reason: 'no pending-review sentence on the profiles screen');
    });

    testWidgets('home profile card shows no PROPOSED badge', (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_location': jsonEncode({
          'name': 'Nouakchott',
          'latitude': 18.0858,
          'longitude': -15.9785,
          'isDevice': false,
        }),
      });
      final settings = await SettingsService.load();
      final location = await LocationService.load();
      await settings.setLanguageCode('en');

      // Tall viewport so the profile card (below the fold) builds at once.
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
          MalikiPrayerTimesApp(settings: settings, location: location));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.house));
      await tester.pump();

      expect(find.textContaining(RegExp('proposed', caseSensitive: false)),
          findsNothing,
          reason: 'no PROPOSED badge on the home profile card');
      // The card itself (title + active profile name) still renders.
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.calculationProfile), findsOneWidget,
          reason: 'profile card title still present');
    });
  });
}
