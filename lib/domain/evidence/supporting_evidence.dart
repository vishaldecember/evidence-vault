import '../../models/relationship_type.dart';
import '../../models/verification_model.dart';
import '../../services/storage/evidence_upload_models.dart';
import 'evidence_provenance_event.dart';
import 'evidence_sync_status.dart';
import 'evidence_temporal_intent.dart';
import 'supporting_evidence_type.dart';

/// Flexible enrichment artifact — may link to captured or other supporting evidence.
///
/// Supporting items enrich a primary chronology event. Prefer [parentEvidenceId]
/// + [relationshipType] for Evidence Chains, AI reasoning, narrative, and Trust
/// Package assembly. [linkedCapturedEvidenceIds] remains for multi-link parity.
class SupportingEvidence {
  const SupportingEvidence({
    required this.id,
    required this.incidentId,
    required this.type,
    required this.createdAt,
    required this.title,
    required this.integrityVerified,
    required this.verification,
    this.notePreview,
    this.fileName,
    this.filePath,
    this.thumbnailPath,
    this.parentEvidenceId,
    this.relationshipType = RelationshipType.supports,
    this.linkedCapturedEvidenceIds = const {},
    this.linkedSupportingEvidenceIds = const {},
    this.participantId,
    this.storagePath,
    this.downloadUrl,
    this.thumbnailUrl,
    this.mimeType,
    this.fileSizeBytes,
    this.uploadStatus = EvidenceUploadStatus.pending,
    this.deviceModel,
    this.latitude,
    this.longitude,
    this.timelineOrder,
    this.syncStatus = EvidenceSyncStatus.localCaptured,
    this.context,
    this.updatedAt,
    this.collectionId,
    this.captureSessionId,
    this.uploadProgress = 0,
    this.retryCount = 0,
    this.contentHash,
    this.temporalIntent,
    this.metadata = const {},
    this.provenanceEvents = const [],
  });

  final String id;
  final String incidentId;
  final SupportingEvidenceType type;
  final DateTime createdAt;
  final String title;
  final bool integrityVerified;
  final VerificationModel verification;
  final String? notePreview;
  final String? fileName;
  final String? filePath;
  final String? thumbnailPath;

  /// Primary evidence this item supports (Photo / Video / Voice).
  final String? parentEvidenceId;

  /// How this item relates to [parentEvidenceId] — default [RelationshipType.supports].
  final RelationshipType relationshipType;

  final Set<String> linkedCapturedEvidenceIds;
  final Set<String> linkedSupportingEvidenceIds;
  final String? participantId;

  final String? storagePath;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String? mimeType;
  final int? fileSizeBytes;
  final EvidenceUploadStatus uploadStatus;

  final String? deviceModel;
  final double? latitude;
  final double? longitude;
  final int? timelineOrder;

  /// Canonical lifecycle status (Sprint 6A).
  final EvidenceSyncStatus syncStatus;

  /// Free-form context / notes text — falls back to [notePreview] when unset.
  final String? context;

  final DateTime? updatedAt;

  /// Organize-stage [EvidenceCollection] assignment (Sprint 5B).
  final String? collectionId;

  /// Optional [CaptureSession] this item belongs to (Sprint 6C).
  /// Null for legacy evidence captured before sessions existed.
  final String? captureSessionId;

  final double uploadProgress;
  final int retryCount;

  /// SHA-256 of the preserved original payload. Immutable once recorded.
  final String? contentHash;

  /// User-declared timeline participation. Null = undeclared / legacy.
  final EvidenceTemporalIntent? temporalIntent;

  final Map<String, String> metadata;

  /// Append-only capture/preserve/action history for this evidence.
  final List<EvidenceProvenanceEvent> provenanceEvents;

  String? get localPath => filePath;
  String? get cloudPath => storagePath;
  String get evidenceId => id;

  /// Resolved context text for display / persistence — prefers [context].
  String? get resolvedContext => context ?? notePreview;

  /// True when linked to at least one primary / captured parent.
  bool get isContextual =>
      parentEvidenceId != null || linkedCapturedEvidenceIds.isNotEmpty;

  /// Resolved parent for chain traversal — explicit field wins, else first link.
  String? get resolvedParentEvidenceId =>
      parentEvidenceId ??
      (linkedCapturedEvidenceIds.isEmpty
          ? null
          : linkedCapturedEvidenceIds.first);

  SupportingEvidence copyWith({
    VerificationModel? verification,
    String? notePreview,
    String? parentEvidenceId,
    bool clearParentEvidenceId = false,
    RelationshipType? relationshipType,
    Set<String>? linkedCapturedEvidenceIds,
    Set<String>? linkedSupportingEvidenceIds,
    String? participantId,
    bool clearParticipantId = false,
    String? fileName,
    String? filePath,
    String? thumbnailPath,
    String? storagePath,
    String? downloadUrl,
    String? thumbnailUrl,
    String? mimeType,
    int? fileSizeBytes,
    EvidenceUploadStatus? uploadStatus,
    String? deviceModel,
    double? latitude,
    double? longitude,
    int? timelineOrder,
    EvidenceSyncStatus? syncStatus,
    String? context,
    DateTime? updatedAt,
    String? collectionId,
    bool clearCollectionId = false,
    String? captureSessionId,
    bool clearCaptureSessionId = false,
    double? uploadProgress,
    int? retryCount,
    String? contentHash,
    EvidenceTemporalIntent? temporalIntent,
    Map<String, String>? metadata,
    List<EvidenceProvenanceEvent>? provenanceEvents,
  }) {
    final nextParent = clearParentEvidenceId
        ? null
        : (parentEvidenceId ?? this.parentEvidenceId);
    final nextLinkedCaptured =
        linkedCapturedEvidenceIds ?? this.linkedCapturedEvidenceIds;

    return SupportingEvidence(
      id: id,
      incidentId: incidentId,
      type: type,
      createdAt: createdAt,
      title: title,
      integrityVerified: integrityVerified,
      verification: verification ?? this.verification,
      notePreview: notePreview ?? this.notePreview,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      parentEvidenceId: nextParent,
      relationshipType: relationshipType ?? this.relationshipType,
      linkedCapturedEvidenceIds: nextLinkedCaptured,
      linkedSupportingEvidenceIds:
          linkedSupportingEvidenceIds ?? this.linkedSupportingEvidenceIds,
      participantId:
          clearParticipantId ? null : (participantId ?? this.participantId),
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      deviceModel: deviceModel ?? this.deviceModel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timelineOrder: timelineOrder ?? this.timelineOrder,
      syncStatus: syncStatus ?? this.syncStatus,
      context: context ?? this.context,
      updatedAt: updatedAt ?? this.updatedAt,
      collectionId:
          clearCollectionId ? null : (collectionId ?? this.collectionId),
      captureSessionId: clearCaptureSessionId
          ? null
          : (captureSessionId ?? this.captureSessionId),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      retryCount: retryCount ?? this.retryCount,
      contentHash: contentHash ?? this.contentHash,
      temporalIntent: temporalIntent ?? this.temporalIntent,
      metadata: metadata ?? this.metadata,
      provenanceEvents: provenanceEvents ?? this.provenanceEvents,
    );
  }
}
