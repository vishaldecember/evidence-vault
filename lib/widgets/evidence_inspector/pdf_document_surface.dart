import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'evidence_media_source.dart';

/// Renders a local PDF from its durable [filePath] — never a temp copy.
class PdfDocumentSurface extends StatelessWidget {
  const PdfDocumentSurface({
    super.key,
    required this.filePath,
    this.padding = EdgeInsets.zero,
  });

  final String? filePath;
  final EdgeInsets padding;

  /// Production PDFium builder — registered from `main.dart`.
  static Widget Function(String filePath)? nativeBuilder;

  /// Test seam — bypasses PDFium so unit tests do not load native viewer code.
  @visibleForTesting
  static Widget Function(String filePath)? debugSurfaceBuilder;

  static const errorKey = Key('pdf_document_surface_error');
  static const loadingKey = Key('pdf_document_surface_loading');
  static const viewerKey = Key('pdf_document_surface_viewer');

  @override
  Widget build(BuildContext context) {
    final path = filePath?.trim() ?? '';
    if (path.isEmpty) {
      return const _PdfSurfaceMessage(
        key: errorKey,
        title: 'PDF is unavailable',
        detail: 'The original file could not be opened.',
      );
    }

    final testOverride = debugSurfaceBuilder;
    if (testOverride != null) {
      return KeyedSubtree(
        key: viewerKey,
        child: testOverride(path),
      );
    }

    if (!EvidenceMediaSource.isReadableFile(path)) {
      return const _PdfSurfaceMessage(
        key: errorKey,
        title: 'PDF is unavailable',
        detail: 'The original file could not be opened.',
      );
    }

    final override = nativeBuilder;
    if (override != null) {
      return KeyedSubtree(
        key: viewerKey,
        child: override(path),
      );
    }

    return const _PdfSurfaceMessage(
      key: errorKey,
      title: 'PDF viewer is not ready',
      detail: 'The in-app renderer is unavailable in this session.',
    );
  }
}

class _PdfSurfaceMessage extends StatelessWidget {
  const _PdfSurfaceMessage({
    super.key,
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 36,
                  color: AppColors.navy.withValues(alpha: 0.7),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
