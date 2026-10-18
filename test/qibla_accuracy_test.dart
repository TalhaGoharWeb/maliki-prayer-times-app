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

/// Fake compass: the test drives headings and quality explicitly, so no
/// platform channels are ever touched.
class FakeCompassService extends CompassService {
  final _controller = StreamController<double?>.broadcast();
  final _qualityController = StreamController<CompassQuality>.broadcast();

  @override
  Stream<double?> get headings => _controller.stream;

  @override
  Stream<CompassQuality> get quality => _qualityController.stream;

  void emit(double? heading) => _controller.add(heading);

  void emitQuality(CompassQuality quality) => _qualityController.add(quality);

  @override
  void dispose() {
    _controller.close();
    _qualityController.close();
  }
}

/// Cairo (30.0444, 31.2357): qibla bearing ≈ 136.1°.
Widget _qibla(FakeCompassService compass) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: _delegates,
    supportedLocales: _supportedLocales,
    home: Scaffold(
      body: QiblaScreen(
        coordinates: const Coordinates(30.0444, 31.2357),
        locationName: 'Cairo',
        timeZoneOffset: const Duration(hours: 2),
        compass: compass,
      ),
    ),
  );
}

void main() {
  group('HeadingSmoother', () {
    test('first sample passes through untouched', () {
      final s = HeadingSmoother();
      expect(s.update(123.0), closeTo(123.0, 1e-9));
      expect(s.value, closeTo(123.0, 1e-9));
    });

    test('step response settles within 1° without overshoot', () {
      final s = HeadingSmoother();
      for (var i = 0; i < 5; i++) {
        s.update(0.0);
      }
      double last = 0.0;
      for (var i = 0; i < 12; i++) {
        final v = s.update(90.0);
        // Monotonic approach: never steps past the target, never goes back.
        expect(v, greaterThanOrEqualTo(last - 1e-9));
        expect(v, lessThanOrEqualTo(90.0 + 1e-9));
        last = v;
      }
      expect(last, closeTo(90.0, 1.0));
    });

    test('wrap-around smooths forward through 0°, not backward', () {
      final s = HeadingSmoother();
      s.update(350.0);
      // A step from 350° to 10° is +20° forward; the smoothed value must
      // move toward 0/360, never backward toward 180°.
      final v = s.update(10.0);
      expect(v > 350.0 || v < 10.0, isTrue,
          reason: 'smoothed $v should move forward through north');
    });

    test('reset makes the next sample pass through', () {
      final s = HeadingSmoother();
      s.update(0.0);
      s.update(90.0);
      s.reset();
      expect(s.value, isNull);
      expect(s.update(200.0), closeTo(200.0, 1e-9));
    });

    test('rejects non-positive alpha', () {
      expect(() => HeadingSmoother(alpha: 0.0), throwsAssertionError);
      expect(() => HeadingSmoother(alpha: 1.0), throwsAssertionError);
    });
  });

  group('angularDifferenceDegrees', () {
    test('basic cases', () {
      expect(angularDifferenceDegrees(10, 20), closeTo(10.0, 1e-9));
      expect(angularDifferenceDegrees(20, 10), closeTo(10.0, 1e-9));
      expect(angularDifferenceDegrees(0, 180), closeTo(180.0, 1e-9));
    });

    test('wrap-around', () {
      expect(angularDifferenceDegrees(350, 10), closeTo(20.0, 1e-9));
      expect(angularDifferenceDegrees(10, 350), closeTo(20.0, 1e-9));
    });

    test('identical headings', () {
      expect(angularDifferenceDegrees(136.1, 136.1), closeTo(0.0, 1e-9));
    });
  });

  group('CompassQualityTracker', () {
    test('sane field (50 µT) is ok', () {
      final t = CompassQualityTracker();
      expect(t.addSample(30.0, 40.0, 0.0, 90.0), CompassQuality.ok);
    });

    test('weak field (5 µT) is suspect', () {
      final t = CompassQualityTracker();
      expect(t.addSample(3.0, 4.0, 0.0, 90.0), CompassQuality.suspect);
    });

    test('strong field (100 µT, near a magnet) is suspect', () {
      final t = CompassQualityTracker();
      expect(t.addSample(60.0, 80.0, 0.0, 90.0), CompassQuality.suspect);
    });

    test('band edges 25 and 65 µT are ok', () {
      final t = CompassQualityTracker();
      expect(t.addSample(25.0, 0.0, 0.0, 0.0), CompassQuality.ok);
      expect(t.addSample(65.0, 0.0, 0.0, 0.0), CompassQuality.ok);
    });

    test('three consecutive implausible jumps are suspect', () {
      final t = CompassQualityTracker();
      // Sane field, ~50 µT throughout.
      expect(t.addSample(30.0, 40.0, 0.0, 0.0), CompassQuality.ok);
      expect(t.addSample(30.0, 40.0, 0.0, 100.0), CompassQuality.ok);
      expect(t.addSample(30.0, 40.0, 0.0, 200.0), CompassQuality.ok);
      expect(t.addSample(30.0, 40.0, 0.0, 300.0), CompassQuality.suspect);
    });

    test('small moves reset the jump streak', () {
      final t = CompassQualityTracker();
      expect(t.addSample(30.0, 40.0, 0.0, 0.0), CompassQuality.ok);
      expect(t.addSample(30.0, 40.0, 0.0, 100.0), CompassQuality.ok);
      expect(t.addSample(30.0, 40.0, 0.0, 200.0), CompassQuality.ok);
      // A gentle move breaks the streak: no longer suspect.
      expect(t.addSample(30.0, 40.0, 0.0, 205.0), CompassQuality.ok);
    });

    test('null heading still assesses the field', () {
      final t = CompassQualityTracker();
      expect(t.addSample(3.0, 4.0, 0.0, null), CompassQuality.suspect);
      expect(t.addSample(30.0, 40.0, 0.0, null), CompassQuality.ok);
    });
  });

  group('QiblaScreen alignment + quality UI', () {
    testWidgets('aligned state shows within ±2° of the bearing',
        (tester) async {
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass));
      await tester.pump();
      // Cairo bearing ≈ 136.1°: heading exactly on it must read aligned.
      compass.emit(136.1);
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.qiblaAligned), findsOneWidget);
      expect(find.text(l10n.degreesOff('0')), findsNothing);
    });

    testWidgets('degrees-off readout shows when not aligned',
        (tester) async {
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass));
      await tester.pump();
      compass.emit(100.0);
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      // |136.1 − 100| ≈ 36°.
      expect(find.text(l10n.degreesOff('36')), findsOneWidget);
      expect(find.text(l10n.qiblaAligned), findsNothing);
    });

    testWidgets('suspect quality surfaces the calibration warning',
        (tester) async {
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass));
      await tester.pump();
      compass.emit(90.0);
      await tester.pump();
      compass.emitQuality(CompassQuality.suspect);
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      // The calibration card (with its unique suspect body) is below the
      // fold: scroll it into view.
      await tester.scrollUntilVisible(
        find.text(l10n.calibrationNeededBody),
        800,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.calibrationNeededBody), findsOneWidget);
      // Title appears in both the dial warning banner and the card.
      expect(find.text(l10n.calibrationNeeded), findsNWidgets(2));
    });

    testWidgets('no warning while quality is ok', (tester) async {
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass));
      await tester.pump();
      compass.emit(90.0);
      await tester.pump();
      compass.emitQuality(CompassQuality.ok);
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.calibrationNeeded), findsNothing);
      expect(find.text(l10n.calibrationNeededBody), findsNothing);
    });
  });
}
