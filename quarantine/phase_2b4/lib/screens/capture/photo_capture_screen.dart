import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_category.dart';
import '../../models/evidence_type.dart';
import '../../models/pending_evidence.dart';
import '../../navigation/app_navigation.dart';
import '../../services/metadata_service.dart';
import '../../services/photo_capture_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ev_button.dart';
import '../evidence_preview_screen.dart';

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({
    super.key,
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;
  final EvidenceCategory category;

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  String? _photoPath;
  bool _isCapturing = false;

  Future<void> _openCamera() async {
    setState(() => _isCapturing = true);

    try {
      final path = await PhotoCaptureService.capturePhoto();
      if (!mounted) return;
      setState(() => _photoPath = path);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _continueToPreview() async {
    final path = _photoPath;
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
          type: EvidenceType.photo,
          filePath: path,
          thumbnailPath: path,
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
        title: Text('Photo Capture', style: AppTextStyles.screenTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_photoPath == null) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 72,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Open the camera to capture photo evidence.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
              EVButton(
                text: 'Open Camera',
                isLoading: _isCapturing,
                onPressed: _isCapturing ? null : _openCamera,
              ),
            ] else ...[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                  child: Image.file(
                    File(_photoPath!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              EVButton(text: 'Save', onPressed: _continueToPreview),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _isCapturing ? null : _openCamera,
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
