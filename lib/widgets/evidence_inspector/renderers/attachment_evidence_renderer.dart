import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/evidence_formatters.dart';
import '../../../utils/workspace_evidence_formatters.dart';
import '../evidence_media_source.dart';
import '../evidence_preview_renderer.dart';

/// Professional file-attachment card — overflow-safe at any slot size.
class AttachmentEvidenceRenderer extends EvidencePreviewRenderer {
  const AttachmentEvidenceRenderer();

  @override
  Widget build(BuildContext context, EvidencePreviewContext preview) {
    final evidence = preview.record.evidence;
    final fileName = EvidenceMediaSource.displayName(
      evidence.fileName,
      fallback: evidence.title,
    );
    final extension = EvidenceMediaSource.extensionOf(fileName);
    final sizeLabel = EvidenceMediaSource.fileSizeLabel(preview.record) ??
        (EvidenceMediaSource.isReadableFile(evidence.filePath)
            ? EvidenceFormatters.fileSize(File(evidence.filePath!).lengthSync())
            : '—');
    final uploadDate = WorkspaceEvidenceFormatters.evidenceClock(
      evidence.lastPreservedAt,
    );
    final previewPath = EvidenceMediaSource.previewPath(evidence);
    final showImagePreview = EvidenceMediaSource.isReadableFile(previewPath) &&
        EvidenceMediaSource.isImagePath(previewPath);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        if (maxH <= 0 || maxW <= 0) {
          return const SizedBox.shrink();
        }

        final compact = maxH < 160;
        final showThumb = showImagePreview && maxH >= 140;

        final card = _FileCard(
          fileName: fileName,
          extension: extension,
          sizeLabel: sizeLabel,
          uploadDate: uploadDate,
          compact: compact,
          maxHeight: showThumb ? math.max(56.0, maxH * 0.42) : maxH,
        );

        if (!showThumb) {
          return Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxW,
                maxHeight: maxH,
              ),
              child: card,
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xxs,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: Image.file(
                    File(previewPath!),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.max(56.0, maxH * 0.42)),
              child: card,
            ),
          ],
        );
      },
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.fileName,
    required this.extension,
    required this.sizeLabel,
    required this.uploadDate,
    required this.compact,
    required this.maxHeight,
  });

  final String fileName;
  final String extension;
  final String sizeLabel;
  final String uploadDate;
  final bool compact;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final tight = maxHeight < 96;
    final iconSize = tight ? 32.0 : (compact ? 48.0 : 56.0);
    final pad = tight ? AppSpacing.xs : (compact ? AppSpacing.sm : AppSpacing.md);

    return Padding(
      padding: EdgeInsets.all(tight ? AppSpacing.xxs : pad / 2),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: maxHeight,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: math.max(120, 280),
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.55),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                size: tight ? 16 : (compact ? 20 : 26),
                                color: AppColors.navy,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                extension,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: tight ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: tight ? 12 : (compact ? 13 : 15),
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$extension · $sizeLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!tight) ...[
                          const SizedBox(height: 2),
                          Text(
                            uploadDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
