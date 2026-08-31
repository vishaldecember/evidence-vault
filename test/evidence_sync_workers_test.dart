import 'dart:async';
import 'dart:io';

import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late EvidenceSyncQueue queue;
  late EvidenceSyncManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'owner@test.com',
      name: 'Owner',
      userId: 'user-1',
    );
    tempRoot = await Directory.systemTemp.createTemp('ev_workers_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    queue = EvidenceSyncQueue();
    manager = EvidenceSyncManager(
      queue: queue,
      maxConcurrentUploads: 2,
      enableDebugLogging: false,
    );
    await manager.resetForTests();
    // resetForTests clears queue via manager's queue — rebind.
    queue = EvidenceSyncQueue();
    manager = EvidenceSyncManager(
      queue: queue,
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
    String path = '',
    EvidenceSyncStatus status = EvidenceSyncStatus.queuedForUpload,
  }) async {
    final filePath = path.isEmpty ? p.join(tempRoot.path, '$id.jpg') : path;
    final file = File(filePath);
    if (!await file.exists()) {
      await file.writeAsBytes(List<int>.filled(8, 1));
    }
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: id,
        incidentId: 'inc-1',
        userId: 'user-1',
        evidenceType: EvidenceRecordType.photo,
        createdAt: now,
        capturedAt: now,
        syncStatus: status,
        localFilePath: filePath,
        captureMode: WorkspaceCaptureMode.photo,
        fileName: '$id.jpg',
        fileSizeBytes: 8,
      ),
    );
  }

  StorageUploadResult okResult(String id) => StorageUploadResult(
        storagePath: 'users/u/incidents/inc-1/photos/$id',
        downloadUrl: 'https://example.com/$id',
        fileSize: 8,
        contentType: 'image/jpeg',
      );

  test('A. queue ordering prefers FAST_SYNC HIGH FIFO', () async {
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'late',
        incidentId: 'inc',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.utc(2026, 8, 9, 12, 0, 2),
      ),
    );
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'early',
        incidentId: 'inc',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.utc(2026, 8, 9, 12, 0, 1),
      ),
    );
    expect(queue.peekNext()?.evidenceId, 'early');
  });

  test('B. two workers process two evidence items concurrently', () async {
    await seedLocal(id: 'a');
    await seedLocal(id: 'b');

    final started = <String>[];
    final bothStarted = Completer<void>();
    final release = Completer<void>();
    var uploads = 0;

    manager.setUploadFnForTests((item) async {
      started.add(item.evidenceId);
      uploads++;
      if (uploads == 2 && !bothStarted.isCompleted) {
        bothStarted.complete();
      }
      await release.future;
      return okResult(item.evidenceId);
    });

    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'a',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, 'a.jpg'),
      ),
    );
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'b',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now().add(const Duration(milliseconds: 1)),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, 'b.jpg'),
      ),
    );

    unawaited(manager.schedule());
    await bothStarted.future.timeout(const Duration(seconds: 3));
    expect(started.toSet(), {'a', 'b'});
    expect(manager.activeUploadCount, 2);
    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  test('C. one worker failure does not stop the second worker', () async {
    await seedLocal(id: 'fail');
    await seedLocal(id: 'ok');

    final okDone = Completer<void>();
    manager.setUploadFnForTests((item) async {
      if (item.evidenceId == 'fail') {
        return null;
      }
      okDone.complete();
      return okResult(item.evidenceId);
    });

    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'fail',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, 'fail.jpg'),
      ),
    );
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'ok',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now().add(const Duration(milliseconds: 1)),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, 'ok.jpg'),
      ),
    );

    await manager.schedule();
    await okDone.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final okCached = await LocalEvidenceCache.byId('ok');
    expect(okCached?.syncStatus, EvidenceSyncStatus.ready);
  });

  test('D. failed item is retried with backoff metadata', () async {
    await seedLocal(id: 'retry-me');
    var calls = 0;
    manager.setUploadFnForTests((item) async {
      calls++;
      if (calls == 1) {
        return null;
      }
      return okResult(item.evidenceId);
    });

    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'retry-me',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, 'retry-me.jpg'),
      ),
    );

    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final afterFail = queue.items.where((e) => e.evidenceId == 'retry-me');
    expect(afterFail, isNotEmpty);
    expect(afterFail.first.attempts, greaterThan(0));
    expect(afterFail.first.nextAttemptAt, isNotNull);

    // Force due now and schedule again.
    final item = afterFail.first;
    await queue.remove('retry-me');
    await queue.enqueue(item.copyWith(clearNextAttemptAt: true));
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final cached = await LocalEvidenceCache.byId('retry-me');
    expect(cached?.syncStatus, EvidenceSyncStatus.ready);
    expect(calls, greaterThanOrEqualTo(2));
  });

  Future<EvidenceSyncStatus?> waitUntilStatus(
    String id,
    EvidenceSyncStatus expected, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final cached = await LocalEvidenceCache.byId(id);
      if (cached?.syncStatus == expected) {
        return cached?.syncStatus;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return (await LocalEvidenceCache.byId(id))?.syncStatus;
  }

  test('E. app restart recovers queued evidence', () async {
    UserSessionService.establishSession(
      email: 'owner@test.com',
      name: 'Owner',
      userId: 'user-1',
    );
    await seedLocal(id: 'interrupted', status: EvidenceSyncStatus.uploading);
    final recoveredQueue = EvidenceSyncQueue();
    final recovered = EvidenceSyncManager(
      queue: recoveredQueue,
      maxConcurrentUploads: 2,
      enableDebugLogging: false,
    );
    recovered.setUploadFnForTests((item) async => okResult(item.evidenceId));
    recovered.setOnlineForTests(true);

    await recovered.start();
    recovered.setOnlineForTests(true);
    await recovered.schedule();
    expect(
      await waitUntilStatus('interrupted', EvidenceSyncStatus.ready),
      EvidenceSyncStatus.ready,
    );
    await recovered.resetForTests();
  });

  test('F. duplicate enqueue does not create two queue rows', () async {
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'same',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
      ),
    );
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'same',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
      ),
    );
    expect(queue.fastSyncItems.where((e) => e.evidenceId == 'same').length, 1);
  });

  test('G. local file retained after successful sync', () async {
    final path = p.join(tempRoot.path, 'keep.jpg');
    await seedLocal(id: 'keep', path: path);
    manager.setUploadFnForTests((item) async => okResult(item.evidenceId));

    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'keep',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: path,
      ),
    );
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(File(path).existsSync(), isTrue);
    final cached = await LocalEvidenceCache.byId('keep');
    expect(cached?.localFilePath, path);
    expect(cached?.syncStatus, EvidenceSyncStatus.ready);
  });

  test('H. offline evidence synchronizes when schedule runs again', () async {
    await seedLocal(id: 'offline');
    var allow = false;
    manager.setUploadFnForTests((item) async {
      if (!allow) {
        return null;
      }
      return okResult(item.evidenceId);
    });

    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'offline',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, 'offline.jpg'),
      ),
    );
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    allow = true;
    final pending = queue.items.where((e) => e.evidenceId == 'offline');
    if (pending.isNotEmpty) {
      final item = pending.first;
      await queue.remove('offline');
      await queue.enqueue(item.copyWith(clearNextAttemptAt: true));
    }
    await manager.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(
      (await LocalEvidenceCache.byId('offline'))?.syncStatus,
      EvidenceSyncStatus.ready,
    );
  });

  test('I. FAST_SYNC does not wait for intelligence', () async {
    await seedLocal(id: 'fast');
    final fastDone = Completer<void>();

    manager.setUploadFnForTests((item) async {
      if (!fastDone.isCompleted) {
        fastDone.complete();
      }
      return okResult(item.evidenceId);
    });

    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'intel-slow',
        incidentId: 'inc-1',
        lane: EvidenceSyncLane.intelligence,
        priority: SyncWorkPriority.normal,
        enqueuedAt: DateTime.now(),
      ),
    );
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'fast',
        incidentId: 'inc-1',
        userId: 'user-1',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, 'fast.jpg'),
      ),
    );

    unawaited(manager.schedule());
    await fastDone.future.timeout(const Duration(seconds: 3));
    expect(
      await waitUntilStatus('fast', EvidenceSyncStatus.ready),
      EvidenceSyncStatus.ready,
    );
    // Intelligence must not leave FAST_SYNC blocked — fast is READY.
    expect(queue.peekLane(EvidenceSyncLane.fastSync), isNull);
  });

  test('J. rapid captures produce separate stable evidence IDs', () async {
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      final id = 'rapid-$i';
      ids.add(id);
      await seedLocal(id: id);
      await manager.registerLocalCapture(
        evidenceId: id,
        incidentId: 'inc-1',
        evidenceType: EvidenceRecordType.photo,
        capturedAt: DateTime.now(),
        mode: WorkspaceCaptureMode.photo,
        kickDrain: false,
      );
    }
    expect(ids.toSet().length, 5);
    expect(queue.fastSyncItems.map((e) => e.evidenceId).toSet().length, 5);
  });

  test('backoff duration grows then caps', () {
    expect(EvidenceSyncManager.backoffForAttempt(1).inSeconds, 2);
    expect(EvidenceSyncManager.backoffForAttempt(2).inSeconds, 4);
    expect(EvidenceSyncManager.backoffForAttempt(3).inSeconds, 8);
    expect(EvidenceSyncManager.backoffForAttempt(10).inSeconds, 60);
  });
}
