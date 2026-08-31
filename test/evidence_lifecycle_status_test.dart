import 'package:evidence_vault/domain/evidence/evidence_lifecycle.dart';
import 'package:evidence_vault/domain/evidence/evidence_record.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/storage/evidence_status_bridge.dart';
import 'package:evidence_vault/services/storage/evidence_upload_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidenceSyncStatus wire compatibility', () {
    test('decodes legacy Sprint 4D names', () {
      expect(EvidenceSyncStatus.fromWire('localOnly'),
          EvidenceSyncStatus.localCaptured);
      expect(EvidenceSyncStatus.fromWire('pendingSync'),
          EvidenceSyncStatus.queuedForUpload);
      expect(EvidenceSyncStatus.fromWire('syncing'),
          EvidenceSyncStatus.uploading);
      expect(EvidenceSyncStatus.fromWire('synchronized'),
          EvidenceSyncStatus.synced);
      expect(EvidenceSyncStatus.fromWire('syncFailed'),
          EvidenceSyncStatus.failed);
    });

    test('decodes canonical names', () {
      for (final status in EvidenceSyncStatus.values) {
        expect(EvidenceSyncStatus.fromWire(status.wireName), status);
      }
    });
  });

  group('EvidenceLifecycle transitions', () {
    test('happy path capture → ready', () {
      var status = EvidenceSyncStatus.localCaptured;
      expect(
        EvidenceLifecycle.canTransition(
            status, EvidenceSyncStatus.queuedForUpload),
        isTrue,
      );
      status = EvidenceSyncStatus.queuedForUpload;
      expect(
        EvidenceLifecycle.canTransition(status, EvidenceSyncStatus.uploading),
        isTrue,
      );
      status = EvidenceSyncStatus.uploading;
      expect(
        EvidenceLifecycle.canTransition(status, EvidenceSyncStatus.synced),
        isTrue,
      );
      status = EvidenceSyncStatus.synced;
      expect(
        EvidenceLifecycle.canTransition(status, EvidenceSyncStatus.processing),
        isTrue,
      );
      status = EvidenceSyncStatus.processing;
      expect(
        EvidenceLifecycle.canTransition(status, EvidenceSyncStatus.ready),
        isTrue,
      );
    });

    test('rejects illegal skip from local to ready', () {
      expect(
        EvidenceLifecycle.canTransition(
          EvidenceSyncStatus.localCaptured,
          EvidenceSyncStatus.ready,
        ),
        isFalse,
      );
    });

    test('failed can re-queue', () {
      expect(
        EvidenceLifecycle.canTransition(
          EvidenceSyncStatus.failed,
          EvidenceSyncStatus.queuedForUpload,
        ),
        isTrue,
      );
    });
  });

  group('EvidenceStatusBridge', () {
    test('round-trips upload enum', () {
      for (final upload in EvidenceUploadStatus.values) {
        final life = EvidenceStatusBridge.fromUploadStatus(upload);
        final back = EvidenceStatusBridge.toUploadStatus(life);
        // localCaptured maps to pending; queued also pending — acceptable.
        expect(
          back == upload ||
              (upload == EvidenceUploadStatus.pending &&
                  back == EvidenceUploadStatus.pending),
          isTrue,
        );
      }
    });
  });

  group('EvidenceRepository lifecycle', () {
    test('create → record → update status', () {
      final aggregate = IncidentAggregate.empty();
      final repo = aggregate.evidenceRepository;
      final captured =
          repo.addCapturedFromCaptureMode(WorkspaceCaptureMode.photo);
      expect(captured.syncStatus, EvidenceSyncStatus.localCaptured);

      final records = repo.evidenceRecords;
      expect(records, isNotEmpty);
      expect(records.first.evidenceId, captured.id);
      expect(records.first.evidenceType, EvidenceRecordType.photo);

      final ok = repo.updateLifecycleStatus(
        evidenceId: captured.id,
        status: EvidenceSyncStatus.queuedForUpload,
      );
      expect(ok, isTrue);
      expect(
        repo.recordById(captured.id)!.syncStatus,
        EvidenceSyncStatus.queuedForUpload,
      );

      expect(
        repo.updateLifecycleStatus(
          evidenceId: captured.id,
          status: EvidenceSyncStatus.ready,
        ),
        isFalse,
      );

      expect(
        repo.updateLifecycleStatus(
          evidenceId: captured.id,
          status: EvidenceSyncStatus.ready,
          force: true,
        ),
        isTrue,
      );
    });

    test('EvidenceRecord exposes required lifecycle fields', () {
      final record = EvidenceRecord(
        evidenceId: 'e1',
        incidentId: 'i1',
        evidenceType: EvidenceRecordType.photo,
        localPath: '/tmp/a.jpg',
        cloudPath: 'users/u/incidents/i1/photos/e1',
        thumbnailPath: '/tmp/a_thumb.jpg',
        createdAt: DateTime(2026, 1, 1),
        capturedAt: DateTime(2026, 1, 1),
        syncStatus: EvidenceSyncStatus.localCaptured,
        uploadProgress: 0.25,
        retryCount: 1,
        hash: 'abc',
        metadata: const {'deviceModel': 'test'},
      );
      expect(record.hasLocalMedia, isTrue);
      expect(record.hasCloudMedia, isTrue);
      expect(record.uploadProgress, 0.25);
      expect(record.retryCount, 1);
      expect(record.hash, 'abc');
      expect(record.metadata['deviceModel'], 'test');
    });
  });
}
