import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/timeline_item_model.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/workspace_card.dart';
import 'timeline_item_card.dart';

/// Chronological understanding of an incident — not a feed or activity log.
///
/// Answers: "What happened, and in what order?"
/// Extension points reserved for relationship, reflection, witness,
/// verification, AI, and export events.
class IncidentTimelineSection extends StatelessWidget {
  const IncidentTimelineSection({
    super.key,
    required this.evidence,
    required this.onItemSelected,
    this.timelineItems,
  });

  final List<WorkspaceEvidenceItem> evidence;
  final List<TimelineItemModel>? timelineItems;
  final ValueChanged<WorkspaceEvidenceItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final items =
        timelineItems ?? TimelineItemModel.fromWorkspace(items: evidence);
    final itemById = {for (final item in evidence) item.id: item};

    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionHeader(
            title: 'Incident Timeline',
            caption: 'What happened, and in what order.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            const _EmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final timelineItem = items[index];
                return RepaintBoundary(
                  child: TimelineItemCard(
                    item: timelineItem,
                    showConnector: index < items.length - 1,
                    onTap: () {
                      final evidenceItem = itemById[timelineItem.evidenceId];
                      if (evidenceItem != null) {
                        onItemSelected(evidenceItem);
                      }
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'As you preserve evidence and enrich it with context, your incident '
      'timeline will begin to tell the story of what happened.',
      style: AppTextStyles.bodySmall.copyWith(height: 1.5),
    );
  }
}
