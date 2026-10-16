import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/review_status.dart';
import 'package:malikiprayertimes/screens/review_record_screen.dart';
import 'package:malikiprayertimes/services/review_packet_service.dart';

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

Future<void> _pumpReviewScreen(
  WidgetTester tester,
  Locale locale, {
  Future<void> Function(String text, String subject)? shareFn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: _delegates,
      supportedLocales: _supportedLocales,
      locale: locale,
      home: Scaffold(body: ReviewRecordScreen(shareFn: shareFn)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('buildReviewPacket', () {
    test('contains all 26 questions in English, Arabic, and French',
        () async {
      for (final code in ['en', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        final packet = buildReviewPacket(l10n,
            packetDate: DateTime(2026, 10, 16));
        expect(packet, contains(l10n.reviewPacketTitle), reason: code);
        expect(packet, contains(l10n.reviewPacketIntro), reason: code);
        expect(packet, contains('2026-10-16'), reason: '$code date');
        for (final item in ReviewRegistry.allItems()) {
          expect(packet, contains(reviewQuestionText(l10n, item)),
              reason: '$code ${item.id} question');
          expect(packet, contains(reviewWhyText(l10n, item)),
              reason: '$code ${item.id} why');
          expect(packet, contains(reviewEvidenceText(l10n, item)),
              reason: '$code ${item.id} evidence');
          expect(packet, contains('### ${item.id}'), reason: '$code ${item.id}');
        }
        for (final group in ReviewRegistry.groupOrder()) {
          expect(packet, contains(reviewGroupLabel(l10n, group)),
              reason: '$code $group header');
        }
        expect(packet, contains(l10n.reviewPacketAnswerPrompt), reason: code);
      }
    });

    test('keeps fixed Arabic terms Arabic in every packet language',
        () async {
      for (final code in ['en', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        final packet = buildReviewPacket(l10n);
        expect(packet, contains('واثم الا لعذر'),
            reason: '$code keeps the daruri matn in Arabic');
      }
    });

    test('packet never claims endorsement or approval', () async {
      // "fiqh-verified" is D7's own evidence-status vocabulary for source
      // attestation (e.g. Q2, Q5); the ban here is on app-level claims.
      final banned = ['endorsed', 'approved'];
      for (final code in ['en', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        final packet = buildReviewPacket(l10n).toLowerCase();
        for (final word in banned) {
          expect(packet, isNot(contains(word)),
              reason: '$code packet contains "$word"');
        }
        // The honest disclaimer is present in every language.
        expect(packet,
            contains(l10n.reviewPacketIntro.toLowerCase()), reason: code);
      }
    });
  });

  group('shareReviewPacket', () {
    test('hands the packet text to the share function', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      String? capturedText;
      String? capturedSubject;
      await shareReviewPacket(
        l10n: l10n,
        packetDate: DateTime(2026, 10, 16),
        shareFn: (text, subject) async {
          capturedText = text;
          capturedSubject = subject;
        },
      );
      expect(capturedText, isNotNull);
      expect(capturedText, contains(l10n.reviewPacketTitle));
      expect(capturedText, contains('2026-10-16'));
      expect(capturedSubject, l10n.reviewPacketTitle);
    });
  });

  /// The screen builds its ListView lazily, so each group header and item
  /// is scrolled into view before asserting on it.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 600);
    await tester.pumpAndSettle();
  }

  group('ReviewRecordScreen', () {
    testWidgets('renders all groups and 26 awaiting-review rows (en)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpReviewScreen(tester, const Locale('en'));
      expect(tester.takeException(), isNull,
          reason: 'no overflow on a real-size frame');

      final l10n =
          await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.reviewTitle), findsOneWidget);
      // Nothing may claim endorsement with the seeded data.
      expect(find.text(l10n.reviewStatusEndorsed), findsNothing);
      expect(find.text(l10n.reviewStatusReviewed), findsNothing);

      for (final group in ReviewRegistry.groupOrder()) {
        final header =
            find.text(reviewGroupLabel(l10n, group).toUpperCase());
        await scrollTo(tester, header);
        expect(header, findsOneWidget, reason: '$group header');
        final groupIds = ReviewRegistry.allItems()
            .where((i) => i.group == group)
            .map((i) => i.id);
        for (final id in groupIds) {
          final row = find.textContaining('$id. ', findRichText: true);
          await scrollTo(tester, row);
          expect(row, findsOneWidget, reason: '$id row');
        }
        // Every row in the group carries the neutral awaiting badge.
        expect(find.text(l10n.reviewStatusProposed), findsWidgets,
            reason: '$group badges');
      }
      // The share button is present and enabled at the end of the list.
      final shareButton = find.text(l10n.reviewSharePacket);
      await scrollTo(tester, shareButton);
      expect(shareButton, findsOneWidget);
    });

    testWidgets('renders all groups and 26 rows in Arabic (RTL)',
        (tester) async {
      await _pumpReviewScreen(tester, const Locale('ar'));
      expect(tester.takeException(), isNull);

      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(find.text(l10n.reviewTitle), findsOneWidget);
      for (final group in ReviewRegistry.groupOrder()) {
        final header =
            find.text(reviewGroupLabel(l10n, group).toUpperCase());
        await scrollTo(tester, header);
        expect(header, findsOneWidget, reason: '$group header');
        final groupIds = ReviewRegistry.allItems()
            .where((i) => i.group == group)
            .map((i) => i.id);
        for (final id in groupIds) {
          final row = find.textContaining('$id. ', findRichText: true);
          await scrollTo(tester, row);
          expect(row, findsOneWidget, reason: '$id row');
          if (id == 'Q1') {
            expect(
              find.text('Q1. ${l10n.reviewQ1Question}'),
              findsOneWidget,
              reason: 'Arabic question text renders',
            );
          }
        }
      }
      expect(find.text(l10n.reviewStatusProposed), findsWidgets);
      expect(
        Directionality.of(tester.element(find.text(l10n.reviewTitle))),
        TextDirection.rtl,
        reason: 'Arabic screen is RTL',
      );
    });

    testWidgets('share button calls the injected share function',
        (tester) async {
      String? capturedText;
      await _pumpReviewScreen(
        tester,
        const Locale('en'),
        shareFn: (text, subject) async {
          capturedText = text;
        },
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final shareButton = find.text(l10n.reviewSharePacket);
      await scrollTo(tester, shareButton);
      await tester.tap(shareButton);
      await tester.pumpAndSettle();
      expect(capturedText, isNotNull);
      expect(capturedText, contains(l10n.reviewPacketTitle));
    });
  });
}
