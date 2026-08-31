import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../constants/app_notifications.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';

/// Centred, non-blocking success acknowledgement — replaces bottom SnackBars.
abstract final class SuccessConfirmation {
  static OverlayEntry? _currentEntry;

  /// Shows a brief circular progress → checkmark confirmation.
  ///
  /// [message] is announced to screen readers only.
  static void show(BuildContext context, {String? message}) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _SuccessConfirmationOverlay(
        message: message,
        onDismissed: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _SuccessConfirmationOverlay extends StatefulWidget {
  const _SuccessConfirmationOverlay({
    this.message,
    required this.onDismissed,
  });

  final String? message;
  final VoidCallback onDismissed;

  @override
  State<_SuccessConfirmationOverlay> createState() =>
      _SuccessConfirmationOverlayState();
}

class _SuccessConfirmationOverlayState extends State<_SuccessConfirmationOverlay>
    with SingleTickerProviderStateMixin {
  static const double _size = 56;
  static const double _strokeWidth = 2.5;

  late final AnimationController _controller;
  late final Animation<double> _ringProgress;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppNotifications.successAnimationDuration,
    );

    final total = AppNotifications.successAnimationDuration.inMilliseconds;
    final ringEnd = AppNotifications.successRingDuration.inMilliseconds / total;
    final checkStart =
        AppNotifications.successCheckStart.inMilliseconds / total;
    final checkEnd = AppNotifications.successCheckEnd.inMilliseconds / total;
    final fadeStart =
        AppNotifications.successFadeStart.inMilliseconds / total;

    _ringProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0, ringEnd, curve: AppMotion.enter),
      ),
    );

    _checkOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(checkStart, checkEnd, curve: AppMotion.enter),
      ),
    );

    _fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(fadeStart, 1, curve: AppMotion.exit),
      ),
    );

    _controller.forward().whenComplete(widget.onDismissed);

    if (widget.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        SemanticsService.sendAnnouncement(
          View.of(context),
          widget.message!,
          TextDirection.ltr,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fade.value.clamp(0, 1),
            child: Center(
                child: Semantics(
                liveRegion: true,
                label: widget.message ?? 'Success',
                child: SizedBox(
                  key: const Key('success_confirmation'),
                  width: _size,
                  height: _size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(_size, _size),
                        painter: _ProgressRingPainter(
                          progress: _ringProgress.value,
                          strokeWidth: _strokeWidth,
                        ),
                      ),
                      Opacity(
                        opacity: _checkOpacity.value,
                        child: Icon(
                          Icons.check_rounded,
                          size: 26,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
  });

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) {
      return;
    }

    final progressPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
