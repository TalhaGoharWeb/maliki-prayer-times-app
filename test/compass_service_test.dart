import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/qibla_screen.dart';
import 'package:malikiprayertimes/services/compass_service.dart';

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

/// Fake compass: the test drives headings explicitly, so no platform
/// channels are ever touched.
class FakeCompassService extends CompassService {
  final _controller = StreamController<double?>.broadcast();

  @override
  Stream<double?> get headings => _controller.stream;

  void emit(double? heading) => _controller.add(heading);

  @override
  void dispose() => _controller.close();
}

Widget _qibla(FakeCompassService compass) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: _delegates,
    supportedLocales: _supportedLocales,
    home: Scaffold(
      body: QiblaScreen(
        coordinates: const Coordinates(24.86, 67.0),
        locationName: 'Karachi',
        timeZoneOffset: const Duration(hours: 5),
        compass: compass,
      ),
    ),
  );
}

void main() {
  group('tiltCompensatedHeading', () {
    // Device flat face-up (accelerometer reads +g on z); magnetic field
    // points north and downward (northern hemisphere).
    const ax = 0.0, ay = 0.0, az = 9.8;
    const dip = -10.0; // downward component in device coords

    test('top of phone pointing magnetic north reads 0', () {
      final h = tiltCompensatedHeading(ax, ay, az, 0.0, 50.0, dip);
      expect(h, isNotNull);
      expect(h!, closeTo(0.0, 1e-9));
    });

    test('top of phone pointing east reads 90', () {
      final h = tiltCompensatedHeading(ax, ay, az, -50.0, 0.0, dip);
      expect(h, isNotNull);
      expect(h!, closeTo(90.0, 1e-9));
    });

    test('top of phone pointing south reads 180', () {
      final h = tiltCompensatedHeading(ax, ay, az, 0.0, -50.0, dip);
      expect(h, isNotNull);
      expect(h!, closeTo(180.0, 1e-9));
    });

    test('top of phone pointing west reads 270', () {
      final h = tiltCompensatedHeading(ax, ay, az, 50.0, 0.0, dip);
      expect(h, isNotNull);
      expect(h!, closeTo(270.0, 1e-9));
    });

    test('zero accelerometer vector returns null', () {
      expect(tiltCompensatedHeading(0, 0, 0, 0, 50, dip), isNull);
    });

    test('magnetic field parallel to accelerometer returns null', () {
      // Phone in free-fall alignment: M x U == 0.
      expect(tiltCompensatedHeading(0, 0, 9.8, 0, 0, 50), isNull);
    });

    test('result is always in [0, 360)', () {
      final h = tiltCompensatedHeading(ax, ay, az, 50.0, 0.01, dip);
      expect(h, isNotNull);
      final heading = h ?? 0.0;
      expect(heading, inInclusiveRange(0.0, 360.0));
      expect(heading < 360.0, isTrue);
    });
  });

  group('QiblaScreen live dial', () {
    testWidgets('shows acquiring state before the first reading',
        (tester) async {
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass));
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.compassAcquiring), findsOneWidget);
      expect(find.text(l10n.liveBadge), findsNothing);
    });

    testWidgets('LIVE badge and heading appear on sensor readings',
        (tester) async {
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass));
      await tester.pump();
      compass.emit(90.0);
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.liveBadge), findsOneWidget);
      expect(find.text(l10n.liveHeading('90')), findsOneWidget);
      expect(find.text(l10n.calibrationHint), findsOneWidget);
      expect(find.text(l10n.compassUnavailable), findsNothing);
    });

    testWidgets('null reading falls back to the static dial with a note',
        (tester) async {
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass));
      await tester.pump();
      compass.emit(null);
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.compassUnavailable), findsOneWidget);
      expect(find.text(l10n.liveBadge), findsNothing);
      expect(find.text(l10n.northUp), findsOneWidget);
    });

    testWidgets('keeps the qibla info rows in live mode', (tester) async {
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass));
      await tester.pump();
      compass.emit(45.0);
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      // Info rows survive regardless of compass mode.
      expect(find.text(l10n.greatCircle), findsOneWidget);
      expect(find.text(l10n.rhumbLine), findsOneWidget);
      expect(find.text(l10n.trueNorthOffset), findsOneWidget);
      // The calibration card is below the fold: scroll it into view.
      await tester.scrollUntilVisible(
        find.text(l10n.calibrationTitle),
        800,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.calibrationTitle), findsOneWidget);
    });
  });
}
