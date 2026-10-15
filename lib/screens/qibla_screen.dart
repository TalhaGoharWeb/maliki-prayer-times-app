import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/utils/qibla.dart';

/// Milestone 2 qibla screen: a static compass dial showing the great-circle
/// bearing from [coordinates] to the Kaaba.
///
/// This screen is deliberately NOT a live compass: it draws the dial once
/// with the Kaaba-direction arrow fixed at the computed bearing, and tells
/// the user to align it with a real compass. No rotation animation pretends
/// to track the device.
class QiblaScreen extends StatelessWidget {
  final Coordinates coordinates;
  final String locationName;

  const QiblaScreen({
    super.key,
    required this.coordinates,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    final bearing =
        qiblaBearingDegrees(coordinates.latitude, coordinates.longitude);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla direction'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            locationName,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${bearing.toStringAsFixed(1)}° clockwise from true north',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _QiblaDialPainter(bearing),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Align using any compass app or physical compass — this screen '
            'does not use your phone\'s compass sensor.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Static compass dial: north marker, degree ticks, cardinal letters, and a
/// fixed Kaaba-direction arrow at [bearingDegrees]. Nothing rotates.
class _QiblaDialPainter extends CustomPainter {
  final double bearingDegrees;

  _QiblaDialPainter(this.bearingDegrees);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF616161);
    canvas.drawCircle(center, radius, ringPaint);

    // Degree ticks every 15°, longer at the cardinals.
    for (var deg = 0; deg < 360; deg += 15) {
      final rad = deg * math.pi / 180.0;
      final isCardinal = deg % 90 == 0;
      final inner = radius - (isCardinal ? 14 : 8);
      final p1 = center +
          Offset(math.sin(rad), -math.cos(rad)) * inner;
      final p2 = center +
          Offset(math.sin(rad), -math.cos(rad)) * radius;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = isCardinal ? 3 : 1.5
          ..color = const Color(0xFF616161),
      );
    }

    // Cardinal letters.
    const cardinals = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final rad = i * 90 * math.pi / 180.0;
      final pos = center +
          Offset(math.sin(rad), -math.cos(rad)) * (radius - 26);
      final tp = TextPainter(
        text: TextSpan(
          text: cardinals[i],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: i == 0
                ? const Color(0xFFB71C1C)
                : const Color(0xFF212121),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        pos - Offset(tp.width / 2, tp.height / 2),
      );
    }

    // North marker: small red triangle at the top of the dial.
    final northTip = center + const Offset(0, -1) * (radius - 2);
    final northPath = Path()
      ..moveTo(northTip.dx, northTip.dy)
      ..lineTo(northTip.dx - 7, northTip.dy + 14)
      ..lineTo(northTip.dx + 7, northTip.dy + 14)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()..color = const Color(0xFFB71C1C),
    );

    // Kaaba-direction arrow at the bearing, drawn from the center.
    final bRad = bearingDegrees * math.pi / 180.0;
    final dir = Offset(math.sin(bRad), -math.cos(bRad));
    final tip = center + dir * (radius - 34);
    final arrowPaint = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF00695C);
    canvas.drawLine(center, tip, arrowPaint);
    // Arrowhead.
    const headLen = 16.0;
    const headAngle = 0.5; // radians from the shaft
    for (final sign in [-1.0, 1.0]) {
      final a = bRad + math.pi + sign * headAngle;
      canvas.drawLine(
        tip,
        tip + Offset(math.sin(a), -math.cos(a)) * headLen,
        arrowPaint,
      );
    }

    // Label under the arrow tip.
    final labelPos = center + dir * (radius - 58);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Qibla',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00695C),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      labelPos - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_QiblaDialPainter oldDelegate) =>
      oldDelegate.bearingDegrees != bearingDegrees;
}
