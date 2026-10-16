import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/widgets/travel_banner.dart';

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

Future<void> _pumpBanner(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: _delegates,
      supportedLocales: _supportedLocales,
      theme: AppFonts.themeFor(locale, seedColor: Colors.teal),
      home: const Scaffold(body: TravelBanner()),
    ),
  );
  await tester.pump();
}

void main() {
  group('TravelBanner', () {
    testWidgets('shows the English banner text', (tester) async {
      await _pumpBanner(tester, const Locale('en'));

      expect(
        find.text('Travel mode: Dhuhr, Asr, Isha are 2 rak\'ahs'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.flight_takeoff_outlined), findsOneWidget);
    });

    testWidgets('banner is localized in Urdu', (tester) async {
      await _pumpBanner(tester, const Locale('ur'));

      expect(find.text('سفر کا موڈ: ظہر، عصر، عشاء 2 رکعت'), findsOneWidget);
    });

    testWidgets('banner is localized in Arabic', (tester) async {
      await _pumpBanner(tester, const Locale('ar'));

      expect(
        find.text('وضع السفر: الظهر والعصر والعشاء ركعتان'),
        findsOneWidget,
      );
    });
  });
}
