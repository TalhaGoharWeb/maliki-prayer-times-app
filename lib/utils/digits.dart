/// Locale-aware digit rendering for prayer-time displays.
///
/// Only the Arabic locale converts Western digits (to Arabic-Indic ٠١٢٣٤٥٦٧٨٩).
/// Urdu uses standard Western digits per user directive (2026-10-15): no
/// Urdu-Indic digits. Day-period markers (AM/PM, صبح/شام, ص/م, du matin…)
/// appear ONLY in 12-hour mode; 24-hour mode never carries them.
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
/// standard digits otherwise).
///
/// In 24-hour mode ([use24Hour] true) the output is exactly the historical
/// one — no day-period markers, ever. In 12-hour mode the hour folds to
/// 1–12 with a locale-correct day-period marker: en "4:49 AM", ur "4:49
/// صبح" / "4:49 شام", ar "٤:٤٩ ص" / "٤:٤٩ م", fr "4:49 du matin" /
/// "4:49 de l'après-midi" / "4:49 du soir".
String formatPrayerTime(DateTime time, String? languageCode,
    {required bool use24Hour}) {
  final mm = time.minute.toString().padLeft(2, '0');
  if (use24Hour) {
    return localizeDigits(
        '${time.hour.toString().padLeft(2, '0')}:$mm', languageCode);
  }
  final h12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final marker = switch (languageCode) {
    'ur' => time.hour < 12 ? 'صبح' : 'شام',
    'ar' => time.hour < 12 ? 'ص' : 'م',
    'fr' => time.hour < 12
        ? 'du matin'
        : time.hour < 18
            ? "de l'après-midi"
            : 'du soir',
    _ => time.hour < 12 ? 'AM' : 'PM',
  };
  return localizeDigits('$h12:$mm $marker', languageCode);
}
