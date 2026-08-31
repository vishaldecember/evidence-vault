import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../engines/enrichment_engine.dart';
import '../../models/evidence_record_model.dart';
import '../../models/relationship_group.dart';
import '../../models/timeline_anchor_node.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/relationship_group_color_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../timeline/timeline_anchor_card_metadata.dart';
import '../timeline/timeline_evidence_labels.dart';
import '../workspace/living_evidence_preview.dart';

/// Lightweight evidence inspector for the Reconstruction Canvas.
class EvidenceInspectorPanel extends StatelessWidget {
  const EvidenceInspectorPanel({
    super.key,
    required this.evidence,
    required this.timelineNodes,
    required this.relationshipGroups,
    required this.onOpenFullRecord,
    required this.onClose,
  });

  final WorkspaceEvidenceItem evidence;
  final List<TimelineAnchorNode> timelineNodes;
  final List<RelationshipGroup> relationshipGroups;
  final VoidCallback onOpenFullRecord;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final metadata = EvidenceRecordMetadata.forItem(evidence);
    final groups = _groupsForEvidence();
    final timelinePosition = _timelinePositionLabel();
    final contextText = _contextSummary();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Evidence Inspector',
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close inspector',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: LivingEvidencePreview(
                        item: evidence,
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
                        EnrichmentEngine.isPrimaryEvidence(evidence)
                            ? TimelineEvidenceLabels.capturedLabel(evidence)
                            : TimelineEvidenceLabels.supportingLabel(evidence),
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      _InspectorRow(
                        label: 'Evidence type',
                        value: evidence.kind.label,
                      ),
                      for (final clock
                          in EvidenceInspectorSemantics.instants(evidence))
                        _InspectorRow(
                          label: clock.label,
                          value: clock.formatted,
                        ),
                      if (metadata.device != null)
                        _InspectorRow(
                          label: 'Device',
                          value: metadata.device!,
                        ),
                      if (_locationLabel(metadata) != null)
                        _InspectorRow(
                          label: 'Location',
                          value: _locationLabel(metadata)!,
                        ),
                      if (contextText != null)
                        _InspectorRow(
                          label: EvidenceInspectorSemantics.observationLabel,
                          value: contextText,
                        ),
                      if (timelinePosition != null)
                        _InspectorRow(
                          label: 'Timeline Position',
                          value: timelinePosition,
                        ),
                      _InspectorRow(
                        label: 'Relationship Groups',
                        value: groups.isEmpty
                            ? 'None'
                            : groups
                                .map(
                                  (group) =>
                                      RelationshipGroupColorService.displayName(
                                    group,
                                    relationshipGroups,
                                  ),
                                )
                                .join(', '),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onOpenFullRecord,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: Text(
                'View complete record →',
                style: AppTextStyles.link.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _timelinePositionLabel() {
    for (var i = 0; i < timelineNodes.length; i++) {
      if (timelineNodes[i].capturedItem.id == evidence.id) {
        return 'Primary ${i + 1} of ${timelineNodes.length}';
      }
    }
    return null;
  }

  String? _contextSummary() {
    if (evidence.isContextual && evidence.notePreview?.trim().isNotEmpty == true) {
      return evidence.notePreview!.trim();
    }
    if (evidence.notePreview?.trim().isNotEmpty == true) {
      return evidence.notePreview!.trim();
    }
    return null;
  }

  String? _locationLabel(EvidenceRecordMetadata metadata) {
    for (final node in timelineNodes) {
      if (node.capturedItem.id == evidence.id) {
        return TimelineAnchorCardMetadata.fromNode(node).captureLocation;
      }
    }
    return metadata.location;
  }

  List<RelationshipGroup> _groupsForEvidence() {
    final matches = <RelationshipGroup>[];
    for (final group in relationshipGroups) {
      if (group.memberEvidenceIds.contains(evidence.id)) {
        matches.add(group);
      }
    }
    return RelationshipGroupColorService.orderedGroups(matches);
  }
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Text(
        '$label: $value',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          height: 1.35,
        ),
      ),
    );
  }
}
