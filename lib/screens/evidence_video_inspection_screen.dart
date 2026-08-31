import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../constants/app_spacing.dart';
import '../models/workspace_evidence_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/evidence_inspector/evidence_media_source.dart';

/// Expanded playback using the existing [VideoPlayerController.file] path.
///
/// Does not introduce a new video engine or cache.
class EvidenceVideoInspectionScreen extends StatefulWidget {
  const EvidenceVideoInspectionScreen({
    super.key,
    required this.evidence,
  });

  final WorkspaceEvidenceItem evidence;

  static const screenKey = Key('evidence_video_inspection_screen');
  static const playKey = Key('evidence_video_inspection_play');
  static const seekKey = Key('evidence_video_inspection_seek');
  static const closeKey = Key('evidence_video_inspection_close');
  static const errorKey = Key('evidence_video_inspection_error');

  static String? sourcePath(WorkspaceEvidenceItem item) =>
      EvidenceMediaSource.playbackPath(item);

  @override
  State<EvidenceVideoInspectionScreen> createState() =>
      _EvidenceVideoInspectionScreenState();
}

class _EvidenceVideoInspectionScreenState
    extends State<EvidenceVideoInspectionScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _initFailed = false;

  String? get _path =>
      EvidenceVideoInspectionScreen.sourcePath(widget.evidence);

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final path = _path;
    if (!EvidenceMediaSource.isReadableFile(path)) {
      setState(() => _initFailed = true);
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
      controller.addListener(_tick);
      setState(() => _initialized = true);
    } catch (_) {
      await controller.dispose();
      _controller = null;
      if (mounted) {
        setState(() => _initFailed = true);
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

  Future<void> _seek(double value) async {
    final controller = _controller;
    if (controller == null || !_initialized) {
      return;
    }
    final duration = controller.value.duration;
    if (duration <= Duration.zero) {
      return;
    }
    await controller.seekTo(
      Duration(milliseconds: (duration.inMilliseconds * value).round()),
    );
  }

  static String _clock(Duration value) {
    final total = value.inSeconds.clamp(0, 359999);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasPlayer = _initialized && controller != null && !_initFailed;
    final playing = controller?.value.isPlaying ?? false;
    final duration = controller?.value.duration ?? Duration.zero;
    final position = controller?.value.position ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Scaffold(
      key: EvidenceVideoInspectionScreen.screenKey,
      backgroundColor: AppColors.canvasDeep,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(
                key: EvidenceVideoInspectionScreen.closeKey,
                color: AppColors.onCanvas,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: Semantics(
                label: hasPlayer
                    ? 'Video evidence. Expanded playback.'
                    : 'Video unavailable',
                child: hasPlayer
                    ? GestureDetector(
                        onTap: _togglePlay,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: controller.value.aspectRatio == 0
                                ? 16 / 9
                                : controller.value.aspectRatio,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      )
                    : const _VideoInspectionUnavailable(),
              ),
            ),
            if (hasPlayer)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: EvidenceVideoInspectionScreen.playKey,
                      tooltip: playing ? 'Pause video' : 'Play video',
                      onPressed: _togglePlay,
                      color: AppColors.onCanvas,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    Text(
                      _clock(position),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onCanvasSecondary,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        key: EvidenceVideoInspectionScreen.seekKey,
                        value: progress,
                        onChanged: _seek,
                        activeColor: AppColors.onCanvas,
                        inactiveColor:
                            AppColors.onCanvasSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    Text(
                      _clock(duration),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onCanvasSecondary,
                      ),
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

class _VideoInspectionUnavailable extends StatelessWidget {
  const _VideoInspectionUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: EvidenceVideoInspectionScreen.errorKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 56,
              color: AppColors.onCanvasSecondary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Video unavailable',
              style: AppTextStyles.label.copyWith(
                color: AppColors.onCanvas,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'The video file could not be opened. The original evidence was not changed.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onCanvasSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
