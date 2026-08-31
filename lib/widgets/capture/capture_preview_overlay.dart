import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'cockpit_immersive_preview.dart';

/// Instant Capture confirmation overlay.
///
/// Live capture stays alive underneath (straight — never rotated).
/// When [useImmersivePreviewFrame] is true, only the preview representation
/// receives orange border + ~-5° tilt. Accept / Delete stay upright below.
class CapturePreviewOverlay extends StatelessWidget {
  const CapturePreviewOverlay({
    super.key,
    required this.child,
    required this.onAccept,
    required this.onDiscard,
    this.acceptTooltip = 'Accept',
    this.discardTooltip = 'Discard',
    this.useImmersivePreviewFrame = false,
    this.skipImmersiveEntrance = false,
    this.bottomChromeInset = 0,
    this.topChromeInset = 0,
    this.sideChromeInset = 0,
    this.leftChromeInset,
    this.rightChromeInset,
  });

  final Widget child;
  final VoidCallback onAccept;
  final VoidCallback onDiscard;
  final String acceptTooltip;
  final String discardTooltip;

  /// Cockpit post-capture frame: tilt + orange border on preview only.
  final bool useImmersivePreviewFrame;

  /// Skip entrance motion in widget tests.
  final bool skipImmersiveEntrance;

  /// Reserved space for Cockpit modality bar / system inset.
  final double bottomChromeInset;

  /// Reserved space for Cockpit title band (embedded).
  final double topChromeInset;

  /// Fallback horizontal gutter when left/right are unspecified.
  final double sideChromeInset;

  /// Optional asymmetric left gutter.
  final double? leftChromeInset;

  /// Optional asymmetric right gutter (DONE + Close stack).
  final double? rightChromeInset;

  /// Legacy max-height fraction before ergonomic expansion (~0.48).
  static const double legacyMaxHeightFraction = 0.48;

  /// Expanded immersive preview height budget inside the chrome-safe column.
  static const double immersiveMaxHeightFraction = 0.98;

  /// Expanded immersive preview width budget between side gutters.
  static const double immersiveMaxWidthFraction = 0.98;

  /// Baseline area ratio used by tests to assert the enlarged preview.
  static const double legacyPreviewAreaFraction = 0.22;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mediaPad = MediaQuery.paddingOf(context);
    final bottomInset =
        bottomChromeInset > 0 ? bottomChromeInset : mediaPad.bottom;
    final topInset = topChromeInset > 0
        ? topChromeInset + AppSpacing.xs
        : mediaPad.top + AppSpacing.sm;
    final leftInset = leftChromeInset ??
        (sideChromeInset > 0 ? sideChromeInset : size.width * 0.14);
    final rightInset = rightChromeInset ??
        (sideChromeInset > 0 ? sideChromeInset : size.width * 0.14);

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Padding(
        padding: EdgeInsets.only(
          top: topInset,
          bottom: bottomInset,
          left: useImmersivePreviewFrame ? leftInset : 0,
          right: useImmersivePreviewFrame ? rightInset : 0,
        ),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = useImmersivePreviewFrame
                      ? constraints.maxWidth * immersiveMaxWidthFraction
                      : size.width * 0.72;
                  final maxHeight = useImmersivePreviewFrame
                      ? constraints.maxHeight * immersiveMaxHeightFraction
                      : size.height * legacyMaxHeightFraction;
                  return Center(
                    child: SizedBox(
                      width: maxWidth,
                      height: maxHeight,
                      child: useImmersivePreviewFrame
                          ? CockpitImmersivePreview(
                              skipEntrance: skipImmersiveEntrance,
                              child: child,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ColoredBox(
                                color: AppColors.navy,
                                child: child,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            // Control zone: upright, above modality bar / safe inset.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PreviewActionButton(
                    key: const Key('capture_preview_discard'),
                    tooltip: discardTooltip,
                    icon: Icons.close,
                    onPressed: onDiscard,
                    emphasized: false,
                  ),
                  _PreviewActionButton(
                    key: const Key('capture_preview_accept'),
                    tooltip: acceptTooltip,
                    icon: Icons.check,
                    onPressed: onAccept,
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium minimal circular actions — outlined discard, orange accept.
class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.emphasized,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final size = emphasized ? 56.0 : 44.0;
    if (emphasized) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.warning,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: AppColors.shadow,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: AppColors.navy, size: 28),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.92),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class CaptureImagePreview extends StatelessWidget {
  const CaptureImagePreview({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
      ),
    );
  }
}

/// Captured video review — thumbnail + play using [video_player].
class CaptureVideoPreviewPlaceholder extends StatefulWidget {
  const CaptureVideoPreviewPlaceholder({
    super.key,
    this.thumbnailPath,
    this.videoPath,
    required this.durationLabel,
  });

  final String? thumbnailPath;
  final String? videoPath;
  final String durationLabel;

  @override
  State<CaptureVideoPreviewPlaceholder> createState() =>
      _CaptureVideoPreviewPlaceholderState();
}

class _CaptureVideoPreviewPlaceholderState
    extends State<CaptureVideoPreviewPlaceholder> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final path = widget.videoPath;
    if (path == null || path.startsWith('test://')) {
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      return;
    }
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_tick);
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  void _tick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_tick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !_ready) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration &&
          controller.value.duration > Duration.zero) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final playing = controller?.value.isPlaying ?? false;
    final showPlayer = _ready && controller != null && !_failed;
    final hasThumb = widget.thumbnailPath != null &&
        !widget.thumbnailPath!.startsWith('test://');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Prefer live decoder frame (paused = first frame). Fall back to
        // generated JPEG thumbnail, then navy only while loading/failed.
        if (showPlayer)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          )
        else if (hasThumb)
          Image.file(
            File(widget.thumbnailPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.navy),
          )
        else
          const ColoredBox(color: AppColors.navy),
        if (!playing)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.28),
            child: Center(
              child: IconButton(
                key: const Key('capture_video_preview_play'),
                tooltip: widget.durationLabel.isEmpty
                    ? 'Play'
                    : 'Play (${widget.durationLabel})',
                onPressed: showPlayer ? () => unawaited(_togglePlay()) : null,
                iconSize: 56,
                icon: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
          )
        else
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: IconButton(
              key: const Key('capture_video_preview_pause'),
              tooltip: 'Pause',
              onPressed: () => unawaited(_togglePlay()),
              icon: const Icon(Icons.pause_circle_filled, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/// Voice captured-preview content inside the immersive orange frame.
class CaptureVoicePreviewContent extends StatelessWidget {
  const CaptureVoicePreviewContent({
    super.key,
    required this.levels,
    required this.durationLabel,
    required this.isPlaying,
    required this.onPlayPause,
  });

  final List<double> levels;
  final String durationLabel;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key('capture_voice_preview_play'),
              tooltip: isPlaying ? 'Pause preview' : 'Play preview',
              onPressed: onPlayPause,
              iconSize: 52,
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final level in levels)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: FractionallySizedBox(
                          heightFactor: math.max(0.15, level),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              durationLabel,
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
