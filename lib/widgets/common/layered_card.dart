import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// White card floating above the atmospheric canvas with a thin document stack.
///
/// Resembles a protected record sitting on the environment — not
/// neumorphism, glassmorphism, or a thick physical card pile.
class LayeredCard extends StatelessWidget {
  const LayeredCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.radius = AppSpacing.cardRadius,
    this.color = AppColors.card,
    this.onTap,
    this.clipBehavior = Clip.none,
    this.elevated = false,
    this.atmosphere,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color color;
  final VoidCallback? onTap;
  final Clip clipBehavior;
  final Widget? atmosphere;

  /// Incident Cover / primary Home cards sit slightly higher than Capture Now.
  final bool elevated;

  static const double _stackPeek = 6;
  static const double _deepInset = 8;
  static const double _midInset = 3;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final peek = elevated ? 7.0 : _stackPeek;
    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.03),
          child: content,
        ),
      );
    }

    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.88)),
        boxShadow: elevated
            ? AppDecorations.cardShadowsElevated
            : AppDecorations.cardShadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clipBehavior == Clip.none ? Clip.antiAlias : clipBehavior,
        child: atmosphere == null
            ? content
            : Stack(
                children: [
                  Positioned.fill(child: atmosphere!),
                  content,
                ],
              ),
      ),
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.only(bottom: peek),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _deepInset,
              right: _deepInset,
              top: elevated ? 9 : 8,
              bottom: 0,
              child: DecoratedBox(
                decoration: AppDecorations.cardStackLayer(
                  radius: radius,
                  color: AppColors.cardStackDeep,
                ),
              ),
            ),
            Positioned(
              left: _midInset,
              right: _midInset,
              top: elevated ? 5 : 4,
              bottom: 3,
              child: DecoratedBox(
                decoration: AppDecorations.cardStackLayer(radius: radius),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: peek),
              child: face,
            ),
          ],
        ),
      ),
    );
  }
}
