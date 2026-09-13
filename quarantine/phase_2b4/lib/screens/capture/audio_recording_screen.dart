import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_category.dart';
import '../../models/evidence_type.dart';
import '../../models/pending_evidence.dart';
import '../../navigation/app_navigation.dart';
import '../../services/audio_capture_service.dart';
import '../../services/metadata_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ev_button.dart';
import '../evidence_preview_screen.dart';

class AudioRecordingScreen extends StatefulWidget {
  const AudioRecordingScreen({
    super.key,
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;
  final EvidenceCategory category;

  @override
  State<AudioRecordingScreen> createState() => _AudioRecordingScreenState();
}

class _AudioRecordingScreenState extends State<AudioRecordingScreen> {
  final _player = AudioPlayer();
  String? _recordingPath;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    AudioCaptureService.dispose();
    super.dispose();
  }

  Future<void> _refreshState() async {
    final recording = await AudioCaptureService.isRecording;
    final paused = await AudioCaptureService.isPaused;
    if (!mounted) return;
    setState(() {
      _isRecording = recording;
      _isPaused = paused;
    });
  }

  Future<void> _startRecording() async {
    await AudioCaptureService.start();
    setState(() {
      _recordingPath = null;
      _isPlaying = false;
    });
    await _refreshState();
  }

  Future<void> _pauseRecording() async {
    await AudioCaptureService.pause();
    await _refreshState();
  }

  Future<void> _resumeRecording() async {
    await AudioCaptureService.resume();
    await _refreshState();
  }

  Future<void> _stopRecording() async {
    final path = await AudioCaptureService.stop();
    if (!mounted) return;
    setState(() {
      _recordingPath = path;
      _isRecording = false;
      _isPaused = false;
    });
  }

  Future<void> _togglePlayback() async {
    final path = _recordingPath;
    if (path == null) return;

    if (_isPlaying) {
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    await _player.play(DeviceFileSource(path));
    if (mounted) setState(() => _isPlaying = true);

    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _continueToPreview() async {
    final path = _recordingPath;
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
          type: EvidenceType.audio,
          filePath: path,
          metadata: metadata,
          fileSizeBytes: fileSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRecording = _recordingPath != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Audio Recording', style: AppTextStyles.screenTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRecording
                          ? Icons.fiber_manual_record
                          : Icons.mic_outlined,
                      size: 72,
                      color: _isRecording
                          ? AppColors.danger
                          : AppColors.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _statusLabel(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ),
            if (!_isRecording && !hasRecording)
              EVButton(text: 'Record Audio', onPressed: _startRecording),
            if (_isRecording) ...[
              if (!_isPaused)
                EVButton(text: 'Pause', onPressed: _pauseRecording),
              if (_isPaused)
                EVButton(text: 'Resume', onPressed: _resumeRecording),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _stopRecording,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                  side: const BorderSide(color: AppColors.danger),
                ),
                child: Text(
                  'Stop',
                  style: AppTextStyles.label.copyWith(color: AppColors.danger),
                ),
              ),
            ],
            if (hasRecording && !_isRecording) ...[
              EVButton(
                text: _isPlaying ? 'Stop Playback' : 'Playback',
                onPressed: _togglePlayback,
              ),
              const SizedBox(height: AppSpacing.sm),
              EVButton(text: 'Save', onPressed: _continueToPreview),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _startRecording,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: Text(
                  'Record again',
                  style: AppTextStyles.label.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel() {
    if (_isRecording && _isPaused) {
      return 'Recording paused. Resume or stop when ready.';
    }
    if (_isRecording) {
      return 'Recording in progress…';
    }
    if (_recordingPath != null) {
      return 'Recording complete. Review playback before saving.';
    }
    return 'Record audio evidence with pause and resume controls.';
  }
}
