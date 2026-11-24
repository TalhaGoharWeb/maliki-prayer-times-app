import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/qada_screen.dart';
import 'package:malikiprayertimes/services/qada_service.dart';
import 'package:malikiprayertimes/services/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the qada screen with the app's localizations in English. The
/// screen loads its own [QadaService], so entries are seeded through a
/// throwaway service instance sharing the mock preferences first.
Future<void> _pumpQadaScreen(WidgetTester tester,
    {SecureStore? secureStore}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
        Locale('ar'),
        Locale('fr'),
      ],
      locale: const Locale('en'),
      home: Scaffold(body: QadaScreen(secureStore: secureStore)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QadaScreen', () {
    testWidgets('shows seeded count, mark-done decreases it', (tester) async {
      // Real-size phone frame (1080x2400 @3x).
      tester.view.physicalSize = const Size(1080, 8100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final seed = QadaService();
      await seed.load();
      await seed.logMissed(
          date: DateTime(2026, 10, 15), prayer: Prayer.fajr);

      await _pumpQadaScreen(tester);
      expect(tester.takeException(), isNull,
          reason: 'no overflow on a real-size frame');

      // The header shows the seeded count; the pending list shows the entry.
      expect(find.text('Total remaining: 1'), findsOneWidget);
      expect(find.text('2026-10-15'), findsOneWidget);
      expect(find.text('Mark done'), findsOneWidget);

      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();

      expect(find.text('Total remaining: 0'), findsOneWidget);
      expect(find.text('Mark done'), findsNothing);
      // The section header follows the app's uppercase-eyebrow convention.
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets('empty state when nothing is logged', (tester) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});

      await _pumpQadaScreen(tester);

      expect(find.text('Total remaining: 0'), findsOneWidget);
      expect(
        find.text(
            'No missed prayers logged. When you miss a prayer, log it here.'),
        findsOneWidget,
      );
      expect(find.text('Mark done'), findsNothing);
    });

    testWidgets('dashboard navigation buttons open the three screens',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 8100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      await _pumpQadaScreen(tester,
          secureStore: SecureStore(backend: InMemorySecureBackend()));

      Future<void> openAndBack(String button, Finder expectOnScreen) async {
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(expectOnScreen, findsWidgets);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Total remaining: 0'), findsOneWidget);
      }

      await openAndBack(
          'Calculation modes', find.text('B · ESTIMATE BY DATE RANGES'));
      await openAndBack(
          'Planner & history', find.text('PROJECTED FINISH (ESTIMATE)'));
      await openAndBack(
          'Hayd & Nifas tracker', find.text('Hayd & Nifas tracker'));
    });

    testWidgets('a stalled secure store does not leave the screen spinning',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'qada_v2_state': jsonEncode({'bleeding': []}),
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ur'),
            Locale('ar'),
            Locale('fr'),
          ],
          locale: const Locale('en'),
          home: Scaffold(
            body: QadaScreen(
              secureStore: SecureStore(backend: _HangingReadBackend()),
            ),
          ),
        ),
      );
      // Let the 5-second secure-store timeout fire, then rebuild.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(find.text('Total remaining: 0'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

/// Secure backend whose reads never complete (stalled keystore).
class _HangingReadBackend implements SecureBackend {
  final Map<String, String> _values = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) =>
      Completer<String?>().future;

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}
