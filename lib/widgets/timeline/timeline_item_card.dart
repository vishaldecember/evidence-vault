import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_artifact_model.dart';
import '../../models/timeline_item_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';
import '../../utils/workspace_evidence_formatters.dart';

/// Single entry on the Incident Timeline — archival, not a feed.
class TimelineItemCard extends StatelessWidget {
  const TimelineItemCard({
    super.key,
    required this.item,
    required this.showConnector,
    this.onTap,
  });

  final TimelineItemModel item;
  final bool showConnector;
  final VoidCallback? onTap;

  static const double _railWidth = 22;
  static const double _nodeSize = 10;

  static const double _connectorHeight = 56;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _railWidth,
          child: Column(
            children: [
              _TimelineNode(item: item),
              if (showConnector)
                Container(
                  height: _connectorHeight,
                  width: 2,
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: showConnector ? AppSpacing.md : 0,
            ),
            child: LayeredCard(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: AppSpacing.xs,
              ),
              radius: AppSpacing.sm,
              onTap: onTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EventIcon(item: item),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          item.description,
                          style: AppTextStyles.bodySmall.copyWith(
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          WorkspaceEvidenceFormatters.preservedTimestamp(
                            item.occurredAt,
                          ),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.item});

  final TimelineItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TimelineItemCard._nodeSize,
      height: TimelineItemCard._nodeSize,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 2),
      ),
    );
  }
}

class _EventIcon extends StatelessWidget {
  const _EventIcon({required this.item});

  final TimelineItemModel item;

  @override
  Widget build(BuildContext context) {
    final icon = item.artifactType != null
        ? _artifactIcon(item.artifactType!)
        : item.eventType.icon;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Icon(icon, size: 20, color: AppColors.primary),
    );
  }

  IconData _artifactIcon(EvidenceArtifactType type) => switch (type) {
        EvidenceArtifactType.photo => Icons.photo_outlined,
        EvidenceArtifactType.video => Icons.videocam_outlined,
        EvidenceArtifactType.voiceRecording => Icons.mic_outlined,
        EvidenceArtifactType.note => Icons.edit_note_outlined,
        EvidenceArtifactType.document => Icons.insert_drive_file_outlined,
      };
}
