import 'package:flutter/material.dart';

/// Design tokens for the Maliki Prayer Times redesign (light mode only).
///
/// Exact palette from the approved Stitch templates — hardcoded, never
/// generated from a seed. These are the single source of truth; widgets
/// should read them from [Theme.of(context).colorScheme], and custom
/// painters from [AppColors].
abstract final class AppColors {
  static const Color primary = Color(0xFF003527);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0B4D3B);
  static const Color surface = Color(0xFFE5FFF6);
  static const Color background = Color(0xFFE5FFF6);
  static const Color onSurface = Color(0xFF04201A);
  static const Color onSurfaceVariant = Color(0xFF404944);
  static const Color surfaceContainer = Color(0xFFD6F4EB);
  static const Color containerLow = Color(0xFFDCFAF0);
  static const Color containerHigh = Color(0xFFD1EFE5);
  static const Color containerHighest = Color(0xFFCBE9DF);
  static const Color containerLowest = Color(0xFFFFFFFF);
  static const Color dim = Color(0xFFC3E0D7);
  static const Color secondary = Color(0xFF3C6658);
  static const Color secondaryContainer = Color(0xFFBEEDDA);
  static const Color onSecondaryContainer = Color(0xFF426D5E);
  static const Color tertiary = Color(0xFF3B2B00);
  static const Color tertiaryContainer = Color(0xFF574000);
  static const Color tertiaryFixed = Color(0xFFFFDF9C);
  static const Color tertiaryFixedDim = Color(0xFFE5C277);
  static const Color onTertiaryFixed = Color(0xFF251A00);
  static const Color onTertiaryFixedVariant = Color(0xFF5B4301);
  static const Color onTertiaryContainer = Color(0xFFCEAC63);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color outline = Color(0xFF707974);
  static const Color outlineVariant = Color(0xFFBFC9C3);
  static const Color inverseSurface = Color(0xFF1B352F);
  static const Color inverseOnSurface = Color(0xFFD9F7ED);
  static const Color inversePrimary = Color(0xFF97D3BB);
}

/// Font-family hooks for the app's multilingual UI.
///
/// * Urdu (`ur`): Nafees Nastaleeq (bundled, CRULP — redistribution verified).
/// * Arabic (`ar`): Amiri (bundled, OFL).
/// * English/French (`en`/`fr`): Source Serif 4 for headlines and TIME
///   readouts, Manrope for body/labels (both bundled, OFL).
abstract final class AppFonts {
  /// Preferred family for Urdu text (Nastaliq, bundled).
  static const String urdu = 'Nafees Nastaleeq';

  /// Preferred family for Arabic text (bundled).
  static const String arabic = 'Amiri';

  /// Serif family for Latin-script headlines and time readouts (bundled).
  static const String latinSerif = 'Source Serif 4';

  /// Sans family for Latin-script body text and labels (bundled).
  static const String latinSans = 'Manrope';

  /// Preferred font family for [locale]'s UI language, or `null` for the
  /// platform default (Latin locales use per-role families instead).
  static String? forLocale(Locale? locale) => switch (locale?.languageCode) {
        'ur' => urdu,
        'ar' => arabic,
        _ => null,
      };

  /// Hero countdown digits: 32px bold.
  static TextStyle hero(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return t.displayLarge!;
  }

  /// All HH:MM readouts: 20px semibold.
  static TextStyle timeLabel(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!;
  }

  /// Eyebrow labels: 11px, semibold, 0.04em tracking.
  static TextStyle eyebrow(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge!;
  }

  /// Scholarly badge labels: 11px, semibold, 0.08em tracking.
  static TextStyle badgeLabel(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall!;
  }

  /// The app's light [ColorScheme], built from the exact Stitch tokens.
  static ColorScheme get lightScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onPrimary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onPrimary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        // The fixed tertiary roles are real Stitch tokens (AppColors) — they
        // must be wired explicitly: the ColorScheme getters fall back to
        // tertiary/onTertiary (dark brown/white) when unset, which inverted
        // every tertiaryFixed surface (I-02: the marker rendered white).
        tertiaryFixed: AppColors.tertiaryFixed,
        tertiaryFixedDim: AppColors.tertiaryFixedDim,
        onTertiaryFixed: AppColors.onTertiaryFixed,
        onTertiaryFixedVariant: AppColors.onTertiaryFixedVariant,
        error: AppColors.error,
        onError: AppColors.onPrimary,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        surfaceContainerLowest: AppColors.containerLowest,
        surfaceContainerLow: AppColors.containerLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.containerHigh,
        surfaceContainerHighest: AppColors.containerHighest,
        surfaceDim: AppColors.dim,
        surfaceBright: AppColors.surface,
        surfaceTint: AppColors.primary,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
      );

  static TextTheme _textThemeFor(String? languageCode) {
    final serif = switch (languageCode) {
      'ur' => urdu,
      'ar' => arabic,
      _ => latinSerif,
    };
    final sans = switch (languageCode) {
      'ur' => urdu,
      'ar' => arabic,
      _ => latinSans,
    };
    // Nastaleeq's tall glyphs need generous line height.
    final double? bodyHeight = languageCode == 'ur' ? 2.0 : null;
    TextStyle s(double size, FontWeight w, {double? height}) => TextStyle(
          fontFamily: serif,
          fontSize: size,
          fontWeight: w,
          height: height,
        );
    TextStyle b(double size, FontWeight w, {double? tracking}) => TextStyle(
          fontFamily: sans,
          fontSize: size,
          fontWeight: w,
          letterSpacing: tracking,
          height: bodyHeight,
        );
    // Scholarly badge labels get 0.08em tracking on Latin locales only:
    // letter-spacing breaks Arabic-script joining in ur (Nastaleeq) and
    // ar (Amiri).
    final badgeTracking =
        (languageCode == 'ur' || languageCode == 'ar') ? 0.0 : 0.08 * 11;
    return TextTheme(
      displayLarge: s(32, FontWeight.w700), // hero countdown
      displayMedium: s(30, FontWeight.w600), // headline lg
      displaySmall: s(22, FontWeight.w600), // headline md
      headlineSmall: s(18, FontWeight.w600), // headline sm
      titleLarge: s(20, FontWeight.w600), // TIME labels (HH:MM)
      titleMedium: s(16, FontWeight.w600),
      titleSmall: b(14, FontWeight.w600),
      bodyLarge: b(14, FontWeight.w400),
      bodyMedium: b(14, FontWeight.w400),
      bodySmall: b(12, FontWeight.w400),
      labelLarge: b(11, FontWeight.w600, tracking: 0.04 * 11), // eyebrow
      labelMedium: b(12, FontWeight.w600),
      // Scholarly badge labels: 11px semibold, 0.08em tracking (Latin
      // locales only — see badgeTracking above), serif.
      labelSmall: s(11, FontWeight.w600, height: 1.4).copyWith(
        letterSpacing: badgeTracking,
      ),
    );
  }

  /// App [ThemeData] with the locale-appropriate font families applied.
  ///
  /// The palette is the fixed Stitch light scheme; [seedColor] is accepted
  /// for signature compatibility and ignored.
  static ThemeData themeFor(Locale? locale, {required Color seedColor}) {
    final scheme = lightScheme;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: _textThemeFor(locale?.languageCode),
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
