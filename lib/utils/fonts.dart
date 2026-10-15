import 'package:flutter/material.dart';

/// Font-family hooks for the app's multilingual UI.
///
/// Jameel Noori Nastaleeq is bundled (assets/fonts/, declared in pubspec.yaml)
/// and used for Urdu text. NOTE ON RIGHTS: no redistribution license for this
/// font could be verified — font sites list it as personal-use-only and no
/// official license document exists. It was bundled at the user's explicit
/// direction on 2026-10-15 after they were informed of this; see ATTRIBUTION.md.
/// The residual licensing risk is the user's accepted decision.
///
/// Each hook names a preferred family first; when the family is absent from
/// the device, Flutter silently falls back to the platform default font.
/// Documented chains:
///
/// * Urdu (`ur`): `'JameelNooriNastaleeq'` (bundled) → platform default.
/// * Arabic (`ar`): `'Amiri'` → platform default. Amiri is not installed on
///   stock devices, so in practice this resolves to the platform default
///   Arabic font until a licensed font is bundled.
/// * Latin-script locales (`en`, `fr`, and any other): no override — the
///   Material default (Roboto on Android, San Francisco on iOS).
abstract final class AppFonts {
  /// Preferred family for Urdu text (Nastaliq style, bundled).
  static const String urdu = 'JameelNooriNastaleeq';

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
