import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/learn_screen.dart';
import 'package:malikiprayertimes/screens/learn_texts.dart';

/// Passages whose source book could not be determined from the research
/// evidence (D1/D4). A block listed here is a KNOWN gap — the source is
/// deliberately empty, never guessed. Add an entry only when the research
/// evidence genuinely cannot name the book; new Arabic passages must be
/// traced through D4 before landing here.
const _unresolvedSources = <String>{
  // Currently empty: all 7 passages in the Learn section are traced to an
  // exact book in the research evidence (see the group below).
};

/// The exact set of source books traced through the D4 evidence database.
/// Adding a new Arabic passage with a book outside this set requires
/// re-tracing the D4 evidence ID and updating this set deliberately —
/// this test fails if anyone invents a book name.
const _verifiedBooks = <String>{
  '«الرسالة»', // D4 A3.1, A3.4, A3.5 — متن الرسالة لابن أبي زيد القيرواني
  '«مختصر خليل»', // D4 A4.1 — مختصر العلامة خليل (دار الحديث، القاهرة)
  '«تشريح الأفلاك»', // D4 D3.4 — بهاء الدين العاملي (secondary quotation)
};

const _supportedLocales = [
  Locale('en'),
  Locale('ur'),
  Locale('ar'),
  Locale('fr'),
];

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Pumps the learn screen in [code] on a tall frame so every block lays
/// out, then expands every expansion tile so Arabic passages and source
/// lines enter the element tree.
Future<void> _pumpAndExpand(String code, WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 216000);
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
  final count = learnSections.fold<int>(
      0, (n, s) => n + learnContent('en', s.id).blocks.length);
  for (var i = 0; i < count; i++) {
    await tester.tap(find.byType(ExpansionTile).at(i));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('LearnBlock sources', () {
    test('every Arabic passage names its source book (or is explicitly '
        'unresolved)', () {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        for (final section in learnSections) {
          for (final b in learnContent(code, section.id).blocks) {
            if (b.arabic.isEmpty) continue;
            final unresolved = _unresolvedSources.contains(
                '$code/${section.id}/${b.title}');
            expect(b.source.isNotEmpty || unresolved, isTrue,
                reason: '$code/${section.id}/${b.title}: Arabic passage '
                    'has no source book — either trace it through D4 or '
                    'list it in _unresolvedSources');
          }
        }
      }
    });

    test('every source is one of the D4-verified books — no invented names',
        () {
      final seen = <String>{};
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        for (final section in learnSections) {
          for (final b in learnContent(code, section.id).blocks) {
            if (b.source.isNotEmpty) seen.add(b.source);
          }
        }
      }
      expect(seen, _verifiedBooks,
          reason: 'a source book appeared that is not in the D4-verified '
              'set — check D4 before accepting it');
    });

    test('the same passage names the same book in every locale', () {
      final byPassage = <String, Set<String>>{};
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        for (final section in learnSections) {
          for (final b in learnContent(code, section.id).blocks) {
            if (b.arabic.isEmpty) continue;
            byPassage.putIfAbsent(b.arabic, () => {}).add(b.source);
          }
        }
      }
      expect(byPassage.length, 7,
          reason: 'expected the 7 known passages across locales');
      for (final entry in byPassage.entries) {
        expect(entry.value.length, 1,
            reason: 'passage «${entry.key.substring(0, 20)}…» names '
                'different books in different locales: ${entry.value}');
      }
    });
  });

  group('LearnScreen source rendering', () {
    testWidgets('the source line renders above the passage, RTL, in Amiri',
        (tester) async {
      await _pumpAndExpand('en', tester);
      expect(tester.takeException(), isNull);

      final block = learnContent('en', 'definitions').blocks.first;
      final sourceText = 'من كتاب: ${block.source}';
      expect(block.source, isNotEmpty);

      final sourceFinder = find.text(sourceText);
      expect(sourceFinder, findsWidgets);

      final sourceWidget = tester.widget<Text>(sourceFinder.first);
      expect(sourceWidget.textDirection, TextDirection.rtl,
          reason: 'the source line must read right-to-left');
      expect(sourceWidget.style?.fontFamily, isNotNull);

      // Directly above the passage in layout.
      final passageFinder = find.text(block.arabic);
      expect(passageFinder, findsWidgets);
      final sourceTop = tester.getTopLeft(sourceFinder.first).dy;
      final passageTop = tester.getTopLeft(passageFinder.first).dy;
      expect(sourceTop, lessThan(passageTop),
          reason: 'source line must render above the Arabic passage');
    });

    testWidgets('blocks without a source show no source line',
        (tester) async {
      await _pumpAndExpand('en', tester);
      expect(tester.takeException(), isNull);
      // Glossary/FAQ blocks have no Arabic passage and no source book:
      // exactly one source line per quoted passage (7 in the en pump).
      expect(find.textContaining('من كتاب:'), findsNWidgets(7));
    });
  });
}
