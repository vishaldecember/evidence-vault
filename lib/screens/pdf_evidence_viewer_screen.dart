import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../models/workspace_evidence_item.dart';
import '../presentation/evidence_presentation_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/evidence_inspector/pdf_document_surface.dart';

/// Dedicated PDF viewing surface. Pops back to the route that opened it.
class PdfEvidenceViewerScreen extends StatelessWidget {
  const PdfEvidenceViewerScreen({
    super.key,
    required this.evidence,
  });

  final WorkspaceEvidenceItem evidence;

  static const screenKey = Key('pdf_evidence_viewer_screen');

  /// Viewing source of truth — the existing durable evidence path.
  static String? sourcePath(WorkspaceEvidenceItem item) => item.filePath;

  @override
  Widget build(BuildContext context) {
    final presentation = EvidencePresentationResolver.resolve(evidence);
    final title = evidence.fileName?.trim().isNotEmpty == true
        ? evidence.fileName!.trim()
        : evidence.title;
    final sizeLabel = presentation.metadata.fileSize;

    return Scaffold(
      key: screenKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        leading: const AppBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            if (sizeLabel != null && sizeLabel.isNotEmpty)
              Text(
                sizeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: PdfDocumentSurface(filePath: sourcePath(evidence)),
      ),
    );
  }
}
