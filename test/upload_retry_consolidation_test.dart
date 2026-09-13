import 'dart:io';

import 'package:evidence_vault/domain/evidence/evidence_provenance_event.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/repositories/storage_repository.dart';
import 'package:evidence_vault/services/capture/capture_engine.dart';
import 'package:evidence_vault/services/capture/capture_job.dart';
import 'package:evidence_vault/services/capture/capture_provenance.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/durable_upload_queue.dart';
import 'package:evidence_vault/services/storage/evidence_upload_coordinator.dart';
import 'package:evidence_vault/services/storage/evidence_upload_queue.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/storage_upload_result.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/sync/evidence_sync_queue.dart';
import 'package:evidence_vault/services/user_session_service.dart';
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

class _NoteCaptureHost implements CapturePipelineHost {
  final calls = <String>[];

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
  }) {}

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
  }) {}

  @override
  void failCaptureUpload(String evidenceId) {}

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
  void recordContentHash({required String evidenceId, required String hash}) {}

  @override
  void appendEvidenceProvenance(EvidenceProvenanceEvent event) {}

  @override
  void abandonFailedLocalCapture(String evidenceId) {}

  @override
  bool updateLifecycleStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  }) {
    return true;
  }
}

class _ThrowingStorage extends Fake implements StorageRepository {
  int uploadCalls = 0;

