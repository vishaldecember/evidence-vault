import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Organize chronology evidence labels. Independent of Graph typography.
///
/// Do not reuse these colors for Groups, Graph, Capture, or global theme text.
abstract final class OrganizeEvidenceTypography {
  static const Color thumbnailText = Color(0xFF000000);
  static const Color timestamp = Color(0xFF000000);
  static const Color date = Color(0xFF000000);
  static const Color participant = Color(0xFF000000);
}

/// Organize-local contrast and atmosphere. Does not change global [AppColors].
abstract final class OrganizeVisuals {
  /// Clock gutter on the space-grey Organize canvas.
  static const Color clock = Color(0xFFFFFFFF);

  /// Kind identifiers (Photo, Voice, Note, File).
  static const Color kindLabel = Color(0xFFF6F8FC);

  /// Dates, supporting captions, secondary chrome.
  static const Color meta = Color(0xFFC9D3E4);

  /// Captured chronology spine.
  static const Color spine = Color(0xFFD4E4F2);

  /// Floating context fill — elevated, not a second timeline lane.
  static const Color contextFill = Color(0xD624344C);

  static const Color contextBorder = Color(0x66D4E4F2);

  /// Instruction color while floating context awaits placement.
  /// Single fluorescent purple — never a rainbow treatment.
  static const Color contextInstruction = Color(0xFFE445FF);

  /// Milky-white galaxy core used while dragging / snapping.
  static const Color milkyCore = Color(0xF2F7FBFF);

  static const Color milkyMid = Color(0x99E8F1F8);

  static const Color milkyEdge = Color(0x33F4F8FC);
}

/// Soft abstract material behind a captured tile. Presentation only.
class OrganizeCapturedMaterialPainter extends CustomPainter {
  const OrganizeCapturedMaterialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.canvasHaloCore.withValues(alpha: 0.10),
            AppColors.canvasGlow.withValues(alpha: 0.06),
            AppColors.canvasBlueSheen.withValues(alpha: 0.05),
          ],
        ).createShader(rect),
    );

    _softOrb(
      canvas,
      center: Offset(size.width * 0.78, size.height * 0.22),
      radius: math.max(size.width, size.height) * 0.42,
      color: AppColors.canvasHaloCore.withValues(alpha: 0.14),
    );
    _softOrb(
      canvas,
      center: Offset(size.width * 0.18, size.height * 0.78),
      radius: math.max(size.width, size.height) * 0.34,
      color: AppColors.canvasGlow.withValues(alpha: 0.10),
    );
    _softOrb(
      canvas,
      center: Offset(size.width * 0.55, size.height * 0.55),
      radius: math.max(size.width, size.height) * 0.22,
      color: Colors.white.withValues(alpha: 0.05),
    );
  }

  void _softOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Quiet modern-art wash behind a grouped-context modal. Thumbnails stay primary.
class OrganizeContextModalCanvasPainter extends CustomPainter {
  const OrganizeContextModalCanvasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x14283648), Color(0x10202C3C), Color(0x181C2838)],
        ).createShader(rect),
    );

    _softOrb(
      canvas,
      center: Offset(size.width * 0.16, size.height * 0.22),
      radius: math.max(size.width, size.height) * 0.38,
      color: Colors.white.withValues(alpha: 0.05),
    );
    _softOrb(
      canvas,
      center: Offset(size.width * 0.84, size.height * 0.78),
      radius: math.max(size.width, size.height) * 0.42,
      color: OrganizeVisuals.milkyMid.withValues(alpha: 0.08),
    );
    _softOrb(
      canvas,
      center: Offset(size.width * 0.58, size.height * 0.38),
      radius: math.max(size.width, size.height) * 0.24,
      color: const Color(0x14D4E4F2),
    );

    final grain = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    const step = 22.0;
    for (var x = 10.0; x < size.width; x += step) {
      for (var y = 8.0; y < size.height; y += step) {
        final sway = ((x + y) % 14) - 7;
        canvas.drawLine(Offset(x, y), Offset(x + 3.5, y + sway * 0.12), grain);
      }
    }
  }

  void _softOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Restrained milky-white galaxy aura. Feedback only — never persisted.
class OrganizeMilkyGalaxyPainter extends CustomPainter {
  const OrganizeMilkyGalaxyPainter({this.intensity = 1});

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height) * 0.72;
    final a = intensity.clamp(0.0, 1.0);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            OrganizeVisuals.milkyCore.withValues(alpha: 0.34 * a),
            OrganizeVisuals.milkyMid.withValues(alpha: 0.22 * a),
            OrganizeVisuals.milkyEdge.withValues(alpha: 0.10 * a),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.58, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.4);
    canvas.scale(1.28, 0.42);
    final arm = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawRect(
      arm,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.16 * a),
            OrganizeVisuals.milkyMid.withValues(alpha: 0.10 * a),
            Colors.transparent,
          ],
        ).createShader(arm),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OrganizeMilkyGalaxyPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}
