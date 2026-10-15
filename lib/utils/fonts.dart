import 'package:flutter/material.dart';

/// Font-family hooks for the app's multilingual UI.
///
/// NO font files are bundled with this app (nothing is declared under
/// `fonts:` in pubspec.yaml). The Jameel Noori Nastaleeq redistribution
/// rights are unverified, so bundling that font is a known pending item
/// (see the "Fonts" section of the settings screen) and nothing may be
/// shipped until that decision is made.
///
/// Each hook names a preferred family first; when the family is absent from
/// the device, Flutter silently falls back to the platform default font.
/// Documented chains:
///
/// * Urdu (`ur`): `'Noto Nastaliq Urdu'` → platform default. Android 13+
///   ships Noto Nastaliq Urdu; on older Android / iOS the platform default
///   (Noto Naskh Arabic on Android, the system Arabic font on iOS) is used.
/// * Arabic (`ar`): `'Amiri'` → platform default. Amiri is not installed on
///   stock devices, so in practice this resolves to the platform default
///   Arabic font until a licensed font is bundled.
/// * Latin-script locales (`en`, `fr`, and any other): no override — the
///   Material default (Roboto on Android, San Francisco on iOS).
abstract final class AppFonts {
  /// Preferred family for Urdu text (Nastaliq style when available).
  static const String urdu = 'Noto Nastaliq Urdu';

  /// Preferred family for Arabic text.
  static const String arabic = 'Amiri';

  /// Preferred family for Latin-script text; `null` = platform default.
  static const String? latin = null;

  /// Preferred font family for [locale]'s UI language, or `null` for the
  /// platform default.
  static String? forLocale(Locale? locale) => switch (locale?.languageCode) {
        'ur' => urdu,
        'ar' => arabic,
        _ => latin,
      };

  /// App [ThemeData] with the locale-appropriate font family applied.
  ///
  /// Pass the app's resolved [Locale] (or `null` for the system default).
  /// Only the font family differs from the stock Material 3 theme; all
  /// colors and shapes stay identical so the design is unchanged.
  static ThemeData themeFor(Locale? locale, {required Color seedColor}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      useMaterial3: true,
      fontFamily: forLocale(locale),
    );
  }
}
