import '../domain/evidence/captured_evidence.dart';
import '../domain/evidence/captured_evidence_type.dart';
import '../domain/evidence/supporting_evidence.dart';
import '../domain/evidence/supporting_evidence_type.dart';
import '../domain/participant/related_person_metadata.dart';
import '../models/evidence_relationship.dart';
import '../models/reflection_model.dart';
import '../models/workspace_capture_mode.dart';
import '../models/workspace_evidence_item.dart';
import '../repositories/incident_store.dart';

/// Projects canonical domain models to legacy presentation DTOs.
abstract final class EvidenceProjection {
  static List<WorkspaceEvidenceItem> toWorkspaceItems(IncidentStore store) {
    final ownerId = store.incident.id.trim();
    final items = <WorkspaceEvidenceItem>[
      ...store.capturedEvidence.map(
        (item) => _capturedToWorkspace(item, ownerId),
      ),
      ...store.supportingEvidence.map(
        (item) => _supportingToWorkspace(item, ownerId),
      ),
    ];
    // Guard against accidental id collisions across captured/supporting lists.
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.id)) item,
    ];
  }

  static WorkspaceEvidenceState toWorkspaceState(IncidentStore store) {
    return WorkspaceEvidenceState(
      items: toWorkspaceItems(store),
      relationships: List<EvidenceRelationship>.from(store.relationships),
      relationshipGroups: List.from(store.relationshipGroups),
      reflections: store.reconstructionNotes
          .map(
            (note) => ReflectionModel(
              id: note.id,
              title: note.title,
              body: note.body,
              createdAt: note.createdAt,
              updatedAt: note.updatedAt,
            ),
          )
          .toList(),
      incidentName: store.incident.title,
      incidentManuallyComplete: store.incident.manuallyComplete,
    );
  }

  /// Stamp a blank domain incidentId from the store at this projection only.
  static String _ownedIncidentId(String itemIncidentId, String storeIncidentId) {
    final itemId = itemIncidentId.trim();
    if (itemId.isNotEmpty) {
      return itemId;
    }
    return storeIncidentId.trim();
  }

  static WorkspaceEvidenceItem _capturedToWorkspace(
    CapturedEvidence item,
    String storeIncidentId,
  ) {
    return WorkspaceEvidenceItem(
      id: item.id,
      kind: _kindForCaptured(item.type),
      title: item.title,
      lastPreservedAt: item.capturedAt,
      capturedAt: item.capturedAt,
      recordedAt: item.createdAt,
      contentHash: item.contentHash,
      temporalIntent: item.temporalIntent,
      provenanceEvents: item.provenanceEvents,
      integrityVerified: item.integrityVerified,
      verification: item.verification,
      notePreview: item.notePreview,
      fileName: item.fileName,
      filePath: item.filePath,
      thumbnailPath: item.thumbnailPath ?? item.thumbnailUrl,
      participantId: item.participantId,
      relatedPersonName: RelatedPersonMetadata.nameOf(item.metadata),
      relatedPersonRole: RelatedPersonMetadata.roleOf(item.metadata),
      relatedPeople: RelatedPersonMetadata.peopleOf(item.metadata),
      updatedAt: item.updatedAt,
      storagePath: item.storagePath,
      downloadUrl: item.downloadUrl,
      mimeType: item.mimeType,
      fileSizeBytes: item.fileSizeBytes,
      uploadStatus: item.uploadStatus,
      collectionId: item.collectionId,
      incidentId: _ownedIncidentId(item.incidentId, storeIncidentId),
      deviceModel: item.deviceModel,
      latitude: item.latitude,
      longitude: item.longitude,
    );
  }

  static WorkspaceEvidenceItem _supportingToWorkspace(
    SupportingEvidence item,
    String storeIncidentId,
  ) {
    final parentId = item.resolvedParentEvidenceId;
    return WorkspaceEvidenceItem(
      id: item.id,
      kind: _kindForSupporting(item.type),
      title: item.title,
      lastPreservedAt: item.createdAt,
      recordedAt: item.createdAt,
      contentHash: item.contentHash,
      temporalIntent: item.temporalIntent,
      provenanceEvents: item.provenanceEvents,
      integrityVerified: item.integrityVerified,
      verification: item.verification,
      notePreview: item.notePreview,
      fileName: item.fileName,
      filePath: item.filePath,
      thumbnailPath: item.thumbnailPath ?? item.thumbnailUrl,
      parentEvidenceId: parentId,
      relationshipType: parentId == null ? null : item.relationshipType,
      isContextual: item.isContextual,
      relatedEvidenceIds: {
        ?parentId,
        ...item.linkedCapturedEvidenceIds,
        ...item.linkedSupportingEvidenceIds,
      },
      participantId: item.participantId,
      relatedPersonName: RelatedPersonMetadata.nameOf(item.metadata),
      relatedPersonRole: RelatedPersonMetadata.roleOf(item.metadata),
      relatedPeople: RelatedPersonMetadata.peopleOf(item.metadata),
      updatedAt: item.updatedAt,
      storagePath: item.storagePath,
      downloadUrl: item.downloadUrl,
      mimeType: item.mimeType,
      fileSizeBytes: item.fileSizeBytes,
      uploadStatus: item.uploadStatus,
      collectionId: item.collectionId,
      incidentId: _ownedIncidentId(item.incidentId, storeIncidentId),
      deviceModel: item.deviceModel,
      latitude: item.latitude,
      longitude: item.longitude,
    );
  }

  static WorkspaceEvidenceKind _kindForCaptured(CapturedEvidenceType type) =>
      switch (type) {
        CapturedEvidenceType.photo => WorkspaceEvidenceKind.image,
        CapturedEvidenceType.video => WorkspaceEvidenceKind.video,
        CapturedEvidenceType.voice => WorkspaceEvidenceKind.voice,
      };

  static WorkspaceEvidenceKind _kindForSupporting(
    SupportingEvidenceType type,
  ) =>
      switch (type) {
        SupportingEvidenceType.note => WorkspaceEvidenceKind.note,
        SupportingEvidenceType.pdf ||
        SupportingEvidenceType.document ||
        SupportingEvidenceType.attachment =>
          WorkspaceEvidenceKind.attachment,
        SupportingEvidenceType.witnessStatement => WorkspaceEvidenceKind.witness,
      };

  static CapturedEvidenceType? capturedTypeForKind(WorkspaceEvidenceKind kind) =>
      switch (kind) {
        WorkspaceEvidenceKind.image => CapturedEvidenceType.photo,
        WorkspaceEvidenceKind.video => CapturedEvidenceType.video,
        WorkspaceEvidenceKind.voice => CapturedEvidenceType.voice,
        _ => null,
      };

  static SupportingEvidenceType supportingTypeForKind(
    WorkspaceEvidenceKind kind,
  ) =>
      switch (kind) {
        WorkspaceEvidenceKind.note => SupportingEvidenceType.note,
        WorkspaceEvidenceKind.attachment => SupportingEvidenceType.attachment,
        WorkspaceEvidenceKind.witness => SupportingEvidenceType.witnessStatement,
        _ => SupportingEvidenceType.document,
      };

  static bool isCapturedCaptureMode(WorkspaceCaptureMode mode) =>
      switch (mode) {
        WorkspaceCaptureMode.photo ||
        WorkspaceCaptureMode.video ||
        WorkspaceCaptureMode.voice =>
          true,
        WorkspaceCaptureMode.note || WorkspaceCaptureMode.file => false,
      };
}
