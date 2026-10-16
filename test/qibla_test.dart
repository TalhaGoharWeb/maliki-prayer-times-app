import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/qibla_screen.dart';
import 'package:malikiprayertimes/services/compass_service.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/qibla.dart';
import 'package:malikiprayertimes/utils/solar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brings a sun-card control fully into the 800x600 test viewport so taps
/// land: [WidgetTester.scrollUntilVisible] stops as soon as the widget is
/// *built* (ListView cache extent), which can leave its center offscreen
/// where taps silently miss; [WidgetTester.ensureVisible] finishes the job.
Future<void> _scrollCardIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300.0);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

void main() {
  group('published city bearings (±0.5°)', () {
    // Reference bearings are great-circle initial bearings from the city
    // center to the Kaaba (21.4225 N, 39.8262 E), published at
    // https://makkahlive.net/en/tools/qibla (checked 2026-10-15):
    // London 119.0°, New York 58.5°, Karachi 267.7°.
    // (A second source lists New York ≈ 58° and London ≈ 119°:
    // https://medium.com/@fr3reza/before-you-arrive-know-which-way-to-pray-the-global-qibla-directory-every-traveling-muslim-needs-d08b19ccd4a2)
    test('London (51.5074, -0.1278) ≈ 119.0°', () {
      expect(qiblaBearingDegrees(51.5074, -0.1278), closeTo(119.0, 0.5));
    });

    test('New York (40.7128, -74.0060) ≈ 58.5°', () {
      expect(qiblaBearingDegrees(40.7128, -74.0060), closeTo(58.5, 0.5));
    });

    test('Karachi (24.8607, 67.0011) ≈ 267.7°', () {
      expect(qiblaBearingDegrees(24.8607, 67.0011), closeTo(267.7, 0.5));
    });
  });

  group('range', () {
    test('result is always within 0..360', () {
      for (final (lat, lon) in [
        (0.0, 0.0),
        (90.0, 0.0),
        (-90.0, 0.0),
        (51.5074, -0.1278),
        (-33.8688, 151.2093), // Sydney
        (18.08581, -15.9785), // Nouakchott
      ]) {
        final b = qiblaBearingDegrees(lat, lon);
        expect(b.isFinite, isTrue, reason: 'finite at ($lat, $lon)');
        expect(b, greaterThanOrEqualTo(0.0));
        expect(b, lessThan(360.0));
      }
    });
  });

  group('degenerate points', () {
    test('at the Kaaba itself the bearing is a finite 0..360 value', () {
      final b = qiblaBearingDegrees(kaabaLatitude, kaabaLongitude);
      expect(b.isFinite, isTrue);
      expect(b, greaterThanOrEqualTo(0.0));
      expect(b, lessThan(360.0));
    });

    test('at the antipode of the Kaaba the bearing is finite', () {
      final b = qiblaBearingDegrees(-kaabaLatitude, kaabaLongitude - 180.0);
      expect(b.isFinite, isTrue);
      expect(b, greaterThanOrEqualTo(0.0));
      expect(b, lessThan(360.0));
    });
  });

  group('direction sanity', () {
    test('Nouakchott faces roughly east-northeast', () {
      // The Kaaba (21.4 N, 39.8 E) lies east and slightly north of
      // Nouakchott (18.1 N, 16.0 W), so the bearing must be in the
      // north-east quadrant, closer to east than to north.
      final b = qiblaBearingDegrees(18.08581, -15.9785);
      expect(b, greaterThan(45.0));
      expect(b, lessThan(135.0));
    });

    test('Karachi faces west', () {
      final b = qiblaBearingDegrees(24.8607, 67.0011);
      expect(b, greaterThan(180.0));
      expect(b, lessThan(360.0));
    });
  });

  group('sunReminderSchedulable (REL-06)', () {
    // alignWall 10:15 wall-clock at UTC+5 == 05:15 UTC true instant.
    final alignWall = DateTime.utc(2026, 5, 1, 10, 15);
    const offset = Duration(hours: 5);

    test('past event is not schedulable', () {
      expect(
        sunReminderSchedulable(alignWall, offset, DateTime.utc(2026, 5, 1, 7)),
        isFalse,
      );
    });

    test('future event is schedulable', () {
      expect(
        sunReminderSchedulable(alignWall, offset, DateTime.utc(2026, 5, 1, 4)),
        isTrue,
      );
    });

    test('exactly-now is not schedulable', () {
      expect(
        sunReminderSchedulable(
            alignWall, offset, DateTime.utc(2026, 5, 1, 5, 15)),
        isFalse,
      );
    });
  });

  group('SunAlignCard reminder (REL-06)', () {
    testWidgets('past alignment shows the passed note and schedules nothing',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);
      await tester.pumpWidget(_qibla(
        compass: compass,
        timeZoneOffset: const Duration(hours: -26),
        notifications: service,
      ));
      await tester.pump();
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      // The card sits below the fold in the test viewport: scroll it in.
      await tester.scrollUntilVisible(
          find.text(l10n.sunAlignPassed), 300.0);
      expect(find.text(l10n.sunAlignPassed), findsOneWidget);
      expect(find.text(l10n.remindMe), findsNothing);
      expect(fake.scheduled, isEmpty);
    });

    testWidgets(
        'future alignment: tapping Remind me schedules the true UTC instant',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);
      const offset = Duration(hours: 26);
      await tester.pumpWidget(_qibla(
        compass: compass,
        timeZoneOffset: offset,
        notifications: service,
      ));
      await tester.pump();
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      // The card sits below the fold in the test viewport: scroll it in.
      await _scrollCardIntoView(tester, find.text(l10n.remindMe));
      expect(find.text(l10n.remindMe), findsOneWidget);
      await tester.tap(find.text(l10n.remindMe));
      await tester.pump();
      await tester.pump();
      expect(fake.scheduled, hasLength(1));
      final scheduled = fake.scheduled.single;
      expect(scheduled.id, NotificationService.sunReminderId);
      // The true UTC instant of the event: recompute the wall-date alignment
      // the card shows and convert the wall reading back to UTC.
      final bearing = qiblaBearingDegrees(30.0444, 31.2357);
      final now = DateTime.now().toUtc().add(offset);
      final today = DateTime(now.year, now.month, now.day);
      final alignUtc =
          sunAlignmentUtcHours(30.0444, 31.2357, today, bearing)!;
      final expectedUtc = DateTime.utc(today.year, today.month, today.day)
          .add(Duration(microseconds: (alignUtc * 3600 * 1e6).round()));
      expect(scheduled.scheduledUtc, expectedUtc);
      // Card flips to the scheduled state with a cancel affordance.
      expect(find.text(l10n.cancelReminder), findsOneWidget);
    });
  });

  group('SunAlignCard persistence (REL-16)', () {
    testWidgets('future-dated persisted reminder starts in scheduled state',
        (tester) async {
      final futureUtc = DateTime.now().toUtc().add(const Duration(hours: 2));
      SharedPreferences.setMockInitialValues(
          {'sun_reminder_utc': futureUtc.toIso8601String()});
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);
      await tester.pumpWidget(_qibla(
        compass: compass,
        timeZoneOffset: const Duration(hours: 26),
        notifications: service,
      ));
      await tester.pump();
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      // The card sits below the fold in the test viewport: scroll it in.
      await tester.scrollUntilVisible(
          find.text(l10n.cancelReminder), 300.0);
      expect(find.text(l10n.cancelReminder), findsOneWidget);
      expect(find.text(l10n.remindMe), findsNothing);
      expect(fake.scheduled, isEmpty);
    });

    testWidgets('cancel clears the scheduler, prefs, and the card state',
        (tester) async {
      final futureUtc = DateTime.now().toUtc().add(const Duration(hours: 2));
      SharedPreferences.setMockInitialValues(
          {'sun_reminder_utc': futureUtc.toIso8601String()});
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      final fake = FakeNotificationScheduler();
      final service = NotificationService(scheduler: fake);
      await tester.pumpWidget(_qibla(
        compass: compass,
        timeZoneOffset: const Duration(hours: 26),
        notifications: service,
      ));
      await tester.pump();
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      // The card sits below the fold in the test viewport: scroll it in.
      await _scrollCardIntoView(tester, find.text(l10n.cancelReminder));
      expect(find.text(l10n.cancelReminder), findsOneWidget);
      await tester.tap(find.text(l10n.cancelReminder));
      await tester.pump();
      await tester.pump();
      expect(fake.cancelledIds,
          contains(NotificationService.sunReminderId));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sun_reminder_utc'), isNull);
      expect(find.text(l10n.cancelReminder), findsNothing);
      expect(find.text(l10n.remindMe), findsOneWidget);
    });
  });

  group('heading throttle (REL-08)', () {
    testWidgets('100 rapid same-degree headings cause a bounded rebuild count',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      var builds = 0;
      await tester.pumpWidget(_qibla(
        compass: compass,
        onBuild: () => builds++,
      ));
      await tester.pump();
      final baseline = builds;
      for (var i = 0; i < 100; i++) {
        compass.emit(45.0 + i * 0.001); // every reading rounds to 45
        await tester.pump();
      }
      // The first heading flips live-ness (one rebuild); the remaining 99
      // are throttled away. (Unthrottled code rebuilds ~100 times here.)
      expect(builds - baseline, lessThanOrEqualTo(2));
    });

    testWidgets('a genuine heading change still updates the UI',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(_qibla(compass: compass));
      await tester.pump();
      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.liveBadge), findsNothing);
      compass.emit(90.0);
      await tester.pump();
      expect(find.text(l10n.liveBadge), findsOneWidget);
      compass.emit(120.0); // ≥1° change
      await tester.pump();
      expect(find.text(l10n.liveHeading('120')), findsOneWidget);
    });
  });

  group('static dial semantics digits (I-13)', () {
    testWidgets('ar static-fallback label contains no Western digits',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final compass = FakeCompassService();
      addTearDown(compass.dispose);
      await tester.pumpWidget(
          _qibla(compass: compass, locale: const Locale('ar')));
      await tester.pump();
      compass.emit(null); // force the static fallback dial
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      final bearing = qiblaBearingDegrees(30.0444, 31.2357);
      final expectedLabel = l10n.qiblaBearing(
          localizeDigits(bearing.toStringAsFixed(1), 'ar'));
      expect(RegExp(r'[0-9]').hasMatch(expectedLabel), isFalse,
          reason: 'ar semantics label must not contain Western digits');
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            widget.properties.label == expectedLabel),
        findsOneWidget,
      );
    });
  });
}

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

/// Cairo (30.0444, 31.2357): its qibla bearing (136.1°) lies inside the sun's
/// daily azimuth sweep year-round, so a sun–qibla alignment exists on every
/// civil date — the alignment card always renders in these tests.
///
/// The ±26h offsets are deliberately non-physical: with −26h the wall date
/// sits ~a day back, so its alignment instant is *guaranteed* in the past
/// (alignment hour < 24h < 26h elapsed); with +26h it is guaranteed future.
Widget _qibla({
  required FakeCompassService compass,
  Duration timeZoneOffset = const Duration(hours: 5),
  NotificationService? notifications,
  VoidCallback? onBuild,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: _delegates,
    supportedLocales: _supportedLocales,
    home: Scaffold(
      body: QiblaScreen(
        coordinates: const Coordinates(30.0444, 31.2357),
        locationName: 'Cairo',
        timeZoneOffset: timeZoneOffset,
        compass: compass,
        notifications: notifications,
        onBuild: onBuild,
      ),
    ),
  );
}
