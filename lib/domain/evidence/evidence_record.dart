import 'evidence_record_type.dart';
import 'evidence_sync_status.dart';

/// Canonical lifecycle-oriented evidence record (Sprint 6A).
///
/// Unifies captured + supporting evidence for sync orchestration, dual-queue
/// prep (6B), and UI status reads. Does not replace [CapturedEvidence] /
/// [SupportingEvidence] in the investigation aggregate — it projects them.
class EvidenceRecord {
  const EvidenceRecord({
    required this.evidenceId,
    required this.incidentId,
    required this.evidenceType,
    required this.createdAt,
    required this.capturedAt,
    required this.syncStatus,
    this.localPath,
    this.cloudPath,
    this.thumbnailPath,
    this.uploadProgress = 0,
    this.retryCount = 0,
    this.hash,
    this.metadata = const {},
    this.downloadUrl,
    this.mimeType,
    this.fileSizeBytes,
    this.isPrimaryChronology = false,
  });

  final String evidenceId;
  final String incidentId;
  final EvidenceRecordType evidenceType;
  final String? localPath;
  final String? cloudPath;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime capturedAt;
  final EvidenceSyncStatus syncStatus;

  /// 0.0 – 1.0 upload fraction (domain-owned; UI does not invent this).
  final double uploadProgress;
  final int retryCount;

  /// Content integrity hash when available (Sprint 6B durable cache).
  final String? hash;

  /// Extensible metadata bag (device, GPS, mime hints, pipeline flags).
  final Map<String, String> metadata;

  final String? downloadUrl;
  final String? mimeType;
  final int? fileSizeBytes;
  final bool isPrimaryChronology;

  bool get hasLocalMedia =>
      localPath != null && localPath!.trim().isNotEmpty;

  bool get hasCloudMedia =>
      cloudPath != null && cloudPath!.trim().isNotEmpty;

  EvidenceRecord copyWith({
    String? localPath,
    String? cloudPath,
    String? thumbnailPath,
    EvidenceSyncStatus? syncStatus,
    double? uploadProgress,
    int? retryCount,
    String? hash,
    Map<String, String>? metadata,
    String? downloadUrl,
    String? mimeType,
    int? fileSizeBytes,
    bool? isPrimaryChronology,
  }) {
    return EvidenceRecord(
      evidenceId: evidenceId,
      incidentId: incidentId,
      evidenceType: evidenceType,
      localPath: localPath ?? this.localPath,
      cloudPath: cloudPath ?? this.cloudPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt,
      capturedAt: capturedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      retryCount: retryCount ?? this.retryCount,
      hash: hash ?? this.hash,
      metadata: metadata ?? this.metadata,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isPrimaryChronology: isPrimaryChronology ?? this.isPrimaryChronology,
    );
  }
}
