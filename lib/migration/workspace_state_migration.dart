import '../domain/evidence/captured_evidence.dart';
import '../domain/evidence/supporting_evidence.dart';
import '../domain/incident/incident.dart';
import '../domain/incident/incident_status.dart';
import '../domain/participant/related_person_metadata.dart';
import '../domain/reconstruction/reconstruction_note.dart';
import '../domain/relationship/relationship_group.dart';
import '../domain/timeline/timeline_anchor.dart';
import '../mappers/evidence_projection.dart';
import '../models/evidence_relationship.dart';
import '../models/relationship_type.dart';
import '../repositories/incident_store.dart';

/// Migrates legacy [WorkspaceEvidenceState] into the Sprint 9 [IncidentStore].
abstract final class WorkspaceStateMigration {
  static IncidentStore migrate(WorkspaceEvidenceState legacy) {
    final now = DateTime.now();
    final incident = Incident(
      id: 'incident-1',
      title: legacy.incidentName,
      status: IncidentStatus.draft,
      createdAt: now,
      updatedAt: now,
      manuallyComplete: legacy.incidentManuallyComplete,
    );

    final captured = <CapturedEvidence>[];
    final supporting = <SupportingEvidence>[];
    final anchors = <TimelineAnchor>[];

    final journeyCandidates = legacy.items.where((item) => !item.isContextual).toList()
      ..sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));

    var anchorSequence = 0;
    for (final item in legacy.items) {
      final capturedType = EvidenceProjection.capturedTypeForKind(item.kind);
      if (capturedType != null && !item.isContextual) {
        final anchorId = 'migrated-anchor-${item.id}';
        anchors.add(
          TimelineAnchor(
            id: anchorId,
            incidentId: incident.id,
            capturedEvidenceId: item.id,
            anchoredAt: item.lastPreservedAt,
            sequenceOrder: anchorSequence++,
          ),
        );
        captured.add(
          CapturedEvidence(
            id: item.id,
            incidentId: incident.id,
            type: capturedType,
            capturedAt: item.capturedAt ?? item.lastPreservedAt,
            createdAt: item.recordedAt,
            title: item.title,
            integrityVerified: item.integrityVerified,
            verification: item.verification,
            timelineAnchorId: anchorId,
            notePreview: item.notePreview,
            fileName: item.fileName,
            filePath: item.filePath,
            thumbnailPath: item.thumbnailPath,
            participantId: item.participantId,
            contentHash: item.contentHash,
            provenanceEvents: item.provenanceEvents,
            deviceModel: item.deviceModel,
            fileSizeBytes: item.fileSizeBytes,
            mimeType: item.mimeType,
            latitude: item.latitude,
            longitude: item.longitude,
            metadata: RelatedPersonMetadata.merge(
              current: const {},
              participantId: item.participantId,
              displayName: item.relatedPersonName,
              roleName: item.relatedPersonRole,
            ),
          ),
        );
        continue;
      }

      final linkedCaptured = item.relatedEvidenceIds
          .where((id) => captured.any((c) => c.id == id))
          .toSet();
      final parentId = item.parentEvidenceId ??
          (linkedCaptured.isEmpty ? null : linkedCaptured.first);
      supporting.add(
        SupportingEvidence(
          id: item.id,
          incidentId: incident.id,
          type: EvidenceProjection.supportingTypeForKind(item.kind),
          createdAt: item.recordedAt ?? item.lastPreservedAt,
          title: item.title,
          integrityVerified: item.integrityVerified,
          verification: item.verification,
          notePreview: item.notePreview,
          fileName: item.fileName,
          filePath: item.filePath,
          thumbnailPath: item.thumbnailPath,
          contentHash: item.contentHash,
          provenanceEvents: item.provenanceEvents,
          deviceModel: item.deviceModel,
          fileSizeBytes: item.fileSizeBytes,
          mimeType: item.mimeType,
          latitude: item.latitude,
          longitude: item.longitude,
          parentEvidenceId: parentId,
          relationshipType:
              item.relationshipType ?? RelationshipType.supports,
          linkedCapturedEvidenceIds: linkedCaptured,
          linkedSupportingEvidenceIds: item.relatedEvidenceIds
              .where((id) => supporting.any((s) => s.id == id))
              .toSet(),
          participantId: item.participantId,
          updatedAt: item.updatedAt,
          metadata: RelatedPersonMetadata.merge(
            current: const {},
            participantId: item.participantId,
            displayName: item.relatedPersonName,
            roleName: item.relatedPersonRole,
          ),
        ),
      );
    }

    // Preserve journey ordering for anchors when legacy had primary chronology
    // items that somehow skipped the first pass. Never coerce notes/files into
    // captured photos — they remain supporting evidence.
    if (anchors.isEmpty && journeyCandidates.isNotEmpty) {
      for (final item in journeyCandidates) {
        final capturedType = EvidenceProjection.capturedTypeForKind(item.kind);
        if (capturedType == null || captured.any((c) => c.id == item.id)) {
          continue;
        }
        final anchorId = 'migrated-anchor-${item.id}';
        anchors.add(
          TimelineAnchor(
            id: anchorId,
            incidentId: incident.id,
            capturedEvidenceId: item.id,
            anchoredAt: item.lastPreservedAt,
            sequenceOrder: anchorSequence++,
          ),
        );
        captured.add(
          CapturedEvidence(
            id: item.id,
            incidentId: incident.id,
            type: capturedType,
            capturedAt: item.capturedAt ?? item.lastPreservedAt,
            createdAt: item.recordedAt,
            title: item.title,
            integrityVerified: item.integrityVerified,
            verification: item.verification,
            timelineAnchorId: anchorId,
            notePreview: item.notePreview,
            fileName: item.fileName,
            filePath: item.filePath,
            thumbnailPath: item.thumbnailPath,
            participantId: item.participantId,
            contentHash: item.contentHash,
            provenanceEvents: item.provenanceEvents,
            deviceModel: item.deviceModel,
            fileSizeBytes: item.fileSizeBytes,
            mimeType: item.mimeType,
            latitude: item.latitude,
            longitude: item.longitude,
            metadata: RelatedPersonMetadata.merge(
              current: const {},
              participantId: item.participantId,
              displayName: item.relatedPersonName,
              roleName: item.relatedPersonRole,
            ),
          ),
        );
      }
    }

    final notes = legacy.reflections
        .map(
          (reflection) => ReconstructionNote(
            id: reflection.id,
            incidentId: incident.id,
            title: reflection.title,
            body: reflection.body,
            createdAt: reflection.createdAt,
            updatedAt: reflection.updatedAt,
          ),
        )
        .toList();

    final groups = legacy.relationshipGroups
        .map(
          (group) => RelationshipGroup(
            id: group.id,
            incidentId: incident.id,
            memberEvidenceIds: group.memberEvidenceIds,
            type: group.type,
            createdAt: group.createdAt,
            colorIndex: group.colorIndex,
          ),
        )
        .toList();

    return IncidentStore(
      incident: incident,
      capturedEvidence: captured,
      supportingEvidence: supporting,
      timelineAnchors: anchors,
      relationshipGroups: groups,
      relationships: List<EvidenceRelationship>.from(legacy.relationships),
      reconstructionNotes: notes,
    );
  }
}
