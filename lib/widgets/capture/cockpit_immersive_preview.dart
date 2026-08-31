import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';

/// Post-capture preview frame — orange border + ~-5° counter-clockwise tilt.
///
/// Applies ONLY to the captured-preview representation. Never wrap the live
/// camera / video / voice capture surface in this widget.
class CockpitImmersivePreview extends StatefulWidget {
  const CockpitImmersivePreview({
    super.key,
    required this.child,
    this.skipEntrance = false,
  });

  final Widget child;

  /// Widget tests can skip motion while still asserting the settled frame.
  final bool skipEntrance;

  /// Settled tilt — exactly 5° counter-clockwise.
  static const double tiltRadians = -5 * math.pi / 180;

  /// Four-sided orange border — medium weight (~2.75 logical px).
  static const double borderWidth = 2.75;

  /// Rounded corners for the tilted preview frame.
  static const double cornerRadius = 12;

  static const Duration entranceDuration = Duration(milliseconds: 300);

  @override
  State<CockpitImmersivePreview> createState() =>
      _CockpitImmersivePreviewState();
}

class _CockpitImmersivePreviewState extends State<CockpitImmersivePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _angle;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CockpitImmersivePreview.entranceDuration,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.enter,
    );
    _scale = Tween<double>(begin: 0.9, end: 1).animate(curve);
    _angle = Tween<double>(
      begin: 0,
      end: CockpitImmersivePreview.tiltRadians,
    ).animate(curve);
    _opacity = Tween<double>(begin: 0.5, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curve);

    if (widget.skipEntrance) {
      _controller.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward();
        }
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Transform.rotate(
              angle: _angle.value,
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            ),
          ),
        );
      },
      // Border is painted ABOVE the media (Stack overlay) so it cannot be
      // covered by the image/video child or lost under ClipRRect.
      // Parent ConstrainedBox owns chrome-safe size — fill it (no fixed
      // 3:4 lock) so the frame can use the available Cockpit surface.
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: DecoratedBox(
          key: const Key('cockpit_immersive_preview'),
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(
                  CockpitImmersivePreview.borderWidth,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    CockpitImmersivePreview.cornerRadius -
                        CockpitImmersivePreview.borderWidth,
                  ),
                  child: ColoredBox(
                    color: Colors.black,
                    child: widget.child,
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      CockpitImmersivePreview.cornerRadius,
                    ),
                    border: Border.all(
                      color: AppColors.warning,
                      width: CockpitImmersivePreview.borderWidth,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
