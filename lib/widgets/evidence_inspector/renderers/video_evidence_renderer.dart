import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../constants/app_spacing.dart';
import '../../../navigation/app_navigation.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../evidence_media_source.dart';
import '../evidence_preview_renderer.dart';

/// Large video thumbnail with play control, remaining time, and inline playback.
class VideoEvidenceRenderer extends EvidencePreviewRenderer {
  const VideoEvidenceRenderer();

  @override
  Widget build(BuildContext context, EvidencePreviewContext preview) {
    return _VideoPreviewSurface(preview: preview);
  }
}

class _VideoPreviewSurface extends StatefulWidget {
  const _VideoPreviewSurface({required this.preview});

  final EvidencePreviewContext preview;

  @override
  State<_VideoPreviewSurface> createState() => _VideoPreviewSurfaceState();
}

class _VideoPreviewSurfaceState extends State<_VideoPreviewSurface> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _initFailed = false;

  String? get _path =>
      EvidenceMediaSource.playbackPath(widget.preview.record.evidence);

  @override
  void initState() {
    super.initState();
    _preparePlayer();
  }

  Future<void> _preparePlayer() async {
    final path = _path;
    if (!EvidenceMediaSource.isReadableFile(path)) {
      return;
    }
    final controller = VideoPlayerController.file(File(path!));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onPlayerTick);
      try {
        await InspectorAutoplay.startWhenReady(
          seekToStart: () => controller.seekTo(Duration.zero),
          play: () => controller.play(),
        );
      } catch (_) {
        // Keep the initialized surface; the user can start playback.
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
      });
    } catch (_) {
      await controller.dispose();
      _controller = null;
      if (mounted) {
        setState(() => _initFailed = true);
      }
    }
  }

  void _onPlayerTick() {
    if (!mounted) {
      return;
    }
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero &&
        !controller.value.isPlaying) {
      // Loop-ready: stay paused at end with play affordance visible.
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !_initialized) {
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

  String _remainingLabel(VideoPlayerController controller) {
    final duration = controller.value.duration;
    final position = controller.value.position;
    final remaining = duration - position;
    final safe = remaining.isNegative ? Duration.zero : remaining;
    return _formatClock(safe);
  }

  static String _formatClock(Duration value) {
    final totalSeconds = value.inSeconds.clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final playing = controller?.value.isPlaying ?? false;
    final hasPlayer = _initialized && controller != null && !_initFailed;
    final thumbPath = EvidenceMediaSource.previewPath(
      widget.preview.record.evidence,
    );

    return Semantics(
      label: hasPlayer
          ? 'Video evidence'
          : (_initFailed
              ? 'Video unavailable'
              : 'Video evidence. Preview unavailable'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.transparent),
          if (hasPlayer)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else if (EvidenceMediaSource.isReadableFile(thumbPath) &&
              EvidenceMediaSource.isImagePath(thumbPath))
            Image.file(
              File(thumbPath!),
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, error, stackTrace) =>
                  _VideoFallback(failed: _initFailed),
            )
          else
            _VideoFallback(failed: _initFailed),
          if (!hasPlayer)
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.62),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.onPrimary,
                  size: 40,
                ),
              ),
            ),
          if (hasPlayer)
            Positioned(
              left: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: _DurationChip(label: _remainingLabel(controller)),
            ),
          if (ModalRoute.of(context)?.settings.name !=
              AppNavigation.videoInspectionRouteName)
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Material(
                color: Colors.transparent,
                child: IconButton.filledTonal(
                  key: const Key('evidence_video_open_full'),
                  tooltip: 'Expand video',
                  onPressed: () {
                    AppNavigation.openVideoInspection(
                      context,
                      evidence: widget.preview.record.evidence,
                    );
                  },
                  icon: const Icon(Icons.fullscreen),
                ),
              ),
            ),
          if (hasPlayer && !playing)
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _togglePlay,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.onPrimary,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_outlined,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          Text(
            failed ? 'Video unavailable' : 'Video evidence',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!failed)
            Text(
              'Preview unavailable',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 4,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
