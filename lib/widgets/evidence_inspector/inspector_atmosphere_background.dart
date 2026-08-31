import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Soft sculptural 3D atmosphere behind Evidence Inspector content.
///
/// Presentation only. Does not interpret evidence, include text, or
/// compete with media, metadata, or controls.
class InspectorAtmosphereBackground extends StatelessWidget {
  const InspectorAtmosphereBackground({super.key});

  static const Key layerKey = Key('evidence_inspector_atmosphere');

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(
        key: layerKey,
        painter: InspectorAtmospherePainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

/// Very low-contrast sculptural volume on the Inspector field.
///
/// Reads as a premium 3D material — folded form, not illustration.
class InspectorAtmospherePainter extends CustomPainter {
  const InspectorAtmospherePainter();

  static const Color field = Color(0xFF3F4B5E);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = field);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.08, -0.22),
          radius: 1.18,
          colors: [
            const Color(0xFF4C5A6E).withValues(alpha: 0.42),
            field.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    _sculptedForm(
      canvas,
      center: Offset(size.width * 0.24, size.height * 0.68),
      rx: size.width * 0.46,
      ry: size.height * 0.32,
      rotation: -0.28,
      body: const Color(0xFF2C3646).withValues(alpha: 0.20),
      light: AppColors.canvasGlow.withValues(alpha: 0.06),
      shade: const Color(0xFF161C26).withValues(alpha: 0.14),
    );

    _sculptedForm(
      canvas,
      center: Offset(size.width * 0.64, size.height * 0.40),
      rx: size.width * 0.52,
      ry: size.height * 0.36,
      rotation: 0.34,
      body: const Color(0xFF536274).withValues(alpha: 0.18),
      light: const Color(0xFFC9D6E6).withValues(alpha: 0.09),
      shade: const Color(0xFF1E2632).withValues(alpha: 0.16),
    );

    _softVolume(
      canvas,
      center: Offset(size.width * 0.62, size.height * 0.58),
      radius: math.max(size.width, size.height) * 0.30,
      color: const Color(0xFF121820).withValues(alpha: 0.10),
      squashY: 0.32,
    );

    _softVolume(
      canvas,
      center: Offset(size.width * 0.48, size.height * 0.28),
      radius: math.max(size.width, size.height) * 0.22,
      color: AppColors.canvasHaloCore.withValues(alpha: 0.045),
      squashY: 0.58,
    );
  }

  void _sculptedForm(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required double rotation,
    required Color body,
    required Color light,
    required Color shade,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2,
      height: ry * 2,
    );

    canvas.drawOval(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.28, -0.38),
          radius: 0.92,
          colors: [
            body,
            body.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-rx * 0.18, -ry * 0.22),
        width: rx * 1.15,
        height: ry * 0.95,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [light, light.withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(-rx * 0.18, -ry * 0.22),
            radius: rx * 0.72,
          ),
        ),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rx * 0.16, ry * 0.28),
        width: rx * 1.35,
        height: ry * 1.05,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [shade, shade.withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(rx * 0.16, ry * 0.28),
            radius: rx * 0.82,
          ),
        ),
    );

    canvas.restore();
  }

  void _softVolume(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double squashY,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, squashY);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
