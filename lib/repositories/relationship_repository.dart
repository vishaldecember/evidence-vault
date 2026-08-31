import '../models/evidence_relationship.dart';
import '../models/relationship_group.dart';
import '../models/relationship_type.dart';

/// Abstraction for Linked Evidence persistence — independent of UI.
///
/// Extension points reserved for bidirectional sync, witness/location links,
/// AI suggestions, and graph queries.
abstract class RelationshipRepository {
  /// Relationships where [evidenceId] is the source artifact.
  List<EvidenceRelationship> linkedFrom(String evidenceId);

  /// All relationships in the current incident workspace.
  List<EvidenceRelationship> get all;

  /// All committed relationship groups in the current incident workspace.
  List<RelationshipGroup> get groups;

  /// Creates a link between two existing artifacts. Returns null if invalid.
  EvidenceRelationship? linkEvidence({
    required String sourceEvidenceId,
    required String targetEvidenceId,
    required RelationshipType type,
    String? reason,
    String? source,
  });

  /// Commits a [RelationshipGroup] and its derived links in one transaction.
  RelationshipGroup? commitRelationshipGroup({
    required List<String> evidenceIds,
    RelationshipType type = RelationshipType.relatedTo,
  });

  /// Whether a link already exists from source to target.
  bool isLinked({
    required String sourceEvidenceId,
    required String targetEvidenceId,
  });

  /// Moves supporting evidence into [targetGroupId]. Captured evidence cannot move.
  RelationshipGroup? moveSupportingToGroup({
    required String supportingEvidenceId,
    required String targetGroupId,
  });

  /// Removes supporting evidence from [groupId].
  RelationshipGroup? removeSupportingFromGroup({
    required String supportingEvidenceId,
    required String groupId,
  });

  /// Merges [sourceGroupId] into [targetGroupId]. Target colour is preserved.
  RelationshipGroup? mergeGroups({
    required String sourceGroupId,
    required String targetGroupId,
  });

  /// Splits [supportingEvidenceIds] from [groupId] into a new group.
  RelationshipGroup? splitGroup({
    required String groupId,
    required List<String> supportingEvidenceIds,
  });

  /// Deletes a group only when it has no members.
  bool deleteEmptyGroup({required String groupId});

  /// Persists investigator-defined group metadata. Empty input clears fields.
  RelationshipGroup? updateGroupInvestigation({
    required String groupId,
    required String displayName,
    required String description,
  });
}
