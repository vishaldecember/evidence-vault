import '../../domain/evidence/evidence_record_type.dart';
import '../../domain/evidence/evidence_sync_status.dart';
import '../../models/workspace_capture_mode.dart';
import '../../utils/instant_codec.dart';

/// Durable local evidence row (Sprint 6B).
///
/// Stored in [LocalEvidenceCache] JSON index. Media binaries live beside it
/// under `evidence_cache/{incidentId}/`.
class CachedEvidenceEntry {
  const CachedEvidenceEntry({
    required this.evidenceId,
    required this.incidentId,
    required this.userId,
    required this.evidenceType,
    required this.createdAt,
    required this.capturedAt,
    required this.syncStatus,
    this.localFilePath,
    this.thumbnailPath,
    this.uploadProgress = 0,
    this.retryCount = 0,
    this.hash,
    this.metadata = const {},
    this.captureMode,
    this.fileName,
    this.fileSizeBytes,
    this.cloudPath,
    this.downloadUrl,
    this.noteText,
    this.mimeType,
    this.parentEvidenceId,
    this.captureSessionId,
  });

  final String evidenceId;
  final String incidentId;
  final String userId;
  final EvidenceRecordType evidenceType;
  final String? localFilePath;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime capturedAt;
  final EvidenceSyncStatus syncStatus;
  final double uploadProgress;
  final int retryCount;
  final String? hash;
  final Map<String, String> metadata;
  final WorkspaceCaptureMode? captureMode;
  final String? fileName;
  final int? fileSizeBytes;
  final String? cloudPath;
  final String? downloadUrl;

  /// Written note body (text notes).
  final String? noteText;

  final String? mimeType;

  /// Optional parent primary — null for standalone capture-bar notes/files.
  final String? parentEvidenceId;

  /// Optional [CaptureSession] membership (Sprint 6C). Null for legacy rows.
  final String? captureSessionId;

  bool get needsUpload =>
      syncStatus == EvidenceSyncStatus.localCaptured ||
      syncStatus == EvidenceSyncStatus.queuedForUpload ||
      syncStatus == EvidenceSyncStatus.failed ||
      syncStatus == EvidenceSyncStatus.uploading;

  /// True when this cache row is Organise context, not Library evidence.
  bool get isLibraryContext {
    final parent = parentEvidenceId?.trim() ?? '';
    if (parent.isNotEmpty) {
      return true;
    }
    return metadata['organizeContext'] == 'true';
  }

  CachedEvidenceEntry copyWith({
    String? localFilePath,
    String? thumbnailPath,
    EvidenceSyncStatus? syncStatus,
    double? uploadProgress,
    int? retryCount,
    String? hash,
    Map<String, String>? metadata,
    String? cloudPath,
    String? downloadUrl,
    String? fileName,
    int? fileSizeBytes,
    String? noteText,
    String? mimeType,
    String? parentEvidenceId,
    bool clearParentEvidenceId = false,
    String? captureSessionId,
    bool clearCaptureSessionId = false,
  }) {
    return CachedEvidenceEntry(
      evidenceId: evidenceId,
      incidentId: incidentId,
      userId: userId,
      evidenceType: evidenceType,
      localFilePath: localFilePath ?? this.localFilePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt,
      capturedAt: capturedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      retryCount: retryCount ?? this.retryCount,
      hash: hash ?? this.hash,
      metadata: metadata ?? this.metadata,
      captureMode: captureMode,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      cloudPath: cloudPath ?? this.cloudPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      noteText: noteText ?? this.noteText,
      mimeType: mimeType ?? this.mimeType,
      parentEvidenceId: clearParentEvidenceId
          ? null
          : (parentEvidenceId ?? this.parentEvidenceId),
      captureSessionId: clearCaptureSessionId
          ? null
          : (captureSessionId ?? this.captureSessionId),
    );
  }

  Map<String, dynamic> toJson() => {
        'evidenceId': evidenceId,
        'incidentId': incidentId,
        'userId': userId,
        'evidenceType': evidenceType.name,
        'localFilePath': localFilePath,
        'thumbnailPath': thumbnailPath,
        'createdAt': InstantCodec.encode(createdAt),
        'capturedAt': InstantCodec.encode(capturedAt),
        'syncStatus': syncStatus.wireName,
        'uploadProgress': uploadProgress,
        'retryCount': retryCount,
        'hash': hash,
        'metadata': metadata,
        'captureMode': captureMode?.name,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        'cloudPath': cloudPath,
        'downloadUrl': downloadUrl,
        'noteText': noteText,
        'mimeType': mimeType,
        'parentEvidenceId': parentEvidenceId,
        'captureSessionId': captureSessionId,
      };

  factory CachedEvidenceEntry.fromJson(Map<String, dynamic> json) {
    final typeName = json['evidenceType'] as String? ?? 'other';
    final type = EvidenceRecordType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => EvidenceRecordType.other,
    );
    final modeName = json['captureMode'] as String?;
    WorkspaceCaptureMode? mode;
    if (modeName != null) {
      mode = WorkspaceCaptureMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => WorkspaceCaptureMode.photo,
      );
    }
    final created = InstantCodec.decode(json['createdAt']) ?? DateTime.now().toUtc();
    final captured = InstantCodec.decode(json['capturedAt']) ?? created;
    final metaRaw = json['metadata'];
    final metadata = <String, String>{};
    if (metaRaw is Map) {
      metaRaw.forEach((key, value) {
        if (key != null && value != null) {
          metadata['$key'] = '$value';
        }
      });
    }
    return CachedEvidenceEntry(
      evidenceId: json['evidenceId'] as String? ?? '',
      incidentId: json['incidentId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      evidenceType: type,
      localFilePath: json['localFilePath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      createdAt: created,
      capturedAt: captured,
      syncStatus: EvidenceSyncStatus.fromWire(json['syncStatus'] as String?),
      uploadProgress: (json['uploadProgress'] as num?)?.toDouble() ?? 0,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      hash: json['hash'] as String?,
      metadata: metadata,
      captureMode: mode,
      fileName: json['fileName'] as String?,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      cloudPath: json['cloudPath'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      noteText: json['noteText'] as String?,
      mimeType: json['mimeType'] as String?,
      parentEvidenceId: json['parentEvidenceId'] as String?,
      captureSessionId: json['captureSessionId'] as String? ??
          metadata['captureSessionId'],
    );
  }
}
