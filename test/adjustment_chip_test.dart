import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/screens/home_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/widgets/adjustment_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 1C acceptance tests for the "never silently adjust" requirement
/// (program Part A §2.3): every manual offset and ihtiyat minute applied to
/// a displayed time must surface as a visible chip on that time's row.
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

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _phonePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<(SettingsService, LocationService)> _services() async {
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsService.load();
  final location = await LocationService.load();
  await location.useManualLocation(const SavedLocation(
      name: 'Karachi', latitude: 24.86, longitude: 67.0));
  return (settings, location);
}

Widget _wrap(Widget child, Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: _delegates,
    supportedLocales: _supportedLocales,
    theme: AppFonts.themeFor(locale, seedColor: Colors.teal),
    home: Scaffold(body: child),
  );
}

Future<void> _pumpHome(
    WidgetTester tester, SettingsService settings, LocationService location,
    {Locale locale = const Locale('en')}) async {
  _usePhoneSize(tester);
  await tester.pumpWidget(_wrap(
      HomeScreen(settings: settings, location: location), locale));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scrolls the home timetable until [finder] builds (rows are lazily
/// built), then asserts it is present exactly once.
Future<void> _scrollUntilFound(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 16 && finder.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsOneWidget);
}

Finder _chip({required int minutes, required AdjustmentKind kind}) =>
    find.byWidgetPredicate(
        (w) => w is AdjustmentChip && w.minutes == minutes && w.kind == kind);

void main() {
  group('AdjustmentChip rendering', () {
    testWidgets('manual chip shows signed minutes', (tester) async {
      await tester.pumpWidget(_wrap(
          const Center(
              child: AdjustmentChip(minutes: 5, kind: AdjustmentKind.manual)),
          const Locale('en')));
      await tester.pump();
      expect(find.text('+5 min'), findsOneWidget);
    });

    testWidgets('negative manual chip keeps the minus sign', (tester) async {
      await tester.pumpWidget(_wrap(
          const Center(
              child: AdjustmentChip(minutes: -3, kind: AdjustmentKind.manual)),
          const Locale('en')));
      await tester.pump();
      expect(find.text('-3 min'), findsOneWidget);
    });

    testWidgets('ihtiyat chip names the precautionary delay', (tester) async {
      await tester.pumpWidget(_wrap(
          const Center(
              child:
                  AdjustmentChip(minutes: 1, kind: AdjustmentKind.ihtiyat)),
          const Locale('en')));
      await tester.pump();
      expect(find.text('ihtiyat +1 min'), findsOneWidget);
    });

    testWidgets('urdu chip uses standard digits', (tester) async {
      await tester.pumpWidget(_wrap(
          const Center(
              child: AdjustmentChip(minutes: 5, kind: AdjustmentKind.manual)),
          const Locale('ur')));
      await tester.pump();
      expect(find.text('+5 منٹ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('home screen: no silent adjustments', () {
    testWidgets('manual Asr adjustment shows a chip on Asr’s row',
        (tester) async {
      final (settings, location) = await _services();
      await settings.setAdjustment(Prayer.asr, 5);
      await _pumpHome(tester, settings, location);

      final chip = _chip(minutes: 5, kind: AdjustmentKind.manual);
      await _scrollUntilFound(tester, chip);

      // The chip must sit inside Asr's row card, next to Asr's time —
      // not floating somewhere unrelated.
      final card = find.ancestor(of: chip, matching: find.byType(Card)).first;
      expect(find.descendant(of: card, matching: find.text('Asr')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled ihtiyat shows chips on Dhuhr and Maghrib',
        (tester) async {
      final (settings, location) = await _services();
      expect(settings.ihtiyatEnabled, isTrue);
      await _pumpHome(tester, settings, location);

      final chips = find.byWidgetPredicate((w) =>
          w is AdjustmentChip && w.kind == AdjustmentKind.ihtiyat);
      // Rows are lazily built: keep scrolling until both chips exist.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 16 && chips.evaluate().length < 2; i++) {
        await tester.drag(scrollable, const Offset(0, -700));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(chips, findsNWidgets(2));
      // Both carry the profile's +1 minute ihtiyat.
      for (final element in chips.evaluate()) {
        final chip = element.widget as AdjustmentChip;
        expect(chip.minutes, 1);
      }
    });

    testWidgets('disabling ihtiyat removes the Dhuhr/Maghrib chips',
        (tester) async {
      final (settings, location) = await _services();
      await settings.setIhtiyatEnabled(false);
      await _pumpHome(tester, settings, location);

      // Scroll the whole timetable into existence first, so a missing chip
      // means "not rendered", not "not built yet".
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      await _scrollUntilFound(tester, find.text(l10n.roundingFootnote));

      expect(
          find.byWidgetPredicate(
              (w) => w is AdjustmentChip && w.kind == AdjustmentKind.ihtiyat),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rounding is disclosed once per screen', (tester) async {
      final (settings, location) = await _services();
      await _pumpHome(tester, settings, location);

      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      await _scrollUntilFound(tester, find.text(l10n.roundingFootnote));
    });

    testWidgets('chips render in the ur (RTL) layout without overflow',
        (tester) async {
      final (settings, location) = await _services();
      await settings.setAdjustment(Prayer.asr, 5);
      await _pumpHome(tester, settings, location,
          locale: const Locale('ur'));

      final chip = _chip(minutes: 5, kind: AdjustmentKind.manual);
      await _scrollUntilFound(tester, chip);
      expect(tester.takeException(), isNull,
          reason: 'overflow with adjustment chips in ur (RTL)');
    });
  });
}
