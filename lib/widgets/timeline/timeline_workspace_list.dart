import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/timeline_anchor_node.dart';
import '../../models/timeline_workspace_filter.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'timeline_anchor_entry.dart';
import 'timeline_workspace_filters.dart';
import 'timeline_workspace_header.dart';

/// Scrollable anchor-ordered timeline for the Timeline Workspace.
class TimelineWorkspaceList extends StatelessWidget {
  const TimelineWorkspaceList({
    super.key,
    required this.nodes,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.incidentName,
    required this.timelineAnchorCount,
    required this.supportingEvidenceCount,
    required this.relationshipGroupCount,
    required this.onCapturedTap,
    required this.onSupportingTap,
    this.highlightedAnchorIds = const {},
    this.onAnchorSelected,
    this.showHeader = true,
    this.resolveParticipantName,
  });

  final List<TimelineAnchorNode> nodes;
  final TimelineWorkspaceFilter selectedFilter;
  final ValueChanged<TimelineWorkspaceFilter> onFilterSelected;
  final String incidentName;
  final int timelineAnchorCount;
  final int supportingEvidenceCount;
  final int relationshipGroupCount;
  final ValueChanged<WorkspaceEvidenceItem> onCapturedTap;
  final ValueChanged<WorkspaceEvidenceItem> onSupportingTap;
  final Set<String> highlightedAnchorIds;
  final ValueChanged<String>? onAnchorSelected;
  final bool showHeader;
  final String? Function(String participantId)? resolveParticipantName;

  @override
  Widget build(BuildContext context) {
    final filteredNodes = TimelineWorkspaceFilter.apply(
      filter: selectedFilter,
      nodes: nodes,
    );

    return CustomScrollView(
      slivers: [
        if (showHeader) ...[
          SliverToBoxAdapter(
            child: TimelineWorkspaceHeader(
              incidentName: incidentName,
              timelineAnchorCount: timelineAnchorCount,
              supportingEvidenceCount: supportingEvidenceCount,
              relationshipGroupCount: relationshipGroupCount,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        ],
        SliverToBoxAdapter(
          child: TimelineWorkspaceFilters(
            selectedFilter: selectedFilter,
            onFilterSelected: onFilterSelected,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        if (nodes.isEmpty)
          SliverToBoxAdapter(
            child: Text(
              'As you preserve captured evidence, your incident timeline '
              'will reconstruct what happened in order.',
              style: AppTextStyles.bodySmall.copyWith(
                height: 1.5,
                color: AppColors.onCanvasSecondary,
              ),
            ),
          )
        else if (filteredNodes.isEmpty)
          SliverToBoxAdapter(
            child: Text(
              'No timeline entries match this filter.',
              style: AppTextStyles.bodySmall.copyWith(
                height: 1.5,
                color: AppColors.onCanvasSecondary,
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: filteredNodes.length,
            itemBuilder: (context, index) {
              final node = filteredNodes[index];
              return TimelineAnchorEntry(
                node: node,
                showConnector: index < filteredNodes.length - 1,
                isHighlighted: highlightedAnchorIds.contains(node.capturedItem.id),
                onCapturedTap: () {
                  onAnchorSelected?.call(node.capturedItem.id);
                  onCapturedTap(node.capturedItem);
                },
                onSupportingTap: onSupportingTap,
                resolveParticipantName: resolveParticipantName,
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}
