import '../engines/enrichment_engine.dart';
import '../models/connection_group_node.dart';
import '../models/relationship_group_confidence.dart';
import '../models/workspace_evidence_item.dart';

/// Derives investigative completeness coaching for relationship groups.
abstract final class RelationshipGroupConfidenceService {
  static RelationshipGroupConfidence compute(
    ConnectionGroupNode node,
    EnrichmentContext context,
  ) {
    final members = _allMembers(node);
    final evidenceCount = members.length;
    final typeCount = _distinctEvidenceTypes(members).length;
    final hasContext = _hasContext(members);
    final primaryMembers =
        members.where(EnrichmentEngine.isPrimaryEvidence).toList();
    final somePrimaryEnriched = primaryMembers.any(
      (item) => EnrichmentEngine.isEnriched(item, context),
    );
    final allPrimaryEnriched = primaryMembers.isNotEmpty &&
        primaryMembers.every(
          (item) => EnrichmentEngine.isEnriched(item, context),
        );
    final hasSupporting = _hasSupportingEvidence(node);

    if (evidenceCount <= 2 || !hasContext || typeCount <= 1) {
      return RelationshipGroupConfidence.low;
    }

    if (evidenceCount >= 3 &&
        allPrimaryEnriched &&
        typeCount >= 3 &&
        hasSupporting) {
      return RelationshipGroupConfidence.high;
    }

    if (evidenceCount >= 3 && somePrimaryEnriched && typeCount >= 2) {
      return RelationshipGroupConfidence.medium;
    }

    return RelationshipGroupConfidence.low;
  }

  static List<WorkspaceEvidenceItem> _allMembers(ConnectionGroupNode node) {
    return [
      for (final entry in node.capturedEntries) entry.captured,
      for (final entry in node.capturedEntries) ...entry.supportingItems,
      ...node.standaloneSupporting,
    ];
  }

  static bool _hasSupportingEvidence(ConnectionGroupNode node) {
    return node.capturedEntries.any(
          (entry) => entry.supportingItems.isNotEmpty,
        ) ||
        node.standaloneSupporting.isNotEmpty;
  }

  static bool _hasContext(List<WorkspaceEvidenceItem> members) {
    return members.any(
      (item) =>
          item.isContextual && item.kind == WorkspaceEvidenceKind.note,
    );
  }

  static Set<String> _distinctEvidenceTypes(
    List<WorkspaceEvidenceItem> members,
  ) {
    return members.map(_evidenceTypeKey).toSet();
  }

  static String _evidenceTypeKey(WorkspaceEvidenceItem item) {
    if (item.isContextual && item.kind == WorkspaceEvidenceKind.note) {
      return 'context';
    }

    return switch (item.kind) {
      WorkspaceEvidenceKind.image => 'photo',
      WorkspaceEvidenceKind.video => 'video',
      WorkspaceEvidenceKind.voice => 'voice',
      WorkspaceEvidenceKind.note => 'note',
      WorkspaceEvidenceKind.attachment => 'document',
      WorkspaceEvidenceKind.witness => 'witness',
    };
  }
}
