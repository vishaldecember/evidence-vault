import 'evidence_artifact_model.dart';
import 'evidence_relationship.dart';
import 'relationship_type.dart';
import 'workspace_evidence_item.dart';

/// Presentation model for one linked artifact on an Evidence Record.
class LinkedEvidenceItem {
  const LinkedEvidenceItem({
    required this.relationshipId,
    required this.evidenceId,
    required this.type,
    required this.artifactType,
    required this.preservedAt,
    this.title,
    this.relationshipGroupColorIndex,
  });

  final String relationshipId;
  final String evidenceId;
  final RelationshipType type;
  final EvidenceArtifactType artifactType;
  final DateTime preservedAt;
  final String? title;
  final int? relationshipGroupColorIndex;

  factory LinkedEvidenceItem.fromRelationship({
    required EvidenceRelationship relationship,
    required WorkspaceEvidenceItem targetItem,
    int? relationshipGroupColorIndex,
  }) {
    return LinkedEvidenceItem(
      relationshipId: relationship.id,
      evidenceId: targetItem.id,
      type: relationship.type,
      artifactType: EvidenceArtifactType.fromWorkspaceKind(targetItem.kind),
      preservedAt: targetItem.lastPreservedAt,
      title: targetItem.title,
      relationshipGroupColorIndex: relationshipGroupColorIndex,
    );
  }
}
