import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/screens/profile_labels.dart';
import 'package:malikiprayertimes/screens/profiles_screen.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 3 tests: the "Maliki — Morocco Habous" profile (19/17) and the
/// per-profile / per-parameter evidence badges in the D9 vocabulary.
///
/// Integrity anchors: Habous is labeled institutional — NEVER a fiqh
/// ruling — wherever its name renders; the UOIF "disputed" label from the
/// D1 trap register is surfaced honestly and never softened.
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

void main() {
  group('Morocco Habous profile', () {
    test('carries Fajr 19 and Isha 17', () {
      final p = PrayerProfiles.malikiMoroccoHabous;
      expect(p.id, 'maliki-morocco-habous');
      expect(p.fajrAngle, 19.0);
      expect(p.ishaAngle, 17.0);
      expect(p.asrShadowFactor, 1.0);
    });

    test('is a selectable profile in PrayerProfiles.all', () {
      final ids = PrayerProfiles.all.map((p) => p.id).toList();
      expect(ids, contains('maliki-morocco-habous'));
      expect(PrayerProfiles.all.length, 4);
    });

    test('existing profiles are unchanged', () {
      expect(PrayerProfiles.malikiMwlWestAfrica.fajrAngle, 18.0);
      expect(PrayerProfiles.malikiMwlWestAfrica.ishaAngle, 17.0);
      expect(PrayerProfiles.malikiEgyptian.fajrAngle, 19.5);
      expect(PrayerProfiles.malikiEgyptian.ishaAngle, 17.5);
      expect(PrayerProfiles.malikiUoif.fajrAngle, 12.0);
      expect(PrayerProfiles.malikiUoif.ishaAngle, 12.0);
      expect(PrayerProfiles.defaultProfile.id, 'maliki-mwl-west-africa');
    });

    test('localized name renders wherever the profile name renders',
        () async {
      for (final code in ['en', 'ur', 'ar', 'fr']) {
        final l10n = await _load(code);
        final labels =
            profileLabel(l10n, PrayerProfiles.malikiMoroccoHabous);
        expect(labels.name, isNotEmpty);
        expect(labels.name, l10n.profileNameMoroccoHabous);
      }
    });

    test('institutional labeling in all four locales (never a fiqh ruling)',
        () async {
      // Case-insensitive: the basis uses "NOT a fiqh ruling", the badge
      // uses "not a fiqh ruling" — both must carry the marker.
      const marker = 'not a fiqh ruling';
      final basisMarkers = {
        'en': marker,
        'ur': 'فقہی حکم نہیں',
        'ar': 'ليس حكماً فقهياً',
        'fr': 'pas une règle de fiqh',
      };
      for (final entry in basisMarkers.entries) {
        final l10n = await _load(entry.key);
        final labels =
            profileLabel(l10n, PrayerProfiles.malikiMoroccoHabous);
        expect(labels.basis.toLowerCase(), contains(entry.value),
            reason: 'Habous basis lost its institutional marker in '
                '${entry.key}');
        expect(
            profileEvidenceBadge(l10n, PrayerProfiles.malikiMoroccoHabous)
                .toLowerCase(),
            contains(entry.value),
            reason: 'Habous summary badge lost its institutional marker in '
                '${entry.key}');
      }
    });
  });

  group('D9 evidence vocabulary', () {
    test('profile-level summary badges', () async {
      final l10n = await _load('en');
      expect(profileEvidenceBadge(l10n, PrayerProfiles.malikiMwlWestAfrica),
          l10n.evidenceProfileProvisional);
      expect(profileEvidenceBadge(l10n, PrayerProfiles.malikiMoroccoHabous),
          l10n.evidenceBadgeInstitutional);
      expect(profileEvidenceBadge(l10n, PrayerProfiles.malikiEgyptian),
          l10n.evidenceBadgeInstitutional);
      expect(profileEvidenceBadge(l10n, PrayerProfiles.malikiUoif),
          l10n.evidenceBadgeDisputed);
    });

    test('per-parameter badges: angles follow profile standing', () async {
      final l10n = await _load('en');
      PrayerProfile byId(String id) =>
          PrayerProfiles.all.firstWhere((p) => p.id == id);

      // MWL West Africa 18/17: provisional convention (default).
      for (final param in [ProfileParam.fajrAngle, ProfileParam.ishaAngle]) {
        expect(
            parameterEvidenceBadge(
                l10n, byId('maliki-mwl-west-africa'), param),
            l10n.evidenceBadgeProvisional);
      }
      // Habous 19/17 and Egyptian 19.5/17.5: institutional preset.
      for (final id in ['maliki-morocco-habous', 'maliki-egyptian']) {
        for (final param in [ProfileParam.fajrAngle, ProfileParam.ishaAngle]) {
          expect(parameterEvidenceBadge(l10n, byId(id), param),
              l10n.evidenceBadgeInstitutional);
        }
      }
      // UOIF 12/12: disputed — see research (D1 trap register).
      for (final param in [ProfileParam.fajrAngle, ProfileParam.ishaAngle]) {
        expect(parameterEvidenceBadge(l10n, byId('maliki-uoif'), param),
            l10n.evidenceBadgeDisputed);
      }
    });

    test('per-parameter badges: Asr ×1 is fiqh-derived on every profile',
        () async {
      final l10n = await _load('en');
      for (final p in PrayerProfiles.all) {
        expect(
            parameterEvidenceBadge(
                l10n, p, ProfileParam.asrShadowFactor),
            l10n.evidenceBadgeFiqhDerived);
      }
    });

    test('only the UOIF preset is flagged disputed', () {
      for (final p in PrayerProfiles.all) {
        expect(profileAnglesDisputed(p), p.id == 'maliki-uoif');
      }
    });
  });

  group('profiles screen badges', () {
    Future<AppLocalizations> pumpProfiles(WidgetTester tester,
        {String localeCode = 'en'}) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(localeCode),
          localizationsDelegates: _delegates,
          supportedLocales: _supportedLocales,
          home: Scaffold(
            body: ProfilesScreen(
              settings: settings,
              coordinates: const Coordinates(34.02, -6.84),
              timeZoneOffset: const Duration(hours: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return _load(localeCode);
    }

    testWidgets('each profile shows its D9 evidence badges', (tester) async {
      final l10n = await pumpProfiles(tester);
      // Profile-level summary badges (each also appears on the angle
      // params, so counts > 1).
      expect(find.text(l10n.evidenceProfileProvisional), findsWidgets);
      expect(find.text(l10n.evidenceBadgeInstitutional), findsWidgets);
      expect(find.text(l10n.evidenceBadgeDisputed), findsWidgets);
      // The UOIF disputed detail is surfaced, not softened.
      expect(find.text(l10n.evidenceDisputedDetail), findsOneWidget);
      // Per-parameter badges.
      expect(find.text(l10n.evidenceBadgeProvisional), findsWidgets);
      expect(find.text(l10n.evidenceBadgeFiqhDerived), findsWidgets);
      // The new profile renders by its localized name.
      expect(find.text(l10n.profileNameMoroccoHabous), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in ur (RTL) without overflow', (tester) async {
      final l10n = await pumpProfiles(tester, localeCode: 'ur');
      expect(find.text(l10n.profileNameMoroccoHabous), findsWidgets);
      expect(find.text(l10n.evidenceBadgeInstitutional), findsWidgets);
      expect(tester.takeException(), isNull,
          reason: 'overflow on the profiles screen in ur (RTL)');
    });
  });
}
