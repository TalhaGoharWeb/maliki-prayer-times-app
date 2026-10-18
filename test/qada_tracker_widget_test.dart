import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/qada_models.dart';
import 'package:malikiprayertimes/screens/hayd_nifas_screen.dart';
import 'package:malikiprayertimes/screens/qada_modes_screen.dart';
import 'package:malikiprayertimes/screens/qada_planner_screen.dart';
import 'package:malikiprayertimes/screens/qada_screen.dart';
import 'package:malikiprayertimes/services/qada_service.dart';
import 'package:malikiprayertimes/services/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [screen] with the app's localizations in English. QadaScreen
/// renders body content only (needs a Scaffold ancestor); the other
/// screens are full Scaffolds.
Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  final Widget home =
      screen is QadaScreen ? Scaffold(body: screen) : screen;
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
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// Seeds v2 balances + a daily target through a throwaway service that
/// shares the mock preferences with the screen's own service instance.
Future<void> _seedV2({
  Map<Prayer, int> counts = const {},
  int dailyTarget = 0,
}) async {
  final seed = QadaService();
  await seed.load();
  await seed.setExactCounts(
    {
      Prayer.fajr: 0,
      Prayer.dhuhr: 0,
      Prayer.asr: 0,
      Prayer.maghrib: 0,
      Prayer.isha: 0,
      ...counts,
    },
    'user-entered 2026-10-19',
  );
  if (dailyTarget > 0) await seed.setDailyTarget(dailyTarget);
}

