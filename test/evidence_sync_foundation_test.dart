import 'dart:io';

import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_queue.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_sync_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
  });

  tearDown(() async {
    LocalEvidenceCache.resetForTests();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('LocalEvidenceCache upsert survives reload', () async {
    final now = DateTime.utc(2026, 8, 8, 12);
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'ev-1',
        incidentId: 'inc-1',
        userId: 'user-1',
        evidenceType: EvidenceRecordType.photo,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.localCaptured,
        localFilePath: p.join(tempRoot.path, 'a.jpg'),
        thumbnailPath: p.join(tempRoot.path, 'a_thumb.jpg'),
        uploadProgress: 0,
        retryCount: 0,
        hash: 'abc',
        metadata: const {'device': 'test'},
      ),
    );

    LocalEvidenceCache.resetForTests();
    final restored = await LocalEvidenceCache.byId('ev-1');
    expect(restored, isNotNull);
    expect(restored!.incidentId, 'inc-1');
    expect(restored.syncStatus, EvidenceSyncStatus.localCaptured);
    expect(restored.hash, 'abc');
    expect(restored.metadata['device'], 'test');
  });

  test('EvidenceSyncQueue drains FAST_SYNC before INTELLIGENCE', () async {
    final queue = EvidenceSyncQueue();
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'intel-1',
        incidentId: 'inc',
        lane: EvidenceSyncLane.intelligence,
        priority: SyncWorkPriority.normal,
        enqueuedAt: DateTime.now(),
      ),
    );
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'media-1',
        incidentId: 'inc',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
      ),
    );

    expect(queue.peekNext()?.evidenceId, 'media-1');
    final first = await queue.takeNext();
    expect(first?.evidenceId, 'media-1');
    expect(queue.peekNext()?.evidenceId, 'intel-1');
  });

  test('FAST_SYNC FIFO within HIGH priority', () async {
    final queue = EvidenceSyncQueue();
    final t0 = DateTime.utc(2026, 8, 9, 10);
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'e1',
        incidentId: 'inc',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: t0,
      ),
    );
    await queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: 'e2',
        incidentId: 'inc',
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: t0.add(const Duration(seconds: 1)),
      ),
    );
    expect((await queue.takeNext())?.evidenceId, 'e1');
    expect((await queue.takeNext())?.evidenceId, 'e2');
  });

  test('pendingSync includes failed and queued rows', () async {
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'ready',
        incidentId: 'inc',
        userId: 'u',
        evidenceType: EvidenceRecordType.photo,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.ready,
      ),
    );
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'failed',
        incidentId: 'inc',
        userId: 'u',
        evidenceType: EvidenceRecordType.video,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.failed,
      ),
    );

    final pending = await LocalEvidenceCache.pendingSync(userId: 'u');
    expect(pending.map((e) => e.evidenceId), contains('failed'));
    expect(pending.map((e) => e.evidenceId), isNot(contains('ready')));
  });
}
