import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/widgets/why_time_sheet.dart';

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

Future<AppLocalizations> _load(String code) =>
    AppLocalizations.delegate.load(Locale(code));

/// Host page with a button that opens the sheet via the production entry
/// point ([showWhyTimeSheet]).
Widget _host(String code, Prayer prayer, String timeLabel) {
  return MaterialApp(
    locale: Locale(code),
    localizationsDelegates: _delegates,
    supportedLocales: _supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          key: const Key('why-test-open'),
          onPressed: () => showWhyTimeSheet(
            context: context,
            prayer: prayer,
            timeLabel: timeLabel,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  group('WhyTimeSheet.bodyFor', () {
    test('maps every prayer to its rule-registry explanation, verbatim',
        () async {
      final expected = <AppLocalizations, Map<Prayer, String>>{};
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await _load(code);
        expected[l10n] = {
          Prayer.fajr: l10n.whyFajr,
          Prayer.sunrise: l10n.whySunrise,
          Prayer.dhuhr: l10n.whyDhuhr,
          Prayer.asr: l10n.whyAsr,
          Prayer.maghrib: l10n.whyMaghrib,
          Prayer.isha: l10n.whyIsha,
        };
      }
      for (final entry in expected.entries) {
        final l10n = entry.key;
        for (final prayerEntry in entry.value.entries) {
          final body = WhyTimeSheet.bodyFor(prayerEntry.key, l10n);
          // Verbatim: the exact l10n string, never reworded here.
          expect(body, prayerEntry.value,
              reason: '${prayerEntry.key.name} body');
          expect(body.trim(), isNotEmpty,
              reason: '${prayerEntry.key.name} body non-empty');
        }
      }
    });

    test('no review-state language in the why-sheet strings', () async {
      // User directive: no "PROPOSED — pending scholarly review" text
      // anywhere in the UI, in any language.
      final banned = [
        'propos', // proposed / PROPOSED / proposé
        'pending scholarly review',
        'examen par des savants',
        'révision savante',
        'مجوزہ',
        'مقترح',
        'بانتظار المراجعة',
        'المراجعة العلمية',
        'علمی جائزے',
        'علمی جائزہ',
        'شرعی توثیق',
      ];
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await _load(code);
        final strings = [
          l10n.whySheetTitle,
          l10n.whySheetNote,
          for (final p in Prayer.values) WhyTimeSheet.bodyFor(p, l10n),
        ];
        for (final s in strings) {
          for (final word in banned) {
            expect(s.toLowerCase(), isNot(contains(word)),
                reason: '$code why-sheet string contains "$word": $s');
          }
        }
      }
    });
  });

  group('WhyTimeSheet widget', () {
    testWidgets('sheet shows title, prayer name, time, body and note in en',
        (tester) async {
      final l10n = await _load('en');

      await tester.pumpWidget(_host('en', Prayer.asr, '16:45'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('why-test-open')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.whySheetTitle.toUpperCase()), findsOneWidget,
          reason: 'sheet title');
      expect(find.textContaining(l10n.prayerAsr), findsWidgets,
          reason: 'prayer name');
      expect(find.text('16:45'), findsOneWidget, reason: 'prayer time');
      expect(find.text(l10n.whyAsr), findsOneWidget, reason: 'body');
      expect(find.text(l10n.whySheetNote), findsOneWidget,
          reason: 'registry note');
      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL: ar sheet lays out right-to-left and renders strings',
        (tester) async {
      final l10n = await _load('ar');

      await tester.pumpWidget(_host('ar', Prayer.fajr, '05:12'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('why-test-open')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.whySheetTitle.toUpperCase()), findsOneWidget,
          reason: 'ar sheet title');
      expect(find.text(l10n.prayerFajr), findsOneWidget,
          reason: 'ar prayer name');
      expect(find.text('05:12'), findsOneWidget, reason: 'ar prayer time');
      expect(find.text(l10n.whyFajr), findsOneWidget, reason: 'ar body');
      expect(find.text(l10n.whySheetNote), findsOneWidget,
          reason: 'ar registry note');

      // The sheet inherits right-to-left directionality in Arabic.
      final sheetElement = tester.element(find.byType(WhyTimeSheet));
      expect(Directionality.of(sheetElement), TextDirection.rtl,
          reason: 'ar sheet is RTL');
      expect(tester.takeException(), isNull);
    });

    testWidgets('en sheet stays left-to-right', (tester) async {
      await tester.pumpWidget(_host('en', Prayer.maghrib, '18:20'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('why-test-open')));
      await tester.pumpAndSettle();

      final sheetElement = tester.element(find.byType(WhyTimeSheet));
      expect(Directionality.of(sheetElement), TextDirection.ltr,
          reason: 'en sheet is LTR');
      expect(tester.takeException(), isNull);
    });
  });
}
