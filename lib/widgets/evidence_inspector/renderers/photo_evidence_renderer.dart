import 'dart:io';

import 'package:flutter/material.dart';

import '../../../navigation/app_navigation.dart';
import '../../../theme/app_colors.dart';
import '../evidence_media_source.dart';
import '../evidence_preview_renderer.dart';

/// Large proportional photo preview — no cropping.
class PhotoEvidenceRenderer extends EvidencePreviewRenderer {
  const PhotoEvidenceRenderer();

  @override
  Widget build(BuildContext context, EvidencePreviewContext preview) {
    final evidence = preview.record.evidence;
    final path = EvidenceMediaSource.previewPath(evidence);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = EvidenceMediaSource.decodeWidth(
      logicalWidth: preview.availableSize.width,
      devicePixelRatio: dpr,
    );

    return Semantics(
      label: 'Photo evidence. Double tap or activate to examine closely.',
      image: true,
      button: true,
      onTap: () => AppNavigation.openImageInspection(
        context,
        evidence: evidence,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('evidence_image_open'),
          onTap: () => AppNavigation.openImageInspection(
            context,
            evidence: evidence,
          ),
          child: ColoredBox(
            color: Colors.transparent,
            child: Center(
              child: EvidenceMediaSource.isReadableFile(path)
                  ? Image.file(
                      File(path!),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      width: preview.availableSize.width,
                      height: preview.availableSize.height,
                      cacheWidth: cacheWidth,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return const _PhotoPlaceholder(loading: true);
                      },
                      errorBuilder: (_, _, _) => const _PhotoUnavailable(),
                    )
                  : const _PhotoUnavailable(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_outlined,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              loading ? 'Photo loading' : 'Photo evidence',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoUnavailable extends StatelessWidget {
  const _PhotoUnavailable();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_outlined,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'Photo evidence',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Preview unavailable',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
