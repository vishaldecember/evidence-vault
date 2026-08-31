import 'captured_evidence.dart';
import 'evidence_record.dart';
import 'evidence_record_type.dart';
import 'evidence_sync_status.dart';
import 'supporting_evidence.dart';

/// Projects aggregate evidence entities into [EvidenceRecord].
abstract final class EvidenceRecordMapper {
  static EvidenceRecord fromCaptured(CapturedEvidence evidence) {
    return EvidenceRecord(
      evidenceId: evidence.id,
      incidentId: evidence.incidentId,
      evidenceType: EvidenceRecordType.fromCaptured(evidence.type),
      localPath: evidence.localPath,
      cloudPath: evidence.cloudPath,
      thumbnailPath: evidence.thumbnailPath,
      createdAt: evidence.createdAt ?? evidence.capturedAt,
      capturedAt: evidence.capturedAt,
      syncStatus: evidence.syncStatus,
      uploadProgress: evidence.uploadProgress,
      retryCount: evidence.retryCount,
      hash: evidence.contentHash,
      metadata: evidence.metadata,
      downloadUrl: evidence.downloadUrl,
      mimeType: evidence.mimeType,
      fileSizeBytes: evidence.fileSizeBytes,
      isPrimaryChronology: evidence.isPrimaryEvidence,
    );
  }

  static EvidenceRecord fromSupporting(SupportingEvidence evidence) {
    return EvidenceRecord(
      evidenceId: evidence.id,
      incidentId: evidence.incidentId,
      evidenceType: EvidenceRecordType.fromSupporting(evidence.type),
      localPath: evidence.localPath,
      cloudPath: evidence.cloudPath,
      thumbnailPath: evidence.thumbnailPath,
      createdAt: evidence.createdAt,
      capturedAt: evidence.createdAt,
      syncStatus: evidence.syncStatus,
      uploadProgress: evidence.uploadProgress,
      retryCount: evidence.retryCount,
      hash: evidence.contentHash,
      metadata: evidence.metadata,
      downloadUrl: evidence.downloadUrl,
      mimeType: evidence.mimeType,
      fileSizeBytes: evidence.fileSizeBytes,
      isPrimaryChronology: false,
    );
  }

  static EvidenceSyncStatus initialForMediaCapture() =>
      EvidenceSyncStatus.localCaptured;

  static EvidenceSyncStatus initialForTextOnly() =>
      EvidenceSyncStatus.localCaptured;
}
