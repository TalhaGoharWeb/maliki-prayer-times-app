import 'dart:math' as math;

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
import 'package:malikiprayertimes/screens/date_labels.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/screens/monthly_screen.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/screens/qibla_screen.dart';
import 'package:malikiprayertimes/screens/settings_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/hijri.dart';
import 'package:malikiprayertimes/widgets/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accessibility audit tests (Track C).
///
/// Covers: accessible names on every interactive element, no color-only
/// state signaling, 48x48 touch targets, large-text (2x/3x) overflow
/// freedom on phone and tablet widths, and WCAG AA contrast ratios.
///
/// Note on lazily-built lists: ListView/GridView only build the visible
/// window, so tests scroll each screen to the end before asserting on
/// below-the-fold content.

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

const _coords = Coordinates(24.86, 67.0); // Karachi
const _offset = Duration(hours: 5);

/// Narrow-phone logical size used for the touch-target and large-text
/// passes (360x800 @3x).
const _phoneSize = Size(1080, 2400);
const _phonePixelRatio = 3.0;

Widget _wrap(Widget home, double scale) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
      localizationsDelegates: _delegates,
      supportedLocales: _supportedLocales,
      // Same theme the real app uses (teal seed); font family left at the
      // test default.
      theme: AppFonts.themeFor(const Locale('en'), seedColor: Colors.teal),
      home: home,
    ),
  );
}

/// Locale-pinned variant of [_wrap]: the app locale drives both the
/// localizations and the locale-specific text theme (e.g. Amiri for `ar`).
Widget _wrapLocale(Widget home, double scale, Locale locale) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _delegates,
      supportedLocales: _supportedLocales,
      theme: AppFonts.themeFor(locale, seedColor: Colors.teal),
      home: home,
    ),
  );
}

