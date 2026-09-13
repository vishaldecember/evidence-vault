import 'dart:async';
import 'dart:io';

import 'package:evidence_vault/domain/evidence/evidence_integrity.dart';
import 'package:evidence_vault/domain/evidence/evidence_provenance_event.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/models/evidence_device.dart';
import 'package:evidence_vault/models/evidence_location.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/capture/capture_engine.dart';
import 'package:evidence_vault/services/capture/capture_job.dart';
import 'package:evidence_vault/services/capture/capture_provenance.dart';
import 'package:evidence_vault/services/metadata_service.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/evidence_upload_coordinator.dart';
import 'package:evidence_vault/services/storage/evidence_upload_models.dart';
import 'package:evidence_vault/services/storage/evidence_upload_queue.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

class _FakeHost implements CapturePipelineHost {
  final calls = <String>[];
  String? lastThumb;
  EvidenceSyncStatus? lastLifecycleStatus;
  String? lastLifecycleEvidenceId;
  final hashes = <String, String>{};
  final coords = <String, (double?, double?)>{};

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
  }) {
    coords[evidenceId] = (latitude, longitude);
    calls.add('gps:$evidenceId');
  }

  @override
  void recordContentHash({
    required String evidenceId,
    required String hash,
  }) {
    if (hashes.containsKey(evidenceId)) {
      return;
    }
    hashes[evidenceId] = hash;
    calls.add('hash:$evidenceId');
  }

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

  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CaptureEngine.resetForTests();
    MetadataService.debugCollectAtCapture = null;
    EvidenceIntegrity.debugSha256OfFile = null;
    tempRoot = await Directory.systemTemp.createTemp('ev_engine_phase1_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
  });

  tearDown(() async {
    MetadataService.debugCollectAtCapture = null;
    EvidenceIntegrity.debugSha256OfFile = null;
    CaptureEngine.resetForTests();
    LocalEvidenceCache.resetForTests();
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {}
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

  test('Accept returns before SHA-256; hash arrives later and is first-write-wins',
      () async {
    final bytes = List<int>.generate(64, (i) => i);
    final source = File(p.join(tempRoot.path, 'shot.bin'));
    await source.writeAsBytes(bytes, flush: true);
    final expected = EvidenceIntegrity.sha256OfBytes(bytes);
    final delayedHash = Completer<String>();
    EvidenceIntegrity.debugSha256OfFile = (_) => delayedHash.future;
    final host = _FakeHost();
    final coordinator = EvidenceUploadCoordinator(queue: EvidenceUploadQueue());

    final id = await CaptureEngine.instance.receive(
      host: host,
      mode: WorkspaceCaptureMode.photo,
      createLocalEvidence: (_) => 'ev-hash-later',
      uploadCoordinator: coordinator,
      media: CapturedMediaFile(
        localPath: source.path,
        fileName: 'shot.bin',
        fileSizeBytes: bytes.length,
        thumbnailPath: source.path,
      ),
    );

    expect(id, 'ev-hash-later');
    expect(host.hashes.containsKey(id), isFalse);

    delayedHash.complete(expected);
    await CaptureEngine.waitForBackgroundWork();
    expect(host.hashes[id], expected);

    host.recordContentHash(evidenceId: id, hash: 'should-not-overwrite');
    expect(host.hashes[id], expected);
  });

  test('Accept returns while GPS is still pending, then attaches real coords',
      () async {
    final gps = Completer<CaptureProvenanceSnapshot>();
    MetadataService.debugCollectAtCapture = () => gps.future;
    final source = File(p.join(tempRoot.path, 'gps.jpg'));
    await source.writeAsBytes(const [1, 2, 3, 4], flush: true);
    final host = _FakeHost();
    final coordinator = EvidenceUploadCoordinator(queue: EvidenceUploadQueue());

    final id = await CaptureEngine.instance.receive(
      host: host,
      mode: WorkspaceCaptureMode.photo,
      createLocalEvidence: (_) => 'ev-gps-later',
      uploadCoordinator: coordinator,
      media: CapturedMediaFile(
        localPath: source.path,
        fileName: 'gps.jpg',
        fileSizeBytes: 4,
        thumbnailPath: source.path,
      ),
    );

    expect(id, 'ev-gps-later');
    expect(host.coords.containsKey(id), isFalse);

    gps.complete(
      const CaptureProvenanceSnapshot(
        device: EvidenceDevice(name: 'Test Phone', platform: 'test'),
        location: EvidenceLocation(latitude: 30.086731, longitude: 78.267608),
        locationStatus: CaptureLocationStatus.captured,
      ),
    );
    await CaptureEngine.waitForBackgroundWork();
    expect(host.coords[id], (30.086731, 78.267608));
  });

  test('unavailable GPS does not invent coordinates on Accept or later',
      () async {
    MetadataService.debugCollectAtCapture = () async {
      return const CaptureProvenanceSnapshot(
        device: EvidenceDevice(name: '', platform: 'test'),
        location: EvidenceLocation(),
        locationStatus: CaptureLocationStatus.temporarilyUnavailable,
      );
    };
    final host = _FakeHost();
    final coordinator = EvidenceUploadCoordinator(queue: EvidenceUploadQueue());
    final id = await CaptureEngine.instance.receive(
      host: host,
      mode: WorkspaceCaptureMode.note,
      createLocalEvidence: (_) => 'ev-no-gps',
      uploadCoordinator: coordinator,
      noteText: 'No fix',
    );
    await CaptureEngine.waitForBackgroundWork();
    expect(id, 'ev-no-gps');
    expect(host.coords[id], (null, null));
  });
}
