import '../domain/timeline/timeline_anchor.dart';
import 'workspace_evidence_item.dart';

/// One chronological anchor and its attached supporting evidence.
///
/// **Order** is capture chronology from [TimelineRepository.orderedCapturedEvidenceIds]
/// ([TimelineAnchor.sequenceOrder]) — never [lastPreservedAt] / Inspector order.
/// **Clock** for the captured item is the shared evidence clock of [lastPreservedAt].
class TimelineAnchorNode {
  const TimelineAnchorNode({
    required this.anchor,
    required this.capturedItem,
    required this.supportingItems,
  });

  final TimelineAnchor anchor;
  final WorkspaceEvidenceItem capturedItem;
  final List<WorkspaceEvidenceItem> supportingItems;
}
