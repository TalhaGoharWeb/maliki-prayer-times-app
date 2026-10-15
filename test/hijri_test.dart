import 'package:flutter_test/flutter_test.dart';
import 'package:malikiprayertimes/utils/hijri.dart';

void main() {
  group('epoch anchor', () {
    test('hijriToGregorian(1, 1, 1) is 19 July 622 (proleptic Gregorian)', () {
      // The Dershowitz/Reingold islamic-epoch (fixed day 227015) is
      // 1 Muharram 1 AH = Friday 16 July 622 CE in the Julian calendar,
      // which is 19 July 622 in the proleptic Gregorian calendar that
      // Dart's DateTime uses. Anchor verified via
      // https://en.wikipedia.org/wiki/Lunar_Hijri_calendar (checked
      // 2026-10-15).
      final g = hijriToGregorian(1, 1, 1);
      expect(g.year, 622);
      expect(g.month, 7);
      expect(g.day, 19);
    });

    test('gregorianToHijri(622-07-19) is 1 Muharram 1 AH', () {
      expect(
        gregorianToHijri(DateTime(622, 7, 19)),
        const HijriDate(1, 1, 1),
      );
    });

    test('dates before the epoch are clamped to 1/1/1', () {
      expect(
        gregorianToHijri(DateTime(600, 1, 1)),
        const HijriDate(1, 1, 1),
      );
    });
  });

  group('web-verified anchor', () {
    test('30 July 2022 is 1 Muharram 1444 AH', () {
      // 1 Muharram 1444 was Saturday 30 July 2022: announced by the Saudi
      // Supreme Court
      // (https://www.siasat.com/saudi-arabia-announces-first-day-of-muharram-1444-hijri-2379288/)
      // and recorded by the UK moonsighting committee
      // (https://www.wifaqululama.co.uk/1444-2/). Checked 2026-10-15.
      expect(
        gregorianToHijri(DateTime(2022, 7, 30)),
        const HijriDate(1444, 1, 1),
      );
    });

    test('hijriToGregorian(1444, 1, 1) is 30 July 2022', () {
      final g = hijriToGregorian(1444, 1, 1);
      expect(g.year, 2022);
      expect(g.month, 7);
      expect(g.day, 30);
    });
  });

  group('round trip', () {
    test('500 consecutive dates round-trip exactly', () {
      var date = DateTime(2019, 3, 14);
      for (var i = 0; i < 500; i++) {
        final hijri = gregorianToHijri(date);
        final back = hijriToGregorian(hijri.year, hijri.month, hijri.day);
        expect(back.year, date.year, reason: 'year at $date');
        expect(back.month, date.month, reason: 'month at $date');
        expect(back.day, date.day, reason: 'day at $date');
        date = date.add(const Duration(days: 1));
      }
    });

    test('every day of two full Hijri years round-trips', () {
      for (var year = 1444; year <= 1445; year++) {
        for (var month = 1; month <= 12; month++) {
          var day = 1;
          while (true) {
            final back = gregorianToHijri(
              hijriToGregorian(year, month, day),
            );
            if (back.month != month) break;
            expect(back, HijriDate(year, month, day));
            day++;
          }
        }
      }
    });

    test('only the date fields are used; time of day is ignored', () {
      expect(
        gregorianToHijri(DateTime(2022, 7, 30, 23, 59, 59)),
        gregorianToHijri(DateTime(2022, 7, 30)),
      );
    });
  });

  group('month lengths', () {
    // Tabular rule: odd months 30 days, even months 29 days, Dhu al-Hijjah
    // 30 days in leap years (2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29 mod 30).
    bool isLeap(int year) => ((11 * year) + 14) % 30 < 11;

    int monthLength(int year, int month) {
      final start = hijriToGregorian(year, month, 1);
      final next = month == 12
          ? hijriToGregorian(year + 1, 1, 1)
          : hijriToGregorian(year, month + 1, 1);
      return next.difference(start).inDays;
    }

    test('29/30 alternation holds across years 1440-1450', () {
      for (var year = 1440; year <= 1450; year++) {
        for (var month = 1; month <= 12; month++) {
          final expected = month == 12
              ? (isLeap(year) ? 30 : 29)
              : (month.isOdd ? 30 : 29);
          expect(
            monthLength(year, month),
            expected,
            reason: 'length of month $month in $year AH',
          );
        }
      }
    });

    test('leap years 2,5,7,10,13,16,18,21,24,26,29 (mod 30) give Dhu '
        'al-Hijjah 30 days', () {
      const leaps = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29];
      for (var r = 0; r < 30; r++) {
        // 1440 mod 30 == 0, so 1440 + r covers every residue class.
        final year = 1440 + r;
        expect(
          monthLength(year, 12),
          leaps.contains(r) ? 30 : 29,
          reason: 'Dhu al-Hijjah length in $year AH (residue $r)',
        );
      }
    });

    test('years have 354 or 355 days', () {
      for (var year = 1440; year <= 1450; year++) {
        final start = hijriToGregorian(year, 1, 1);
        final next = hijriToGregorian(year + 1, 1, 1);
        final days = next.difference(start).inDays;
        expect(
          days,
          isLeap(year) ? 355 : 354,
          reason: 'length of $year AH',
        );
      }
    });
  });

  group('monthName', () {
    test('maps 1..12 to hijriMonthNames', () {
      expect(hijriMonthNames, hasLength(12));
      for (var m = 1; m <= 12; m++) {
        expect(
          HijriDate(1447, m, 1).monthName,
          hijriMonthNames[m - 1],
        );
      }
    });

    test('spot checks', () {
      expect(const HijriDate(1447, 1, 1).monthName, 'Muharram');
      expect(const HijriDate(1447, 9, 1).monthName, 'Ramadan');
      expect(const HijriDate(1447, 12, 1).monthName, 'Dhu al-Hijjah');
    });
  });
}
