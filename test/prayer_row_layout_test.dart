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

/// Prayer-row composition tests (user feedback, 2026-10-16):
/// each home timetable row must keep the time readout adjacent to the
/// prayer name — no dead space between them — in both LTR and RTL,
/// at 1.0x/1.5x/2.0x text scaling, with no overflow.
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

const _phoneSize = Size(1080, 2400);
const _phonePixelRatio = 3.0;

// Timetable readout: 24-hour "04:49" or 12-hour with locale day-period
// markers ("4:49 AM", "4:49 صبح", "٤:٤٩ ص", "4:49 du matin").
final _timePattern = RegExp(r'^[\d٠-٩]{1,2}:[\d٠-٩]{2}( .*)?$');

String _textOf(Text t) => (t.data ?? t.textSpan?.toPlainText() ?? '').trim();

Widget _wrap(Widget home, double scale, Locale locale) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
      localizationsDelegates: _delegates,
      supportedLocales: _supportedLocales,
      locale: locale,
      theme: AppFonts.themeFor(locale, seedColor: Colors.teal),
      home: home,
    ),
  );
}

Future<(SettingsService, LocationService)> _services() async {
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsService.load();
  final location = await LocationService.load();
  await location.useManualLocation(const SavedLocation(
      name: 'Karachi', latitude: 24.86, longitude: 67.0));
  return (settings, location);
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _phonePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Horizontal gap between the time readout and the nearest name-side text
/// sharing its line inside the first timetable row card (the one below the
/// "today's times" header, so the hero card's big time is excluded).
double _nameTimeGap(WidgetTester tester, String headerLabel, bool rtl) {
  final headerBox = tester.getRect(find.text(headerLabel));
  final timeTexts = find.byWidgetPredicate(
      (w) => w is Text && _timePattern.hasMatch(_textOf(w)));
  Finder? rowTime;
  for (final element in timeTexts.evaluate()) {
    final candidate = find.byWidget(element.widget);
    if (tester.getRect(candidate).top > headerBox.bottom) {
      rowTime = candidate;
      break;
    }
  }
  expect(rowTime, isNotNull, reason: 'no timetable row time found');
  final card =
      find.ancestor(of: rowTime!, matching: find.byType(Card)).first;
  final timeBox = tester.getRect(rowTime);
  final timeMidY = timeBox.center.dy;
  // Closest text on the name side of the readout that shares its line
  // (name, Arabic companion, or next-prayer badge — not the descriptor
  // below, which is filtered out by the same-line check).
  double minGap = double.infinity;
  final candidates = find.descendant(of: card, matching: find.byType(Text));
  for (final element in candidates.evaluate()) {
    final text = _textOf(element.widget as Text);
    if (text.isEmpty || _timePattern.hasMatch(text)) continue;
    final box = tester.getRect(find.byWidget(element.widget));
    if (box.top > timeMidY || box.bottom < timeMidY) continue;
    final gap = rtl ? box.left - timeBox.right : timeBox.left - box.right;
    if (gap >= -0.5 && gap < minGap) minGap = gap;
  }
  expect(minGap, isNot(double.infinity),
      reason: 'no name-side text found on the readout line');
  return minGap;
}

Future<void> _checkRowComposition(WidgetTester tester,
    {required Locale locale,
    required double scale,
    required String headerLabel,
    required bool rtl}) async {
  final (settings, location) = await _services();
  _usePhoneSize(tester);
  await tester.pumpWidget(
      _wrap(HomeScreen(settings: settings, location: location), scale, locale));
  await tester.pump(const Duration(milliseconds: 300));
  // The timetable is lazily built: scroll until the section header exists.
  // (The header renders its title upper-cased.)
  final headerFinder = find.text(headerLabel.toUpperCase());
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 12 && headerFinder.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(headerFinder, findsOneWidget,
      reason: 'timetable header never built while scrolling');
  await tester.ensureVisible(headerFinder);
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull,
      reason: 'overflow at ${scale}x in ${locale.languageCode}');
  final gap = _nameTimeGap(tester, headerLabel.toUpperCase(), rtl);
  // The readout must hug the name cluster: 10px design gap plus slack.
  // The pre-fix layout stranded the time at the far edge (~150px+ here).
  expect(gap, lessThan(48),
      reason: 'dead space between time and name at ${scale}x '
          'in ${locale.languageCode} (gap ${gap.toStringAsFixed(1)}px)');
}

void main() {
  group('prayer row composition: time adjacent to name', () {
    testWidgets('ur (RTL) at 1.0x', (tester) async {
      await _checkRowComposition(tester,
          locale: const Locale('ur'),
          scale: 1.0,
          headerLabel: 'آج کے اوقات',
          rtl: true);
    });

    testWidgets('ur (RTL) at 1.5x', (tester) async {
      await _checkRowComposition(tester,
          locale: const Locale('ur'),
          scale: 1.5,
          headerLabel: 'آج کے اوقات',
          rtl: true);
    });

    testWidgets('ur (RTL) at 2.0x', (tester) async {
      await _checkRowComposition(tester,
          locale: const Locale('ur'),
          scale: 2.0,
          headerLabel: 'آج کے اوقات',
          rtl: true);
    });

    testWidgets('en (LTR) at 1.0x', (tester) async {
      await _checkRowComposition(tester,
          locale: const Locale('en'),
          scale: 1.0,
          headerLabel: 'Today’s times',
          rtl: false);
    });

    testWidgets('en (LTR) at 2.0x', (tester) async {
      await _checkRowComposition(tester,
          locale: const Locale('en'),
          scale: 2.0,
          headerLabel: 'Today’s times',
          rtl: false);
    });
  });
}
