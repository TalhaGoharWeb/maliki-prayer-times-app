import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/services/compass_service.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/timezone_service.dart';
import 'package:malikiprayertimes/utils/digits.dart';
import 'package:malikiprayertimes/utils/fonts.dart';
import 'package:malikiprayertimes/utils/qibla.dart';
import 'package:malikiprayertimes/utils/solar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qibla tab: the great-circle bearing to the Kaaba with a live compass dial,
/// distance, rhumb-line bearing, calibration guidance, and the sun-alignment
/// method.
///
/// The dial is LIVE when the device has a magnetometer: it rotates with the
/// device so the teal qibla arrow always points along the computed bearing.
/// Without a compass sensor it falls back to the static dial with an
/// explanatory note. Magnetic declination is intentionally omitted (no
/// offline geomagnetic model — the figure is never invented); the live
/// compass follows the magnetic sensor and says so.
class QiblaScreen extends StatefulWidget {
  final Coordinates coordinates;
  final String locationName;
  final Duration timeZoneOffset;

  /// IANA zone id the sun-alignment time renders in. When non-null, the
  /// wall-clock offset resolves from the zone; when null the
  /// constructor-supplied offset is used (legacy).
  final String? zoneId;

  /// When null, the sun-alignment "Remind me" button is hidden (e.g. in
  /// widget tests where no real notification plugin exists).
  final NotificationService? notifications;

  /// Injected compass (widget tests). When null, a [SensorCompassService]
  /// is created and owned by this screen.
  final CompassService? compass;

