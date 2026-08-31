import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/capture/capture_session_status.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/persistence/local_incident_pointer.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/local_evidence_hydrator.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
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
  final manager = CaptureSessionManager.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_cs_manager_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    await manager.resetForTests();
    await EvidenceSyncManager.instance.resetForTests();
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-6c2',
    );
  });

  tearDown(() async {
    await EvidenceSyncManager.instance.resetForTests();
    await manager.resetForTests();
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {}
  });

  Future<File> seedFile(String name) async {
    final file = File(p.join(tempRoot.path, name));
    await file.writeAsBytes(List<int>.filled(24, 9));
    return file;
  }

  test('1. start session', () async {
    final incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    final session = await manager.startSession(
      incidentId: incidentId,
      userId: 'user-6c2',
    );
    expect(session.id, isNotEmpty);
    expect(session.incidentId, incidentId);
    expect(session.status, CaptureSessionStatus.active);
    expect(session.endedAt, isNull);
  });

  test('2. active session retrieval', () async {
    final incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    final started = await manager.startSession(incidentId: incidentId);
    expect(manager.getActiveSession(incidentId)?.id, started.id);
  });

  test('3. automatic session creation', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    expect(manager.getActiveSession(incidentId), isNull);

    final photo = await seedFile('auto.jpg');
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'auto.jpg',
        fileSizeBytes: 24,
        thumbnailPath: photo.path,
      ),
    );

    final active = manager.getActiveSession(incidentId);
    expect(active, isNotNull);
    expect(active!.status, CaptureSessionStatus.active);
  });

  test('4. evidence attachment', () async {
    final incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    final session = await manager.startSession(incidentId: incidentId);
    final attached = await manager.attachEvidenceToSession(
      sessionId: session.id,
      evidenceId: 'ev-attach-1',
    );
    expect(attached?.evidenceIds, contains('ev-attach-1'));
    expect(manager.getActiveSession(incidentId)?.evidenceIds, contains('ev-attach-1'));
  });

  test('5. pause', () async {
    final incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    final session = await manager.startSession(incidentId: incidentId);
    final paused = await manager.pauseSession(sessionId: session.id);
    expect(paused?.status, CaptureSessionStatus.paused);
    expect(manager.getActiveSession(incidentId), isNull);
    expect(manager.getOpenSession(incidentId)?.id, session.id);
  });

  test('6. resume', () async {
    final incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    final session = await manager.startSession(incidentId: incidentId);
    await manager.pauseSession(sessionId: session.id);
    final resumed = await manager.resumeSession(sessionId: session.id);
    expect(resumed?.status, CaptureSessionStatus.active);
    expect(manager.getActiveSession(incidentId)?.id, session.id);
  });

  test('7. complete', () async {
    final incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    final session = await manager.startSession(incidentId: incidentId);
    final completed = await manager.completeSession(sessionId: session.id);
    expect(completed?.status, CaptureSessionStatus.completed);
    expect(completed?.endedAt, isNotNull);
    expect(manager.getActiveSession(incidentId), isNull);

    final refused = await manager.attachEvidenceToSession(
      sessionId: session.id,
      evidenceId: 'ev-after-complete',
    );
    expect(refused, isNull);
  });

  test('8. archive', () async {
    final incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    final session = await manager.startSession(incidentId: incidentId);
    final archived = await manager.archiveSession(sessionId: session.id);
    expect(archived?.status, CaptureSessionStatus.archived);
    expect(archived?.endedAt, isNotNull);
    expect(manager.getActiveSession(incidentId), isNull);
  });

  test('9. completed session creates new session', () async {
    final sessionCtrl = WorkspaceSession.instance;
    final incidentId = sessionCtrl.controller.currentIncident.id;
    final first = await manager.startSession(incidentId: incidentId);
    await manager.attachEvidenceToSession(
      sessionId: first.id,
      evidenceId: 'ev-first',
    );
    await manager.completeSession(sessionId: first.id);

    final photo = await seedFile('next.jpg');
    await sessionCtrl.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'next.jpg',
        fileSizeBytes: 24,
        thumbnailPath: photo.path,
      ),
    );

    final second = manager.getActiveSession(incidentId);
    expect(second, isNotNull);
    expect(second!.id, isNot(first.id));
    expect(second.status, CaptureSessionStatus.active);
  });

  test('10. restart recovery', () async {
    final sessionCtrl = WorkspaceSession.instance;
    final incidentId = sessionCtrl.controller.currentIncident.id;
    final started = await manager.startSession(incidentId: incidentId);
    await manager.attachEvidenceToSession(
      sessionId: started.id,
      evidenceId: 'ev-restart',
    );

    manager.clearMemory();
    expect(manager.getActiveSession(incidentId), isNull);

    final restored = await manager.restoreForIncident(
      incidentId: incidentId,
      userId: 'user-6c2',
    );
    expect(restored?.id, started.id);
    expect(restored?.status, CaptureSessionStatus.active);
    expect(restored?.evidenceIds, contains('ev-restart'));
  });

  test('11. logout/login recovery', () async {
    final sessionCtrl = WorkspaceSession.instance;
    final incidentId = sessionCtrl.controller.currentIncident.id;
    sessionCtrl.controller.updateIncidentName('Workplace');
    final photo = await seedFile('logout.jpg');
    await sessionCtrl.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'logout.jpg',
        fileSizeBytes: 24,
        thumbnailPath: photo.path,
      ),
    );
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await sessionCtrl.flushBeforeSignOut();
    sessionCtrl.onSignedOut();
    expect(manager.getActiveSession(incidentId), isNull);

    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-6c2',
    );
    expect(await LocalIncidentPointer.recall('user-6c2'), incidentId);
    expect(await LocalIncidentPointer.recallCaptureSession('user-6c2'), sessionId);

    sessionCtrl.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace'),
    );
    await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: sessionCtrl.controller.evidenceRepository,
      userId: 'user-6c2',
    );
    final restored = await manager.restoreForIncident(
      incidentId: incidentId,
      userId: 'user-6c2',
    );
    expect(restored?.id, sessionId);
    expect(restored?.status, CaptureSessionStatus.active);
  });

  test('12. legacy evidence compatibility', () async {
    final sessionCtrl = WorkspaceSession.instance;
    final incidentId = sessionCtrl.controller.currentIncident.id;
    const legacyId = 'ev-legacy-manager';
    final legacyFile = await seedFile('legacy-m.jpg');

    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: legacyId,
        incidentId: incidentId,
        userId: 'user-6c2',
        evidenceType: EvidenceRecordType.photo,
        createdAt: DateTime.now(),
        capturedAt: DateTime.now(),
        syncStatus: EvidenceSyncStatus.localCaptured,
        localFilePath: legacyFile.path,
        fileName: 'legacy-m.jpg',
      ),
    );

    final inserted = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: sessionCtrl.controller.evidenceRepository,
      userId: 'user-6c2',
    );
    sessionCtrl.controller.scheduleCaptureMetadataPersist();
    expect(inserted, 1);
    expect(
      sessionCtrl.controller.evidenceRepository
          .capturedById(legacyId)
          ?.captureSessionId,
      isNull,
    );
    expect(sessionCtrl.controller.currentIncident.evidenceCount, 1);
  });

  test('summary reports duration and media counts', () async {
    final incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    final session = await manager.startSession(incidentId: incidentId);
    await manager.attachEvidenceToSession(
      sessionId: session.id,
      evidenceId: 'ev-sum-photo',
    );
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'ev-sum-photo',
        incidentId: incidentId,
        userId: 'user-6c2',
        evidenceType: EvidenceRecordType.photo,
        createdAt: DateTime.now(),
        capturedAt: DateTime.now(),
        syncStatus: EvidenceSyncStatus.localCaptured,
        captureSessionId: session.id,
      ),
    );
    await manager.attachEvidenceToSession(
      sessionId: session.id,
      evidenceId: 'ev-sum-note',
    );
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'ev-sum-note',
        incidentId: incidentId,
        userId: 'user-6c2',
        evidenceType: EvidenceRecordType.note,
        createdAt: DateTime.now(),
        capturedAt: DateTime.now(),
        syncStatus: EvidenceSyncStatus.localCaptured,
        captureSessionId: session.id,
        noteText: 'hi',
      ),
    );

    final summary = await manager.summarize(sessionId: session.id);
    expect(summary, isNotNull);
    expect(summary!.evidenceCount, 2);
    expect(summary.photoCount, 1);
    expect(summary.noteCount, 1);
    expect(summary.duration, isNot(Duration.zero));
  });
}