Future<(SettingsService, LocationService)> _services(
    {bool withLocation = true}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsService.load();
  final location = await LocationService.load();
  if (withLocation) {
    await location.useManualLocation(const SavedLocation(
        name: 'Karachi', latitude: 24.86, longitude: 67.0));
  }
  return (settings, location);
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _phonePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Scrolls the screen's primary vertical scrollable to the end in steps so
/// lazily-built content below the fold is also laid out, asserting no
/// overflow is reported after each step.
Future<void> _scrollThrough(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  for (var i = 0; i < 8; i++) {
    if (scrollable.evaluate().isEmpty) return;
    await tester.drag(scrollable.first, const Offset(0, -1500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'overflow reported while scrolling');
  }
}

String _textOf(Text t) => (t.data ?? t.textSpan?.toPlainText() ?? '').trim();

/// Every widget matched by [finder] must expose an accessible name:
/// - IconButton: a non-empty (localized) tooltip. Flutter exposes the
///   tooltip message to the semantics tree when the tooltip becomes
///   visible (long-press); this is the sanctioned label mechanism.
/// - Text fields: a non-empty semantics label (from labelText).
/// - Everything else: a non-empty semantics label of its own, or a
///   non-empty visible text descendant (button/tile titles).
void _expectAccessibleName(WidgetTester tester, Finder finder, String what) {
  expect(finder, findsWidgets, reason: 'expected to find $what');
  for (final element in finder.evaluate()) {
    final widget = element.widget;
    if (widget is IconButton) {
      expect((widget.tooltip ?? '').trim(), isNotEmpty,
          reason: '$what: IconButton has no tooltip label');
      continue;
    }
    final node = tester.getSemantics(find.byWidget(widget));
    if (node.label.trim().isNotEmpty) continue;
    final texts = find.descendant(
        of: find.byWidget(widget), matching: find.byType(Text));
    final named =
        tester.widgetList<Text>(texts).any((t) => _textOf(t).isNotEmpty);
    expect(named, isTrue,
        reason: '$what exposes neither a semantics label nor text');
  }
}

/// Day-cell InkWells only (excludes IconButton-internal InkWells).
Finder _dayCells() => find.descendant(
    of: find.byType(GridView), matching: find.byType(InkWell));

void main() {
  group('semantics labels', () {
    testWidgets('home timetable: location header, expansion tile',
        (tester) async {
      final (settings, location) = await _services();
      await tester.pumpWidget(
          _wrap(HomeScreen(settings: settings, location: location), 1.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // The prominent location header (replaced the old ActionChip):
      // the InkWell wrapping the current-location name.
      _expectAccessibleName(
          tester,
          find.ancestor(
              of: find.text('Karachi'),
              matching: find.byType(InkWell)),
          'location header');
      // The about-profile tile is below the fold: scroll first.
      await _scrollThrough(tester);
      _expectAccessibleName(
          tester, find.byType(ExpansionTile), 'about-profile tile');
    });

    testWidgets('hero card shows the Hijri date (day, month name, year)',
        (tester) async {
      final (settings, location) = await _services();
      await tester.pumpWidget(
          _wrap(HomeScreen(settings: settings, location: location), 1.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final expected =
          formatHijriDate(l10n, gregorianToHijri(DateTime.now()));
      // The date sits inside the dark hero card, below its eyebrow.
      final hero = find.ancestor(
        of: find.text(l10n.heroEyebrow.toUpperCase()),
        matching: find.byType(Card),
      );
      expect(hero, findsOneWidget);
      expect(
        find.descendant(of: hero, matching: find.text(expected)),
        findsOneWidget,
        reason: 'hero card must show the Hijri date "$expected"',
      );
    });

    testWidgets('home location prompt: set-location button', (tester) async {
      final (settings, location) = await _services(withLocation: false);
      await tester.pumpWidget(
          _wrap(HomeScreen(settings: settings, location: location), 1.0));
      await tester.pump();
      _expectAccessibleName(
          tester, find.byType(FilledButton), 'set-location button');
    });

    testWidgets('settings: all controls labeled', (tester) async {
      final (settings, _) = await _services();
      // Tall viewport so the lazy list builds every row at once.
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(
          SettingsScreen(
              settings: settings,
              coordinates: _coords,
              timeZoneOffset: _offset),
          1.0));
      await tester.pump();
      expect(tester.takeException(), isNull);

      _expectAccessibleName(
          tester, find.byType(ListTile), 'profile row (tappable)');
      _expectAccessibleName(
          tester,
          find.byType(DropdownButtonFormField<String?>),
          'language dropdown');
      // +/- steppers for the five adjustable prayers.
      final steppers = find.byType(IconButton);
      expect(steppers, findsNWidgets(10));
      _expectAccessibleName(tester, steppers, 'adjustment stepper');
      _expectAccessibleName(
          tester, find.byType(SwitchListTile), 'ihtiyat switch');
      _expectAccessibleName(
          tester, find.byType(TextButton), 'reset-adjustments button');
    });

    testWidgets('monthly: nav buttons and every day cell labeled',
        (tester) async {
      final (settings, _) = await _services();
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: _coords,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: _offset,
              settings: settings),
          1.0));
      await tester.pump();
      expect(tester.takeException(), isNull);

      _expectAccessibleName(
          tester, find.byType(IconButton), 'month nav button');
      // Day cells: each InkWell sits under an explicit Semantics node
      // whose label is the full localized date ("15 October 2026").
      final cells = _dayCells();
      expect(cells, findsWidgets);
      for (final cell in cells.evaluate()) {
        final labeledAncestor = find.ancestor(
          of: find.byWidget(cell.widget),
          matching: find.byWidgetPredicate((w) =>
              w is Semantics && (w.properties.label ?? '').trim().isNotEmpty),
        );
        expect(labeledAncestor, findsWidgets,
            reason: 'day cell has no accessible date label');
      }
    });

    testWidgets('location screen: buttons and fields labeled', (tester) async {
      final (_, location) = await _services();
      await tester.pumpWidget(
          _wrap(LocationScreen(locationService: location), 1.0));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Buttons live below the fold in the lazy ListView: scroll first.
      await _scrollThrough(tester);
      _expectAccessibleName(
          tester, find.byType(FilledButton), 'location buttons');
      for (final e in find.byType(TextFormField).evaluate()) {
        final node = tester.getSemantics(find.byWidget(e.widget));
        expect(node.label.trim(), isNotEmpty,
            reason: 'text field exposes no labelText to semantics');
      }
    });

    testWidgets('profiles: radios and comparison dropdowns labeled',
        (tester) async {
      final (settings, _) = await _services();
      // Tall viewport so the lazy list builds every row at once.
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(
          ProfilesScreen(
              settings: settings,
              coordinates: _coords,
              timeZoneOffset: _offset),
          1.0));
      await tester.pump();
      expect(tester.takeException(), isNull);

      _expectAccessibleName(
          tester,
          find.ancestor(
            of: find.byType(Radio<String>),
            matching: find.byType(Semantics),
          ),
          'profile radio rows');
      _expectAccessibleName(
          tester,
          find.byType(DropdownButtonFormField<PrayerProfile>),
          'comparison dropdowns');
    });

    testWidgets('qibla dial exposes its bearing to screen readers',
        (tester) async {
      await tester.pumpWidget(_wrap(
          QiblaScreen(coordinates: _coords, locationName: 'Karachi', timeZoneOffset: _offset),
          1.0));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label ?? '')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      // The dial's label carries the bearing ("44.7° clockwise from true
      // north" in English): a bare CustomPaint would otherwise be
      // invisible to screen readers.
      expect(labels.any((l) => l.contains('°')), isTrue,
          reason: 'qibla dial has no bearing label; found: $labels');
    });
  });

  group('no color-only signaling', () {
    testWidgets('home bands convey ikhtiyari/daruri as text', (tester) async {
      final (settings, location) = await _services();
      await tester.pumpWidget(
          _wrap(HomeScreen(settings: settings, location: location), 1.0));
      await tester.pump(const Duration(milliseconds: 100));
      await _scrollThrough(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Every band renders the preferred/necessity words as text — state
      // is never carried by color alone.
      expect(find.textContaining(l10n.preferredWord), findsWidgets);
      expect(find.textContaining(l10n.necessityWord), findsWidgets);
    });

    testWidgets('next-prayer highlight pairs color with a text badge',
        (tester) async {
      final (settings, location) = await _services();
      await tester.pumpWidget(
          _wrap(HomeScreen(settings: settings, location: location), 1.0));
      await tester.pump(const Duration(milliseconds: 100));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // The next prayer depends on the wall-clock time: late in the day it
      // is Isha, whose row starts below the fold on the default test
      // surface — and ListView only keeps its visible window in the tree.
      // Scroll in small steps until the badge's row enters the viewport
      // (a full scroll-through would dispose it again at the bottom).
      final badge = find.text(l10n.nextPrayerBadge);
      for (var i = 0; i < 10 && badge.evaluate().isEmpty; i++) {
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(badge, findsOneWidget,
          reason: 'highlighted row must say "${l10n.nextPrayerBadge}"');
    });

    testWidgets('monthly bands use computed/informational text chips',
        (tester) async {
      final (settings, _) = await _services();
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: _coords,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: _offset,
              settings: settings),
          1.0));
      await tester.pump();
      await tester.tap(_dayCells().first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The band cards are below the fold inside the sheet: scroll it.
      final sheetList = find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(ListView));
      for (var i = 0; i < 6; i++) {
        await tester.drag(sheetList, const Offset(0, -1200));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.computedChip), findsWidgets);
      expect(find.text(l10n.informationalChip), findsWidgets);
    });

    testWidgets('high-latitude estimate flag is text, not color-only',
        (tester) async {
      // Fixture: London in June — a full month of persistent-twilight
      // fallback days (the old Tromsø-June fixture is now a no-solution
      // month, which renders no markers at all).
      const london = Coordinates(51.5, -0.12);
      final (settings, _) = await _services();
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: london,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: const Duration(hours: 1),
              settings: settings,
              initialMonth: DateTime(2026, 6)),
          1.0));
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.estimatedMarker), findsWidgets,
          reason: 'estimated marker must render as text');
    });
  });

  group('large text (2x/3x)', () {
    Future<void> pumpAll(WidgetTester tester, double scale, String tag) async {
      final (settings, location) = await _services();
      final screens = <String, Widget>{
        'monthly': MonthlyScreen(
            coordinates: _coords,
            profile: PrayerProfiles.all[0],
            timeZoneOffset: _offset,
            settings: settings),
        'home': HomeScreen(settings: settings, location: location),
        'settings': SettingsScreen(
            settings: settings, coordinates: _coords, timeZoneOffset: _offset),
        'profiles': ProfilesScreen(
            settings: settings, coordinates: _coords, timeZoneOffset: _offset),
        'location': LocationScreen(locationService: location),
        'qibla':
            QiblaScreen(coordinates: _coords, locationName: 'Karachi', timeZoneOffset: _offset),
      };
      for (final entry in screens.entries) {
        await tester.pumpWidget(_wrap(entry.value, scale));
        // Home runs a 1-second countdown timer: pump manually instead of
        // pumpAndSettle (which would time out on the periodic timer).
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull,
            reason: '$tag ${entry.key} at ${scale}x overflowed');
        // Also lay out the below-the-fold content.
        await _scrollThrough(tester);
      }
    }

    testWidgets('no overflow at 2x/3x on a tablet-width surface',
        (tester) async {
      await pumpAll(tester, 2.0, 'tablet');
      await pumpAll(tester, 3.0, 'tablet');
    });

    testWidgets('no overflow at 2x/3x on a 360dp phone', (tester) async {
      _usePhoneSize(tester);
      await pumpAll(tester, 2.0, 'phone');
      await pumpAll(tester, 3.0, 'phone');
    });
  });

  group('touch targets', () {
    testWidgets('monthly day cells are at least 48x48 on a 360dp phone',
        (tester) async {
      _usePhoneSize(tester);
      final (settings, _) = await _services();
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: _coords,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: _offset,
              settings: settings),
          1.0));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final cells = _dayCells();
      expect(cells, findsWidgets);
      for (final cell in cells.evaluate()) {
        final size = tester.getSize(find.byWidget(cell.widget));
        expect(size.width, greaterThanOrEqualTo(48.0),
            reason: 'day cell tap width ${size.width}');
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: 'day cell tap height ${size.height}');
      }
    });

    testWidgets('icon buttons meet 48x48 (settings steppers, month nav)',
        (tester) async {
      _usePhoneSize(tester);
      final (settings, _) = await _services();
      await tester.pumpWidget(_wrap(
          SettingsScreen(
              settings: settings,
              coordinates: _coords,
              timeZoneOffset: _offset),
          1.0));
      await tester.pump();
      for (final b in find.byType(IconButton).evaluate()) {
        final size = tester.getSize(find.byWidget(b.widget));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }

      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: _coords,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: _offset,
              settings: settings),
          1.0));
      await tester.pump();
      for (final b in find.byType(IconButton).evaluate()) {
        final size = tester.getSize(find.byWidget(b.widget));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });
  });

  group('contrast (WCAG AA 4.5:1 for normal text)', () {
    double linearize(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

    double luminance(Color c) =>
        0.2126 * linearize(c.r) +
        0.7152 * linearize(c.g) +
        0.0722 * linearize(c.b);

    double ratio(Color fg, Color bg) {
      final l1 = luminance(fg);
      final l2 = luminance(bg);
      return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
    }

    // The REAL scheme the app renders. themeFor() ignores its seedColor
    // argument (fonts.dart), so the old ColorScheme.fromSeed(Colors.teal)
    // tested a scheme that never appears on screen — which is how the
    // 2.06:1 estimated marker (I-02) slipped through.
    final scheme = AppFonts.lightScheme;

    test('theme text colors against their backgrounds', () {
      final pairs = <String, (Color, Color)>{
        'onSurface / surface': (scheme.onSurface, scheme.surface),
        'onSurfaceVariant / surface':
            (scheme.onSurfaceVariant, scheme.surface),
        'onPrimary / primary': (scheme.onPrimary, scheme.primary),
        'onPrimaryContainer / primaryContainer':
            (scheme.onPrimaryContainer, scheme.primaryContainer),
        'onTertiaryContainer / tertiaryContainer':
            (scheme.onTertiaryContainer, scheme.tertiaryContainer),
        'onErrorContainer / errorContainer':
            (scheme.onErrorContainer, scheme.errorContainer),
        'error / surface (location error text)':
            (scheme.error, scheme.surface),
        // Rendered contexts (not just the paired container):
        // The next-prayer row renders onPrimary on primaryContainer
        // (the old test asserted onSurface here — wrong for the real
        // scheme, where it is 1.74:1).
        'onPrimary / primaryContainer (next-prayer row)':
            (scheme.onPrimary, scheme.primaryContainer),
        // The profile status card renders the fixed tertiary roles on
        // tertiaryFixed.
        'onTertiaryFixed / tertiaryFixed (profile status card)':
            (scheme.onTertiaryFixed, scheme.tertiaryFixed),
        'onTertiaryFixedVariant / tertiaryFixed (profile status body)':
            (scheme.onTertiaryFixedVariant, scheme.tertiaryFixed),
        // The estimated marker sits on the plain day-cell (surface)
        // background, so it must use the darker onTertiaryFixedVariant
        // (#5B4301), not onTertiaryContainer (#CEAC63, 2.06:1).
        'onTertiaryFixedVariant / surface (estimated marker)':
            (scheme.onTertiaryFixedVariant, scheme.surface),
      };
      for (final entry in pairs.entries) {
        final r = ratio(entry.value.$1, entry.value.$2);
        debugPrint('contrast ${entry.key}: ${r.toStringAsFixed(2)}:1');
        expect(r, greaterThanOrEqualTo(4.5), reason: entry.key);
      }
    });

    test('qibla dial paint colors against the real dial card background',
        () {
      // The dial paints on a Card whose theme color is surfaceContainerLow
      // (#DCFAF0); _QiblaDialPainter uses scheme colors. The old test
      // asserted hardcoded teal tones (0xFF00695C…) that the painter never
      // used.
      final bg = scheme.surfaceContainerLow;
      final textPairs = <String, (Color, Color)>{
        'cardinal letters onSurface': (scheme.onSurface, bg),
        'north cardinal error': (scheme.error, bg),
        'qibla arrow primary': (scheme.primary, bg),
        'qibla label primary': (scheme.primary, bg),
        'ticks onSurfaceVariant': (scheme.onSurfaceVariant, bg),
      };
      for (final entry in textPairs.entries) {
        final r = ratio(entry.value.$1, entry.value.$2);
        debugPrint('contrast ${entry.key}: ${r.toStringAsFixed(2)}:1');
        expect(r, greaterThanOrEqualTo(4.5), reason: entry.key);
      }
      // Non-text artwork only needs the 3:1 bar.
      final ringRatio = ratio(scheme.outline, bg);
      debugPrint(
          'contrast ring outline: ${ringRatio.toStringAsFixed(2)}:1');
      expect(ringRatio, greaterThanOrEqualTo(3.0), reason: 'ring outline');
      final markerRatio = ratio(scheme.error, bg);
      debugPrint(
          'contrast north marker: ${markerRatio.toStringAsFixed(2)}:1');
      expect(markerRatio, greaterThanOrEqualTo(3.0),
          reason: 'north marker');
    });

    testWidgets('estimated marker meets 4.5:1 on the real day-cell surface',
        (tester) async {
      // Reads the marker color from the RENDERED widget rather than from
      // the scheme constants: if the screen code ever regresses to the
      // old onTertiaryContainer marker (2.06:1), this test fails.
      // Fixture: London in June — a full month of persistent-twilight
      // fallback days (the old Tromsø-June fixture is now a no-solution
      // month, which renders no markers at all).
      const london = Coordinates(51.5, -0.12);
      final (settings, _) = await _services();
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: london,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: const Duration(hours: 1),
              settings: settings,
              initialMonth: DateTime(2026, 6)),
          1.0));
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final marker =
          tester.widget<Text>(find.text(l10n.estimatedMarker).first);
      final fg = marker.style?.color;
      expect(fg, isNotNull, reason: 'marker must carry an explicit color');
      final r = ratio(fg!, AppFonts.lightScheme.surface);
      debugPrint(
          'contrast estimated marker (rendered): ${r.toStringAsFixed(2)}:1');
      expect(r, greaterThanOrEqualTo(4.5),
          reason: 'estimated marker on day-cell surface');
    });
  });

  group('wave-1 reliability fixes (REL-01/REL-02, E-03)', () {
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    Widget monthlyFor(SettingsService settings,
            {required PrayerProfile profile}) =>
        _wrap(
            MonthlyScreen(
                coordinates: _coords,
                profile: profile,
                timeZoneOffset: _offset,
                settings: settings,
                initialMonth: DateTime(2026, 10)),
            1.0);

    /// Raw engine Fajr for the first visible day, using the same per-date
    /// offset derivation the screen applies.
    DateTime rawDayOneFajr(PrayerProfile profile) =>
        (calculatePrayerTimes(
          coordinates: _coords,
          date: DateTime(2026, 10, 1),
          timeZoneOffset: DateTime(2026, 10, 1).timeZoneOffset,
          profile: profile,
        ) as PrayerTimesComputed)
            .times
            .fajr;

    testWidgets('REL-01: +15 min Fajr adjustment reaches the cell and the day sheet',
        (tester) async {
      final (settings, _) = await _services();
      await tester.pumpWidget(
          monthlyFor(settings, profile: PrayerProfiles.all[0]));
      await tester.pump();

      // Mutate the adjustments on the same SettingsService instance and
      // re-deliver the widget: didUpdateWidget must recompute the grid.
      await settings.setAdjustment(Prayer.fajr, 15);
      await tester.pumpWidget(
          monthlyFor(settings, profile: PrayerProfiles.all[0]));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final expected =
          rawDayOneFajr(PrayerProfiles.all[0]).add(const Duration(minutes: 15));
      expect(
          find.text(l10n.dayCellFajr(localizeDigits(hhmm(expected), 'en'))),
          findsWidgets,
          reason: 'day-1 cell must show the adjusted Fajr');

      await tester.tap(_dayCells().first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(localizeDigits(hhmm(expected), 'en')), findsOneWidget,
          reason: 'day sheet Fajr row must show the adjusted time');
    });

    testWidgets('REL-02: delivering a new profile recomputes the monthly grid',
        (tester) async {
      final (settings, _) = await _services();
      await tester.pumpWidget(monthlyFor(settings,
          profile: PrayerProfiles.malikiMwlWestAfrica));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      String fajrCell(PrayerProfile p) => l10n.dayCellFajr(
          localizeDigits(hhmm(rawDayOneFajr(p)), 'en'));

      expect(find.text(fajrCell(PrayerProfiles.malikiMwlWestAfrica)),
          findsWidgets);
      // The Egyptian profile uses a steeper Fajr angle: didUpdateWidget must
      // reload the grid instead of showing the stale profile's times.
      // Assertions are scoped to the day-1 cell — other days of the month
      // may coincidentally share an HH:MM readout.
      final dayOneCell = _dayCells().first;
      await tester.pumpWidget(
          monthlyFor(settings, profile: PrayerProfiles.malikiEgyptian));
      await tester.pump();
      expect(
          find.descendant(
              of: dayOneCell,
              matching: find.text(fajrCell(PrayerProfiles.malikiEgyptian))),
          findsOneWidget,
          reason: 'grid must recompute for the new profile');
      expect(
          find.descendant(
              of: dayOneCell,
              matching:
                  find.text(fajrCell(PrayerProfiles.malikiMwlWestAfrica))),
          findsNothing,
          reason: 'stale profile times must be gone');
    });

    testWidgets('E-03: home shows the honest state on a no-solution day',
        (tester) async {
      const southPole = Coordinates(-80.0, 0.0);
      final (settings, location) = await _services();
      await location.useManualLocation(const SavedLocation(
          name: 'South Pole', latitude: -80.0, longitude: 0.0));
      await tester.pumpWidget(
          _wrap(HomeScreen(settings: settings, location: location), 1.0));
      // Home runs a 1-second countdown timer: pump manually instead of
      // pumpAndSettle (which would time out on the periodic timer).
      await tester.pump(const Duration(milliseconds: 200));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The engine's verdict is date-dependent (polar seasons), so probe
      // the same computation HomeScreen performs and assert the UI matches
      // the verdict either way — never a vacuous pass.
      final now = DateTime.now();
      final probe = calculatePrayerTimes(
        coordinates: southPole,
        date: DateTime(now.year, now.month, now.day),
        timeZoneOffset: DateTime.now().timeZoneOffset,
        profile: settings.effectiveProfile,
      );
      if (probe is PrayerTimesNoSolution) {
        expect(find.text(l10n.noTimesTitle), findsOneWidget,
            reason: 'honest empty state must show on a no-solution day');
        expect(find.text(l10n.noTimesChooseMethod), findsOneWidget,
            reason: 'the fallback chooser must be one tap away');
      } else {
        final times = (probe as PrayerTimesComputed).times;
        if (times.highLatitudeFallback) {
          expect(find.text(l10n.highLatConventionBadge), findsWidgets,
              reason: 'fallback indicator must show on a fallback day');
        } else {
          expect(find.text(l10n.highLatConventionBadge), findsNothing,
              reason: 'no fallback indicator on a normal day');
        }
      }
    });
  });

  group('wave-2 a11y/i18n fixes', () {
    test('badgeLabel tracking is zero for ur/ar, 0.08em for Latin locales',
        () {
      // I-15: letter-spacing breaks Arabic-script joining in Nastaleeq
      // (ur) and Amiri (ar).
      for (final code in ['en', 'fr']) {
        final style = AppFonts.themeFor(Locale(code), seedColor: Colors.teal)
            .textTheme
            .labelSmall!;
        expect(style.letterSpacing, closeTo(0.08 * 11, 1e-9),
            reason: '$code keeps badge tracking');
      }
      for (final code in ['ur', 'ar']) {
        final style = AppFonts.themeFor(Locale(code), seedColor: Colors.teal)
            .textTheme
            .labelSmall!;
        expect(style.letterSpacing, 0.0,
            reason: '$code must not letter-space badge labels');
      }
    });

    test('asrPreferredInfo no longer claims an approximate display', () async {
      // E-06: the Asr band text said isfirar was "shown approximately",
      // but nothing is shown. The informational-band meaning stays.
      const approxWords = ['approximate', 'تقریبی', 'تقريبي', 'approximatif'];
      const adhanWords = ['adhan', 'اذان', 'أذان'];
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        for (final w in approxWords) {
          expect(l10n.asrPreferredInfo.contains(w), isFalse,
              reason: '$code asrPreferredInfo still claims "$w"');
        }
        expect(
            adhanWords.any(l10n.asrPreferredInfo.contains), isTrue,
            reason: '$code asrPreferredInfo lost the adhan disclaimer');
      }
    });

    testWidgets('fr: qibla numbers use the comma decimal separator',
        (tester) async {
      // I-14: fmtNum must render "7 451,5"-style decimals for fr.
      await tester.pumpWidget(_wrapLocale(
          QiblaScreen(
              coordinates: _coords,
              locationName: 'Karachi',
              timeZoneOffset: _offset),
          1.0,
          const Locale('fr')));
      await tester.pump();
      expect(find.textContaining(RegExp(r'\d,\d°')), findsWidgets,
          reason: 'bearing/rhumb should use a comma decimal in fr');
      expect(find.textContaining(RegExp(r'\d\.\d°')), findsNothing,
          reason: 'no dot decimals in fr degree readouts');
    });

    testWidgets('ar: day sheet shows no Western digits', (tester) async {
      // I-07/I-08: band-time embeddings and the sheet Hijri date must be
      // digit-localized; the sheet Hijri header carries the approximation
      // qualifier.
      final (settings, _) = await _services();
      await tester.pumpWidget(_wrapLocale(
          MonthlyScreen(
              coordinates: _coords,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: _offset,
              settings: settings,
              initialMonth: DateTime(2026, 10)),
          1.0,
          const Locale('ar')));
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      // Open the day sheet for the 1st (day number is Arabic-Indic here).
      await tester.tap(find.text('١').first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DraggableScrollableSheet), findsOneWidget,
          reason: 'day sheet should open');
      // The qualifier must be on the sheet's Hijri header.
      expect(find.textContaining(l10n.hijriApproxQualifier), findsWidgets,
          reason: 'sheet Hijri header needs the approximation qualifier');
      // Scroll the sheet's list from a visible point (the ListView itself
      // extends past the test surface, so dragging the widget misses).
      for (var i = 0; i < 6; i++) {
        await tester.dragFrom(const Offset(400, 500), const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final western = RegExp(r'[0-9]');
      final sheet = find.byType(DraggableScrollableSheet);
      String textOf(Element e) {
        final w = e.widget;
        if (w is Text) {
          return w.data ?? w.textSpan?.toPlainText() ?? '';
        }
        if (w is RichText) return w.text.toPlainText();
        return '';
      }

      for (final e in find
          .descendant(
              of: sheet,
              matching: find.byWidgetPredicate(
                  (w) => w is Text || w is RichText))
          .evaluate()) {
        final s = textOf(e);
        // The ar maghribPreferred template carries literal "15"/"20"
        // duration words (E-04, owned by another wave) — exempt until that
        // template is reworded.
        if (s.contains('15 إلى 20')) continue;
        expect(western.hasMatch(s), isFalse,
            reason: 'Western digit in ar day sheet: "$s"');
      }
    });

    testWidgets('ar: adjustment stepper value uses Arabic-Indic digits',
        (tester) async {
      // I-17: the '+N' stepper value must not show Western digits in ar.
      // Values are checked per scroll step: ListView unmounts rows that
      // scroll out of the cache extent.
      final (settings, _) = await _services();
      await tester.pumpWidget(_wrapLocale(
          SettingsScreen(
              settings: settings,
              coordinates: _coords,
              timeZoneOffset: _offset),
          1.0,
          const Locale('ar')));
      await tester.pump();
      final numeric = RegExp(r'^[+＋\-]?[0-9٠-٩]+$');
      final western = RegExp(r'[0-9]');
      final seen = <String>{};
      final scrollable = find.byType(Scrollable);
      for (var i = 0; i < 8; i++) {
        for (final e in find.byType(Text).evaluate()) {
          final s = _textOf(e.widget as Text);
          if (numeric.hasMatch(s)) {
            seen.add(s);
            expect(western.hasMatch(s), isFalse,
                reason: 'Western digit in ar stepper value: "$s"');
          }
        }
        if (scrollable.evaluate().isEmpty) break;
        await tester.drag(scrollable.first, const Offset(0, -1500));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: 'overflow while scrolling settings');
      }
      expect(seen, isNotEmpty,
          reason: 'expected to find stepper values');
    });

    testWidgets('ar: reminder-offset picker uses Arabic-Indic digits',
        (tester) async {
      // I-17: the offset dropdown labels must not show Western digits.
      final (settings, _) = await _services();
      await settings.setReminderOffsetMinutes(15);
      await tester.pumpWidget(_wrapLocale(
          // The section is a bare Column; it needs a scrollable parent like
          // the settings screen provides.
          ListView(
            children: [
              NotificationSettingsSection(
                  notifications: NotificationService(
                      scheduler: FakeNotificationScheduler()),
                  settings: settings,
                  coordinates: _coords,
                  timeZoneOffset: _offset),
            ],
          ),
          1.0,
          const Locale('ar')));
      await tester.pump();
      // The closed dropdown shows the selected option's label.
      expect(find.textContaining('١٥'), findsWidgets,
          reason: 'offset label should show Arabic-Indic digits');
      for (final e in find.byType(Text).evaluate()) {
        final s = _textOf(e.widget as Text);
        if (s.contains('دقائق')) {
          expect(RegExp(r'[0-9]').hasMatch(s), isFalse,
              reason: 'Western digit in ar offset label: "$s"');
        }
      }
    });

    testWidgets('manual coordinates reject NaN and infinities',
        (tester) async {
      // E-07: "NaN"/"Infinity" used to pass validation and collapse the
      // engine's times to solar noon.
      Future<void> scrollToForm() async {
        // The manual-entry form sits below the fold; ListView only builds
        // visible rows.
        for (var i = 0;
            i < 5 && find.byType(TextFormField).evaluate().isEmpty;
            i++) {
          await tester.drag(
              find.byType(Scrollable).first, const Offset(0, -1500));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(TextFormField), findsWidgets,
            reason: 'manual entry form should scroll into view');
      }

      Future<void> trySave(
          LocationService location, String name, String lat, String lon) async {
        await tester.pumpWidget(_wrap(
            LocationScreen(locationService: location), 1.0));
        await tester.pump();
        await scrollToForm();
        final l10n =
            await AppLocalizations.delegate.load(const Locale('en'));
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), name);
        await tester.enterText(fields.at(1), lat);
        await tester.enterText(fields.at(2), lon);
        await tester.ensureVisible(find.text(l10n.saveCompute));
        await tester.tap(find.text(l10n.saveCompute));
        await tester.pump();
      }

      for (final bad in ['NaN', 'Infinity', '-Infinity']) {
        final (_, location) = await _services();
        await trySave(location, 'Bad $bad', bad, '67.0');
        expect(location.current?.name, 'Karachi',
            reason: '"$bad" latitude must not be saved');
        final (_, location2) = await _services();
        await trySave(location2, 'Bad $bad', '24.86', bad);
        expect(location2.current?.name, 'Karachi',
            reason: '"$bad" longitude must not be saved');
      }
    });

    testWidgets('manual coordinates still accept valid input', (tester) async {
      final (_, location) = await _services();
      await tester.pumpWidget(
          _wrap(LocationScreen(locationService: location), 1.0));
      await tester.pump();
      for (var i = 0;
          i < 5 && find.byType(TextFormField).evaluate().isEmpty;
          i++) {
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -1500));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Valid Place');
      await tester.enterText(fields.at(1), '24.86');
      await tester.enterText(fields.at(2), '67.0');
      await tester.ensureVisible(find.text(l10n.saveCompute));
      await tester.tap(find.text(l10n.saveCompute));
      await tester.pump();
      expect(location.current?.name, 'Valid Place');
      expect(location.current?.latitude, closeTo(24.86, 1e-9));
    });
  });
}
