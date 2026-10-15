/// Locale-aware digit rendering for prayer-time displays.
///
/// Only the Arabic locale converts Western digits (to Arabic-Indic ٠١٢٣٤٥٦٧٨٩).
/// Urdu uses standard Western digits per user directive (2026-10-15): no
/// Urdu-Indic digits and no daypart suffixes (ص/د/ش) anywhere.
library;

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Replaces Western digits in [input] with the locale's digit set.
/// Only 'ar' is converted; everything else (including 'ur') is returned
/// unchanged.
String localizeDigits(String input, String? languageCode) {
  if (languageCode != 'ar') return input;
  final buf = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buf.write(_arabicDigits[unit - 0x30]);
    } else {
      buf.writeCharCode(unit);
    }
  }
  return buf.toString();
}

/// Formats [time] as HH:MM with the locale's digits (Arabic-Indic for 'ar',
/// standard digits otherwise). No daypart suffixes are ever appended.
String formatPrayerTime(DateTime time, String? languageCode) {
  final hhmm =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  return localizeDigits(hhmm, languageCode);
}