  /// Test-only hook invoked at the end of every build so widget tests can
  /// count rebuilds (verifies the heading throttle, REL-08). Null in
  /// production.
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Whether the sun-alignment time renders 24-hour (false = 12-hour with
  /// day-period markers). Defaults to 12-hour, the app-wide default.
  final bool use24Hour;

  const QiblaScreen({
    super.key,
    required this.coordinates,
    required this.locationName,
    required this.timeZoneOffset,
    this.zoneId,
    this.notifications,
    this.compass,
    this.onBuild,
    this.use24Hour = false,
  });

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  late final CompassService _compass;
  late final bool _ownsCompass;
  StreamSubscription<double?>? _liveSub;
  StreamSubscription<CompassQuality>? _qualitySub;
  bool _liveMode = false;

  /// Latest magnetometer health; drives the calibration warning state.
  /// Starts unknown until the first assessed sample arrives.
  CompassQuality _quality = CompassQuality.unknown;

  /// Heading-throttle state (REL-08): the raw sensor fires at hardware rate
  /// (tens–hundreds of events/sec), but this subscription only drives the
  /// calibration card's live-ness flag.
  int? _lastRoundedHeading;
  DateTime _lastHeadingUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _ownsCompass = widget.compass == null;
    _compass = widget.compass ?? SensorCompassService();
    // Track live-ness for the calibration card; the dial itself renders
    // from a StreamBuilder on the same broadcast stream.
    _liveSub = _compass.headings.listen((heading) {
      if (!mounted) return;
      // Throttle: rebuild only when the rounded heading moved by ≥1° or
      // ≥100ms elapsed since the last UI update — and only when the live
      // flag actually flips, so a steady stream costs nothing.
      final live = heading != null;
      final rounded = heading?.round();
      final now = DateTime.now();
      final moved = rounded != _lastRoundedHeading &&
          (_lastRoundedHeading == null ||
              rounded == null ||
              (rounded - _lastRoundedHeading!).abs() >= 1);
      if (moved ||
          now.difference(_lastHeadingUiUpdate) >=
              const Duration(milliseconds: 100)) {
        _lastRoundedHeading = rounded;
        _lastHeadingUiUpdate = now;
        if (_liveMode != live) setState(() => _liveMode = live);
      }
    });
    // Magnetometer health for the calibration warning. A change in quality
    // always rebuilds (it is rare); the dial reads the same value.
    _qualitySub = _compass.quality.listen((quality) {
      if (!mounted) return;
      if (_quality != quality) setState(() => _quality = quality);
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _qualitySub?.cancel();
    if (_ownsCompass) _compass.dispose();
    super.dispose();
  }

  /// Wall-clock offset for the sun-alignment display: the zone's offset
  /// for today when [QiblaScreen.zoneId] is set, otherwise the
  /// constructor-supplied offset (legacy).
  Duration _displayOffset() {
    final zoneId = widget.zoneId;
    if (zoneId != null) {
      try {
        return TimezoneService.offsetFor(zoneId, DateTime.now());
      } catch (_) {
        // Fall through to the constructor offset.
      }
    }
    return widget.timeZoneOffset;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    final bearing = qiblaBearingDegrees(
      widget.coordinates.latitude,
      widget.coordinates.longitude,
    );
    final point = compassPoint16(bearing);
    final km = qiblaDistanceKm(widget.coordinates.latitude, widget.coordinates.longitude);
    final nm = km / 1.852;
    final rhumb = qiblaRhumbBearingDeg(
      widget.coordinates.latitude,
      widget.coordinates.longitude,
    );
    final eastOffset = bearing - 90.0;

    // Sun-alignment: the wall-clock time today when the sun's azimuth
    // equals the qibla bearing. Rendered in the location zone's frame
    // (or the constructor offset's frame when no zone was supplied).
    final displayOffset = _displayOffset();
    final now = DateTime.now().toUtc().add(displayOffset);
    final today = DateTime(now.year, now.month, now.day);
    final alignUtc = sunAlignmentUtcHours(
      widget.coordinates.latitude,
      widget.coordinates.longitude,
      today,
      bearing,
    );
    DateTime? alignWall;
    if (alignUtc != null) {
      final base = DateTime.utc(today.year, today.month, today.day);
      alignWall = base
          .add(Duration(microseconds: (alignUtc * 3600 * 1e6).round()))
          .add(displayOffset);
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
        // French uses a comma as the decimal separator ("7 451,5 km").
        final decSep = lang == 'fr' ? ',' : '.';
        s = parts.length > 1 ? '$head$decSep${parts[1]}' : head;
      }
      return localizeDigits(s, lang);
    }

    widget.onBuild?.call();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Location header.
        Text(
          widget.locationName,
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
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${widget.coordinates.latitude.toStringAsFixed(5)}°  ·  '
                  '${widget.coordinates.longitude.toStringAsFixed(5)}°',
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

        // Compass dial: live when the device has a magnetometer, static
        // fallback otherwise.
        _CompassDial(
          compass: _compass,
          bearing: bearing,
          quality: _quality,
        ),
        const SizedBox(height: 12),

        // Calibration notice with expandable steps (copy follows the mode).
        _CalibrationCard(
            bearing: bearing, live: _liveMode, quality: _quality),
        const SizedBox(height: 12),

        // Sun-alignment method.
        _SunAlignCard(
          alignWall: alignWall,
          languageCode: lang,
          // The card recovers the true UTC instant from the wall clock, so
          // it must use the same frame the wall clock was computed in.
          timeZoneOffset: displayOffset,
          notifications: widget.notifications,
          use24Hour: widget.use24Hour,
        ),
      ],
    );
  }
}

/// Whether the sun-alignment reminder may still be scheduled for
/// [alignWall]: the event's true UTC instant must lie in the future.
/// [alignWall] carries the wall-clock reading of the event (a UTC-mode
/// DateTime whose clock shows local time), so subtract [timeZoneOffset] to
/// recover the true UTC instant before comparing. Scheduling a past instant
/// would fire immediately (REL-06).
@visibleForTesting
bool sunReminderSchedulable(
  DateTime alignWall,
  Duration timeZoneOffset,
  DateTime nowUtc,
) =>
    alignWall.subtract(timeZoneOffset).isAfter(nowUtc);

/// Compass dial: live when the compass emits a heading, static fallback
/// while waiting or when the device has no magnetometer.
///
/// Live behavior is standard-compass: the dial artwork rotates by
/// −heading so the teal qibla arrow stays fixed on the computed bearing
/// while the dial turns with the device. Turn until the arrow points
/// straight up — then the top of the phone faces the qibla.
///
/// The raw sensor stream is jumpy, so headings pass through a
/// [HeadingSmoother] (small time constant: the dial glides, it never
/// lags). When the smoothed heading lands within ±2° of the bearing the
/// dial shows a distinct aligned state with a gentle haptic pulse; a live
/// "X° off" readout helps the user home in the rest of the way. A suspect
/// magnetometer ([CompassQuality.suspect]) surfaces a calibration warning
/// instead of a confident-but-wrong arrow.
class _CompassDial extends StatefulWidget {
  final CompassService compass;
  final double bearing;
  final CompassQuality quality;

