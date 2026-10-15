import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/screens/home_screen.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/screens/monthly_screen.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/screens/qibla_screen.dart';
import 'package:malikiprayertimes/screens/settings_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
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
const _tromso = Coordinates(69.65, 18.96); // triggers high-latitude fallback
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
    testWidgets('home timetable: chip, countdown card, expansion tile',
        (tester) async {
      final (settings, location) = await _services();
      await tester.pumpWidget(
          _wrap(HomeScreen(settings: settings, location: location), 1.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      _expectAccessibleName(tester, find.byType(ActionChip), 'location chip');
      // The about-profile tile is below the fold: scroll first.
      await _scrollThrough(tester);
      _expectAccessibleName(
          tester, find.byType(ExpansionTile), 'about-profile tile');
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
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: _coords,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: _offset),
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
          tester, find.byType(RadioListTile<String>), 'profile radio rows');
      _expectAccessibleName(
          tester,
          find.byType(DropdownButtonFormField<PrayerProfile>),
          'comparison dropdowns');
    });

    testWidgets('qibla dial exposes its bearing to screen readers',
        (tester) async {
      await tester.pumpWidget(_wrap(
          const QiblaScreen(coordinates: _coords, locationName: 'Karachi'),
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

      expect(find.text(l10n.nextPrayerBadge), findsOneWidget,
          reason: 'highlighted row must say "${l10n.nextPrayerBadge}"');
    });

    testWidgets('monthly bands use computed/informational text chips',
        (tester) async {
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: _coords,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: _offset),
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
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: _tromso,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: const Duration(hours: 1),
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
            timeZoneOffset: _offset),
        'home': HomeScreen(settings: settings, location: location),
        'settings': SettingsScreen(
            settings: settings, coordinates: _coords, timeZoneOffset: _offset),
        'profiles': ProfilesScreen(
            settings: settings, coordinates: _coords, timeZoneOffset: _offset),
        'location': LocationScreen(locationService: location),
        'qibla':
            const QiblaScreen(coordinates: _coords, locationName: 'Karachi'),
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
      await tester.pumpWidget(_wrap(
          MonthlyScreen(
              coordinates: _coords,
              profile: PrayerProfiles.all[0],
              timeZoneOffset: _offset),
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
              timeZoneOffset: _offset),
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

    test('theme text colors against their backgrounds', () {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
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
        'onSurface / primaryContainer (next-prayer row)':
            (scheme.onSurface, scheme.primaryContainer),
        'onSurface / tertiaryContainer (profile status card)':
            (scheme.onSurface, scheme.tertiaryContainer),
        // The estimated marker uses onTertiaryContainer on the plain
        // day-cell (surface) background, not on tertiaryContainer.
        'onTertiaryContainer / surface (estimated marker)':
            (scheme.onTertiaryContainer, scheme.surface),
      };
      for (final entry in pairs.entries) {
        final r = ratio(entry.value.$1, entry.value.$2);
        debugPrint('contrast ${entry.key}: ${r.toStringAsFixed(2)}:1');
        expect(r, greaterThanOrEqualTo(4.5), reason: entry.key);
      }
    });

    test('qibla dial paint colors against a light dial background', () {
      const bg = Colors.white; // dial paints on the light scaffold surface
      final pairs = <String, (Color, Color)>{
        'ring/ticks 616161': (const Color(0xFF616161), bg),
        'north marker B71C1C': (const Color(0xFFB71C1C), bg),
        'qibla arrow 00695C': (const Color(0xFF00695C), bg),
        'cardinal letters 212121': (const Color(0xFF212121), bg),
      };
      for (final entry in pairs.entries) {
        final r = ratio(entry.value.$1, entry.value.$2);
        debugPrint('contrast ${entry.key}: ${r.toStringAsFixed(2)}:1');
        expect(r, greaterThanOrEqualTo(4.5), reason: entry.key);
      }
    });
  });
}
