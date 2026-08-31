import 'dart:math' as math;
import 'dart:ui';

/// Deterministic Organize floating-context positions.
///
/// Presentation only. Does not write [OrganizeContextAnchor]s, chronology,
/// or evidence identity. Offsets are stable across rebuilds so widget tests
/// can assert non-overlap without flaking.
abstract final class OrganizeFloatingContextLayout {
  static const double tileWidth = 88;
  static const double tileHeight = 96;
  /// Hit extent of the floating-context remove control.
  static const double removeControlExtent = 36;
  /// How far the remove control hinges outside the thumbnail top-left.
  static const double removeControlOutset = 26;
  static const double layerWidth = tileWidth + removeControlOutset;
  /// Free-space stack — independent of chronology-spine row geometry.
  /// Leaves room above the first thumbnail for the outside remove control.
  static const double topInset = 8 + removeControlOutset;
  static const double rightInset = 0;
  static const double stepY = 112;
  static const double stepX = 10;
  static const double oddNudgeY = 8;
  /// Horizontal gap between a captured moment and its snapped context.
  static const double fingerGap = 48;

  /// Upper-right origin, then below and slightly left — a calm scatter.
  static Offset offsetFor({
    required int index,
    required double canvasWidth,
  }) {
    final maxX = math.max(0.0, canvasWidth - tileWidth - rightInset);
    final dx = maxX - (index * stepX);
    final dy = topInset + (index * stepY) + (index.isOdd ? oddNudgeY : 0);
    return Offset(dx < 0 ? 0 : dx, dy);
  }

  static Rect rectFor({
    required int index,
    required double canvasWidth,
  }) {
    return offsetFor(index: index, canvasWidth: canvasWidth) &
        const Size(tileWidth, tileHeight);
  }

  static double stackHeight(int count) {
    if (count <= 0) {
      return 0;
    }
    return offsetFor(index: count - 1, canvasWidth: 400).dy + tileHeight;
  }

  static bool rectsOverlap(Rect a, Rect b, {double epsilon = 1}) {
    return a.deflate(epsilon).overlaps(b.deflate(epsilon));
  }
}
