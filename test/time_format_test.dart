import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/utils/digits.dart';

/// 12/24-hour prayer-time formatting: one central formatter, every locale.
void main() {
  group('formatPrayerTime 24-hour (historical output, unchanged)', () {
    test('en renders zero-padded HH:MM with no marker', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 4, 49), 'en', use24Hour: true),
          '04:49');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 23, 5), 'en', use24Hour: true),
          '23:05');
    });

    test('ur keeps standard digits, no marker', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 4, 49), 'ur', use24Hour: true),
          '04:49');
    });

    test('ar renders Arabic-Indic digits, no marker', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 4, 49), 'ar', use24Hour: true),
          '٠٤:٤٩');
    });

    test('fr renders HH:MM with no marker', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 16, 30), 'fr', use24Hour: true),
          '16:30');
    });
  });

  group('formatPrayerTime 12-hour (locale-correct day periods)', () {
    test('en: AM/PM markers', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 4, 49), 'en', use24Hour: false),
          '4:49 AM');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 16, 5), 'en', use24Hour: false),
          '4:05 PM');
    });

    test('midnight is 12:00 AM, noon is 12:00 PM (not 0:00)', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 0, 0), 'en', use24Hour: false),
          '12:00 AM');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 12, 0), 'en', use24Hour: false),
          '12:00 PM');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 0, 30), 'ur', use24Hour: false),
          '12:30 صبح');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 12, 30), 'ur', use24Hour: false),
          '12:30 شام');
    });

    test('ur: صبح/شام with standard 0-9 digits', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 4, 49), 'ur', use24Hour: false),
          '4:49 صبح');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 18, 7), 'ur', use24Hour: false),
          '6:07 شام');
    });

    test('ar: ص/م with Arabic-Indic digits', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 4, 49), 'ar', use24Hour: false),
          '٤:٤٩ ص');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 18, 7), 'ar', use24Hour: false),
          '٦:٠٧ م');
    });

    test('fr: du matin / de l\u2019après-midi / du soir', () {
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 4, 49), 'fr', use24Hour: false),
          '4:49 du matin');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 14, 5), 'fr', use24Hour: false),
          "2:05 de l'après-midi");
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 20, 15), 'fr', use24Hour: false),
          '8:15 du soir');
      expect(
          formatPrayerTime(DateTime(2026, 1, 1, 0, 0), 'fr', use24Hour: false),
          '12:00 du matin');
    });
  });
}
