import 'dart:developer' as developer;

import '../domain/evidence/captured_evidence.dart';
import '../models/evidence_relationship.dart';
import '../models/relationship_type.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';

/// Canonical evidence vocabulary for coaching, validation, Graph, and Journey.
///
/// Approved Step 4C contract (not a store; does not mutate persistence):
/// - **Primary** is a role: captured chronology (Photo / Video / Voice) that is
///   not explicitly contextual. Distinct from [CapturedEvidence.isPrimaryEvidence].
/// - **Supporting** is structural: parent-child or explicit SUPPORTS — not kind,
///   RELATED, collection, or group membership.
/// - **Suggested RELATED** is not supporting, corroboration, causation, or
///   enrichment.
/// - **Context** is recorded fields (location, written notes, attached
///   contextual children) — not timestamp alone, not related-person metadata.
/// - **Witness** is witness-kind evidence, not a participant or related person.
/// - **Corroboration** is not a domain state.
///
/// [WorkspaceEvidenceItem.isSupportingEvidence] remains a legacy *kind* getter
/// for Timeline/UI. Do not use it as structural support.
abstract final class EvidenceSemantics {
  EvidenceSemantics._();

  /// Primary chronology role: Photo / Video / Voice, excluding contextual items.
  static bool isPrimaryChronologyEvidence(WorkspaceEvidenceItem item) {
    if (item.isContextual) {
      return false;
    }
    return item.kind.isPrimaryChronology;
  }

  static List<WorkspaceEvidenceItem> primaryChronology(
    Iterable<WorkspaceEvidenceItem> items,
  ) {
    return [
      for (final item in items)
        if (isPrimaryChronologyEvidence(item)) item,
    ];
  }

  static int primaryChronologyCount(Iterable<WorkspaceEvidenceItem> items) {
    return primaryChronology(items).length;
  }

  /// [child] is structurally attached as supporting of [parentId].
  ///
  /// Parent-child and explicit SUPPORTS only. Siblings, collections, and
  /// metadata RELATED do not qualify.
  static bool structurallySupports({
    required WorkspaceEvidenceItem child,
    required String parentId,
    List<EvidenceRelationship> relationships = const [],
  }) {
    if (child.id == parentId || parentId.isEmpty) {
      return false;
    }
    final parentField = child.parentEvidenceId?.trim() ?? '';
    if (parentField == parentId) {
      return true;
    }
    if (!isPrimaryChronologyEvidence(child) &&
        child.relatedEvidenceIds.contains(parentId)) {
      return true;
    }
    return relationships.any(
      (relationship) =>
          relationship.type == RelationshipType.supports &&
          !isSuggestedRelated(relationship) &&
          _relationshipTouches(relationship, child.id, parentId),
    );
  }

  static bool hasStructuralSupport({
    required String evidenceId,
    required Iterable<WorkspaceEvidenceItem> items,
    List<EvidenceRelationship> relationships = const [],
  }) {
    return items.any(
      (item) => structurallySupports(
        child: item,
        parentId: evidenceId,
        relationships: relationships,
      ),
    );
  }

  static int structuralSupportCount({
    required String evidenceId,
    required Iterable<WorkspaceEvidenceItem> items,
    List<EvidenceRelationship> relationships = const [],
  }) {
    return items
        .where(
          (item) => structurallySupports(
            child: item,
            parentId: evidenceId,
            relationships: relationships,
          ),
        )
        .length;
  }

  /// True when any recorded context *dimension* exists. Not equivalent to
  /// enrichment-via-relationship. Timestamp / related-person are excluded.
  static bool hasRecordedContext(
    WorkspaceEvidenceItem item, {
    Iterable<WorkspaceEvidenceItem> incidentItems = const [],
    List<EvidenceRelationship> relationships = const [],
    String? eventSummary,
    bool hasReconstructionNotes = false,
  }) {
    if (hasLocation(item)) {
      return true;
    }
    if (hasWrittenDescription(item)) {
      return true;
    }
    if (item.isContextual) {
      return true;
    }
    if (eventSummary?.trim().isNotEmpty ?? false) {
      return true;
    }
    if (hasReconstructionNotes) {
      return true;
    }
    return incidentItems.any(
      (other) =>
          structurallySupports(
            child: other,
            parentId: item.id,
            relationships: relationships,
          ) &&
          (hasWrittenDescription(other) || other.isContextual),
    );
  }

  static bool hasLocation(WorkspaceEvidenceItem item) {
    return item.latitude != null && item.longitude != null;
  }

  /// Written description / note preview on this item. Not timestamp, GPS, or
  /// related-person metadata.
  static bool hasWrittenDescription(WorkspaceEvidenceItem item) {
    return item.notePreview?.trim().isNotEmpty ?? false;
  }

  /// Witness statement/evidence item — not [Participant] or related-person fields.
  static bool hasWitnessKind(Iterable<WorkspaceEvidenceItem> items) {
    return items.any((item) => item.kind == WorkspaceEvidenceKind.witness);
  }

  static bool hasSupportingDocumentKind(Iterable<WorkspaceEvidenceItem> items) {
    return items.any(
      (item) =>
          item.kind == WorkspaceEvidenceKind.note ||
          item.kind == WorkspaceEvidenceKind.attachment,
    );
  }

  static bool hasStructurallyAttachedDocument({
    required String evidenceId,
    required Iterable<WorkspaceEvidenceItem> items,
    List<EvidenceRelationship> relationships = const [],
  }) {
    return items.any(
      (item) =>
          (item.kind == WorkspaceEvidenceKind.note ||
              item.kind == WorkspaceEvidenceKind.attachment) &&
          structurallySupports(
            child: item,
            parentId: evidenceId,
            relationships: relationships,
          ),
    );
  }