/// Tall phone frame so long ListViews build all their children:
/// 360x1600 logical pixels.
void _tallFrame(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Extra-tall frame (360x2700 logical) for the longest screens.
void _extraTallFrame(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 8100);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Finds a [TextField] by its (English) label text.
Finder _fieldWithLabel(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );

/// Shared in-memory secure backend so seeded bleeding records are visible
/// to the pumped screen.
SecureStore _testSecureStore() =>
    SecureStore(backend: InMemorySecureBackend());

void main() {
  group('Qada tracker dashboard', () {
    testWidgets('shows totals, progress, plan and navigation', (tester) async {
      _tallFrame(tester);

      SharedPreferences.setMockInitialValues({});
      await _seedV2(
        counts: {Prayer.fajr: 2, Prayer.dhuhr: 2, Prayer.asr: 2, Prayer.maghrib: 2, Prayer.isha: 2},
        dailyTarget: 5,
      );

      await _pumpScreen(tester, const QadaScreen());
      expect(tester.takeException(), isNull,
          reason: 'no overflow on a real-size frame');

      expect(find.text('Total remaining: 10'), findsOneWidget);
      expect(find.text('Made up: 0'), findsOneWidget);
      expect(find.text('0 of 10 made up (0%)'), findsOneWidget);
      expect(find.text('5 prayers today'), findsOneWidget);
      expect(find.text('Calculation modes'), findsOneWidget);
      expect(find.text('Planner & history'), findsOneWidget);
      expect(find.text('Hayd & Nifas tracker'), findsOneWidget);
      // The projected date is labelled as an estimate on the dashboard.
      expect(find.textContaining('Projected finish:'), findsOneWidget);
      // Exact (non-estimated) balances: no Estimated badge.
      expect(find.text('Estimated'), findsNothing);
    });

    testWidgets('shows the Estimated badge for estimated balances',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final seed = QadaService();
      await seed.load();
      final preview = await seed.previewEstimation([
        // 10 days x 1/day fajr
      ]);
      expect(preview.estimated.values.fold(0, (a, b) => a + b), 0);
      await seed.saveEstimation(preview, []);

      await _pumpScreen(tester, const QadaScreen());

      expect(find.text('Estimated'), findsOneWidget);
      expect(
        find.text(
            'Part of this balance comes from an estimation, not a confirmed count.'),
        findsOneWidget,
      );
    });
  });

  group('QadaModesScreen', () {
    testWidgets('renders all four mode sections', (tester) async {
      _extraTallFrame(tester);

      SharedPreferences.setMockInitialValues({});
      await _pumpScreen(
          tester,
          QadaModesScreen(
              secureStore:
                  SecureStore(backend: InMemorySecureBackend())));

      expect(find.text('Calculation modes'), findsWidgets);
      expect(find.text('A · EXACT COUNTS'), findsOneWidget);
      expect(find.text('B · ESTIMATE BY DATE RANGES'), findsOneWidget);
      expect(find.text('C · ESTIMATION WIZARD'), findsOneWidget);
      expect(find.text('D · MANUAL ADJUSTMENT'), findsOneWidget);
      expect(find.text('Preview estimate'), findsWidgets);
    });

    testWidgets('exact-count validation rejects bad input', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpScreen(
          tester,
          QadaModesScreen(
              secureStore:
                  SecureStore(backend: InMemorySecureBackend())));

      // First numeric field (Fajr): non-numeric input.
      await tester.enterText(find.byType(TextFormField).first, 'abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      expect(find.text('Enter a whole number, 0 or more.'),
          findsOneWidget);

      // Negative input is rejected too.
      await tester.enterText(find.byType(TextFormField).first, '-5');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      expect(find.text('Enter a whole number, 0 or more.'),
          findsOneWidget);
    });
  });

  group('HaydNifasScreen', () {
    testWidgets('shows three segments and the no-auto-classify banner',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpScreen(
          tester,
          HaydNifasScreen(
              secureStore:
                  SecureStore(backend: InMemorySecureBackend())));

      expect(find.text('Hayd'), findsWidgets);
      expect(find.text('Nifas'), findsWidgets);
      expect(find.text('Irregular'), findsWidgets);
      expect(
        find.text(
            'The app does not classify bleeding automatically. It only stores what you record. Uncertain cases need a qualified scholar.'),
        findsOneWidget,
      );
      expect(find.text('No records yet.'), findsOneWidget);
      expect(find.text('Add record'), findsOneWidget);
    });
  });

  group('QadaPlannerScreen', () {
    testWidgets('shows ETA label, reminder and history', (tester) async {
      _extraTallFrame(tester);

      SharedPreferences.setMockInitialValues({});
      await _seedV2(
        counts: {Prayer.fajr: 10},
        dailyTarget: 5,
      );

      await _pumpScreen(
          tester,
          QadaPlannerScreen(
              secureStore:
                  SecureStore(backend: InMemorySecureBackend())));
      expect(tester.takeException(), isNull,
          reason: 'no overflow on a real-size frame');

      expect(find.text('PROJECTED FINISH (ESTIMATE)'), findsOneWidget);
      expect(find.text('PLAN MODE'), findsOneWidget);
      expect(find.text('REMINDER'), findsOneWidget);
      expect(find.textContaining('never marks prayers as done'),
          findsOneWidget);
      expect(find.text('HISTORY'), findsOneWidget);
      expect(find.text('PRIVACY'), findsOneWidget);
      expect(find.text('Delete all qada data'), findsOneWidget);
    });
  });

  group('Service-throw validations (Worker B integration)', () {
    testWidgets('mode D rejects an adjustment below zero', (tester) async {
      _extraTallFrame(tester);
      SharedPreferences.setMockInitialValues({});
      await _seedV2(counts: {Prayer.fajr: 2});
      await _pumpScreen(
          tester, QadaModesScreen(secureStore: _testSecureStore()));

      await tester.enterText(
          _fieldWithLabel('Amount (negative reduces the balance)'), '-5');
      await tester.enterText(_fieldWithLabel('Reason'), 'test reason');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();

      expect(
          find.text(
              'That would take Fajr below zero (only 2 outstanding).'),
          findsOneWidget);
    });

    testWidgets('planner refuses to complete more than the balance',
        (tester) async {
      _extraTallFrame(tester);
      SharedPreferences.setMockInitialValues({});
      await _seedV2(counts: {Prayer.fajr: 2});
      await _pumpScreen(
          tester, QadaPlannerScreen(secureStore: _testSecureStore()));

      // Switch to a preset mode so only the log-made-up Save button remains.
      await tester.tap(find.text('Custom schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('After each fard'));
      await tester.pumpAndSettle();

      await tester.enterText(_fieldWithLabel('Count'), '5');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      expect(
          find.text(
              'Only 2 Fajr outstanding — the balance cannot go below zero.'),
          findsOneWidget);
    });

    testWidgets('import of malformed JSON shows an error, imports nothing',
        (tester) async {
      _extraTallFrame(tester);
      SharedPreferences.setMockInitialValues({});
      await _seedV2(counts: {Prayer.fajr: 2});
      await _pumpScreen(
          tester, QadaPlannerScreen(secureStore: _testSecureStore()));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Import backup'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'not-json{{{');
      await tester.tap(find.widgetWithText(FilledButton, 'Import backup'));
      await tester.pumpAndSettle();
      // Confirm dialog.
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();

      expect(
          find.textContaining(
              "That doesn't look like a valid backup. Nothing was imported."),
          findsOneWidget);
      // Balance untouched.
      final check = QadaService(secureStore: _testSecureStore());
      await check.load();
      expect(check.v2Counts()[Prayer.fajr], 2);
    });

    testWidgets('exemption over the balance is rejected in the dialog',
        (tester) async {
      _tallFrame(tester);
      SharedPreferences.setMockInitialValues({});
      final store = _testSecureStore();
      final seed = QadaService(secureStore: store);
      await seed.load();
      await seed.setExactCounts(
        {for (final p in Prayer.values) p: 0, Prayer.fajr: 2},
        'user-entered 2026-10-19',
      );
      await seed.saveBleedingRecord(BleedingRecord(
        id: 'r1',
        type: BleedingType.hayd,
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 5),
        status: BleedingStatus.completed,
      ));

      await _pumpScreen(tester, HaydNifasScreen(secureStore: store));
      await tester.tap(find.text('Review for exemption'));
      await tester.pumpAndSettle();

      // Fajr stepper is the first row: raise it above the balance of 2.
      final addButtons = find.byIcon(Icons.add_circle_outline);
      await tester.tap(addButtons.first);
      await tester.tap(addButtons.first);
      await tester.tap(addButtons.first);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();

      expect(
          find.text(
              'More days chosen than the outstanding balance for Fajr (2 outstanding).'),
          findsOneWidget);
    });
  });
}
