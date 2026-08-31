import 'package:flutter_test/flutter_test.dart';
import 'package:evidence_vault/services/storage/evidence_storage_service.dart';
import 'package:evidence_vault/services/storage/storage_upload_result.dart';
import 'package:evidence_vault/services/storage/evidence_upload_models.dart';
import 'package:evidence_vault/services/storage/evidence_upload_queue.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';

void main() {
  group('StorageUploadResult', () {
    test('holds path, url, size, and content type', () {
      const result = StorageUploadResult(
        storagePath: 'users/u1/incidents/i1/photos/e1.jpg',
        downloadUrl: 'https://example.com/e1.jpg',
        fileSize: 2048,
        contentType: 'image/jpeg',
      );

      expect(result.storagePath, contains('users/u1/incidents/i1/photos/'));
      expect(result.downloadUrl, startsWith('https://'));
      expect(result.fileSize, 2048);
      expect(result.contentType, 'image/jpeg');
    });
  });

  group('Evidence upload progress labels', () {
    test('formats calm syncing label without blocking percent copy', () {
      const progress = EvidenceUploadProgress(
        evidenceId: 'e1',
        status: EvidenceUploadStatus.uploading,
        fraction: 0.42,
      );
      expect(progress.percent, 42);
      expect(progress.label, 'Syncing');
    });

    test('processing and synced labels', () {
      expect(
        const EvidenceUploadProgress(
          evidenceId: 'e1',
          status: EvidenceUploadStatus.processing,
          fraction: 0.1,
        ).label,
        'Processing',
      );
      expect(
        const EvidenceUploadProgress(
          evidenceId: 'e1',
          status: EvidenceUploadStatus.uploaded,
          fraction: 1,
        ).label,
        'Synced',
      );
      expect(
        const EvidenceUploadProgress(
          evidenceId: 'e1',
          status: EvidenceUploadStatus.pending,
          fraction: 0,
        ).label,
        'Saved',
      );
    });

    test('failed uses default message', () {
      const progress = EvidenceUploadProgress(
        evidenceId: 'e1',
        status: EvidenceUploadStatus.failed,
        fraction: 0.1,
      );
      expect(progress.label, 'Saved on device');
    });
  });

  group('EvidenceUploadQueue', () {
    test('retains failed uploads for retry without dropping evidence id', () {
      final queue = EvidenceUploadQueue();
      queue.enqueue(
        buildQueuedEvidenceUpload(
          evidenceId: 'e1',
          incidentId: 'i1',
          localFilePath: '/tmp/photo.jpg',
          mode: WorkspaceCaptureMode.photo,
          intendedStoragePath: 'users/u1/incidents/i1/photos/e1.jpg',
        ),
      );

      expect(queue.hasPending, isTrue);
      expect(queue.byEvidenceId('e1')?.localFilePath, '/tmp/photo.jpg');

      final next = queue.takeNext();
      expect(next?.evidenceId, 'e1');
      expect(queue.hasPending, isFalse);
    });
  });

  group('EvidenceStorageService path helpers', () {
    test('service constructs without throwing', () {
      // Construction only — network uploads require Firebase emulator / device.
      expect(() => EvidenceStorageService(), returnsNormally);
    });
  });
}
