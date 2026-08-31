import 'package:evidence_vault/domain/evidence/evidence_provenance_event.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/capture/capture_engine.dart';
import 'package:evidence_vault/services/capture/capture_job.dart';
import 'package:evidence_vault/services/capture/capture_provenance.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/evidence_upload_coordinator.dart';
import 'package:evidence_vault/services/storage/evidence_upload_models.dart';
import 'package:evidence_vault/services/storage/evidence_upload_queue.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHost implements CapturePipelineHost {
  final calls = <String>[];
  String? lastThumb;
  EvidenceSyncStatus? lastLifecycleStatus;
  String? lastLifecycleEvidenceId;

  @override
  String get captureIncidentId => 'incident-1';

  @override
  String get captureIncidentTitle => '';

  @override
  void attachCaptureThumbnail({
    required String evidenceId,
    required String filePath,
    String? fileName,
    String? thumbnailPath,
    int? fileSizeBytes,
  }) {
    calls.add('attach:$evidenceId');
    lastThumb = thumbnailPath;
  }

  @override
  void scheduleCaptureMetadataPersist() {
    calls.add('persist');
  }

  @override
  void completeCaptureUpload({
    required String evidenceId,
    required String storagePath,
    required String downloadUrl,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {
    calls.add('complete:$evidenceId');
  }

  @override
  void failCaptureUpload(String evidenceId) {
    calls.add('fail:$evidenceId');
  }

  @override
  void rememberCaptureProvenance(CaptureProvenanceSnapshot snapshot) {}

  @override
  void applyCaptureProvenance({
    required String evidenceId,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {}

  @override
  void recordContentHash({
    required String evidenceId,
    required String hash,
  }) {}

  @override
  void appendEvidenceProvenance(EvidenceProvenanceEvent event) {}

  @override
  void abandonFailedLocalCapture(String evidenceId) {
    calls.add('abandon:$evidenceId');
  }

  @override
  bool updateLifecycleStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  }) {
    lastLifecycleEvidenceId = evidenceId;
    lastLifecycleStatus = status;
    calls.add('lifecycle:$evidenceId:${status.name}');
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('CaptureEngine returns after local commit with evidence id', () async {
    final host = _FakeHost();
    final coordinator = EvidenceUploadCoordinator(queue: EvidenceUploadQueue());
    final id = await CaptureEngine.instance.receive(
      host: host,
      mode: WorkspaceCaptureMode.note,
      createLocalEvidence: (_) => 'ev-instant',
      uploadCoordinator: coordinator,
      noteText: 'hello',
    );

    expect(id, 'ev-instant');
    expect(host.calls, contains('persist'));
  });

  test('CaptureEngine fails closed when photo media is not durable', () async {
    final host = _FakeHost();
    final coordinator = EvidenceUploadCoordinator(queue: EvidenceUploadQueue());
    await expectLater(
      CaptureEngine.instance.receive(
        host: host,
        mode: WorkspaceCaptureMode.photo,
        createLocalEvidence: (_) => 'ev-photo',
        uploadCoordinator: coordinator,
        media: const CapturedMediaFile(
          localPath: '/tmp/photo.jpg',
          fileName: 'photo.jpg',
          fileSizeBytes: 10,
          thumbnailPath: '/tmp/photo.jpg',
        ),
      ),
      throwsA(isA<MediaDurabilityException>()),
    );
    expect(host.calls, contains('abandon:ev-photo'));
    expect(coordinator.progressFor('ev-photo'), isNull);
  });

  test('EvidenceUploadStatus display labels match quiet sync labels', () {
    expect(EvidenceUploadStatus.pending.displayLabel, 'Saved');
    expect(EvidenceUploadStatus.uploading.displayLabel, 'Syncing');
    expect(EvidenceUploadStatus.processing.displayLabel, 'Processing');
    expect(EvidenceUploadStatus.uploaded.displayLabel, 'Synced');
    expect(EvidenceUploadStatus.failed.displayLabel, 'Saved on device');
  });
}
