import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/screens/home_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The 12/24-hour setting must change every rendered prayer time.
/// Pumps the real HomeScreen (hero card is above the fold — no scrolling
/// needed) and flips the setting live.
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

final _twelveHourPattern = RegExp(r'^\d{1,2}:\d{2} [AP]M$');
final _twentyFourHourPattern = RegExp(r'^\d{2}:\d{2}$');

String _textOf(Text t) => (t.data ?? t.textSpan?.toPlainText() ?? '').trim();

Future<(SettingsService, LocationService)> _services() async {
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsService.load();
  final location = await LocationService.load();
  await location.useManualLocation(const SavedLocation(
      name: 'Karachi', latitude: 24.86, longitude: 67.0));
  return (settings, location);
}

void main() {
  testWidgets('toggling 12h/24h changes the hero prayer time display',
      (tester) async {
    final (settings, location) = await _services();
    // Default is 12-hour.
    expect(settings.use24Hour, isFalse);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: _delegates,
      supportedLocales: _supportedLocales,
      locale: const Locale('en'),
      theme: AppFonts.themeFor(const Locale('en'), seedColor: Colors.teal),
      home: HomeScreen(settings: settings, location: location),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    Finder twelveHour() => find.byWidgetPredicate(
        (w) => w is Text && _twelveHourPattern.hasMatch(_textOf(w)));
    Finder twentyFourHour() => find.byWidgetPredicate(
        (w) => w is Text && _twentyFourHourPattern.hasMatch(_textOf(w)));

    // 12-hour mode: hero shows e.g. "4:49 AM", never bare "04:49".
    expect(twelveHour(), findsWidgets);
    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            _twelveHourPattern.hasMatch(_textOf(w)) &&
            _textOf(w).startsWith('0')),
        findsNothing,
        reason: '12-hour times must not be zero-padded');

    // Flip to 24-hour live: the hero re-renders without re-pumping the app.
    await settings.setUse24Hour(true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(twentyFourHour(), findsWidgets);
    expect(twelveHour(), findsNothing,
        reason: 'no AM/PM markers may remain in 24-hour mode');

    // And back again.
    await settings.setUse24Hour(false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(twelveHour(), findsWidgets);
  });

  test('use24Hour persists across SettingsService loads', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    expect(settings.use24Hour, isFalse);
    await settings.setUse24Hour(true);
    final reloaded = await SettingsService.load();
    expect(reloaded.use24Hour, isTrue);
  });
}