  /// Metadata TIME/SPACE RELATED and Matter (`source: ai`) RELATED are
  /// suggested intelligence — not supporting, not corroboration, not context.
  static bool isSuggestedRelated(EvidenceRelationship relationship) {
    if (relationship.type != RelationshipType.relatedTo) {
      return false;
    }
    final source = (relationship.source ?? '').toLowerCase();
    if (source == 'metadata' || source == 'ai') {
      return true;
    }
    if (source == 'user') {
      return false;
    }
    // Fail closed toward "suggested" when the persisted reason is the
    // Matter/heuristic because-text but source was dropped. Do not infer
    // source == ai or source == metadata from a missing source field.
    final reason = relationship.reason ?? '';
    return reason.startsWith('Related because') ||
        reason.startsWith('Related through') ||
        reason.startsWith('Suggested relationship because');
  }

  static bool isExplicitUserRelationship(EvidenceRelationship relationship) {
    return !isSuggestedRelated(relationship);
  }

  /// Parent-child or explicit (non-suggested) relationship — not collections.
  static bool hasStructuralRelationship({
    required String evidenceId,
    required Iterable<WorkspaceEvidenceItem> items,
    List<EvidenceRelationship> relationships = const [],
  }) {
    for (final item in items) {
      if (item.id == evidenceId) {
        final parent = item.parentEvidenceId?.trim() ?? '';
        if (parent.isNotEmpty) {
          return true;
        }
        if (item.relatedEvidenceIds.isNotEmpty &&
            !isPrimaryChronologyEvidence(item)) {
          return true;
        }
      }
      if (structurallySupports(
        child: item,
        parentId: evidenceId,
        relationships: relationships,
      )) {
        return true;
      }
    }
    for (final relationship in relationships) {
      if (isSuggestedRelated(relationship)) {
        continue;
      }
      if (relationship.sourceEvidenceId == evidenceId ||
          relationship.targetEvidenceId == evidenceId) {
        return true;
      }
    }
    return false;
  }

  static bool hasSuggestedRelationship({
    required String evidenceId,
    required List<EvidenceRelationship> relationships,
  }) {
    return relationships.any(
      (relationship) =>
          isSuggestedRelated(relationship) &&
          (relationship.sourceEvidenceId == evidenceId ||
              relationship.targetEvidenceId == evidenceId),
    );
  }

  static bool isInCollection(WorkspaceEvidenceItem item) {
    final id = item.collectionId?.trim() ?? '';
    return id.isNotEmpty;
  }

  static List<WorkspaceEvidenceItem> incidentScopedItems(
    Iterable<WorkspaceEvidenceItem> items,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    final owned = <WorkspaceEvidenceItem>[];
    for (final item in items) {
      if (item.belongsToIncident(incidentId)) {
        owned.add(item);
      } else {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: item.incidentId,
          evidenceId: item.id,
        );
      }
    }
    return owned;
  }

  static List<CapturedEvidence> incidentScopedCaptured(
    Iterable<CapturedEvidence> items,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    return [
      for (final item in items)
        if (item.incidentId.isNotEmpty && item.incidentId == incidentId) item,
    ];
  }

  static List<EvidenceRelationship> incidentScopedRelationships({
    required Iterable<EvidenceRelationship> relationships,
    required Iterable<WorkspaceEvidenceItem> scopedItems,
  }) {
    final ownedIds = {for (final item in scopedItems) item.id};
    return [
      for (final relationship in relationships)
        if (ownedIds.contains(relationship.sourceEvidenceId) &&
            ownedIds.contains(relationship.targetEvidenceId))
          relationship,
    ];
  }

  static List<TimelineAnchorNode> incidentScopedTimeline(
    Iterable<TimelineAnchorNode> nodes,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    final scoped = <TimelineAnchorNode>[];
    for (final node in nodes) {
      if (!node.capturedItem.belongsToIncident(incidentId)) {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: node.capturedItem.incidentId,
          evidenceId: node.capturedItem.id,
        );
        continue;
      }
      if (node.anchor.incidentId.isNotEmpty &&
          node.anchor.incidentId != incidentId) {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: node.anchor.incidentId,
          evidenceId: node.capturedItem.id,
        );
        continue;
      }
      scoped.add(
        TimelineAnchorNode(
          anchor: node.anchor,
          capturedItem: node.capturedItem,
          supportingItems: incidentScopedItems(node.supportingItems, incidentId),
        ),
      );
    }
    return scoped;
  }

  static bool _relationshipTouches(
    EvidenceRelationship relationship,
    String a,
    String b,
  ) {
    return (relationship.sourceEvidenceId == a &&
            relationship.targetEvidenceId == b) ||
        (relationship.sourceEvidenceId == b &&
            relationship.targetEvidenceId == a);
  }

  static void _logExcluded({
    required String expectedIncidentId,
    required String actualIncidentId,
    required String evidenceId,
  }) {
    developer.log(
      'EXPECTED INCIDENT:\n$expectedIncidentId\n\n'
      'ACTUAL INCIDENT:\n$actualIncidentId\n\n'
      'EXPECTED EVIDENCE:\n(owned by $expectedIncidentId)\n\n'
      'ACTUAL EVIDENCE:\n$evidenceId',
      name: 'EvidenceSemantics',
    );
  }
}
