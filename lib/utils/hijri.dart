/// Tabular (arithmetic) Islamic calendar conversion, pure Dart.
///
/// Implements the arithmetic Islamic calendar described by Dershowitz and
/// Reingold ("Calendrical Calculations"): a 30-year cycle with leap years
/// 2, 5, 7, 10, 13, 16, 18, 21, 24, 26 and 29, odd months of 30 days and
/// even months of 29 days (Dhu al-Hijjah gains a 30th day in leap years).
///
/// Verified anchors (checked 2026-10-15):
/// * 1 Muharram 1 AH = the calendar epoch (fixed day number 227015, the
///   Dershowitz/Reingold "islamic-epoch"): Friday 16 July 622 CE in the
///   Julian calendar = 19 July 622 in the proleptic Gregorian calendar used
///   by Dart's [DateTime]
///   (https://en.wikipedia.org/wiki/Lunar_Hijri_calendar).
/// * 30 July 2022 (Gregorian, a Saturday) = 1 Muharram 1444 AH — announced
///   by the Saudi Supreme Court
///   (https://www.siasat.com/saudi-arabia-announces-first-day-of-muharram-1444-hijri-2379288/)
///   and recorded by the UK moonsighting committee
///   (https://www.wifaqululama.co.uk/1444-2/).
/// Known variance: some tabular listings place 1 Muharram 1447 on 26 June
/// 2025 (e.g. https://en.wikipedia.org/wiki/List_of_Islamic_years), while
/// this Dershowitz/Reingold implementation gives 27 June 2025 — arithmetic
/// variants differ by ±1 day, which is why the UI must always carry
/// [hijriCalendarNote].
///
/// All arithmetic is integer-based (no floating point), so conversions are
/// exact and round-trip cleanly.
library;

/// The fixed day number (Rata Die: days since 1 January 1 CE, proleptic
/// Gregorian) of 1 Muharram 1 AH — the Dershowitz/Reingold islamic-epoch.
const int _islamicEpoch = 227015;

/// Fixed day number of the given Islamic date.
int _fixedFromIslamic(int year, int month, int day) {
  // ceil(29.5 * (month - 1)) computed as integers: ceil(59*(m-1)/2).
  final monthOffset = (59 * (month - 1) + 1) ~/ 2;
  return day +
      monthOffset +
      (year - 1) * 354 +
      ((3 + 11 * year) ~/ 30) +
      _islamicEpoch -
      1;
}

/// Islamic year containing the given fixed day number.
///
/// Dershowitz/Reingold: floor((30 * (fixed − epoch) + 10646) / 10631).
int _islamicYearFromFixed(int fixed) {
  return (30 * (fixed - _islamicEpoch) + 10646) ~/ 10631;
}

/// Fixed day number of the given proleptic-Gregorian civil date.
int _fixedFromGregorian(int year, int month, int day) {
  final isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  return (year - 1) * 365 +
      (year - 1) ~/ 4 -
      (year - 1) ~/ 100 +
      (year - 1) ~/ 400 +
      (367 * month - 362) ~/ 12 +
      (month <= 2 ? 0 : (isLeap ? -1 : -2)) +
      day;
}

/// Proleptic-Gregorian civil date of the given fixed day number,
/// as (year, month, day).
(int, int, int) _gregorianFromFixed(int fixed) {
  final d0 = fixed - 1;
  final n400 = d0 ~/ 146097;
  final d1 = d0 % 146097;
  final n100 = d1 ~/ 36524;
  final d2 = d1 % 36524;
  final n4 = d2 ~/ 1461;
  final d3 = d2 % 1461;
  final n1 = d3 ~/ 365;
  var year = 400 * n400 + 100 * n100 + 4 * n4 + n1;
  if (n100 == 4 || n1 == 4) {
    return (year, 12, 31);
  }
  year += 1;
  final priorDays = d3 - 365 * n1;
  final isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  final correction = fixed < _fixedFromGregorian(year, 3, 1)
      ? 0
      : (isLeap ? 1 : 2);
  final month = ((priorDays + correction) * 12 + 373) ~/ 367;
  final day = fixed - _fixedFromGregorian(year, month, 1) + 1;
  return (year, month, day);
}

/// English names of the twelve Hijri months, in order.
const List<String> hijriMonthNames = [
  'Muharram',
  'Safar',
  "Rabi' al-Awwal",
  "Rabi' al-Thani",
  'Jumada al-Ula',
  'Jumada al-Akhirah',
  'Rajab',
  "Sha'ban",
  'Ramadan',
  'Shawwal',
  "Dhu al-Qa'dah",
  'Dhu al-Hijjah',
];

/// One date in the tabular Islamic calendar.
class HijriDate {
  final int year;
  final int month;
  final int day;

  const HijriDate(this.year, this.month, this.day);

  /// English name of [month], e.g. "Ramadan".
  String get monthName => hijriMonthNames[month - 1];

  @override
  String toString() => '$day $monthName $year AH';

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Tabular Islamic calendar — an arithmetic approximation; actual month
/// starts depend on moon sighting.
const String hijriCalendarNote = 'Tabular (arithmetic) Islamic calendar — '
    'an arithmetic approximation; actual month starts depend on moon sighting.';

/// Converts a Gregorian calendar date to the tabular Islamic date.
///
/// Only [date]'s year/month/day are used (the time-of-day is ignored).
/// Dates before the calendar epoch are clamped to 1 Muharram 1 AH.
HijriDate gregorianToHijri(DateTime date) {
  var fixed = _fixedFromGregorian(date.year, date.month, date.day);
  if (fixed < _islamicEpoch) fixed = _islamicEpoch;
  final year = _islamicYearFromFixed(fixed);
  final priorDays = fixed - _fixedFromIslamic(year, 1, 1);
  // Month m starts at prior-day ceil(29.5 * (m − 1)); the largest m with
  // ceil(29.5 * (m − 1)) ≤ priorDays is floor(priorDays / 29.5) + 1.
  final month = (2 * priorDays) ~/ 59 + 1;
  final day = fixed - _fixedFromIslamic(year, month, 1) + 1;
  return HijriDate(year, month, day);
}

/// Converts a tabular Islamic date to the Gregorian calendar date.
///
/// The result is a [DateTime] at midnight (local, unspecified zone — only
/// year/month/day carry meaning).
DateTime hijriToGregorian(int year, int month, int day) {
  final fixed = _fixedFromIslamic(year, month, day);
  final (y, m, d) = _gregorianFromFixed(fixed);
  return DateTime(y, m, d);
}
