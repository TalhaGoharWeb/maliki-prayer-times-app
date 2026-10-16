import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/methodology_screen.dart';
import 'package:malikiprayertimes/screens/methodology_texts.dart';

const _supportedLocales = [
  Locale('en'),
  Locale('ur'),
  Locale('ar'),
  Locale('fr'),
];

/// The repo's standard localization delegates: ExpansionTile reads
/// MaterialLocalizations for its semantics hints, so `ar`/`ur` renders
/// need the delegates present (as in the real app) for the tile children
/// to inflate.
const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Pumps the methodology screen in [code].
///
/// [frame] is the physical surface: the default is a real-size phone frame
/// (used for the overflow check). Badge/count tests use a tall frame so the
/// lazily-built sliver children below the fold exist in the element tree.
Future<void> _pumpMethodology(
  String code,
  WidgetTester tester, {
  Size frame = const Size(1080, 2400),
}) async {
  tester.view.physicalSize = frame;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(code),
      localizationsDelegates: _delegates,
      supportedLocales: _supportedLocales,
      home: const Scaffold(body: MethodologyScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tall frame (4000 logical px): the whole 24-row table lays out, so every
/// row's badge and tile exists in the element tree.
const _tallFrame = Size(1080, 12000);

/// Expands every method-table row so detail text enters the tree.
Future<void> _expandAll(WidgetTester tester) async {
  for (var i = 0; i < methodologyRows.length; i++) {
    await tester.tap(find.byType(ExpansionTile).at(i));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('MethodologyScreen', () {
    testWidgets('header shows profile name, version and data vintage',
        (tester) async {
      await _pumpMethodology('en', tester);
      expect(tester.takeException(), isNull,
          reason: 'no overflow on a real-size frame');

      final s = methodologyStrings('en');
      expect(find.text(s.title.toUpperCase()), findsOneWidget);
      expect(find.textContaining('Maliki — MWL West Africa'), findsOneWidget);
      expect(find.textContaining(s.versionValue), findsOneWidget);
      expect(find.textContaining('2026-10-16'), findsOneWidget);
    });

    testWidgets('badge counts match row statuses (en)', (tester) async {
      await _pumpMethodology('en', tester, frame: _tallFrame);
      final s = methodologyStrings('en');
      final fiqh = methodologyRows
          .where((r) => r.status == MethodStatus.fiqhDerived)
          .length;
      final conv = methodologyRows
          .where((r) => r.status == MethodStatus.convention)
          .length;

      // Every row renders exactly one badge labeled by its own status:
      // the counts prove no convention row wears a fiqh badge and no
      // fiqh row wears a convention badge.
      expect(find.text(s.badgeFiqh), findsNWidgets(fiqh));
      expect(find.text(s.badgeConvention), findsNWidgets(conv));
      expect(fiqh, greaterThan(0));
      expect(conv, greaterThan(0));
    });

    testWidgets('badge counts match row statuses (ar, RTL)', (tester) async {
      await _pumpMethodology('ar', tester, frame: _tallFrame);
      final s = methodologyStrings('ar');
      expect(find.text(s.badgeFiqh), findsNWidgets(10));
      expect(find.text(s.badgeConvention), findsNWidgets(14));

      // RTL-correct: the ambient directionality is right-to-left.
      final element = tester.element(find.byType(ExpansionTile).first);
      expect(Directionality.of(element), TextDirection.rtl);
    });

    testWidgets('expanding rows shows details; no banned review text',
        (tester) async {
      await _pumpMethodology('en', tester, frame: _tallFrame);
      await _expandAll(tester);

      // A detail line from a convention row is now visible.
      final fajr = methodologyText('en', 'fajr-angle');
      expect(find.text(fajr.detail), findsOneWidget);

      // The banned banner phrasing never appears in the app UI.
      expect(find.textContaining('PROPOSED'), findsNothing);
      expect(find.textContaining('pending scholarly review'), findsNothing);
      expect(find.textContaining('verified/endorsed/approved'), findsNothing);
    });

    testWidgets('no banned review text in ar rendering', (tester) async {
      await _pumpMethodology('ar', tester, frame: _tallFrame);
      await _expandAll(tester);
      expect(find.textContaining('PROPOSED'), findsNothing);
      expect(find.textContaining('pending scholarly review'), findsNothing);
    });
  });

  group('methodologyTexts content', () {
    test('all 24 rows localized in all 4 locales, no blanks', () {
      expect(methodologyRows.length, 24);
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        for (final row in methodologyRows) {
          final t = methodologyText(code, row.id);
          expect(t.parameter, isNotEmpty, reason: '$code/${row.id} parameter');
          expect(t.value, isNotEmpty, reason: '$code/${row.id} value');
          expect(t.detail, isNotEmpty, reason: '$code/${row.id} detail');
        }
      }
    });

    test('every convention row carries an explicit disclaimer in its '
        'detail', () {
      // The integrity rule from the plan: software conventions are NEVER
      // presented as Maliki rulings. Every convention row's detail line
      // must therefore contain an explicit disclaimer word naming it as a
      // convention / institutional / software decision.
      const disclaimers = {
        'en': [
          'convention', 'institutional', 'policy decision', 'proxy',
          'not a matn', 'alternative convention', 'software',
        ],
        'ur': [
          'کنونشن', 'ادارہ جاتی', 'پالیسی', 'پراکسی', 'متنی قدر نہیں',
          'متبادل کنونشن', 'سوفٹ ویئر',
        ],
        'ar': [
          'عرف', 'مؤسسي', 'سياسة', 'وكيل', 'متنية', 'عرف بديل', 'برمجي',
        ],
        'fr': [
          'convention', 'institutionnelle', 'politique', 'proxy', 'matn',
          'convention alternative', 'logicielle',
        ],
      };
      for (final row in methodologyRows) {
        if (row.status != MethodStatus.convention) continue;
        for (final entry in disclaimers.entries) {
          final detail =
              methodologyText(entry.key, row.id).detail.toLowerCase();
          final has =
              entry.value.any((w) => detail.contains(w.toLowerCase()));
          expect(has, isTrue,
              reason: '${entry.key}/${row.id} lacks a disclaimer');
        }
      }
    });

    test('unknown locale falls back to English', () {
      expect(methodologyStrings('de').title,
          methodologyStrings('en').title);
      expect(methodologyText('de', 'fajr-angle').parameter,
          methodologyText('en', 'fajr-angle').parameter);
    });

    test('badge labels are status-consistent', () {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        expect(
            methodologyBadgeText(code, MethodStatus.fiqhDerived),
            methodologyStrings(code).badgeFiqh);
        expect(
            methodologyBadgeText(code, MethodStatus.convention),
            methodologyStrings(code).badgeConvention);
      }
    });
  });
}
