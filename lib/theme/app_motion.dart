import 'package:flutter/material.dart';

/// Calm, predictable motion tokens aligned with DESIGN_SYSTEM.md.
abstract final class AppMotion {
  /// Press feedback on capture buttons and primary actions.
  static const Duration fast = Duration(milliseconds: 120);

  /// Sticky layer resize, tab cross-fade, small state changes.
  static const Duration medium = Duration(milliseconds: 200);

  /// Page push/pop and reading-surface transitions.
  static const Duration page = Duration(milliseconds: 250);

  /// Bottom sheets and modal surfaces.
  static const Duration sheet = Duration(milliseconds: 280);

  /// Sticky Capture / Action layer padding adjustments.
  static const Duration layer = Duration(milliseconds: 200);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  static const double pageSlideOffset = 0.02;
  static const double pressScale = 0.97;
}

/// Shared page transition used by auth and in-app navigation.
Widget buildPageTransition(
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: AppMotion.enter,
    reverseCurve: AppMotion.exit,
  );

  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, AppMotion.pageSlideOffset),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}
