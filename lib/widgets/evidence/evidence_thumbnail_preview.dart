import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_type.dart';
import '../../security/https_preview_url.dart';
import '../../theme/app_colors.dart';

class EvidenceThumbnailPreview extends StatelessWidget {
  const EvidenceThumbnailPreview({
    super.key,
    required this.type,
    this.filePath,
    this.thumbnailPath,
  });

  final EvidenceType type;
  final String? filePath;
  final String? thumbnailPath;

  static bool _isNetworkUrl(String path) => isHttpsPreviewUrl(path);

  @override
  Widget build(BuildContext context) {
    final previewPath = thumbnailPath ?? filePath;

    if (previewPath != null &&
        (type == EvidenceType.photo ||
            type == EvidenceType.video ||
            (type == EvidenceType.document && _isImagePath(previewPath)) ||
            _isNetworkUrl(previewPath))) {
      final cacheWidth = (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: _isNetworkUrl(previewPath)
            ? Image.network(
                previewPath,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stackTrace) => _placeholder(type),
              )
            : Image.file(
                File(previewPath),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stackTrace) => _placeholder(type),
              ),
      );
    }

    return _placeholder(type);
  }

  bool _isImagePath(String path) {
    if (_isNetworkUrl(path)) {
      return true;
    }
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }
}

Widget _placeholder(EvidenceType type) {
  final icon = switch (type) {
    EvidenceType.photo => Icons.photo_outlined,
    EvidenceType.video => Icons.videocam_outlined,
    EvidenceType.audio => Icons.mic_outlined,
    EvidenceType.document => Icons.description_outlined,
  };

  return Container(
    height: 220,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      border: Border.all(color: AppColors.border),
    ),
    child: Icon(icon, size: 56, color: AppColors.primary),
  );
}
