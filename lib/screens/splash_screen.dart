import 'package:flutter/material.dart';

/// Launch splash: deep-green brand screen shown briefly at startup.
///
/// Shows the full user-provided logo (with text ring) centered on the
/// Maliki deep green, with the two credit lines pinned to the bottom.
/// The credit strings are verbatim proper-name credits (user's exact
/// spellings) and are intentionally not localized.
class SplashScreen extends StatelessWidget {
  /// Path of the full logo art (white corners removed → transparent).
  static const String logoAsset = 'assets/branding/logo_full_transparent.png';

  /// Deep green shared with the native Android launch background.
  static const Color splashGreen = Color(0xFF003527);

  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: splashGreen,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Image.asset(
                    logoAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    'Developed by Muhammad Talha Bin Farid Al Maliki',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Color(0xFFD9F7ED),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Maliki Fiqh Subcontinent',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
