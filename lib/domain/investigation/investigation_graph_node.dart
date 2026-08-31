/// Node kinds in the investigation graph.
enum InvestigationGraphNodeKind {
  participant,
  capturedEvidence,
  supportingEvidence,
  timelineAnchor,
  relationshipGroup,
  evidenceCollection,
  narrativeEvent,
}

/// One node in the investigation graph — architecture only, not persisted.
class InvestigationGraphNode {
  const InvestigationGraphNode({
    required this.kind,
    required this.id,
    this.participantId,
  });

  final InvestigationGraphNodeKind kind;
  final String id;

  /// When [kind] is evidence, optional link to a [Participant] node.
  final String? participantId;
}
