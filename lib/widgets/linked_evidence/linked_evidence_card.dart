import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_artifact_model.dart';
import '../../models/linked_evidence_item.dart';
import '../../services/relationship_group_color_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';

/// Compact card for one linked artifact on an Evidence Record.
class LinkedEvidenceCard extends StatelessWidget {
  const LinkedEvidenceCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final LinkedEvidenceItem item;
  final VoidCallback? onTap;

  Color get _groupColor {
    final index = item.relationshipGroupColorIndex;
    if (index == null) {
      return AppColors.primary;
    }
    return RelationshipGroupColorService.colorForIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              _CompactTypeIcon(
                type: item.artifactType,
                accentColor: _groupColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.artifactType.label,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.type.label,
                      style: AppTextStyles.caption.copyWith(
                        color: _groupColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Preserved ${WorkspaceEvidenceFormatters.preservedTimestamp(item.preservedAt)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTypeIcon extends StatelessWidget {
  const _CompactTypeIcon({
    required this.type,
    required this.accentColor,
  });

  final EvidenceArtifactType type;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      EvidenceArtifactType.photo => Icons.photo_outlined,
      EvidenceArtifactType.video => Icons.videocam_outlined,
      EvidenceArtifactType.voiceRecording => Icons.mic_outlined,
      EvidenceArtifactType.note => Icons.edit_note_outlined,
      EvidenceArtifactType.document => Icons.insert_drive_file_outlined,
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: accentColor, size: 24),
    );
  }
}
