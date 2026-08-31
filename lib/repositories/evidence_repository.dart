import '../domain/evidence/captured_evidence.dart';
import '../domain/evidence/evidence_provenance_event.dart';
import '../domain/evidence/evidence_record.dart';
import '../domain/evidence/evidence_sync_status.dart';
import '../domain/evidence/evidence_temporal_intent.dart';
import '../domain/evidence/supporting_evidence.dart';
import '../domain/participant/related_person_link.dart';
import '../models/workspace_capture_mode.dart';
import '../services/storage/cached_evidence_entry.dart';

/// Owns canonical evidence persistence within an incident.
///
/// Sprint 6A: lifecycle status is domain-owned. UI reads [EvidenceRecord] /
/// [EvidenceSyncStatus] through this repository — never invents Firebase state.
abstract class EvidenceRepository {
  List<CapturedEvidence> get capturedEvidence;

  List<SupportingEvidence> get supportingEvidence;

  /// Unified lifecycle view of all evidence in the active incident.
  List<EvidenceRecord> get evidenceRecords;

  EvidenceRecord? recordById(String evidenceId);

  CapturedEvidence addCapturedFromCaptureMode(
    WorkspaceCaptureMode mode, {
    String? participantId,
    String? captureSessionId,
  });

  SupportingEvidence addSupportingFromCaptureMode(
    WorkspaceCaptureMode mode, {
    required String parentCapturedEvidenceId,
    String? participantId,
    String? captureSessionId,
  });

  SupportingEvidence addSupportingTextNote({
    required String parentCapturedEvidenceId,
    required String text,
    String? participantId,
    String? captureSessionId,
  });

  SupportingEvidence? updateSupportingNoteText({
    required String evidenceId,
    required String text,
  });

  /// Sets [EvidenceTemporalIntent] only. Does not mutate timestamps, hashes,
  /// chronology, relationships, collections, or placement.
  bool updateTemporalIntent({
    required String evidenceId,
    required EvidenceTemporalIntent intent,
  });

  /// Stamps capture-time device and location onto existing evidence.
  ///
  /// Does not change ids, hashes, timestamps, chronology, or upload state.
  void applyCaptureProvenance({
    required String evidenceId,
    String? deviceModel,
    double? latitude,
    double? longitude,
  });

  /// Records SHA-256 once. Never overwrites an existing fingerprint.
  bool recordContentHash({
    required String evidenceId,
    required String hash,
  });

  /// Appends a provenance event. Does not rewrite earlier events.
  bool appendProvenanceEvent(EvidenceProvenanceEvent event);

  List<EvidenceProvenanceEvent> provenanceEventsFor(String evidenceId);

  /// Attaches a local media file to newly captured evidence (pre-upload).
  void attachLocalMedia({
    required String evidenceId,
    required String filePath,
    String? fileName,
    String? thumbnailPath,
    int? fileSizeBytes,
  });

  /// Applies Firebase Storage upload result onto local evidence metadata.
  void applyStorageUpload({
    required String evidenceId,
    required String storagePath,
    required String downloadUrl,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    String? thumbnailStoragePath,
    String? deviceModel,
    double? latitude,
    double? longitude,
  });

  /// Marks evidence upload as failed while retaining the local file.
  void markUploadFailed({required String evidenceId});

  /// Transitions lifecycle status (validated). Returns false if rejected.
  bool updateLifecycleStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  });

  /// Removes evidence from the local working set (Firestore/Storage cascade
  /// is orchestrated by [IncidentCloudSyncService.deleteEvidenceCascade]).
  void removeEvidence({required String evidenceId});

  /// Merges a durable [LocalEvidenceCache] row into the working set.
  ///
  /// Returns `true` when a new local row was inserted (offline resume).
  /// No-ops when [CachedEvidenceEntry.evidenceId] already exists.
  bool upsertFromLocalCache(CachedEvidenceEntry entry);

  CapturedEvidence? assignParticipantToCaptured({
    required String evidenceId,
    String? participantId,
    String? relatedPersonName,
    String? relatedPersonRole,
  });

  SupportingEvidence? assignParticipantToSupporting({
    required String evidenceId,
    String? participantId,
    String? relatedPersonName,
    String? relatedPersonRole,
  });

  CapturedEvidence? addParticipantToCaptured({
    required String evidenceId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  });

  SupportingEvidence? addParticipantToSupporting({
    required String evidenceId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  });

  CapturedEvidence? replaceParticipantOnCaptured({
    required String evidenceId,
    required String previousParticipantId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  });

  SupportingEvidence? replaceParticipantOnSupporting({
    required String evidenceId,
    required String previousParticipantId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  });

  CapturedEvidence? removeParticipantFromCaptured({
    required String evidenceId,
    required String participantId,
  });

  SupportingEvidence? removeParticipantFromSupporting({
    required String evidenceId,
    required String participantId,
  });

  CapturedEvidence? writeRelatedPeopleOnCaptured({
    required String evidenceId,
    required List<RelatedPersonLink> people,
  });

  SupportingEvidence? writeRelatedPeopleOnSupporting({
    required String evidenceId,
    required List<RelatedPersonLink> people,
  });

  CapturedEvidence? capturedById(String id);

  SupportingEvidence? supportingById(String id);

  bool containsEvidenceId(String id);
}
