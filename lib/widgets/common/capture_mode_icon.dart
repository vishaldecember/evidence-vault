import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/workspace_capture_mode.dart';

/// Premium 3D glass/neon capture-mode tile.
///
/// One asset family for Capture Now, the Capture sticky bar, the
/// Organize toolbar, and Evidence Composition. Presentation only.
///
/// Artwork carries the neon-glass look. Runtime filters stay light so
/// geometry stays crisp — definition over glow.
class CaptureModeIcon extends StatelessWidget {
  const CaptureModeIcon({
    super.key,
    required this.mode,
    this.color = const Color(0xFF00D4FF),
    this.size = CaptureModeIconMetrics.captureNow,
  });

  final WorkspaceCaptureMode mode;

  /// Retained for existing call sites. The glass family is self-colored.
  final Color color;

  final double size;

  static Key keyFor(WorkspaceCaptureMode mode) =>
      Key('capture_mode_icon_${mode.name}');

  static String assetFor(WorkspaceCaptureMode mode) => switch (mode) {
    WorkspaceCaptureMode.photo => CaptureModeIconAssets.photo,
    WorkspaceCaptureMode.video => CaptureModeIconAssets.video,
    WorkspaceCaptureMode.voice => CaptureModeIconAssets.voice,
    WorkspaceCaptureMode.note => CaptureModeIconAssets.text,
    WorkspaceCaptureMode.file => CaptureModeIconAssets.file,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: keyFor(mode),
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          size * CaptureModeIconMetrics.tileRadius,
        ),
        child: ColorFiltered(
          colorFilter: CaptureModeIconMetrics.geometryClarity,
          child: Transform.scale(
            scale: CaptureModeIconMetrics.tileFill,
            filterQuality: FilterQuality.high,
            child: Image.asset(
              assetFor(mode),
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color));
  }
}

/// Source-of-truth raster family. Same five assets on every capture surface.
abstract final class CaptureModeIconAssets {
  static const photo = 'assets/icons/capture/photo.png';
  static const video = 'assets/icons/capture/video.png';
  static const voice = 'assets/icons/capture/voice.png';
  static const text = 'assets/icons/capture/text.png';
  static const file = 'assets/icons/capture/file.png';

  static const all = <String>[photo, video, voice, text, file];
}

/// Lays out [layoutSize] so the label below stays put, and paints [size]
/// aligned to the bottom of that slot (growth goes upward).
class PinnedCaptureModeIcon extends StatelessWidget {
  const PinnedCaptureModeIcon({
    super.key,
    required this.mode,
    required this.size,
    required this.layoutSize,
  });

  final WorkspaceCaptureMode mode;
  final double size;
  final double layoutSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layoutSize,
      height: layoutSize,
      child: OverflowBox(
        minWidth: size,
        maxWidth: size,
        minHeight: size,
        maxHeight: size,
        alignment: Alignment.bottomCenter,
        child: CaptureModeIcon(mode: mode, size: size),
      ),
    );
  }
}

/// Optical sizes for the three capture surfaces. Keep these in lockstep.
abstract final class CaptureModeIconMetrics {
  static const double captureNow = 46;
  static const double captureNowLayout = 42;
  static const double stickyBar = 31;
  static const double stickyBarLayout = 28;
  static const double organizeToolbar = 30;
  static const double compositionGuide = 16;

  /// iOS-like squircle approximation for the shared tile clip.
  static const double tileRadius = 0.22;

  /// Crops the generated black pad so the glass tile fills the clip.
  static const double tileFill = 1.14;

  /// Slight midtone lift + cool bias. No soft-light bloom, no glow expand.
  /// Keeps neon cores bright and dark glass readable without muddying.
  static const ColorFilter geometryClarity = ColorFilter.matrix(<double>[
    1.05,
    0,
    0.02,
    0,
    4,
    0,
    1.07,
    0.03,
    0,
    5,
    0,
    0.01,
    1.10,
    0,
    8,
    0,
    0,
    0,
    1,
    0,
  ]);
}
