import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/engine/prayer_profile.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService', () {
    test('defaults on empty preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      expect(s.activeProfileId, PrayerProfiles.defaultProfile.id);
      expect(s.activeProfile.id, PrayerProfiles.defaultProfile.id);
      expect(s.ihtiyatEnabled, isTrue);
      for (final p in Prayer.values) {
        expect(s.adjustments[p], 0, reason: 'adjustment for $p');
      }
      expect(s.effectiveProfile.dhuhrIhtiyatMinutes,
          s.activeProfile.dhuhrIhtiyatMinutes);
      expect(s.effectiveProfile.maghribIhtiyatMinutes,
          s.activeProfile.maghribIhtiyatMinutes);
    });

    test('setActiveProfile persists and reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      await s.setActiveProfile('maliki-egyptian');
      expect(s.activeProfileId, 'maliki-egyptian');
      expect(s.activeProfile.name, 'Maliki — Egyptian (19.5/17.5)');

      final reloaded = await SettingsService.load();
      expect(reloaded.activeProfileId, 'maliki-egyptian');
    });

    test('unknown profile id is ignored, current kept', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      await s.setActiveProfile('maliki-uoif');
      await s.setActiveProfile('not-a-real-profile');
      expect(s.activeProfileId, 'maliki-uoif');

      final reloaded = await SettingsService.load();
      expect(reloaded.activeProfileId, 'maliki-uoif');
    });

    test('corrupt stored profile id falls back to default', () async {
      SharedPreferences.setMockInitialValues(
          {'active_profile_id': 'bogus-id'});
      final s = await SettingsService.load();

      expect(s.activeProfileId, PrayerProfiles.defaultProfile.id);
      expect(s.activeProfile.id, PrayerProfiles.defaultProfile.id);
    });

    test('adjustments clamp to ±60 and persist', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      await s.setAdjustment(Prayer.fajr, 120);
      await s.setAdjustment(Prayer.isha, -200);
      expect(s.adjustments[Prayer.fajr], 60);
      expect(s.adjustments[Prayer.isha], -60);

      final reloaded = await SettingsService.load();
      expect(reloaded.adjustments[Prayer.fajr], 60);
      expect(reloaded.adjustments[Prayer.isha], -60);
      expect(reloaded.adjustments[Prayer.dhuhr], 0);
    });

    test('resetAdjustments clears all adjustments', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      await s.setAdjustment(Prayer.fajr, 10);
      await s.setAdjustment(Prayer.dhuhr, -7);
      await s.resetAdjustments();

      for (final p in Prayer.values) {
        expect(s.adjustments[p], 0, reason: 'adjustment for $p');
      }
      final reloaded = await SettingsService.load();
      for (final p in Prayer.values) {
        expect(reloaded.adjustments[p], 0, reason: 'reloaded $p');
      }
    });

    test('ihtiyatEnabled=false zeroes ihtiyat in effectiveProfile', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      expect(s.activeProfile.dhuhrIhtiyatMinutes, greaterThan(0));

      await s.setIhtiyatEnabled(false);
      expect(s.ihtiyatEnabled, isFalse);
      expect(s.effectiveProfile.dhuhrIhtiyatMinutes, 0);
      expect(s.effectiveProfile.maghribIhtiyatMinutes, 0);
      // The copy keeps every other field of the active profile.
      expect(s.effectiveProfile.id, s.activeProfile.id);
      expect(s.effectiveProfile.fajrAngle, s.activeProfile.fajrAngle);
      expect(s.effectiveProfile.asrShadowFactor,
          s.activeProfile.asrShadowFactor);

      final reloaded = await SettingsService.load();
      expect(reloaded.ihtiyatEnabled, isFalse);
      expect(reloaded.effectiveProfile.dhuhrIhtiyatMinutes, 0);
      expect(reloaded.effectiveProfile.maghribIhtiyatMinutes, 0);

      await s.setIhtiyatEnabled(true);
      expect(s.effectiveProfile.dhuhrIhtiyatMinutes,
          s.activeProfile.dhuhrIhtiyatMinutes);
    });

    test('adjustedTime applies per-prayer minutes', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      await s.setAdjustment(Prayer.asr, 5);
      await s.setAdjustment(Prayer.maghrib, -3);

      final base = DateTime.utc(2026, 10, 15, 12, 0);
      expect(s.adjustedTime(Prayer.asr, base),
          base.add(const Duration(minutes: 5)));
      expect(s.adjustedTime(Prayer.maghrib, base),
          base.subtract(const Duration(minutes: 3)));
      expect(s.adjustedTime(Prayer.fajr, base), base);
    });

    test('corrupt adjustments JSON falls back to defaults without throwing',
        () async {
      SharedPreferences.setMockInitialValues(
          {'adjustments': 'this is not valid json {{{'});
      final s = await SettingsService.load();

      for (final p in Prayer.values) {
        expect(s.adjustments[p], 0, reason: 'adjustment for $p');
      }
    });

    test('non-map adjustments JSON falls back to defaults without throwing',
        () async {
      SharedPreferences.setMockInitialValues({'adjustments': '["a", "map"]'});
      final s = await SettingsService.load();

      for (final p in Prayer.values) {
        expect(s.adjustments[p], 0, reason: 'adjustment for $p');
      }
    });

    test('adjustments map is an unmodifiable view', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();

      expect(() => s.adjustments[Prayer.fajr] = 5, throwsUnsupportedError);
    });
  });
}
