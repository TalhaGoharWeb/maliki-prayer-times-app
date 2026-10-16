import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/saved_location.dart';
import 'package:malikiprayertimes/screens/calculation_changelog_screen.dart';
import 'package:malikiprayertimes/screens/methodology_screen.dart';
import 'package:malikiprayertimes/screens/review_record_screen.dart';
import 'package:malikiprayertimes/screens/settings_screen.dart';
import 'package:malikiprayertimes/services/location_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 1C tests for the calculation changelog: the in-app screen mirrors
/// docs/CALCULATION_CHANGELOG.md (version + parameter parity), renders with
/// the fiqh/convention integrity badges, and the settings entries that open
/// it (plus Methodology and the review record) actually open their screens.
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

/// Version headings (`## v…`) from the markdown changelog.
List<String> _mdVersions(String md) => RegExp(r'^## (v[0-9][^ \n]*)',
        multiLine: true)
    .allMatches(md)
    .map((m) => m.group(1)!)
    .toList();

/// First-column parameter names from the markdown tables. Skips the header
/// row ("parameter") and the `|---|---|` separator.
List<String> _mdParameters(String md) {
  final params = <String>[];
  for (final line in md.split('\n')) {
    if (!line.startsWith('| ')) continue;
    final first = line.split('|')[1].trim();
    if (first == 'parameter' || first.startsWith('---')) continue;
    params.add(first);
  }
  return params;
}

void main() {
  group('changelog md/screen parity', () {
    test('screen names every version in the markdown file', () {
      final md =
          File('docs/CALCULATION_CHANGELOG.md').readAsStringSync();
      final versions = _mdVersions(md);
      expect(versions, isNotEmpty,
          reason: 'no version headings found in the markdown file');
      final screenVersions =
          changelogVersions.map((e) => e.version).toList();
      for (final v in versions) {
        expect(screenVersions, contains(v),
            reason: 'changelog screen is missing version $v');
      }
    });

    test('screen carries every markdown parameter, in the same order', () {
      final md =
          File('docs/CALCULATION_CHANGELOG.md').readAsStringSync();
      final params = _mdParameters(md);
      expect(params, isNotEmpty,
          reason: 'no parameter rows found in the markdown file');
      final screenParams = [
        for (final entry in changelogVersions)
          for (final row in entry.rows) row.parameter,
      ];
      expect(screenParams, params,
          reason: 'screen parameters drifted from docs/CALCULATION_CHANGELOG.md');
    });

    test('every row carries a fiqh-derived or convention status', () {
      for (final entry in changelogVersions) {
        for (final row in entry.rows) {
          expect(row.status, isNotNull);
          expect(row.changedSince, isNotEmpty);
          expect(row.value, isNotEmpty);
        }
      }
    });
  });

  group('changelog screen rendering', () {
    Future<void> pumpChangelog(WidgetTester tester, Locale locale) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          theme: AppFonts.themeFor(locale, seedColor: Colors.teal),
          home: const CalculationChangelogScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders version, date, parameters and status badges',
        (tester) async {
      await pumpChangelog(tester, const Locale('en'));
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text('v1.2.0+5'), findsOneWidget);
      // Phase 2 added a v1.3.0+6 entry sharing the same date; it is
      // now the released build.
      expect(find.text('v1.3.0+6'), findsOneWidget);
      expect(find.text('2026-10-16'), findsWidgets);
      expect(find.text('Fajr angle'), findsOneWidget);
      expect(find.text('Asr shadow factor'), findsOneWidget);
      expect(find.text(l10n.changelogStatusConvention), findsWidgets);
      expect(find.text(l10n.changelogStatusFiqh), findsOneWidget);
      expect(find.text(l10n.changelogBaselineNote), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in ur (RTL) without overflow', (tester) async {
      await pumpChangelog(tester, const Locale('ur'));
      expect(find.text('v1.2.0+5'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'overflow on the changelog screen in ur (RTL)');
    });
  });

  group('settings wiring: method, review & changes', () {
    Future<(SettingsService, AppLocalizations)> pumpSettings(
        WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final location = await LocationService.load();
      await location.useManualLocation(const SavedLocation(
          name: 'Karachi', latitude: 24.86, longitude: 67.0));
      final coords =
          Coordinates(location.current!.latitude, location.current!.longitude);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: SettingsScreen(
            settings: settings,
            coordinates: coords,
            timeZoneOffset: DateTime.now().timeZoneOffset,
          ),
        ),
      );
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      return (settings, l10n);
    }

    Future<void> tapEntry(WidgetTester tester, String title) async {
      final entry = find.text(title);
      // The entries sit below the fold in the lazily-built settings list.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 16 && entry.evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -700));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(entry, findsOneWidget);
      await tester.ensureVisible(entry);
      await tester.pump();
      await tester.tap(entry);
      await tester.pumpAndSettle();
    }

    testWidgets('opens the Methodology screen', (tester) async {
      final (_, l10n) = await pumpSettings(tester);
      await tapEntry(tester, l10n.settingsMethodologyTitle);
      expect(find.byType(MethodologyScreen), findsOneWidget);
    });

    testWidgets('opens the review record screen', (tester) async {
      final (_, l10n) = await pumpSettings(tester);
      await tapEntry(tester, l10n.settingsReviewTitle);
      expect(find.byType(ReviewRecordScreen), findsOneWidget);
    });

    testWidgets('opens the calculation changelog screen', (tester) async {
      final (_, l10n) = await pumpSettings(tester);
      await tapEntry(tester, l10n.settingsChangelogTitle);
      expect(find.byType(CalculationChangelogScreen), findsOneWidget);
    });
  });
}
