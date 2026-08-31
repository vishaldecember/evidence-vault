import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';

/// Magnet + detent decisions for Organize context placement.
///
/// Presentation only. Does not write [OrganizeContextAnchor]s.
abstract final class OrganizeContextTargeting {
  /// Enter / lock a captured target. Unchanged Stage 1 threshold.
  static const double enterDistance = 72;

  /// Keep the current magnet once locked. [enterDistance] + [AppSpacing.sm].
  static const double retainDistance = enterDistance + AppSpacing.sm;

  /// Hit-tests the captured evidence moment under the pointer.
  ///
  /// Prefers the thumbnail whose rect contains the pointer so snap follows
  /// the intended moment, not a nearby canvas coordinate.
  static String? resolveExactTarget({
    required Map<String, Rect> targetRects,
    required Offset pointer,
    String? currentId,
  }) {
    String? hit;
    var hitArea = double.infinity;
    for (final entry in targetRects.entries) {
      final inflated = entry.value.inflate(16);
      if (inflated.contains(pointer)) {
        final area = inflated.width * inflated.height;
        if (area < hitArea) {
          hitArea = area;
          hit = entry.key;
        }
      }
    }
    if (hit != null) {
      return hit;
    }

    if (currentId != null) {
      final current = targetRects[currentId];
      if (current != null && current.inflate(24).contains(pointer)) {
        return currentId;
      }
    }

    return null;
  }

  static double distanceToRect(Rect rect, Offset pointer) {
    if (rect.contains(pointer)) {
      return 0;
    }
    final dx = pointer.dx < rect.left
        ? rect.left - pointer.dx
        : (pointer.dx > rect.right ? pointer.dx - rect.right : 0.0);
    final dy = pointer.dy < rect.top
        ? rect.top - pointer.dy
        : (pointer.dy > rect.bottom ? pointer.dy - rect.bottom : 0.0);
    return Offset(dx, dy).distance;
  }

  static double magnetStrengthForRect({
    required Rect? targetRect,
    required Offset pointer,
  }) {
    if (targetRect == null) {
      return 0;
    }
    final distance = distanceToRect(targetRect, pointer);
    if (distance >= enterDistance) {
      return 0;
    }
    return (1 - (distance / enterDistance)).clamp(0.0, 1.0);
  }

  /// Nearest captured target within the magnetic rule.
  ///
  /// New lock: Euclidean distance &lt; [enterDistance].
  /// Retain: stay on [currentId] while still ≤ [retainDistance].
  static String? resolveMagnet({
    required String? currentId,
    required Map<String, Offset> centers,
    required Offset pointer,
  }) {
    if (currentId != null) {
      final currentCenter = centers[currentId];
      if (currentCenter != null &&
          (currentCenter - pointer).distance <= retainDistance) {
        return currentId;
      }
    }

    String? nearest;
    var best = enterDistance;
    for (final entry in centers.entries) {
      final distance = (entry.value - pointer).distance;
      if (distance < best) {
        best = distance;
        nearest = entry.key;
      }
    }
    return nearest;
  }

  /// Nearest captured target by vertical alignment (detent lane).
  static String? resolveDetentAlignment({
    required Map<String, Offset> centers,
    required Offset pointer,
  }) {
    String? nearest;
    var best = double.infinity;
    for (final entry in centers.entries) {
      final dy = (entry.value.dy - pointer.dy).abs();
      if (dy < best) {
        best = dy;
        nearest = entry.key;
      }
    }
    return nearest;
  }

  /// True when the pointer enters a new alignment, including the first.
  ///
  /// Does not fire while [nextDetentId] stays equal to [previousDetentId].
  /// Leaving all targets ([nextDetentId] == null) does not tick.
  static bool shouldEmitDetent({
    required String? previousDetentId,
    required String? nextDetentId,
  }) {
    return nextDetentId != null && nextDetentId != previousDetentId;
  }

  static double magnetStrength({
    required Offset? targetCenter,
    required Offset pointer,
  }) {
    if (targetCenter == null) {
      return 0;
    }
    final distance = (targetCenter - pointer).distance;
    if (distance >= enterDistance) {
      return 0;
    }
    return (1 - (distance / enterDistance)).clamp(0.0, 1.0);
  }
}
