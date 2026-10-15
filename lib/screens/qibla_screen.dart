import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/qibla.dart';
import 'package:malikiprayertimes/utils/solar.dart';

/// Qibla tab: the great-circle bearing to the Kaaba with a static compass
/// dial, distance, rhumb-line bearing, calibration guidance, and the
/// sun-alignment method.
///
/// The dial is deliberately NOT a live compass: it draws once with the
/// Kaaba-direction arrow fixed at the computed bearing, and tells the user
/// to align it with a real compass. No rotation animation pretends to track
/// the device. Magnetic declination is intentionally omitted (no offline
/// geomagnetic model — the figure is never invented).
class QiblaScreen extends StatelessWidget {
  final Coordinates coordinates;
  final String locationName;
  final Duration timeZoneOffset;

  /// When null, the sun-alignment "Remind me" button is hidden (e.g. in
  /// widget tests where no real notification plugin exists).
  final NotificationService? notifications;

  const QiblaScreen({
    super.key,
    required this.coordinates,
    required this.locationName,
    required this.timeZoneOffset,
    this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    final bearing = qiblaBearingDegrees(
      coordinates.latitude,
      coordinates.longitude,
    );
    final point = compassPoint16(bearing);
    final km = qiblaDistanceKm(coordinates.latitude, coordinates.longitude);
    final nm = km / 1.852;
    final rhumb = qiblaRhumbBearingDeg(
      coordinates.latitude,
      coordinates.longitude,
    );
    final eastOffset = bearing - 90.0;

    // Sun-alignment: the wall-clock time today when the sun's azimuth
    // equals the qibla bearing.
    final now = DateTime.now().toUtc().add(timeZoneOffset);
    final today = DateTime(now.year, now.month, now.day);
    final alignUtc = sunAlignmentUtcHours(
      coordinates.latitude,
      coordinates.longitude,
      today,
      bearing,
    );
    DateTime? alignWall;
    if (alignUtc != null) {
      final base = DateTime.utc(today.year, today.month, today.day);
      alignWall = base
          .add(Duration(microseconds: (alignUtc * 3600 * 1e6).round()))
          .add(timeZoneOffset);
    }

    String fmtNum(num value, {int decimals = 1}) {
      var s = value.toStringAsFixed(decimals);
      if (lang == 'en' || lang == 'fr') {
        // Thousands separator for readability.
        final parts = s.split('.');
        final head = parts[0].replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => lang == 'fr' ? ' ' : ',',
        );
        s = parts.length > 1 ? '$head.${parts[1]}' : head;
      }
      return localizeDigits(s, lang);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Location header.
        Text(
          locationName,
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.pin_drop, size: 14, color: scheme.secondary),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${coordinates.latitude.toStringAsFixed(5)}°  ·  '
                  '${coordinates.longitude.toStringAsFixed(5)}°',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Azimuth hero card.
        Card(
          color: scheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.explore,
                        size: 14, color: scheme.inversePrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.kaabaAzimuth.toUpperCase(),
                        style: AppFonts.eyebrow(context).copyWith(
                          color: scheme.inversePrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        point,
                        style: AppFonts.badgeLabel(context).copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${fmtNum(bearing)}°',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: scheme.primaryContainer, height: 1),
                const SizedBox(height: 12),
                _StatRow(
                  icon: Icons.route,
                  label: l10n.greatCircle,
                  value:
                      '${l10n.kmValue(fmtNum(km, decimals: 0))}  ·  ${l10n.nauticalMiles(fmtNum(nm, decimals: 0))}',
                  light: true,
                ),
                const SizedBox(height: 8),
                _StatRow(
                  icon: Icons.straighten,
                  label: l10n.rhumbLine,
                  value: '${fmtNum(rhumb)}°',
                  light: true,
                ),
                const SizedBox(height: 8),
                _StatRow(
                  icon: Icons.north,
                  label: l10n.trueNorthOffset,
                  value: l10n.vsDueEast(
                      '${eastOffset >= 0 ? '+' : ''}${fmtNum(eastOffset)}'),
                  light: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Static dial.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.hdr_weak,
                        size: 16, color: scheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.staticVector,
                        style: AppFonts.eyebrow(context).copyWith(
                          color: scheme.secondary,
                        ),
                      ),
                    ),
                    Text(
                      l10n.northUp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1,
                  child: Semantics(
                    // The dial is pure CustomPaint: expose its essential
                    // information (the bearing) to screen readers.
                    label: l10n.qiblaBearing(bearing.toStringAsFixed(1)),
                    child: CustomPaint(
                      painter: _QiblaDialPainter(
                        bearing,
                        l10n.qiblaLabel,
                        scheme,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Calibration notice with expandable steps.
        _CalibrationCard(bearing: bearing),
        const SizedBox(height: 12),

        // Sun-alignment method.
        _SunAlignCard(
          alignWall: alignWall,
          languageCode: lang,
          notifications: notifications,
        ),
      ],
    );
  }
}

/// Label + value row used inside the dark hero card.
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool light;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = light ? scheme.onPrimary : scheme.onSurface;
    final sub = light ? scheme.onInverseSurface : scheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: sub),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: sub,
                ),
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: fg,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Calibration notice: honest non-compass disclaimer + expandable steps.
class _CalibrationCard extends StatelessWidget {
  final double bearing;

  const _CalibrationCard({required this.bearing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: scheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.calibrationTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.calibrationBody, style: theme.textTheme.bodySmall),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  l10n.calibrationSteps,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  _Step(number: '1', text: l10n.step1),
                  _Step(number: '2', text: l10n.step2),
                  _Step(number: '3', text: l10n.step3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Sun-alignment card: the computed time when the sun's azimuth matches the
/// qibla bearing, with an optional one-time reminder.
class _SunAlignCard extends StatefulWidget {
  final DateTime? alignWall;
  final String? languageCode;
  final NotificationService? notifications;

  const _SunAlignCard({
    required this.alignWall,
    required this.languageCode,
    required this.notifications,
  });

  @override
  State<_SunAlignCard> createState() => _SunAlignCardState();
}

class _SunAlignCardState extends State<_SunAlignCard> {
  bool _busy = false;
  bool _scheduled = false;

  Future<void> _remind(AppLocalizations l10n) async {
    final notifications = widget.notifications;
    final alignWall = widget.alignWall;
    if (notifications == null || alignWall == null) return;
    setState(() => _busy = true);
    try {
      final granted = await notifications.areNotificationsEnabled();
      if (!mounted) return;
      if (!granted) {
        final ok = await notifications.requestPermissions();
        if (!mounted) return;
        if (!ok) {
          setState(() => _busy = false);
          return;
        }
      }
      // Convert the wall-clock alignment back to a UTC instant.
      final scheduledUtc = alignWall.toUtc();
      await notifications.scheduleSunReminder(
        scheduledUtc: scheduledUtc,
        title: l10n.sunReminderTitle,
        body: l10n.sunReminderBody,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _scheduled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reminderSet(
              localizeDigits(_hhmm(alignWall), widget.languageCode))),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final alignWall = widget.alignWall;

    return Card(
      color: scheme.tertiaryFixed,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.wb_sunny,
                      color: scheme.onTertiaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.sunAlignTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onTertiaryFixed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.sunAlignBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryFixedVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (alignWall != null) ...[
              Text(
                l10n.sunAlignAt,
                style: AppFonts.eyebrow(context).copyWith(
                  color: scheme.onTertiaryFixedVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localizeDigits(_hhmm(alignWall), widget.languageCode),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: scheme.onTertiaryFixed,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.sunAlignNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onTertiaryFixedVariant,
                ),
              ),
              if (widget.notifications != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: (_busy || _scheduled) ? null : () => _remind(l10n),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.alarm, size: 18),
                  label: Text(_scheduled
                      ? l10n.reminderSet(localizeDigits(
                          _hhmm(alignWall), widget.languageCode))
                      : l10n.remindMe),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.tertiaryContainer,
                    foregroundColor: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ] else
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: scheme.onTertiaryFixedVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.sunAlignNone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryFixedVariant,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Static compass dial: north marker, degree ticks, cardinal letters, and a
/// fixed Kaaba-direction arrow at [bearingDegrees]. Nothing rotates.
class _QiblaDialPainter extends CustomPainter {
  final double bearingDegrees;
  final String qiblaLabel;
  final ColorScheme scheme;

  _QiblaDialPainter(this.bearingDegrees, this.qiblaLabel, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = scheme.outline;
    canvas.drawCircle(center, radius, ringPaint);

    // Degree ticks every 15°, longer at the cardinals.
    for (var deg = 0; deg < 360; deg += 15) {
      final rad = deg * math.pi / 180.0;
      final isCardinal = deg % 90 == 0;
      final inner = radius - (isCardinal ? 14 : 8);
      final p1 = center + Offset(math.sin(rad), -math.cos(rad)) * inner;
      final p2 = center + Offset(math.sin(rad), -math.cos(rad)) * radius;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = isCardinal ? 3 : 1.5
          ..color = scheme.onSurfaceVariant,
      );
    }

    // Cardinal letters.
    const cardinals = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final rad = i * 90 * math.pi / 180.0;
      final pos =
          center + Offset(math.sin(rad), -math.cos(rad)) * (radius - 28);
      final tp = TextPainter(
        text: TextSpan(
          text: cardinals[i],
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: i == 0 ? scheme.error : scheme.onSurface,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // North marker: small red triangle at the top of the dial.
    final northTip = center + const Offset(0, -1) * (radius - 2);
    final northPath = Path()
      ..moveTo(northTip.dx, northTip.dy)
      ..lineTo(northTip.dx - 7, northTip.dy + 14)
      ..lineTo(northTip.dx + 7, northTip.dy + 14)
      ..close();
    canvas.drawPath(northPath, Paint()..color = scheme.error);

    // Kaaba-direction arrow at the bearing, drawn from the center.
    final bRad = bearingDegrees * math.pi / 180.0;
    final dir = Offset(math.sin(bRad), -math.cos(bRad));
    final tip = center + dir * (radius - 36);
    final arrowPaint = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = scheme.primary;
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
    final labelPos = center + dir * (radius - 62);
    final tp = TextPainter(
      text: TextSpan(
        text: qiblaLabel,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: scheme.primary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_QiblaDialPainter oldDelegate) =>
      oldDelegate.bearingDegrees != bearingDegrees ||
      oldDelegate.scheme != scheme;
}
