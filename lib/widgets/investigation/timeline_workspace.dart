import 'package:flutter/material.dart';

import '../../models/timeline_anchor_node.dart';
import '../../models/timeline_workspace_filter.dart';
import '../../models/workspace_evidence_item.dart';
import '../timeline/timeline_workspace_list.dart';

/// Timeline perspective within the Investigation Workspace.
///
/// Order is capture chronology ([TimelineAnchor.sequenceOrder]), not
/// Inspector/Organize preservation order ([lastPreservedAt]).
class TimelineWorkspace extends StatelessWidget {
  const TimelineWorkspace({
    super.key,
    required this.nodes,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.incidentName,
    required this.timelineAnchorCount,
    required this.supportingEvidenceCount,
    required this.relationshipGroupCount,
    required this.highlightedAnchorIds,
    required this.onAnchorSelected,
    required this.onCapturedTap,
    required this.onSupportingTap,
    this.resolveParticipantName,
  });

  final List<TimelineAnchorNode> nodes;
  final TimelineWorkspaceFilter selectedFilter;
  final ValueChanged<TimelineWorkspaceFilter> onFilterSelected;
  final String incidentName;
  final int timelineAnchorCount;
  final int supportingEvidenceCount;
  final int relationshipGroupCount;
  final Set<String> highlightedAnchorIds;
  final ValueChanged<String> onAnchorSelected;
  final ValueChanged<WorkspaceEvidenceItem> onCapturedTap;
  final ValueChanged<WorkspaceEvidenceItem> onSupportingTap;
  final String? Function(String participantId)? resolveParticipantName;

  static const scrollStorageKey = PageStorageKey<String>(
    'investigation_timeline_workspace_scroll',
  );

  @override
  Widget build(BuildContext context) {
    return TimelineWorkspaceList(
      key: scrollStorageKey,
      nodes: nodes,
      selectedFilter: selectedFilter,
      onFilterSelected: onFilterSelected,
      incidentName: incidentName,
      timelineAnchorCount: timelineAnchorCount,
      supportingEvidenceCount: supportingEvidenceCount,
      relationshipGroupCount: relationshipGroupCount,
      highlightedAnchorIds: highlightedAnchorIds,
      onAnchorSelected: onAnchorSelected,
      onCapturedTap: onCapturedTap,
      onSupportingTap: onSupportingTap,
      resolveParticipantName: resolveParticipantName,
      showHeader: false,
    );
  }
}
