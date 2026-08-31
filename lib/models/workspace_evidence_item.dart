import '../models/relationship_type.dart';
import '../models/workspace_capture_mode.dart';
import '../services/storage/evidence_upload_models.dart';
import '../domain/evidence/evidence_provenance_event.dart';
import '../domain/evidence/evidence_temporal_intent.dart';
import '../domain/participant/related_person_link.dart';
import 'evidence_maturity.dart';
import 'verification_model.dart';

/// Presentation-layer evidence kinds for the workspace Evidence Map.
enum WorkspaceEvidenceKind {
  image,
  video,
  voice,
  note,
  attachment,
  witness;

  String get label => switch (this) {
        WorkspaceEvidenceKind.image => 'Photo',
        WorkspaceEvidenceKind.video => 'Video',
        WorkspaceEvidenceKind.voice => 'Voice Note',
        WorkspaceEvidenceKind.note => 'Note',
        WorkspaceEvidenceKind.attachment => 'Attachment',
        WorkspaceEvidenceKind.witness => 'Witness',
      };

  /// Primary chronology kinds — Photo, Video, Voice.
  bool get isPrimaryChronology => switch (this) {
        WorkspaceEvidenceKind.image ||
        WorkspaceEvidenceKind.video ||
        WorkspaceEvidenceKind.voice =>
          true,
        WorkspaceEvidenceKind.note ||
        WorkspaceEvidenceKind.attachment ||
        WorkspaceEvidenceKind.witness =>
          false,
      };

  static WorkspaceEvidenceKind fromCaptureMode(WorkspaceCaptureMode mode) =>
      switch (mode) {
        WorkspaceCaptureMode.photo => WorkspaceEvidenceKind.image,
        WorkspaceCaptureMode.video => WorkspaceEvidenceKind.video,
        WorkspaceCaptureMode.voice => WorkspaceEvidenceKind.voice,
        WorkspaceCaptureMode.note => WorkspaceEvidenceKind.note,
        WorkspaceCaptureMode.file => WorkspaceEvidenceKind.attachment,
      };
}

