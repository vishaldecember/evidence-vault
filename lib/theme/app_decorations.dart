import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import 'app_colors.dart';

/// Shared visual decorations aligned with DESIGN_SYSTEM.md.
abstract final class AppDecorations {
  static const double borderAlpha = 0.6;

  static BorderSide get borderSide =>
      BorderSide(color: AppColors.borderAccent.withValues(alpha: 0.85));

  /// Layer 1 — aerospace floor. Not the appearance of the whole screen.
  static const BoxDecoration spaceCanvas = BoxDecoration(
    color: AppColors.canvasDeep,
  );

  /// Broad atmospheric field behind the Home hero. Brightest density is
  /// localized on the logo; the lower wash still reaches copy and card.
  static BoxDecoration get spaceCanvasGlow => BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(0, -0.70),
      radius: 2.05,
      colors: [
        Color.lerp(AppColors.canvasHaloCore, Colors.white, 0.36)!
            .withValues(alpha: 0.96),
        AppColors.canvasHaloCore.withValues(alpha: 0.76),
        AppColors.canvasGlow.withValues(alpha: 0.46),
        AppColors.canvasBlueSheen.withValues(alpha: 0.34),
        AppColors.canvasBlueSheen.withValues(alpha: 0.18),
        Colors.transparent,
      ],
      stops: const [0.0, 0.12, 0.28, 0.52, 0.84, 1.0],
    ),
  );

  /// Downward extension of the hero field through copy toward the card.
  /// Soft wash only — must not read as a second hotspot.
  static BoxDecoration get spaceCanvasAtmosphere => BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(0, -0.34),
      radius: 1.82,
      colors: [
        AppColors.canvasGlow.withValues(alpha: 0.38),
        AppColors.canvasBlueSheen.withValues(alpha: 0.24),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ),
  );

  /// Restrained violet tint. Must not read as a purple screen.
  static BoxDecoration get spaceCanvasAura => BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(-0.36, -0.18),
      radius: 0.42,
      colors: [
        AppColors.canvasIndigo.withValues(alpha: 0.22),
        AppColors.canvasIndigo.withValues(alpha: 0.08),
        Colors.transparent,
      ],
      stops: const [0.0, 0.38, 1.0],
    ),
  );

  /// Dark chamfered corners — deep space-grey at the rectangle corners,
  /// transparent through the atmospheric field. Not a circular hole.
  static BoxDecoration get spaceCanvasVignette => BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(0, -0.52),
      radius: 1.36,
      colors: [
        Colors.transparent,
        Colors.transparent,
        const Color(0xF20A0C10),
        const Color(0xFA06080C),
      ],
      stops: const [0.0, 0.32, 0.54, 1.0],
    ),
  );

  /// Static layered atmosphere — applied by [SpaceCanvas] in this order.
  static List<BoxDecoration> get spaceCanvasLayers => [
    spaceCanvas,
    spaceCanvasGlow,
    spaceCanvasAtmosphere,
    spaceCanvasAura,
    spaceCanvasVignette,
  ];

  /// Unified indigo → royal violet CTA. One colour family — no magenta/pink.
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.ctaStart,
      AppColors.ctaMid,
      AppColors.ctaEnd,
    ],
    stops: [0.0, 0.48, 1.0],
  );

  /// Bright metallic silver lustre for on-canvas emphasis copy.
  static const LinearGradient silverLustre = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.onCanvasSecondary,
      AppColors.onCanvas,
      Color(0xFFFCFDFF),
      AppColors.canvasHaloCore,
      AppColors.onCanvasSecondary,
    ],
    stops: [0.0, 0.22, 0.5, 0.78, 1.0],
  );

  /// Specular sheen across the CTA — restrained, not glassmorphism.
  static LinearGradient get ctaSheen => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.center,
    colors: [
      Colors.white.withValues(alpha: 0.20),
      Colors.white.withValues(alpha: 0.04),
      Colors.transparent,
    ],
    stops: const [0.0, 0.42, 1.0],
  );

  /// Standard workspace and reading-surface card shell.
  static BoxDecoration card({Color backgroundColor = AppColors.card}) =>
      BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
        boxShadow: cardShadows,
      );

  /// Cool-grey offset sheet under a stacked premium card.
  static BoxDecoration cardStackLayer({
    double radius = AppSpacing.cardRadius,
    Color color = AppColors.cardStack,
  }) =>
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius));

  /// Capture modality tile sitting on a white Capture Now card.
  static BoxDecoration captureTile({
    required bool pressed,
    Color color = AppColors.background,
  }) => BoxDecoration(
    color: pressed ? AppColors.surfaceMuted : color,
    borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
    border: Border.all(
      color: pressed
          ? AppColors.primary.withValues(alpha: 0.45)
          : AppColors.captureTileBorder,
      width: 1.75,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0x1A071426),
        blurRadius: pressed ? 6 : 8,
        offset: Offset(0, pressed ? 1 : 2),
      ),
      BoxShadow(
        color: pressed
            ? AppColors.primaryShadow
            : AppColors.cardHalo.withValues(alpha: 0.14),
        blurRadius: pressed ? 10 : 14,
        offset: Offset(0, pressed ? 4 : 6),
      ),
    ],
  );

  /// Home Library sections and other elevated grouped content.
  static BoxDecoration elevatedSection({
    Color backgroundColor = AppColors.card,
  }) => BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
    border: Border.all(color: AppColors.borderAccent.withValues(alpha: 0.9)),
    boxShadow: cardShadows,
  );

  /// Nested tiles inside section cards.
  static BoxDecoration innerTile({Color backgroundColor = AppColors.card}) =>
      BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(
          color: AppColors.border.withValues(alpha: borderAlpha),
        ),
      );

  /// Capture layer container on Home.
  static BoxDecoration captureLayer() => BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
    boxShadow: captureLayerShadows,
  );

  /// Sticky bottom action layers on Home and Workspace — top card in the stack.
  static BoxDecoration stickyLayer() => BoxDecoration(
    color: AppColors.background,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppSpacing.cardRadius),
    ),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
    boxShadow: stickyLayerShadows,
  );

  static const List<BoxShadow> cardShadows = [
    BoxShadow(
      color: Color(0x1A071426),
      blurRadius: 8,
      offset: Offset(0, 3),
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x331A3A5C),
      blurRadius: 32,
      offset: Offset(0, 10),
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x145A4A8C),
      blurRadius: 36,
      offset: Offset(0, 14),
    ),
  ];

  static const List<BoxShadow> cardShadowsElevated = [
    BoxShadow(
      color: Color(0x24071426),
      blurRadius: 10,
      offset: Offset(0, 4),
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x3D1A3A5C),
      blurRadius: 34,
      offset: Offset(0, 12),
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Color(0x1A5A4A8C),
      blurRadius: 36,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> ctaShadows = [
    BoxShadow(color: Color(0x594B3FE4), blurRadius: 18, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x335B4CE8), blurRadius: 26, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> captureLayerShadows = [
    BoxShadow(
      color: AppColors.shadowLight,
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
    BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
  ];

  static final List<BoxShadow> stickyLayerShadows = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, -3),
    ),
    BoxShadow(
      color: const Color(0x33071426),
      blurRadius: 28,
      offset: const Offset(0, -12),
    ),
    BoxShadow(
      color: AppColors.primaryShadow.withValues(alpha: 0.12),
      blurRadius: 32,
      offset: const Offset(0, -16),
    ),
  ];

  static final List<BoxShadow> bottomNavShadows = [
    BoxShadow(
      color: const Color(0x3D071426),
      blurRadius: 24,
      offset: const Offset(0, -8),
    ),
    BoxShadow(
      color: AppColors.primaryShadow.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, -4),
    ),
  ];

  static RoundedRectangleBorder get snackBarShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppSpacing.sm),
  );
}
