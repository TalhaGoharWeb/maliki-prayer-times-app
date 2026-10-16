import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/services/region_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/widgets/region_suggestion_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 3 tests: the coarse region guess (RegionService), the one-time
/// suggestion bookkeeping (SettingsService.regionSuggestionShown), and the
/// "Recommended settings" dialog — confirm switches, dismiss/barrier keep
/// the current profile, and the UOIF disputed badge is always visible.
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

void main() {
  group('RegionService.guessFor', () {
    test('Maghreb countries suggest the Morocco Habous preset', () {
      for (final (lat, lon) in [
        (34.02, -6.84), // Rabat
        (36.75, 3.06), // Algiers
        (36.80, 10.18), // Tunis
        (32.90, 13.19), // Tripoli
      ]) {
        final guess = RegionService.guessFor(lat, lon);
        expect(guess, isNotNull, reason: 'no guess for ($lat, $lon)');
        expect(guess!.regionCode, RegionService.maghreb);
        expect(guess.suggestedProfileId, 'maliki-morocco-habous');
      }
    });

    test('West Africa suggests the MWL West Africa preset', () {
      for (final (lat, lon) in [
        (18.07, -15.96), // Nouakchott
        (14.72, -17.45), // Dakar
        (12.64, -8.00), // Bamako
        (13.51, 2.11), // Niamey
      ]) {
        final guess = RegionService.guessFor(lat, lon);
        expect(guess, isNotNull, reason: 'no guess for ($lat, $lon)');
        expect(guess!.regionCode, RegionService.westAfrica);
        expect(guess.suggestedProfileId, 'maliki-mwl-west-africa');
      }
    });

    test('Egypt suggests the Egyptian preset', () {
      final guess = RegionService.guessFor(30.04, 31.24); // Cairo
      expect(guess, isNotNull);
      expect(guess!.regionCode, RegionService.egypt);
      expect(guess.suggestedProfileId, 'maliki-egyptian');
    });

    test('France suggests UOIF', () {
      final guess = RegionService.guessFor(48.86, 2.35); // Paris
      expect(guess, isNotNull);
      expect(guess!.regionCode, RegionService.france);
      expect(guess.suggestedProfileId, 'maliki-uoif');
    });

    test('Spain is recognized but maps to no preset (stays silent)', () {
      final guess = RegionService.guessFor(40.42, -3.70); // Madrid
      expect(guess, isNotNull);
      expect(guess!.regionCode, RegionService.spain);
      expect(guess.suggestedProfileId, isNull);
    });

    test('ocean and unlisted land return null (uncertain, no suggestion)',
        () {
      expect(RegionService.guessFor(0.0, -30.0), isNull); // Atlantic
      expect(RegionService.guessFor(-6.20, 106.85), isNull); // Jakarta
      expect(RegionService.guessFor(24.86, 67.00), isNull); // Karachi
    });

    test('suggested profile ids all exist in PrayerProfiles.all', () {
      const ids = {
        'maliki-morocco-habous',
        'maliki-mwl-west-africa',
        'maliki-egyptian',
        'maliki-uoif',
      };
      final known = PrayerProfiles.all.map((p) => p.id).toSet();
      expect(known, containsAll(ids));
    });

    test('region names are localized', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      const guess =
          RegionGuess(regionCode: RegionService.maghreb, suggestedProfileId: 'maliki-morocco-habous');
      expect(guess.name(en), en.regionNameMaghreb);
      expect(guess.name(fr), fr.regionNameMaghreb);
      expect(guess.name(en), isNot(guess.name(fr)));
    });
  });

  group('region suggestion one-time bookkeeping', () {
    test('defaults to false and persists true once set', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      expect(settings.regionSuggestionShown, isFalse);
      await settings.setRegionSuggestionShown();
      expect(settings.regionSuggestionShown, isTrue);
      // A fresh load sees the persisted flag: per-install, never nags.
      final reloaded = await SettingsService.load();
      expect(reloaded.regionSuggestionShown, isTrue);
    });
  });

  group('region suggestion dialog', () {
    Future<({AppLocalizations l10n, Future<bool?> Function() open})>
        pumpHost(WidgetTester tester,
            {required RegionGuess guess,
            required PrayerProfile profile,
            String localeCode = 'en'}) async {
      Future<bool?>? pending;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(localeCode),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const Key('region-test-open'),
                onPressed: () {
                  pending = showRegionSuggestionDialog(
                    context: context,
                    guess: guess,
                    profile: profile,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('region-test-open')));
      await tester.pumpAndSettle();
      final l10n =
          await AppLocalizations.delegate.load(Locale(localeCode));
      return (
        l10n: l10n,
        open: () => pending!,
      );
    }

    const habousGuess = RegionGuess(
      regionCode: RegionService.maghreb,
      suggestedProfileId: 'maliki-morocco-habous',
    );
    const franceGuess = RegionGuess(
      regionCode: RegionService.france,
      suggestedProfileId: 'maliki-uoif',
    );

    testWidgets('confirm returns true', (tester) async {
      final (:l10n, :open) = await pumpHost(tester,
          guess: habousGuess, profile: PrayerProfiles.malikiMoroccoHabous);
      expect(find.text(l10n.regionDialogTitle), findsOneWidget);
      expect(find.text(l10n.evidenceBadgeInstitutional), findsOneWidget);
      await tester.tap(find.text(l10n.regionConfirm));
      await tester.pumpAndSettle();
      expect(await open(), isTrue);
    });

    testWidgets('dismiss returns false (keeps current profile)',
        (tester) async {
      final (:l10n, :open) = await pumpHost(tester,
          guess: habousGuess, profile: PrayerProfiles.malikiMoroccoHabous);
      await tester.tap(find.text(l10n.regionDismiss));
      await tester.pumpAndSettle();
      expect(await open(), isFalse);
    });

    testWidgets('barrier tap returns null (keeps current profile)',
        (tester) async {
      final (:l10n, :open) = await pumpHost(tester,
          guess: habousGuess, profile: PrayerProfiles.malikiMoroccoHabous);
      expect(find.text(l10n.regionDialogTitle), findsOneWidget);
      // Tap outside the dialog: the barrier dismisses it.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text(l10n.regionDialogTitle), findsNothing);
      expect(await open(), isNull);
    });

    testWidgets('France suggestion shows the UOIF disputed badge, unsoftened',
        (tester) async {
      final (:l10n, :open) = await pumpHost(tester,
          guess: franceGuess, profile: PrayerProfiles.malikiUoif);
      expect(find.text(l10n.regionSuggestion(
          l10n.profileNameUoif)), findsOneWidget);
      expect(find.text(l10n.evidenceBadgeDisputed), findsOneWidget);
      expect(find.text(l10n.evidenceDisputedDetail), findsOneWidget);
      // Confirming still returns true: the badge informs, never blocks.
      await tester.tap(find.text(l10n.regionConfirm));
      await tester.pumpAndSettle();
      expect(await open(), isTrue);
    });

    testWidgets('renders in ur (RTL) without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (:l10n, open: _) = await pumpHost(tester,
          guess: habousGuess,
          profile: PrayerProfiles.malikiMoroccoHabous,
          localeCode: 'ur');
      expect(find.text(l10n.regionDialogTitle), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'overflow in the region dialog in ur (RTL)');
    });
  });
}