/// Immutable workspace evidence item for the Evidence Map presentation layer.
///
/// Supporting items carry [parentEvidenceId] + [relationshipType] for Evidence
/// Chains. Does not modify storage models.
class WorkspaceEvidenceItem {
  WorkspaceEvidenceItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.lastPreservedAt,
    required this.integrityVerified,
    required this.verification,
    EvidenceMaturity? maturity,
    this.notePreview,
    this.fileName,
    this.filePath,
    this.thumbnailPath,
    this.parentEvidenceId,
    this.relationshipType,
    this.relatedEvidenceIds = const {},
    this.isContextual = false,
    this.participantId,
    this.relatedPersonName,
    this.relatedPersonRole,
    this.relatedPeople = const [],
    this.updatedAt,
    this.storagePath,
    this.downloadUrl,
    this.mimeType,
    this.fileSizeBytes,
    this.uploadStatus = EvidenceUploadStatus.pending,
    this.collectionId,
    this.incidentId = '',
    this.deviceModel,
    this.latitude,
    this.longitude,
    this.capturedAt,
    this.recordedAt,
    this.contentHash,
    this.temporalIntent,
    this.provenanceEvents = const [],
  }) : maturity = maturity ??
            EvidenceMaturity.forJourneyItem(
              isPrimaryChronology: kind.isPrimaryChronology,
              isStandaloneCaptureBarEvidence:
                  !kind.isPrimaryChronology &&
                  (kind == WorkspaceEvidenceKind.note ||
                      kind == WorkspaceEvidenceKind.attachment) &&
                  (parentEvidenceId == null || parentEvidenceId.isEmpty),
            );

  final String id;
  final WorkspaceEvidenceKind kind;
  final String title;

  /// Journey / carousel presentation clock. Not a third chronology.
  ///
  /// Captured items: domain `capturedAt`. Supporting items: domain `createdAt`.
  /// Do not treat the field name as "when Vault preserved this."
  final DateTime lastPreservedAt;

  /// Domain [CapturedEvidence.capturedAt] when projected. Null on legacy DTOs.
  final DateTime? capturedAt;

  /// Domain `createdAt` when projected. Null on legacy DTOs.
  /// Distinct from [capturedAt] only when Vault recorded the row later.
  final DateTime? recordedAt;

  /// Domain `contentHash` when projected. Null when no canonical hash exists.
  /// Presentation only — never recalculated here.
  final String? contentHash;

  /// Domain [EvidenceTemporalIntent] when projected. Null = undeclared.
  final EvidenceTemporalIntent? temporalIntent;

  /// Projected append-only provenance. Empty for legacy presentation items.
  final List<EvidenceProvenanceEvent> provenanceEvents;
  final bool integrityVerified;
  final VerificationModel verification;

  /// Lane membership for the Evidence Maturity Engine.
  final EvidenceMaturity maturity;

  final String? notePreview;
  final String? fileName;
  final String? filePath;
  final String? thumbnailPath;

  /// Primary evidence this supporting item enriches, if any.
  final String? parentEvidenceId;

  /// Relationship to [parentEvidenceId] — typically [RelationshipType.supports].
  final RelationshipType? relationshipType;

  final Set<String> relatedEvidenceIds;
  final bool isContextual;
  final String? participantId;

  /// Denormalized related-person display — evidence-specific, not session-global.
  final String? relatedPersonName;

  /// [EvidencePersonRelationship] / [ParticipantRole] name on this evidence.
  final String? relatedPersonRole;

  /// All people linked to this item. First entry matches [relatedPersonName].
  final List<RelatedPersonLink> relatedPeople;

  /// Supporting-note last edit. Independent of [lastPreservedAt] capture time.
  final DateTime? updatedAt;

  final String? storagePath;
  final String? downloadUrl;
  final String? mimeType;
  final int? fileSizeBytes;
  final EvidenceUploadStatus uploadStatus;

  /// Organize-stage collection assignment (Sprint 5B).
  final String? collectionId;

  /// Owning incident — Inspector/carousel must not mix items across incidents.
  final String incidentId;

  /// Recorded capture device, when present on the domain evidence.
  final String? deviceModel;

  /// Recorded capture latitude, when present on the domain evidence.
  final double? latitude;

  /// Recorded capture longitude, when present on the domain evidence.
  final double? longitude;

  /// Orange-connector chronology kinds (Photo / Video / Voice).
  ///
  /// Product primary is the chronology *role* (`EvidenceSemantics`, excluding
  /// contextual items). This getter is kind-only for Timeline chrome.
  bool get isPrimaryChronologyEvidence => kind.isPrimaryChronology;

  /// Legacy **kind** getter: note / file / witness (not Photo/Video/Voice).
  ///
  /// This is NOT structural supporting. Coaching, risk, narrative, and
  /// enrichment must use EvidenceSemantics.structurallySupports /
  /// hasStructuralSupport. Optional rename `isSupportingKind` is documented
  /// but not performed (Timeline/UI still bind this).
  bool get isSupportingEvidence => !isPrimaryChronologyEvidence;

  /// True when this item is owned by [incidentId].
  ///
  /// Fail closed: a blank item [incidentId] is not owned by any incident.
  /// Stamp legacy rows at [EvidenceProjection], do not infer ownership here.
  bool belongsToIncident(String incidentId) {
    if (incidentId.isEmpty || this.incidentId.isEmpty) {
      return false;
    }
    return this.incidentId == incidentId;
  }

  WorkspaceEvidenceItem copyWith({
    Set<String>? relatedEvidenceIds,
    String? parentEvidenceId,
    bool clearParentEvidenceId = false,
    RelationshipType? relationshipType,
    VerificationModel? verification,
    EvidenceMaturity? maturity,
    String? participantId,
    bool clearParticipantId = false,
    String? relatedPersonName,
    String? relatedPersonRole,
    List<RelatedPersonLink>? relatedPeople,
    DateTime? updatedAt,
    String? fileName,
    String? filePath,
    String? thumbnailPath,
    String? storagePath,
    String? downloadUrl,
    String? mimeType,
    int? fileSizeBytes,
    EvidenceUploadStatus? uploadStatus,
    String? collectionId,
    bool clearCollectionId = false,
    String? deviceModel,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
    DateTime? recordedAt,
    String? contentHash,
    EvidenceTemporalIntent? temporalIntent,
    List<EvidenceProvenanceEvent>? provenanceEvents,
  }) {
    return WorkspaceEvidenceItem(
      id: id,
      kind: kind,
      title: title,
      lastPreservedAt: lastPreservedAt,
      capturedAt: capturedAt ?? this.capturedAt,
      recordedAt: recordedAt ?? this.recordedAt,
      contentHash: contentHash ?? this.contentHash,
      temporalIntent: temporalIntent ?? this.temporalIntent,
      provenanceEvents: provenanceEvents ?? this.provenanceEvents,
      integrityVerified: integrityVerified,
      verification: verification ?? this.verification,
      maturity: maturity ?? this.maturity,
      notePreview: notePreview,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      parentEvidenceId: clearParentEvidenceId
          ? null
          : (parentEvidenceId ?? this.parentEvidenceId),
      relationshipType: relationshipType ?? this.relationshipType,
      relatedEvidenceIds: relatedEvidenceIds ?? this.relatedEvidenceIds,
      isContextual: isContextual,
      participantId:
          clearParticipantId ? null : (participantId ?? this.participantId),
      relatedPersonName: relatedPersonName ?? this.relatedPersonName,
      relatedPersonRole: relatedPersonRole ?? this.relatedPersonRole,
      relatedPeople: relatedPeople ?? this.relatedPeople,
      updatedAt: updatedAt ?? this.updatedAt,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      collectionId:
          clearCollectionId ? null : (collectionId ?? this.collectionId),
      incidentId: incidentId,
      deviceModel: deviceModel ?? this.deviceModel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
