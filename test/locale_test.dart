import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/main.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
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
        expect(l10n.proposedStatus, isNotEmpty, reason: '$code proposedStatus');
        expect(l10n.proposedBanner, isNotEmpty, reason: '$code proposedBanner');
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
          l10n.proposedStatus,
          l10n.proposedBanner,
          l10n.calculationProfileProposed,
          l10n.compareFootnote,
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
        await tester.tap(find.byIcon(Icons.home));
        await tester.pump();

        // Home tab (index 0) renders the timetable with a location set.
        expect(find.textContaining(RegExp(r'\d\d:\d\d')), findsWidgets,
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
        final l10n =
            await AppLocalizations.delegate.load(Locale(code));
        expect(find.text(l10n.locationTitle), findsOneWidget,
            reason: '$code location title');
        expect(find.text(l10n.useDeviceLocation), findsOneWidget,
            reason: '$code device location button');
      }
    });
  });
}
