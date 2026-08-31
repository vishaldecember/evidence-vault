import '../../domain/evidence/evidence_sync_status.dart';
import 'evidence_upload_models.dart';

/// Bridges legacy [EvidenceUploadStatus] ↔ domain [EvidenceSyncStatus].
abstract final class EvidenceStatusBridge {
  static EvidenceSyncStatus fromUploadStatus(EvidenceUploadStatus status) {
    return switch (status) {
      EvidenceUploadStatus.pending => EvidenceSyncStatus.queuedForUpload,
      EvidenceUploadStatus.uploading => EvidenceSyncStatus.uploading,
      EvidenceUploadStatus.processing => EvidenceSyncStatus.processing,
      EvidenceUploadStatus.uploaded => EvidenceSyncStatus.synced,
      EvidenceUploadStatus.failed => EvidenceSyncStatus.failed,
    };
  }

  static EvidenceUploadStatus toUploadStatus(EvidenceSyncStatus status) {
    return switch (status) {
      EvidenceSyncStatus.localCaptured => EvidenceUploadStatus.pending,
      EvidenceSyncStatus.queuedForUpload => EvidenceUploadStatus.pending,
      EvidenceSyncStatus.uploading => EvidenceUploadStatus.uploading,
      EvidenceSyncStatus.synced => EvidenceUploadStatus.uploaded,
      EvidenceSyncStatus.processing => EvidenceUploadStatus.processing,
      EvidenceSyncStatus.ready => EvidenceUploadStatus.uploaded,
      EvidenceSyncStatus.failed => EvidenceUploadStatus.failed,
    };
  }
}
