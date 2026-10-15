/// Locale-aware digit and daypart rendering for prayer-time displays.
///
/// In the Urdu locale the templates show Urdu-Indic digits (۰۱۲۳۴۵۶۷۸۹) in the
/// hero countdown and ص (morning) / د (afternoon) / ش (evening) suffixes on
/// prayer times. Arabic uses Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩); other locales
/// keep Western digits.
library;

const _urduDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Replaces Western digits in [input] with the locale's digit set.
/// Only 'ur' and 'ar' are converted; everything else is returned unchanged.
String localizeDigits(String input, String? languageCode) {
  final digits = switch (languageCode) {
    'ur' => _urduDigits,
    'ar' => _arabicDigits,
    _ => null,
  };
  if (digits == null) return input;
  final buf = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buf.write(digits[unit - 0x30]);
    } else {
      buf.writeCharCode(unit);
    }
  }
  return buf.toString();
}

/// Daypart suffix for a wall-clock [hour] in the Urdu locale:
/// ص (ṣubḥ/morning) before noon, د (ẓuhr/afternoon) until sunset-ish,
/// ش (shab/evening-night) otherwise. Returns '' for other locales.
///
/// The boundary between د and ش is the sunset hour when known; callers pass
/// [sunsetHour] (0-23) or null to fall back to 18.
String daypartSuffix(int hour, String? languageCode, {int? sunsetHour}) {
  if (languageCode != 'ur') return '';
  if (hour < 12) return 'ص';
  final sunset = sunsetHour ?? 18;
  if (hour < sunset) return 'د';
  return 'ش';
}

/// Formats [time] as HH:MM with the locale's digits and (Urdu) daypart.
String formatPrayerTime(DateTime time, String? languageCode,
    {int? sunsetHour}) {
  final hhmm =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  final localized = localizeDigits(hhmm, languageCode);
  final suffix = daypartSuffix(time.hour, languageCode, sunsetHour: sunsetHour);
  return suffix.isEmpty ? localized : '$localized $suffix';
}
