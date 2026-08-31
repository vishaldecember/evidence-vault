import '../../models/verification_model.dart';
import '../../services/storage/evidence_upload_models.dart';
import 'captured_evidence_type.dart';
import 'evidence_provenance_event.dart';
import 'evidence_sync_status.dart';
import 'evidence_temporal_intent.dart';

/// Immutable core capture — anchors the incident timeline.
class CapturedEvidence {
  const CapturedEvidence({
    required this.id,
    required this.incidentId,
    required this.type,
    required this.capturedAt,
    required this.title,
    required this.integrityVerified,
    required this.verification,
    required this.timelineAnchorId,
    this.notePreview,
    this.fileName,
    this.filePath,
    this.thumbnailPath,
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
    this.createdAt,
    this.updatedAt,
    this.collectionId,
    this.captureSessionId,
    this.isPrimaryEvidence = false,
    this.uploadProgress = 0,
    this.retryCount = 0,
    this.contentHash,
    this.temporalIntent,
    this.metadata = const {},
    this.provenanceEvents = const [],
  });

  final String id;
  final String incidentId;
  final CapturedEvidenceType type;
  final DateTime capturedAt;
  final String title;
  final bool integrityVerified;
  final VerificationModel verification;
  final String timelineAnchorId;
  final String? notePreview;
  final String? fileName;
  final String? filePath;
  final String? thumbnailPath;
  final String? participantId;

  /// Firebase Storage object path (= [cloudPath]).
  final String? storagePath;

  /// Download URL after successful upload.
  final String? downloadUrl;

  /// Thumbnail download URL (compressed preview).
  final String? thumbnailUrl;

  final String? mimeType;
  final int? fileSizeBytes;

  /// Legacy upload enum — keep in sync with [syncStatus] via lifecycle helpers.
  final EvidenceUploadStatus uploadStatus;

  final String? deviceModel;
  final double? latitude;
  final double? longitude;

  /// Stable order within the incident timeline (ascending = earlier).
  final int? timelineOrder;

  /// Canonical lifecycle status (Sprint 6A).
  final EvidenceSyncStatus syncStatus;

  /// Free-form context / notes text — falls back to [notePreview] when unset.
  final String? context;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Organize-stage [EvidenceCollection] assignment (Sprint 5B).
  final String? collectionId;

  /// Optional [CaptureSession] this capture belongs to (Sprint 6C).
  /// Null for legacy evidence captured before sessions existed.
  final String? captureSessionId;

  /// Persisted Sprint 5C designation flag — compatibility only.
  ///
  /// Product primary is the chronology role
  /// (`EvidenceSemantics.isPrimaryChronologyEvidence`), not this flag.
  /// Do not delete or migrate this field in Step 4C. Graph / coaching must
  /// not treat this flag as the user-facing primary definition.
  final bool isPrimaryEvidence;

  /// 0.0 – 1.0 domain-owned upload fraction.
  final double uploadProgress;

  final int retryCount;

  /// SHA-256 of the preserved original payload. Immutable once recorded.
  final String? contentHash;

  /// User-declared timeline participation. Null = undeclared / legacy.
  final EvidenceTemporalIntent? temporalIntent;

  /// Extensible metadata (device, GPS already have first-class fields).
  final Map<String, String> metadata;

  /// Append-only capture/preserve/action history for this evidence.
  final List<EvidenceProvenanceEvent> provenanceEvents;

  /// Sprint 6A alias — local media path.
  String? get localPath => filePath;

  /// Sprint 6A alias — cloud storage path.
  String? get cloudPath => storagePath;

  String get evidenceId => id;

  /// Resolved context text for display / persistence — prefers [context].
  String? get resolvedContext => context ?? notePreview;

  CapturedEvidence copyWith({
    VerificationModel? verification,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    String? collectionId,
    bool clearCollectionId = false,
    String? captureSessionId,
    bool clearCaptureSessionId = false,
    bool? isPrimaryEvidence,
    double? uploadProgress,
    int? retryCount,
    String? contentHash,
    EvidenceTemporalIntent? temporalIntent,
    Map<String, String>? metadata,
    List<EvidenceProvenanceEvent>? provenanceEvents,
  }) {
    return CapturedEvidence(
      id: id,
      incidentId: incidentId,
      type: type,
      capturedAt: capturedAt,
      title: title,
      integrityVerified: integrityVerified,
      verification: verification ?? this.verification,
      timelineAnchorId: timelineAnchorId,
      notePreview: notePreview,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      collectionId:
          clearCollectionId ? null : (collectionId ?? this.collectionId),
      captureSessionId: clearCaptureSessionId
          ? null
          : (captureSessionId ?? this.captureSessionId),
      isPrimaryEvidence: isPrimaryEvidence ?? this.isPrimaryEvidence,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      retryCount: retryCount ?? this.retryCount,
      contentHash: contentHash ?? this.contentHash,
      temporalIntent: temporalIntent ?? this.temporalIntent,
      metadata: metadata ?? this.metadata,
      provenanceEvents: provenanceEvents ?? this.provenanceEvents,
    );
  }
}