  @override
  Future<StorageUploadResult> uploadForMode({
    required WorkspaceCaptureMode mode,
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) async {
    uploadCalls++;
    throw Exception('storage unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late EvidenceSyncQueue queue;
  late EvidenceUploadQueue coordinatorQueue;
  late EvidenceUploadCoordinator coordinator;
  late EvidenceSyncManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'owner@test.com',
      name: 'Owner',
      userId: 'user-1',
    );
    tempRoot = await Directory.systemTemp.createTemp('ev_retry_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();

    queue = EvidenceSyncQueue();
    coordinatorQueue = EvidenceUploadQueue();
    coordinator = EvidenceUploadCoordinator(queue: coordinatorQueue);
    manager = EvidenceSyncManager(
      queue: queue,
      uploadCoordinator: coordinator,
      maxConcurrentUploads: 2,
      enableDebugLogging: false,
    );
    await manager.resetForTests();
    queue = EvidenceSyncQueue();
    coordinatorQueue = EvidenceUploadQueue();
    coordinator = EvidenceUploadCoordinator(queue: coordinatorQueue);
    manager = EvidenceSyncManager(
      queue: queue,
      uploadCoordinator: coordinator,
      maxConcurrentUploads: 2,
      enableDebugLogging: false,
    );
  });

  tearDown(() async {
    UserSessionService.resetForTests();
    await manager.resetForTests();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<void> seedLocal({
    required String id,
    String incidentId = 'inc-1',
  }) async {
    final filePath = p.join(tempRoot.path, '$id.jpg');
    final file = File(filePath);
    if (!await file.exists()) {
      await file.writeAsBytes(List<int>.filled(8, 1));
    }
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: id,
        incidentId: incidentId,
        userId: 'user-1',
        evidenceType: EvidenceRecordType.photo,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.queuedForUpload,
        localFilePath: filePath,
        captureMode: WorkspaceCaptureMode.photo,
        fileName: '$id.jpg',
        fileSizeBytes: 8,
      ),
    );
  }

  Future<void> enqueueFast(String id, {String incidentId = 'inc-1'}) async {
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: id,
        incidentId: incidentId,
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, '$id.jpg'),
      ),
    );
  }

  StorageUploadResult okResult(String id) => StorageUploadResult(
        storagePath: 'users/u/incidents/inc-1/photos/$id',
        downloadUrl: 'https://example.com/$id',
        fileSize: 8,
        contentType: 'image/jpeg',
      );

  int fastRetryCount(String id, {String incidentId = 'inc-1'}) {
    return queue.fastSyncItems
        .where((item) => item.incidentId == incidentId && item.evidenceId == id)
        .length;
  }

  test('Test 1 — failed upload creates exactly one canonical retry record',
      () async {
    await seedLocal(id: 'ev-fail');
    manager.setUploadFnForTests((_) async => null);

    await enqueueFast('ev-fail');
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(queue.countFor(incidentId: 'inc-1', evidenceId: 'ev-fail'), 1);
    expect(fastRetryCount('ev-fail'), 1);
    expect(coordinatorQueue.hasPending, isFalse);
  });

  test('coordinator failure does not persist an independent durable retry',
      () async {
    final throwing = _ThrowingStorage();
    final isolatedQueue = EvidenceUploadQueue();
    final isolated = EvidenceUploadCoordinator(
      storage: throwing,
      queue: isolatedQueue,
    );

    final result = await isolated.uploadCapturedMedia(
      evidenceId: 'ev-coord',
      incidentId: 'inc-1',
      localFilePath: p.join(tempRoot.path, 'missing.bin'),
      mode: WorkspaceCaptureMode.file,
    );

    expect(result, isNull);
    expect(throwing.uploadCalls, 1);
    expect(isolatedQueue.hasPending, isFalse);
    expect(isolated.queue.items, isEmpty);
    expect(await isolated.retry('ev-coord'), isNull);
  });

  test('Test 2 — repeated failures do not duplicate retry records', () async {
    await seedLocal(id: 'ev-repeat');
    manager.setUploadFnForTests((_) async => null);

    await enqueueFast('ev-repeat');
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final afterFirst = queue.items.where((e) => e.evidenceId == 'ev-repeat');
    expect(afterFirst, hasLength(1));
    final item = afterFirst.first;
    await queue.remove('ev-repeat');
    await queue.enqueue(item.copyWith(clearNextAttemptAt: true));
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(queue.countFor(incidentId: 'inc-1', evidenceId: 'ev-repeat'), 1);
    expect(fastRetryCount('ev-repeat'), 1);
    expect(coordinatorQueue.hasPending, isFalse);
  });

  test('Test 3 — successful retry removes the canonical FAST_SYNC record',
      () async {
    await seedLocal(id: 'ev-ok');
    var calls = 0;
    manager.setUploadFnForTests((item) async {
      calls++;
      if (calls == 1) {
        return null;
      }
      return okResult(item.evidenceId);
    });

    await enqueueFast('ev-ok');
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(fastRetryCount('ev-ok'), 1);

    final item = queue.items.firstWhere((e) => e.evidenceId == 'ev-ok');
    await queue.remove('ev-ok');
    await queue.enqueue(item.copyWith(clearNextAttemptAt: true));
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(fastRetryCount('ev-ok'), 0);
    expect(
      (await LocalEvidenceCache.byId('ev-ok'))?.syncStatus,
      EvidenceSyncStatus.ready,
    );
    expect(calls, greaterThanOrEqualTo(2));
  });

  test('Test 4 — Clear Vault clears canonical and leftover durable retry state',
      () async {
    await seedLocal(id: 'ev-wipe');
    await enqueueFast('ev-wipe');
    coordinatorQueue.enqueue(
      buildQueuedEvidenceUpload(
        evidenceId: 'ev-wipe',
        incidentId: 'inc-1',
        userId: 'user-1',
        localFilePath: p.join(tempRoot.path, 'ev-wipe.jpg'),
        mode: WorkspaceCaptureMode.photo,
        intendedStoragePath: 'users/user-1/incidents/inc-1/photos/ev-wipe',
      ),
    );
    await coordinatorQueue.persist();
    expect(queue.hasPending, isTrue);
    expect(coordinatorQueue.hasPending, isTrue);

    await manager.clearLocalSyncState();

    expect(queue.items, isEmpty);
    expect(coordinatorQueue.hasPending, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(EvidenceSyncQueue.storageKey), anyOf(isNull, '[]'));
    expect(prefs.getString(DurableUploadQueue.storageKey), isNull);
  });

  test('Test 5 — same incidentId + evidenceId cannot be queued twice', () async {
    final now = DateTime.now();
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'ev-dup',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: now,
      ),
    );
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'ev-dup',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: now.add(const Duration(seconds: 1)),
        attempts: 3,
      ),
    );

    expect(queue.countFor(incidentId: 'inc-1', evidenceId: 'ev-dup'), 1);
    expect(queue.items, hasLength(1));
    expect(queue.items.single.attempts, 3);
  });

  test('Test 6 — CaptureEngine still returns after local commit', () async {
    await EvidenceSyncManager.instance.resetForTests();
    final host = _NoteCaptureHost();
    final id = await CaptureEngine.instance.receive(
      host: host,
      mode: WorkspaceCaptureMode.note,
      createLocalEvidence: (_) => 'ev-instant',
      uploadCoordinator: coordinator,
      noteText: 'hello',
    );

    expect(id, 'ev-instant');
    expect(host.calls, contains('persist'));
    await EvidenceSyncManager.instance.resetForTests();
  });

  test('unsigned coordinator failure does not create a durable retry row',
      () async {
    UserSessionService.resetForTests();
    final isolatedQueue = EvidenceUploadQueue();
    final isolated = EvidenceUploadCoordinator(queue: isolatedQueue);

    final result = await isolated.uploadCapturedMedia(
      evidenceId: 'ev-unsigned',
      incidentId: 'inc-1',
      localFilePath: '/tmp/x.jpg',
      mode: WorkspaceCaptureMode.photo,
    );

    expect(result, isNull);
    expect(isolatedQueue.hasPending, isFalse);
  });
}
