import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/home_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
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

/// Text direction of the ambient [Directionality] at the deepest widget of
/// type [T] in the tree.
TextDirection _directionOf<T>(WidgetTester tester) {
  final element = tester.element(find.byType(T).first);
  return Directionality.of(element);
}

void main() {
  group('RTL directionality', () {
    testWidgets('MaterialApp direction follows the locale', (tester) async {
      for (final entry in {
        'ar': TextDirection.rtl,
        'ur': TextDirection.rtl,
        'en': TextDirection.ltr,
        'fr': TextDirection.ltr,
      }.entries) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(entry.key),
            localizationsDelegates: _delegates,
            supportedLocales: _supportedLocales,
            home: Builder(
              builder: (context) =>
                  Text('${Directionality.of(context)}'),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(entry.value.toString()), findsOneWidget,
            reason: 'locale ${entry.key}');
      }
    });

    testWidgets('home screen is RTL under the Arabic locale', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final location = await LocationService.load();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: HomeScreen(settings: settings, location: location),
        ),
      );
      await tester.pump();

      expect(_directionOf<HomeScreen>(tester), TextDirection.rtl);
      // No location is set, so the localized choose-location prompt shows.
      expect(find.text('اختر موقعك'), findsOneWidget);
      expect(find.text('تحديد الموقع'), findsOneWidget);
    });

    testWidgets('home screen is RTL under the Urdu locale', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final location = await LocationService.load();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ur'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: HomeScreen(settings: settings, location: location),
        ),
      );
      await tester.pump();

      expect(_directionOf<HomeScreen>(tester), TextDirection.rtl);
      expect(find.text('اپنا مقام منتخب کریں'), findsOneWidget);
    });

    testWidgets('home screen is LTR under the French locale', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final location = await LocationService.load();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: HomeScreen(settings: settings, location: location),
        ),
      );
      await tester.pump();

      expect(_directionOf<HomeScreen>(tester), TextDirection.ltr);
      expect(find.text('Choisissez votre lieu'), findsOneWidget);
    });
  });
}
