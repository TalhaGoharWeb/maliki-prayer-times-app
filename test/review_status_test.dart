import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/models/review_status.dart';

void main() {
  group('ReviewRegistry', () {
    test('seeds exactly 26 items: Q1-Q18 plus P1-P8', () {
      final items = ReviewRegistry.allItems();
      expect(items, hasLength(26));
      final ids = items.map((i) => i.id).toList();
      expect(
        ids,
        [
          for (var n = 1; n <= 18; n++) 'Q$n',
          for (var n = 1; n <= 8; n++) 'P$n',
        ],
      );
      // No duplicate ids.
      expect(ids.toSet(), hasLength(26));
    });

    test('every item starts proposed with no reviewer data', () {
      for (final item in ReviewRegistry.allItems()) {
        expect(item.status, ReviewStatus.proposed, reason: item.id);
        expect(item.reviewerName, isNull, reason: item.id);
        expect(item.reviewDate, isNull, reason: item.id);
        expect(item.reviewText, isNull, reason: item.id);
      }
    });

    test('items are grouped per the D7 sections', () {
      ReviewGroup groupOf(String id) =>
          ReviewRegistry.allItems().firstWhere((i) => i.id == id).group;
      for (var n = 1; n <= 4; n++) {
        expect(groupOf('Q$n'), ReviewGroup.astronomy, reason: 'Q$n');
      }
      for (var n = 5; n <= 11; n++) {
        expect(groupOf('Q$n'), ReviewGroup.fiqh, reason: 'Q$n');
      }
      for (var n = 12; n <= 14; n++) {
        expect(groupOf('Q$n'), ReviewGroup.regional, reason: 'Q$n');
      }
      for (var n = 15; n <= 18; n++) {
        expect(groupOf('Q$n'), ReviewGroup.presentation, reason: 'Q$n');
      }
      for (var n = 1; n <= 8; n++) {
        expect(groupOf('P$n'), ReviewGroup.pass2, reason: 'P$n');
      }
      expect(ReviewRegistry.groupOrder(), hasLength(5));
    });

    test('question/why/evidence keys are set and unique', () {
      final items = ReviewRegistry.allItems();
      final keys = <String>[];
      for (final item in items) {
        expect(item.questionKey, isNotEmpty, reason: item.id);
        expect(item.whyKey, isNotEmpty, reason: item.id);
        expect(item.evidenceKey, isNotEmpty, reason: item.id);
        keys.addAll([item.questionKey, item.whyKey, item.evidenceKey]);
      }
      expect(keys.toSet(), hasLength(keys.length));
    });
  });

  group('review localizations', () {
    test('question, why, and evidence resolve non-empty in all locales',
        () async {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        for (final item in ReviewRegistry.allItems()) {
          expect(reviewQuestionText(l10n, item), isNotEmpty,
              reason: '$code ${item.id} question');
          expect(reviewWhyText(l10n, item), isNotEmpty,
              reason: '$code ${item.id} why');
          expect(reviewEvidenceText(l10n, item), isNotEmpty,
              reason: '$code ${item.id} evidence');
        }
        for (final group in ReviewGroup.values) {
          expect(reviewGroupLabel(l10n, group), isNotEmpty,
              reason: '$code $group label');
        }
      }
    });

    test('status labels never claim verification or review-banner wording',
        () async {
      final banned = [
        'verified',
        'endorsed',
        'approved',
        'proposed',
        'pending scholarly review',
      ];
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        final proposed = reviewStatusLabel(l10n, ReviewStatus.proposed);
        expect(proposed, isNotEmpty, reason: code);
        for (final word in banned) {
          expect(proposed.toLowerCase(), isNot(contains(word)),
              reason: '$code status label contains "$word": $proposed');
        }
        // The reviewed/endorsed labels exist for future recorded reviews.
        expect(reviewStatusLabel(l10n, ReviewStatus.reviewed), isNotEmpty,
            reason: code);
        expect(reviewStatusLabel(l10n, ReviewStatus.endorsed), isNotEmpty,
            reason: code);
      }
    });

    test('screen chrome strings resolve in all locales', () async {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        expect(l10n.reviewTitle, isNotEmpty, reason: code);
        expect(l10n.reviewIntro, isNotEmpty, reason: code);
        expect(l10n.reviewSharePacket, isNotEmpty, reason: code);
        expect(l10n.reviewPacketTitle, isNotEmpty, reason: code);
        expect(l10n.reviewPacketIntro, isNotEmpty, reason: code);
      }
    });
  });
}
