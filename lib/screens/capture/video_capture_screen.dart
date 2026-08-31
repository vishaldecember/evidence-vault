import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_category.dart';
import '../../models/evidence_type.dart';
import '../../models/pending_evidence.dart';
import '../../navigation/app_navigation.dart';
import '../../services/metadata_service.dart';
import '../../services/video_capture_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ev_button.dart';
import '../evidence_preview_screen.dart';

class VideoCaptureScreen extends StatefulWidget {
  const VideoCaptureScreen({
    super.key,
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;
  final EvidenceCategory category;

  @override
  State<VideoCaptureScreen> createState() => _VideoCaptureScreenState();
}

class _VideoCaptureScreenState extends State<VideoCaptureScreen> {
  String? _videoPath;
  bool _isRecording = false;
  VideoPlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _recordVideo() async {
    setState(() => _isRecording = true);

    try {
      await _controller?.dispose();
      _controller = null;

      final path = await VideoCaptureService.captureVideo();
      if (!mounted || path == null) return;

      _controller = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _controller?.setLooping(true);
          _controller?.play();
        });

      setState(() => _videoPath = path);
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _continueToPreview() async {
    final path = _videoPath;
    if (path == null) return;

    final metadata = await MetadataService.collect();
    final fileSize = await File(path).length();

    if (!mounted) return;

    await AppNavigation.push(
      context,
      EvidencePreviewScreen(
        pending: PendingEvidence(
          title: widget.title,
          description: widget.description,
          category: widget.category,
          type: EvidenceType.video,
          filePath: path,
          metadata: metadata,
          fileSizeBytes: fileSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Video Capture', style: AppTextStyles.screenTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_videoPath == null) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_outlined,
                        size: 72,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Record video evidence using your device camera.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
              EVButton(
                text: 'Record Video',
                isLoading: _isRecording,
                onPressed: _isRecording ? null : _recordVideo,
              ),
            ] else ...[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                  child: _controller != null &&
                          _controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              EVButton(text: 'Save', onPressed: _continueToPreview),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _isRecording ? null : _recordVideo,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: Text(
                  'Retake',
                  style: AppTextStyles.label.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
