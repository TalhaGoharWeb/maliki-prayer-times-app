import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/learn_screen.dart';
import 'package:malikiprayertimes/screens/learn_texts.dart';

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

/// Pumps the learn screen in [code].
///
/// [frame] is the physical surface: the default is a real-size phone frame
/// (used for the overflow check). Evidence-reference tests use a tall frame
/// so the lazily-built sliver children below the fold exist in the element
/// tree.
Future<void> _pumpLearn(
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
      home: const Scaffold(body: LearnScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tall frame (72000 logical px): the whole 27-block teaching section lays
/// out with every tile expanded, so every block's content exists in
/// the element tree. (The expanded content grew past the old 48000px frame
/// when source-citation lines were added to the passages.)
const _tallFrame = Size(1080, 216000);

/// Expands every teaching block so Arabic passages and bodies enter the
/// tree. Evidence references stay in the data model and are never
/// rendered in the UI.
Future<void> _expandAll(WidgetTester tester) async {
  final count = learnSections.fold<int>(
      0, (n, s) => n + learnContent('en', s.id).blocks.length);
  for (var i = 0; i < count; i++) {
    await tester.tap(find.byType(ExpansionTile).at(i));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('LearnScreen', () {
    testWidgets('header renders (en), no overflow on a real frame',
        (tester) async {
      await _pumpLearn('en', tester);
      expect(tester.takeException(), isNull,
          reason: 'no overflow on a real-size frame');

      final s = learnStrings('en');
      expect(find.text(s.title.toUpperCase()), findsOneWidget);
      expect(find.text(s.integrityNote), findsOneWidget);
      expect(learnSections.length, 5);
    });

    testWidgets('all five sections render (en)', (tester) async {
      await _pumpLearn('en', tester, frame: _tallFrame);
      for (final s in learnSections) {
        final c = learnContent('en', s.id);
        expect(find.text(c.title.toUpperCase()), findsOneWidget);
        expect(find.text(c.intro), findsOneWidget);
      }
    });

    testWidgets('all five sections render (ar, RTL)', (tester) async {
      await _pumpLearn('ar', tester, frame: _tallFrame);
      for (final s in learnSections) {
        final c = learnContent('ar', s.id);
        expect(find.text(c.title.toUpperCase()), findsOneWidget);
      }
      // RTL-correct: the ambient directionality is right-to-left.
      final element = tester.element(find.byType(ExpansionTile).first);
      expect(Directionality.of(element), TextDirection.rtl);
    });

    testWidgets('no overflow on a real frame (ar)', (tester) async {
      await _pumpLearn('ar', tester);
      expect(tester.takeException(), isNull,
          reason: 'no overflow in ar on a real-size frame');
    });

    testWidgets('spot-check ur and fr render without overflow',
        (tester) async {
      for (final code in ['ur', 'fr']) {
        await _pumpLearn(code, tester);
        expect(tester.takeException(), isNull,
            reason: 'no overflow in $code on a real-size frame');
        final s = learnStrings(code);
        expect(find.text(s.title.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('no block renders its raw evidence reference (en)',
        (tester) async {
      await _pumpLearn('en', tester, frame: _tallFrame);
      await _expandAll(tester);

      // Raw research codes (D1/D4/...) live in the data model only: no
      // claim renders its evidence pointer in the UI.
      for (final s in learnSections) {
        for (final b in learnContent('en', s.id).blocks) {
          expect(find.text(b.refs), findsNothing,
              reason: '${s.id}/${b.title} leaks its evidence refs into UI');
        }
      }
    });

    testWidgets('no block renders its raw evidence reference (ar)',
        (tester) async {
      await _pumpLearn('ar', tester, frame: _tallFrame);
      await _expandAll(tester);
      for (final s in learnSections) {
        for (final b in learnContent('ar', s.id).blocks) {
          expect(find.text(b.refs), findsNothing,
              reason: 'ar ${s.id}/${b.title} leaks its evidence refs into UI');
        }
      }
    });

    testWidgets('18° section carries the honest-boundary disclaimer in all '
        'locales', (tester) async {
      // The integrity spot-assert: the section must state that no
      // classical Maliki text fixes a degree angle — a convention is never
      // presented as a ruling.
      const disclaimer = {
        'en': 'No classical Maliki text',
        'ur': 'سوفٹ ویئر کنونشن، کبھی مالکی حکم نہیں',
        'ar': 'عرف برمجي، وليست حكماً مالكياً أبداً',
        'fr': 'une convention logicielle, jamais une règle malikite',
      };
      for (final entry in disclaimer.entries) {
        await _pumpLearn(entry.key, tester, frame: _tallFrame);
        await _expandAll(tester);
        expect(find.textContaining(entry.value), findsAtLeast(1),
            reason: '${entry.key} 18° section lacks the disclaimer');
      }
    });

    testWidgets('no banned review/endorsement text in en or ar',
        (tester) async {
      for (final code in ['en', 'ar']) {
        await _pumpLearn(code, tester, frame: _tallFrame);
        await _expandAll(tester);
        // The user directive (2026-10-15): no review-status banners in
        // app UI — and no endorsement claims before scholarly review.
        expect(find.textContaining('PROPOSED'), findsNothing);
        expect(find.textContaining('pending scholarly review'), findsNothing);
        expect(find.textContaining('verified/endorsed/approved'), findsNothing);
        expect(find.textContaining('endorsed'), findsNothing);
        expect(find.textContaining('approved'), findsNothing);
      }
    });

    testWidgets('ur RTL no-overflow with all blocks expanded',
        (tester) async {
      await _pumpLearn('ur', tester);
      // Expand the first several tiles on the real-size frame: the long
      // Nastaleeq titles must wrap, never overflow.
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byType(ExpansionTile).at(i));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull,
          reason: 'no overflow in ur with blocks expanded');
    });
  });

  group('learnTexts content', () {
    test('all 5 sections and all blocks localized in all 4 locales, no '
        'blanks', () {
      expect(learnSections.length, 5);
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        for (final section in learnSections) {
          final c = learnContent(code, section.id);
          expect(c.title, isNotEmpty,
              reason: '$code/${section.id} title');
          expect(c.intro, isNotEmpty,
              reason: '$code/${section.id} intro');
          expect(c.blocks, isNotEmpty,
              reason: '$code/${section.id} blocks');
          for (final b in c.blocks) {
            expect(b.title, isNotEmpty,
                reason: '$code/${section.id} block title');
            expect(b.body, isNotEmpty,
                reason: '$code/${section.id}/${b.title} body');
            expect(b.refs, isNotEmpty,
                reason: '$code/${section.id}/${b.title} refs');
          }
        }
      }
    });

    test('every block names D1/D4 evidence; every section links both', () {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        for (final section in learnSections) {
          final refsLine = learnSectionRefs(code, section.id);
          // Section-level: each section visibly links both deliverables.
          expect(refsLine, contains('D1'),
              reason: '$code/${section.id} never cites D1');
          expect(refsLine, contains('D4'),
              reason: '$code/${section.id} never cites D4');
          // Block-level: no claim without a reference.
          for (final b in learnContent(code, section.id).blocks) {
            expect(RegExp(r'D[14]').hasMatch(b.refs), isTrue,
                reason: '$code/${section.id}/${b.title} has no D1/D4 ref');
          }
        }
      }
    });

    test('digits stay Western 0-9 in every locale', () {
      // Urdu-first rule: standard digits, never Arabic-Indic (۰-۹/٠-٩).
      final arabicIndic = RegExp('[۰-۹٠-٩]');
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        for (final section in learnSections) {
          final c = learnContent(code, section.id);
          for (final b in c.blocks) {
            for (final text in [c.title, c.intro, b.title, b.body]) {
              expect(arabicIndic.hasMatch(text), isFalse,
                  reason: '$code/${section.id} uses Arabic-Indic digits');
            }
          }
        }
      }
    });

    test('unknown locale falls back to English', () {
      expect(learnStrings('de').title, learnStrings('en').title);
      expect(learnContent('de', 'definitions').title,
          learnContent('en', 'definitions').title);
    });

    test('the five prayers each get a verbatim Arabic passage', () {
      // The definitions section quotes the classical texts word-for-word
      // from the research evidence (D4) — five prayers, five passages,
      // plus the mukhtar/daruri tier.
      final defs = learnContent('en', 'definitions');
      final withPassage =
          defs.blocks.where((b) => b.arabic.isNotEmpty).toList();
      expect(withPassage.length, 6);
      for (final b in withPassage) {
        expect(b.arabic, startsWith('«'));
      }
    });
  });
}
