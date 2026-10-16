import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:malikiprayertimes/utils/fonts.dart';

/// Launch splash: deep-green brand screen shown briefly at startup.
///
/// Compass-rose brand mark (1024x1024 PNG, fully transparent corners) centered
/// on the Maliki deep green, "Maliki Prayer Times" in Source Serif 4 beneath
/// it, a hand-drawn rotating eight-pointed star loader, and the two credit
/// lines pinned to the bottom. The credit strings are verbatim proper-name
/// credits (user's exact spellings) and are intentionally not localized.
class SplashScreen extends StatefulWidget {
  /// Brand mark: compass rose with transparent corners, so it sits on the
  /// deep green with no box.
  static const String logoAsset = 'assets/branding/compass_rose.png';

  /// Deep green shared with the native Android launch background.
  static const Color splashGreen = Color(0xFF003527);

  /// Gold used for the loader star (Stitch gold token).
  static const Color splashGold = Color(0xFFE5C277);

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kick off the decode on the first frame so the art is already in the
    // image cache when the splash paints. Without this the lazy first-frame
    // decode finishes after the splash is gone and only the green
    // background is ever visible (device report).
    precacheImage(const AssetImage(SplashScreen.logoAsset), context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SplashScreen.splashGreen,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 88),
                      child: Image.asset(
                        SplashScreen.logoAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Maliki Prayer Times',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.latinSerif,
                        fontSize: 26,
                        letterSpacing: 2.0,
                        color: Color(0xFFF6F1E3),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _IslamicLoader(),
                  ],
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

/// Islamic loading animation: a slowly rotating eight-pointed star (khatam /
/// Rub el Hizb — two superimposed squares) hand-drawn with a [CustomPainter].
/// License-clean, no new dependencies, no generic progress indicator.
class _IslamicLoader extends StatefulWidget {
  const _IslamicLoader();

  @override
  State<_IslamicLoader> createState() => _IslamicLoaderState();
}

class _IslamicLoaderState extends State<_IslamicLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: const Size(48, 48),
        painter: _EightPointStarPainter(
          angle: _controller.value * 2 * math.pi,
        ),
      ),
    );
  }
}

class _EightPointStarPainter extends CustomPainter {
  final double angle;

  const _EightPointStarPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SplashScreen.splashGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final radius = size.width / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    // Two squares superimposed at 45 degrees.
    for (var k = 0; k < 2; k++) {
      final path = Path();
      for (var i = 0; i <= 4; i++) {
        final a = (i % 4) * math.pi / 2 + k * math.pi / 4;
        final point = Offset(math.cos(a) * radius, math.sin(a) * radius);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
    // Inner ring for balance.
    canvas.drawCircle(Offset.zero, radius * 0.45, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EightPointStarPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
