import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/screens/location_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 2 widget tests: the searchable IANA zone picker on the manual
/// location form, and the saved-places UI (save / select / delete).
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

Future<void> pumpLocationScreen(
    WidgetTester tester, LocationService location) async {
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
  expect(tester.takeException(), isNull);
}

/// The page's vertical scrollable (the text fields carry their own
/// horizontal editables, so an unscoped scrollable finder is ambiguous).
Finder _pageScrollable() => find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );

void main() {
  group('zone picker', () {
    testWidgets(
        'searching and selecting a zone stores it on the saved manual '
        'location', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final location = await LocationService.load();
      await pumpLocationScreen(tester, location);
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));

      // Scroll the manual form into view.
      await tester.scrollUntilVisible(
        find.text(l10n.saveCompute),
        300,
        scrollable: _pageScrollable(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Open the zone picker from the manual form.
      await tester.tap(find.text(l10n.fieldTimeZone));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      // Search narrows the ~600-zone list.
      final searchField = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'karachi');
      await tester.pump();
      expect(find.text('Asia/Karachi'), findsOneWidget);

      // Pick the zone; the dialog closes and the form shows the choice.
      await tester.tap(find.text('Asia/Karachi'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      // Fill the rest of the form (elevation left empty = sea level).
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Testville');
      await tester.enterText(fields.at(1), '24.86');
      await tester.enterText(fields.at(2), '67.0');
      await tester.tap(find.text(l10n.saveCompute));
      await tester.pump();

      final current = location.current!;
      expect(current.name, 'Testville');
      expect(current.timeZoneId, 'Asia/Karachi',
          reason: 'the picked zone is stored with the location');
      expect(current.elevationMeters, isNull,
          reason: 'empty elevation stays unset');
    });

    testWidgets('dismissing the picker keeps the previous choice',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final location = await LocationService.load();
      await pumpLocationScreen(tester, location);
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));

      await tester.scrollUntilVisible(
        find.text(l10n.saveCompute),
        300,
        scrollable: _pageScrollable(),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(l10n.fieldTimeZone));
      await tester.pumpAndSettle();
      // Close without picking: the button is never dead.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Testville');
      await tester.enterText(fields.at(1), '24.86');
      await tester.enterText(fields.at(2), '67.0');
      await tester.tap(find.text(l10n.saveCompute));
      await tester.pump();
      // Default: the device wall clock (null zone id) — the picker
      // offers an explicit IANA zone for far-away places instead of
      // silently defaulting to a wrong one.
      expect(location.current!.timeZoneId, isNull);
    });
  });

  group('saved places UI', () {
    // The real app pushes LocationScreen from the home screen, and
    // selecting a place pops back. The test mirrors that: selecting must
    // pop to the host page (not destroy the tree), so the flow can
    // continue by reopening the screen.
    Future<void> pumpHost(WidgetTester tester, LocationService location) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LocationScreen(locationService: location),
                    ),
                  ),
                  child: const Text('Open location settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> openLocationScreen(WidgetTester tester) async {
      await tester.tap(find.text('Open location settings'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationScreen), findsOneWidget);
    }

    testWidgets('save current, select, and delete a place', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final location = await LocationService.load();
      await location.useManualLocation(const SavedLocation(
        name: 'Fez',
        latitude: 34.033,
        longitude: -5.0,
        timeZoneId: 'Africa/Casablanca',
      ));
      await pumpHost(tester, location);
      await openLocationScreen(tester);
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));

      // Save the current place.
      await tester.scrollUntilVisible(
        find.text(l10n.saveCurrentPlace),
        300,
        scrollable: _pageScrollable(),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(l10n.saveCurrentPlace));
      await tester.pump();
      expect(location.savedPlaces, hasLength(1));

      // Switch current to somewhere else, then select the saved place.
      await location.useManualLocation(const SavedLocation(
        name: 'Cairo',
        latitude: 30.045,
        longitude: 31.262,
        timeZoneId: 'Africa/Cairo',
      ));
      await tester.pump();
      final placeRow = find.text('Fez');
      expect(placeRow, findsWidgets);
      await tester.tap(placeRow.first);
      // Selecting pops back to the host page, like in the real app.
      await tester.pumpAndSettle();
      expect(find.byType(LocationScreen), findsNothing);
      expect(location.current!.name, 'Fez',
          reason: 'tapping the saved place makes it current');

      // Reopen the screen. The selected (current) place shows a check
      // instead of a delete button; switch away so the delete button is
      // visible, then delete (confirmation dialog first).
      await openLocationScreen(tester);
      await location.useManualLocation(const SavedLocation(
        name: 'Cairo',
        latitude: 30.045,
        longitude: 31.262,
        timeZoneId: 'Africa/Cairo',
      ));
      await tester.pump();
      // Scroll the saved-places section into view (list items build
      // lazily), then the delete button is present and tappable. A
      // manual drag loop is used: scrollUntilVisible's internal
      // element lookup misbehaves on this predicate after a route
      // push/pop cycle, while drag itself is reliable.
      final listView = find.byType(ListView);
      Future<void> dragUpUntil(Finder target) async {
        for (var i = 0;
            i < 20 && target.evaluate().isEmpty;
            i++) {
          await tester.drag(listView, const Offset(0, -300));
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(target, findsWidgets);
      }

      await dragUpUntil(find.text(l10n.savedPlacesTitle.toUpperCase()));
      final deleteButton = find.byIcon(Icons.delete_outline);
      expect(deleteButton, findsOneWidget);
      await dragUpUntil(deleteButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(find.text(l10n.deletePlaceTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, l10n.deleteAction));
      await tester.pump();
      expect(location.savedPlaces, isEmpty);
    });
  });
}
