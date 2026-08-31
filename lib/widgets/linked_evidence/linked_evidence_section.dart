import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_record_model.dart';
import '../../models/linked_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/workspace_card.dart';
import 'linked_evidence_thumbnail.dart';

/// Read-only linked evidence visibility on the Evidence Record.
///
/// Relationship editing belongs in the Connections Workspace — this section
/// only shows connected artifacts as a horizontal thumbnail row.
class LinkedEvidenceSection extends StatelessWidget {
  const LinkedEvidenceSection({
    super.key,
    required this.record,
    required this.onLinkedEvidenceTap,
    this.sectionTitle = 'Linked Evidence',
    this.compact = false,
  });

  final EvidenceRecordModel record;
  final ValueChanged<LinkedEvidenceItem> onLinkedEvidenceTap;
  final String sectionTitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      if (!record.hasLinkedEvidence) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sectionTitle,
            style: AppTextStyles.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < record.linkedEvidence.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  LinkedEvidenceThumbnail(
                    item: record.linkedEvidence[i],
                    onTap: () => onLinkedEvidenceTap(record.linkedEvidence[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionHeader(title: sectionTitle),
          const SizedBox(height: AppSpacing.md),
          if (!record.hasLinkedEvidence)
            Text(
              'No linked evidence yet. Organize related artifacts in the '
              'Connections Workspace.',
              style: AppTextStyles.bodySmall.copyWith(height: 1.5),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < record.linkedEvidence.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    LinkedEvidenceThumbnail(
                      item: record.linkedEvidence[i],
                      onTap: () => onLinkedEvidenceTap(record.linkedEvidence[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
