import '../../models/evidence_relationship.dart';
import '../../models/workspace_evidence_item.dart';
import '../../repositories/incident_store.dart';
import '../../services/relationship/relationship_engine.dart';
import 'investigation_graph_node.dart';

/// Projects the incident aggregate as an investigation graph.
///
/// Participants are first-class nodes alongside evidence, timeline anchors,
/// relationship groups, collections, and narrative events. Edges are derived
/// by [RelationshipEngine] — not drawn manually (Sprint 5C).
abstract final class InvestigationGraph {
  InvestigationGraph._();

  static List<InvestigationGraphNode> nodesFromStore(IncidentStore store) {
    return [
      for (final participant in store.participants)
        InvestigationGraphNode(
          kind: InvestigationGraphNodeKind.participant,
          id: participant.id,
        ),
      for (final evidence in store.capturedEvidence)
        InvestigationGraphNode(
          kind: InvestigationGraphNodeKind.capturedEvidence,
          id: evidence.id,
          participantId: evidence.participantId,
        ),
      for (final evidence in store.supportingEvidence)
        InvestigationGraphNode(
          kind: InvestigationGraphNodeKind.supportingEvidence,
          id: evidence.id,
          participantId: evidence.participantId,
        ),
      for (final anchor in store.timelineAnchors)
        InvestigationGraphNode(
          kind: InvestigationGraphNodeKind.timelineAnchor,
          id: anchor.id,
        ),
      for (final group in store.relationshipGroups)
        InvestigationGraphNode(
          kind: InvestigationGraphNodeKind.relationshipGroup,
          id: group.id,
        ),
      for (final collection in store.evidenceCollections)
        InvestigationGraphNode(
          kind: InvestigationGraphNodeKind.evidenceCollection,
          id: collection.id,
        ),
      for (final event in store.narrativeEvents)
        InvestigationGraphNode(
          kind: InvestigationGraphNodeKind.narrativeEvent,
          id: event.id,
        ),
    ];
  }

  /// Edge / hierarchy projection for Investigation Graph UI.
  static InvestigationGraphView viewFromStore({
    required IncidentStore store,
    required List<WorkspaceEvidenceItem> evidence,
    required List<EvidenceRelationship> relationships,
  }) {
    return RelationshipEngine.instance.buildGraphView(
      store: store,
      evidence: evidence,
      relationships: relationships,
    );
  }
}
