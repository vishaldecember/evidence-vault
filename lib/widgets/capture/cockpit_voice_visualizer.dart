import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Concentric-ring voice presence for Capture Cockpit.
///
/// Rings pulse outward from a calm center. Amplitude drives organic wobble;
/// when quiet or idle, rings settle gently. Not an equalizer.
class CockpitVoiceVisualizer extends StatefulWidget {
  const CockpitVoiceVisualizer({
    super.key,
    required this.level,
    this.active = false,
    this.idleMotion = true,
  });

  /// Normalized microphone level in `0..1` (already clamped by caller).
  final double level;

  /// True while recording (or paused with residual energy).
  final bool active;

  /// Soft ambient motion when inactive / no amplitude (skipped under
  /// reduced-motion accessibility).
  final bool idleMotion;

  /// Neutral cockpit field — not brand blue/navy fill.
  static const Color fieldColor = Color(0xFF12141A);

  /// Soft ring stroke — warm grey with a hint of vault amber, not neon.
  static const Color ringColor = Color(0xFFB8B0A4);

  static const int ringCount = 5;

  @override
  State<CockpitVoiceVisualizer> createState() =>
      _CockpitVoiceVisualizerState();
}

class _CockpitVoiceVisualizerState extends State<CockpitVoiceVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  double _smoothed = 0.08;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) {
      return;
    }
    final dt = (_elapsed == Duration.zero)
        ? 1 / 60
        : (elapsed - _elapsed).inMicroseconds / 1e6;
    _elapsed = elapsed;
    if (dt <= 0 || dt > 0.1) {
      return;
    }

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = widget.active
        ? widget.level.clamp(0.06, 1.0)
        : (widget.idleMotion && !reduceMotion ? 0.1 : 0.06);

    // Fast attack, slower decay — organic, not jittery.
    final rate = target > _smoothed ? 10.0 : 4.5;
    _smoothed += (target - _smoothed) * (1 - math.exp(-rate * dt));

    final spin = reduceMotion
        ? 0.0
        : (0.35 + _smoothed * 1.1) * dt;
    _phase = (_phase + spin) % (math.pi * 2);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const Key('cockpit_voice_visualizer'),
      painter: _ConcentricRingPainter(
        level: _smoothed,
        phase: _phase,
        active: widget.active,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ConcentricRingPainter extends CustomPainter {
  _ConcentricRingPainter({
    required this.level,
    required this.phase,
    required this.active,
  });

  final double level;
  final double phase;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) * 0.42;

    // Soft radial field — premium dark, not flat blue.
    final field = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF1A1D24),
          CockpitVoiceVisualizer.fieldColor,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR * 1.35));
    canvas.drawRect(Offset.zero & size, field);

    // Calm focal core.
    final coreR = maxR * (0.07 + level * 0.04);
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..color = CockpitVoiceVisualizer.ringColor
            .withValues(alpha: 0.22 + level * 0.18),
    );
    canvas.drawCircle(
      center,
      coreR * 0.45,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12 + level * 0.1),
    );

    for (var i = 0; i < CockpitVoiceVisualizer.ringCount; i++) {
      final t = (i + 1) / CockpitVoiceVisualizer.ringCount;
      final base = maxR * (0.22 + t * 0.72);
      // Outward wobble — outer rings lag and amplify speech.
      final lag = phase - i * 0.55;
      final wobble = math.sin(lag) * (0.012 + level * 0.055) * (0.55 + t);
      final pulse = level * (0.04 + t * 0.08);
      final radius = base * (1 + wobble + pulse);

      final alpha = lerpDouble(0.22, 0.58, level)! * (1.08 - t * 0.28);
      final stroke = lerpDouble(1.4, 2.6, level)! * (1.12 - t * 0.22);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = CockpitVoiceVisualizer.ringColor.withValues(
          alpha: active ? alpha : alpha * 0.75,
        );

      // Slight elliptical breathe — organic, not a perfect music viz.
      final oval = Rect.fromCenter(
        center: center,
        width: radius * 2 * (1 + math.sin(lag * 0.5) * 0.018 * level),
        height: radius * 2 * (1 - math.sin(lag * 0.5) * 0.012 * level),
      );
      canvas.drawOval(oval, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.phase != phase ||
        oldDelegate.active != active;
  }
}
