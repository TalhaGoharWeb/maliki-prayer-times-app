import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/widgets/qada_load_error_card.dart';

void main() {
  group('QadaLoadErrorCard', () {
    testWidgets('shows the message and calls retry when tapped',
        (tester) async {
      var retries = 0;
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
            body: QadaLoadErrorCard(
              message: 'Load failed',
              onRetry: () => retries++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Load failed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });
  });
}
