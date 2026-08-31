import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'pdf_document_surface.dart';

/// Production PDFium viewer. Imported from `main.dart` only — not from tests.
Widget buildNativePdfViewer(String filePath) {
  return PdfViewer.file(
    filePath,
    params: PdfViewerParams(
      backgroundColor: AppColors.surfaceMuted,
      loadingBannerBuilder: (context, downloaded, total) {
        return const Center(
          key: PdfDocumentSurface.loadingKey,
          child: CircularProgressIndicator(),
        );
      },
      errorBannerBuilder: (context, error, stackTrace, documentRef) {
        return ColoredBox(
          color: AppColors.surfaceMuted,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
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
                    'PDF could not be rendered',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'The file is missing, corrupt, or unsupported.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