  const _CompassDial({
    required this.compass,
    required this.bearing,
    required this.quality,
  });

  @override
  State<_CompassDial> createState() => _CompassDialState();
}

class _CompassDialState extends State<_CompassDial> {
  final HeadingSmoother _smoother = HeadingSmoother();
  StreamSubscription<double?>? _headingSub;

  /// True once any heading event (including null) has arrived.
  bool _receivedAny = false;

  /// Latest smoothed heading; null while waiting or when the sensor is
  /// unavailable. The dial and readouts render this value.
  double? _smoothHeading;

  /// Whether the aligned haptic has fired for the current aligned visit;
  /// reset when the user drifts back out of the window.
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _headingSub = widget.compass.headings.listen((heading) {
      if (!mounted) return;
      setState(() {
        _receivedAny = true;
        if (heading == null) {
          _smoothHeading = null;
          _smoother.reset();
          _wasAligned = false;
        } else {
          _smoothHeading = _smoother.update(heading);
          final aligned = angularDifferenceDegrees(
                  _smoothHeading!, widget.bearing) <=
              kQiblaAlignedToleranceDegrees;
          if (aligned && !_wasAligned) {
            // A gentle pulse the moment the qibla locks in. In widget
            // tests the platform channel is unmocked and the call is a
            // harmless no-op.
            HapticFeedback.lightImpact();
          }
          _wasAligned = aligned;
        }
      });
    });
  }

  @override
  void dispose() {
    _headingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    final waiting = !_receivedAny;
    // Null while waiting, null when the sensor is unavailable.
    final double? heading = waiting ? null : _smoothHeading;
    final live = heading != null;
    final suspect = widget.quality == CompassQuality.suspect;

    final headerTitle = live ? l10n.liveCompassTitle : l10n.staticVector;
    final semanticsLabel = heading != null
        ? l10n.liveHeading(localizeDigits(heading.toStringAsFixed(0), lang))
        : l10n.qiblaBearing(
            localizeDigits(widget.bearing.toStringAsFixed(1), lang));

    final offBy = heading == null
        ? null
        : angularDifferenceDegrees(heading, widget.bearing);
    final aligned =
        offBy != null && offBy <= kQiblaAlignedToleranceDegrees;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  live ? Icons.explore : Icons.hdr_weak,
                  size: 16,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headerTitle,
                    style: AppFonts.eyebrow(context).copyWith(
                      color: scheme.secondary,
                    ),
                  ),
                ),
                if (live)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.liveBadge,
                          style: AppFonts.badgeLabel(context).copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (waiting)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.secondary,
                    ),
                  )
                else
                  Text(
                    l10n.northUp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.secondary,
                    ),
                  ),
              ],
            ),
            // Magnetometer health warning: shown instead of a
            // confident-but-wrong arrow when the field looks off.
            if (live && suspect) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.calibrationNeeded,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.calibrationHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: Semantics(
                // The dial is pure CustomPaint: expose its essential
                // information to screen readers.
                label: semanticsLabel,
                child: Transform.rotate(
                  // Rotate the artwork opposite the device heading so
                  // the qibla arrow stays fixed on the bearing.
                  angle: heading != null ? -heading * math.pi / 180.0 : 0,
                  child: CustomPaint(
                    painter: _QiblaDialPainter(
                      widget.bearing,
                      l10n.qiblaLabel,
                      scheme,
                      aligned: aligned,
                      // Localized cardinal letters (I-12), in N/E/S/W
                      // order. ar/ur use the Perso-Arabic compass
                      // abbreviations; fr uses N/E/S/O.
                      cardinals: switch (lang) {
                        'ar' || 'ur' => const ['ش', 'ق', 'ج', 'غ'],
                        'fr' => const ['N', 'E', 'S', 'O'],
                        _ => const ['N', 'E', 'S', 'W'],
                      },
                      cardinalFontFamily: switch (lang) {
                        'ur' => AppFonts.urdu,
                        'ar' => AppFonts.arabic,
                        _ => AppFonts.latinSans,
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (heading != null) ...[
              Text(
                l10n.liveHeading(
                  localizeDigits(heading.toStringAsFixed(0), lang),
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (aligned)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.tertiary,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 18, color: scheme.tertiary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.qiblaAligned,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  l10n.degreesOff(
                    localizeDigits(offBy!.toStringAsFixed(0), lang),
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                l10n.qiblaLiveNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gesture, size: 14, color: scheme.secondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.calibrationHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ] else if (waiting)
              Text(
                l10n.compassAcquiring,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.secondary,
                ),
                textAlign: TextAlign.center,
              )
            else
              Text(
                l10n.compassUnavailable,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
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
            alignment: AlignmentDirectional.centerEnd,
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

/// Calibration notice: mode-aware guidance + expandable steps.
///
/// When the magnetometer health is [CompassQuality.suspect] the card leads
/// with a clear recalibration warning instead of the routine guidance.
class _CalibrationCard extends StatelessWidget {
  final double bearing;
  final bool live;
  final CompassQuality quality;

  const _CalibrationCard({
    required this.bearing,
    required this.live,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final suspect = quality == CompassQuality.suspect;
    final steps = live
        ? [l10n.step1Live, l10n.step2Live, l10n.step3Live]
        : [l10n.step1, l10n.step2, l10n.step3];
    return Card(
      // A suspect sensor gets the error tint so the warning reads as a
      // warning, not as routine guidance.
      color: suspect ? scheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  suspect ? Icons.warning_amber_rounded : Icons.info_outline,
                  size: 18,
                  color:
                      suspect ? scheme.onErrorContainer : scheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suspect ? l10n.calibrationNeeded : l10n.calibrationTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: suspect ? scheme.onErrorContainer : null,
                      fontWeight:
                          suspect ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suspect
                  ? l10n.calibrationNeededBody
                  : (live ? l10n.calibrationBodyLive : l10n.calibrationBody),
              style: theme.textTheme.bodySmall?.copyWith(
                color: suspect ? scheme.onErrorContainer : null,
              ),
            ),
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
                  for (var i = 0; i < steps.length; i++)
                    _Step(number: '${i + 1}', text: steps[i]),
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
  final Duration timeZoneOffset;
  final NotificationService? notifications;

  /// Whether the alignment time renders 24-hour (false = 12-hour).
  final bool use24Hour;

  const _SunAlignCard({
    required this.alignWall,
    required this.languageCode,
    required this.timeZoneOffset,
    required this.notifications,
    required this.use24Hour,
  });

  @override
  State<_SunAlignCard> createState() => _SunAlignCardState();
}

class _SunAlignCardState extends State<_SunAlignCard> {
  bool _busy = false;
  bool _scheduled = false;

  /// Prefs key under which [NotificationService.scheduleSunReminder] persists
  /// the pending reminder's fire time (the `_sunReminderUtcKey` in
  /// notification_service.dart). Duplicated here because that key is private
  /// there and this card must not reach into notification internals.
  static const _persistedSunReminderKey = 'sun_reminder_utc';

  @override
  void initState() {
    super.initState();
    _seedScheduled();
  }

  /// Seed [_scheduled] from the persisted reminder (REL-16): a reminder set
  /// before a restart is restored by `rescheduleAll` while its fire time is
  /// still in the future, so the card must open in the scheduled state
  /// rather than offering "Remind me" again.
  Future<void> _seedScheduled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_persistedSunReminderKey);
      final utc = raw == null ? null : DateTime.tryParse(raw);
      if (utc != null && utc.isAfter(DateTime.now().toUtc())) {
        if (mounted) setState(() => _scheduled = true);
      }
    } catch (_) {
      // Persistence is best-effort; the card works without it.
    }
  }

  Future<void> _remind(AppLocalizations l10n) async {
    final notifications = widget.notifications;
    final alignWall = widget.alignWall;
    if (notifications == null || alignWall == null) return;
    // The true UTC instant of the event (see [sunReminderSchedulable]).
    // NOTE: this used to be `alignWall.toUtc()` — a no-op, since alignWall
    // is already UTC-mode — which scheduled the reminder `timeZoneOffset`
    // late and skewed the past-check by the same amount. Fixed 2026-10-16.
    final scheduledUtc = alignWall.subtract(widget.timeZoneOffset);
    if (!sunReminderSchedulable(
        alignWall, widget.timeZoneOffset, DateTime.now().toUtc())) {
      // Today's alignment already passed: never schedule a past instant
      // (it would fire immediately) — show the passed note instead.
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sunAlignPassed)),
      );
      return;
    }
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
              formatPrayerTime(alignWall, widget.languageCode,
                use24Hour: widget.use24Hour))),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Cancel the pending sun-alignment reminder (REL-16).
  Future<void> _cancel() async {
    final notifications = widget.notifications;
    if (notifications == null || _busy) return;
    setState(() => _busy = true);
    try {
      await notifications.cancelSunReminder();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _scheduled = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final alignWall = widget.alignWall;
    // Already-passed alignment: the button is disabled and the passed note
    // is shown instead of scheduling (REL-06).
    final alignPassed = alignWall != null &&
        !sunReminderSchedulable(
            alignWall, widget.timeZoneOffset, DateTime.now().toUtc());

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
                formatPrayerTime(alignWall, widget.languageCode,
                use24Hour: widget.use24Hour),
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
                if (alignPassed)
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16,
                          color: scheme.onTertiaryFixedVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.sunAlignPassed,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onTertiaryFixedVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (_scheduled)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.reminderSet(formatPrayerTime(
                              alignWall, widget.languageCode,
                              use24Hour: widget.use24Hour)),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onTertiaryFixed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _cancel,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(l10n.cancelReminder),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _remind(l10n),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.alarm, size: 18),
                    label: Text(l10n.remindMe),
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
///
/// When [aligned] is true (device heading within ±2° of the bearing) a gold
/// ring is drawn so the "you are facing the qibla" state is unmistakable.
class _QiblaDialPainter extends CustomPainter {
  final double bearingDegrees;
  final String qiblaLabel;
  final ColorScheme scheme;
  final bool aligned;

  /// Cardinal letters in N/E/S/W order, localized per UI locale.
  final List<String> cardinals;

  /// Font for [cardinals]: the Arabic-script font for ar/ur, Manrope
  /// otherwise.
  final String cardinalFontFamily;

  _QiblaDialPainter(this.bearingDegrees, this.qiblaLabel, this.scheme,
      {required this.cardinals,
      required this.cardinalFontFamily,
      this.aligned = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = scheme.outline;
    canvas.drawCircle(center, radius, ringPaint);

    // Aligned state: a gold ring outside the dial face.
    if (aligned) {
      canvas.drawCircle(
        center,
        radius + 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = scheme.tertiary,
      );
    }

    // Degree ticks: minor every 10°, medium at 30°, long at the cardinals.
    for (var deg = 0; deg < 360; deg += 10) {
      final rad = deg * math.pi / 180.0;
      final isCardinal = deg % 90 == 0;
      final isMedium = deg % 30 == 0;
      final inner = radius - (isCardinal ? 16 : (isMedium ? 12 : 7));
      final p1 = center + Offset(math.sin(rad), -math.cos(rad)) * inner;
      final p2 = center + Offset(math.sin(rad), -math.cos(rad)) * radius;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = isCardinal ? 3 : (isMedium ? 2 : 1.25)
          ..color = isCardinal
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
      );
    }

    // Degree numbers every 30° (cardinal points get letters instead).
    for (var deg = 30; deg < 360; deg += 30) {
      if (deg % 90 == 0) continue;
      final rad = deg * math.pi / 180.0;
      final pos =
          center + Offset(math.sin(rad), -math.cos(rad)) * (radius - 34);
      final tp = TextPainter(
        text: TextSpan(
          text: '$deg',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            color: scheme.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Cardinal letters.
    for (var i = 0; i < 4; i++) {
      final rad = i * 90 * math.pi / 180.0;
      final pos =
          center + Offset(math.sin(rad), -math.cos(rad)) * (radius - 30);
      final tp = TextPainter(
        text: TextSpan(
          text: cardinals[i],
          style: TextStyle(
            fontFamily: cardinalFontFamily,
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
      oldDelegate.aligned != aligned ||
      oldDelegate.scheme != scheme;
}
