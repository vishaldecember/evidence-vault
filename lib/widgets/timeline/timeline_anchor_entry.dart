import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/timeline_anchor_node.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';
import '../../theme/investigation_selection_visuals.dart';
import '../evidence/evidence_participant_chip.dart';
import '../investigation/evidence_review_halo.dart';
import '../workspace/living_evidence_preview.dart';
import 'timeline_anchor_card_metadata.dart';
import 'timeline_evidence_labels.dart';

/// One immutable timeline anchor and its attached supporting evidence.
class TimelineAnchorEntry extends StatelessWidget {
  const TimelineAnchorEntry({
    super.key,
    required this.node,
    required this.showConnector,
    required this.onCapturedTap,
    required this.onSupportingTap,
    this.isHighlighted = false,
    this.resolveParticipantName,
  });

  final TimelineAnchorNode node;
  final bool showConnector;
  final VoidCallback onCapturedTap;
  final ValueChanged<WorkspaceEvidenceItem> onSupportingTap;
  final bool isHighlighted;
  final String? Function(String participantId)? resolveParticipantName;

  static const double _railWidth = 20;
  static const double _thumbnailSize = 48;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _railWidth,
              child: Column(
                children: [
                  _TimelineNode(),
                  if (showConnector)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: AppColors.border.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: LayeredCard(
                padding: const EdgeInsets.all(AppSpacing.xs),
                radius: AppSpacing.sm,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EvidenceReviewHalo(
                    evidenceId: node.capturedItem.id,
                    ensureVisible: true,
                    child: _CapturedAnchorRow(
                    node: node,
                    isHighlighted: isHighlighted,
                    onTap: onCapturedTap,
                    participantDisplayName: _participantNameFor(
                      node.capturedItem.participantId,
                    ),
                    ),
                  ),
                  if (node.supportingItems.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    for (var i = 0; i < node.supportingItems.length; i++)
                      EvidenceReviewHalo(
                        evidenceId: node.supportingItems[i].id,
                        child: _SupportingEvidenceRow(
                        item: node.supportingItems[i],
                        isLast: i == node.supportingItems.length - 1,
                        onTap: () => onSupportingTap(node.supportingItems[i]),
                        participantDisplayName: _participantNameFor(
                          node.supportingItems[i].participantId,
                        ),
                        ),
                      ),
                  ],
                  if (showConnector) const SizedBox(height: AppSpacing.md),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _participantNameFor(String? participantId) {
    if (participantId == null || resolveParticipantName == null) {
      return null;
    }
    return resolveParticipantName!(participantId);
  }
}

class _TimelineNode extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 2),
      ),
    );
  }
}

class _CapturedAnchorRow extends StatelessWidget {
  const _CapturedAnchorRow({
    required this.node,
    required this.onTap,
    this.isHighlighted = false,
    this.participantDisplayName,
  });

  final TimelineAnchorNode node;
  final VoidCallback onTap;
  final bool isHighlighted;
  final String? participantDisplayName;

  @override
  Widget build(BuildContext context) {
    final metadata = TimelineAnchorCardMetadata.fromNode(node);

    return AnimatedContainer(
      duration: InvestigationSelectionVisuals.selectionDuration,
      curve: InvestigationSelectionVisuals.selectionCurve,
      decoration: BoxDecoration(
        color: isHighlighted
            ? InvestigationSelectionVisuals.selectionColor.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: isHighlighted
            ? Border.all(
                color: InvestigationSelectionVisuals.selectionColor
                    .withValues(alpha: 0.45),
                width: InvestigationSelectionVisuals.timelineBorderWidth,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: TimelineAnchorEntry._thumbnailSize,
                height: TimelineAnchorEntry._thumbnailSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: LivingEvidencePreview(
                      item: node.capturedItem,
                      uniformThumbnailSize: true,
                      suppressBorder: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${metadata.capturedEmoji} ${metadata.evidenceTypeLabel}',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _MetadataLine(
                      key: Key(
                        'investigate_timeline_clock_${node.capturedItem.id}',
                      ),
                      icon: '🕒',
                      text: metadata.captureTime,
                    ),
                    if (metadata.deviceName != null) ...[
                      const SizedBox(height: 2),
                      _MetadataLine(
                        icon: '📱',
                        text: metadata.deviceName!,
                      ),
                    ],
                    if (metadata.captureLocation != null) ...[
                      const SizedBox(height: 2),
                      _MetadataLine(
                        icon: '📍',
                        text: metadata.captureLocation!,
                      ),
                    ],
                    if (participantDisplayName != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      EvidenceParticipantChip(displayName: participantDisplayName!),
                    ],
                  ],
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

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({
    super.key,
    required this.icon,
    required this.text,
  });

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$icon $text',
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.35,
      ),
    );
  }
}

class _SupportingEvidenceRow extends StatelessWidget {
  const _SupportingEvidenceRow({
    required this.item,
    required this.isLast,
    required this.onTap,
    this.participantDisplayName,
  });

  final WorkspaceEvidenceItem item;
  final bool isLast;
  final VoidCallback onTap;
  final String? participantDisplayName;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs,
            right: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLast ? '└── ' : '├── ',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TimelineEvidenceLabels.supportingLabel(item),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (participantDisplayName != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      EvidenceParticipantChip(displayName: participantDisplayName!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
