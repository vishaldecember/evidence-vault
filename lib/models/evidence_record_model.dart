import '../engines/evidence_semantics.dart';
import '../services/relationship_group_color_service.dart';
import '../utils/evidence_formatters.dart';
import 'context_item.dart';
import 'evidence_artifact_model.dart';
import 'evidence_relationship.dart';
import 'linked_evidence_item.dart';
import 'relationship_group.dart';
import 'verification_factory.dart';
import 'verification_model.dart';
import 'workspace_evidence_item.dart';

/// Optional capture metadata shown when available.
class EvidenceRecordMetadata {
  const EvidenceRecordMetadata({
    this.device,
    this.location,
    this.latitude,
    this.longitude,
    this.fileSize,
    this.duration,
    this.resolution,
    this.source = 'Captured on this device',
  });

  final String? device;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? fileSize;
  final String? duration;
  final String? resolution;
  final String source;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Honest presentation metadata from persisted item fields only.
  ///
  /// Missing size / duration / device / location stay null — never fabricated.
  static EvidenceRecordMetadata forItem(WorkspaceEvidenceItem item) {
    final bytes = item.fileSizeBytes;
    final fileSize =
        (bytes != null && bytes > 0) ? EvidenceFormatters.fileSize(bytes) : null;
    final device = item.deviceModel?.trim();
    final hasCoordinates = item.latitude != null && item.longitude != null;

    return EvidenceRecordMetadata(
      device: (device != null && device.isNotEmpty) ? device : null,
      location: hasCoordinates
          ? EvidenceFormatters.coordinates(item.latitude, item.longitude)
          : null,
      latitude: item.latitude,
      longitude: item.longitude,
      fileSize: fileSize,
      duration: null,
      resolution: null,
      source: item.kind == WorkspaceEvidenceKind.attachment
          ? 'Attached file'
          : 'Captured on this device',
    );
  }
}

/// Presentation model for [EvidenceRecordScreen].
class EvidenceRecordModel {
  const EvidenceRecordModel({
    required this.evidence,
    required this.contextItems,
    required this.linkedEvidence,
    required this.metadata,
    required this.verification,
  });

  final WorkspaceEvidenceItem evidence;
  final List<ContextItem> contextItems;
  final List<LinkedEvidenceItem> linkedEvidence;
  final EvidenceRecordMetadata metadata;
  final VerificationModel verification;

  EvidenceArtifactType get type =>
      EvidenceArtifactType.fromWorkspaceKind(evidence.kind);

  bool get hasContext => contextItems.isNotEmpty;

  bool get hasLinkedEvidence => linkedEvidence.isNotEmpty;

  factory EvidenceRecordModel.fromWorkspace({
    required WorkspaceEvidenceItem evidence,
    required List<WorkspaceEvidenceItem> allItems,
    required List<EvidenceRelationship> relationships,
    List<RelationshipGroup> relationshipGroups = const [],
  }) {
    final itemById = {for (final item in allItems) item.id: item};

    final contextItems = allItems
        .where(
          (item) =>
              item.isContextual &&
              item.relatedEvidenceIds.contains(evidence.id),
        )
        .map(ContextItem.fromWorkspaceItem)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    final linkedEvidence = relationships
        .where(
          (relationship) =>
              relationship.sourceEvidenceId == evidence.id &&
              !EvidenceSemantics.isSuggestedRelated(relationship),
        )
        .map((relationship) {
          final target = itemById[relationship.targetEvidenceId];
          if (target == null) {
            return null;
          }
          return LinkedEvidenceItem.fromRelationship(
            relationship: relationship,
            targetItem: target,
            relationshipGroupColorIndex:
                RelationshipGroupColorService.groupForEvidence(
              target.id,
              relationshipGroups,
            )?.colorIndex,
          );
        })
        .whereType<LinkedEvidenceItem>()
        .toList()
      ..sort((a, b) => b.preservedAt.compareTo(a.preservedAt));

    return EvidenceRecordModel(
      evidence: evidence,
      contextItems: contextItems,
      linkedEvidence: linkedEvidence,
      metadata: EvidenceRecordMetadata.forItem(evidence),
      verification: VerificationFactory.forWorkspaceItem(evidence),
    );
  }
}
