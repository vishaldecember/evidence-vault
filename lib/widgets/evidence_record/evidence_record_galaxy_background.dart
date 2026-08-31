import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Unique Complete Record atmosphere — centered Milky-Way aura.
///
/// Not [SpaceCanvas]. Visual only; cards stay on top unchanged.
class EvidenceRecordGalaxyBackground extends StatelessWidget {
  const EvidenceRecordGalaxyBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(
        painter: _EvidenceRecordGalaxyPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _EvidenceRecordGalaxyPainter extends CustomPainter {
  const _EvidenceRecordGalaxyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.canvasVignette);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height) * 0.72;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.05,
          colors: [
            AppColors.canvasHaloCore.withValues(alpha: 0.22),
            AppColors.canvasHaloCore.withValues(alpha: 0.12),
            AppColors.canvasGlow.withValues(alpha: 0.28),
            AppColors.canvasBlueSheen.withValues(alpha: 0.20),
            AppColors.canvas.withValues(alpha: 0.88),
            AppColors.canvasVignette,
          ],
          stops: const [0.0, 0.12, 0.32, 0.52, 0.78, 1.0],
        ).createShader(rect),
    );

    _paintSpiralArm(
      canvas,
      center: center,
      radius: radius,
      rotation: -0.55,
      scaleX: 1.38,
      scaleY: 0.42,
      colors: [
        AppColors.canvasHaloCore.withValues(alpha: 0.16),
        AppColors.canvasGlow.withValues(alpha: 0.14),
        Colors.transparent,
      ],
    );
    _paintSpiralArm(
      canvas,
      center: center,
      radius: radius * 0.92,
      rotation: 0.72,
      scaleX: 1.22,
      scaleY: 0.36,
      colors: [
        AppColors.canvasGlow.withValues(alpha: 0.18),
        AppColors.canvasBlueSheen.withValues(alpha: 0.12),
        Colors.transparent,
      ],
    );
    _paintSpiralArm(
      canvas,
      center: center,
      radius: radius * 0.78,
      rotation: 1.95,
      scaleX: 1.08,
      scaleY: 0.30,
      colors: [
        Color.lerp(AppColors.canvasHaloCore, Colors.white, 0.18)!
            .withValues(alpha: 0.10),
        AppColors.canvasGlow.withValues(alpha: 0.08),
        Colors.transparent,
      ],
    );
  }

  void _paintSpiralArm(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double rotation,
    required double scaleX,
    required double scaleY,
    required List<Color> colors,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(scaleX, scaleY);
    final armRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawRect(
      armRect,
      Paint()
        ..shader = RadialGradient(
          colors: colors,
          stops: const [0.0, 0.42, 1.0],
        ).createShader(armRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
