import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/settings_screen.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/services/update_service.dart';
import 'package:malikiprayertimes/utils/build_flavor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play-build gate tests (2026-11-23).
///
/// The Play-specific tests run ONLY with the Play define, e.g.
/// `flutter test --dart-define=PLAY_BUILD=true test/play_build_settings_test.dart`
/// — without it they skip (with a reason), so the default suite stays
/// green. The locale-strings test runs in both modes.
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

/// A fetcher that must never be called in a Play build.
class _ForbiddenFetcher implements ReleaseFetcher {
  @override
  Future<Map<String, dynamic>> fetchLatestRelease() async {
    throw StateError('Play build must never fetch the GitHub release feed');
  }
}

/// Skips the Play-only tests when this file runs without the define
/// (run with `--dart-define=PLAY_BUILD=true` to execute them).

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Play Store URL is the stable package id', () {
    expect(kPlayStoreUrl,
        'https://play.google.com/store/apps/details?id=com.talhagohar.malikiprayertimes');
  });

  test('AppUpdateService.check refuses without touching the network '
      'in a Play build', () async {
    final result =
        await AppUpdateService(fetcher: _ForbiddenFetcher()).check();
    expect(result.outcome, UpdateCheckOutcome.unknown);
    expect(result.downloadUrl, isNull);
  }, skip: !kIsPlayBuild);

  testWidgets('Settings shows the Play update row, not the GitHub check',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: _delegates,
        supportedLocales: _supportedLocales,
        home: SettingsScreen(
          settings: settings,
          coordinates: const Coordinates(24.86, 67.0),
          timeZoneOffset: const Duration(hours: 5),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.updateViaPlayStore), findsOneWidget);
    expect(find.text(l10n.openPlayStore), findsOneWidget);
    // The GitHub self-update row must be gone entirely in a Play build.
    expect(find.text(l10n.checkForUpdates), findsNothing);
  }, skip: !kIsPlayBuild);

  test('new Play strings exist and are non-empty in all four locales',
      () async {
    for (final code in ['en', 'ur', 'ar', 'fr']) {
      final l10n = await AppLocalizations.delegate.load(Locale(code));
      expect(l10n.updateViaPlayStore, isNotEmpty, reason: '$code viaPlay');
      expect(l10n.openPlayStore, isNotEmpty, reason: '$code openPlay');
    }
  });
}
