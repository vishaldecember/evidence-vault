import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/capture/capture_session_status.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/capture/capture_session_service.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_capture_session_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    await CaptureSessionService.instance.resetForTests();
    await EvidenceSyncManager.instance.resetForTests();
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-6c',
    );
  });

  tearDown(() async {
    await EvidenceSyncManager.instance.resetForTests();
    await CaptureSessionService.instance.resetForTests();
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

  Future<CapturedMediaFile> mediaFor(String name) async {
    final file = await seedFile(name);
    return CapturedMediaFile(
      localPath: file.path,
      fileName: name,
      fileSizeBytes: 24,
      thumbnailPath: file.path,
    );
  }

  test('1. Start capture creates CaptureSession', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;

    expect(
      CaptureSessionService.instance.activeSessionFor(incidentId),
      isNull,
    );

    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: await mediaFor('start.jpg'),
    );

    final active =
        CaptureSessionService.instance.activeSessionFor(incidentId);
    expect(active, isNotNull);
    expect(active!.incidentId, incidentId);
    expect(active.userId, 'user-6c');
    expect(active.status, CaptureSessionStatus.active);
    expect(active.endedAt, isNull);
    expect(active.evidenceIds, isNotEmpty);

    final durable = await LocalCaptureSessionStore.activeForIncident(
      incidentId,
      userId: 'user-6c',
    );
    expect(durable?.id, active.id);
  });

  test('2. Photo capture attaches to active session', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final id = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: await mediaFor('photo.jpg'),
    );

    final active =
        CaptureSessionService.instance.activeSessionFor(incidentId)!;
    expect(active.evidenceIds, contains(id));
    expect(
      session.controller.evidenceRepository.capturedById(id)?.captureSessionId,
      active.id,
    );
    expect(
      (await LocalEvidenceCache.byId(id))?.captureSessionId,
      active.id,
    );
  });

  test('3. Video capture attaches to active session', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final id = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.video,
      media: await mediaFor('clip.mp4'),
      mimeType: 'video/mp4',
    );

    final active =
        CaptureSessionService.instance.activeSessionFor(incidentId)!;
    expect(active.evidenceIds, contains(id));
    expect(
      session.controller.evidenceRepository.capturedById(id)?.captureSessionId,
      active.id,
    );
  });

  test('4. Voice capture attaches to active session', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final id = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.voice,
      media: await mediaFor('note.m4a'),
      mimeType: 'audio/mp4',
    );

    final active =
        CaptureSessionService.instance.activeSessionFor(incidentId)!;
    expect(active.evidenceIds, contains(id));
    expect(
      session.controller.evidenceRepository.capturedById(id)?.captureSessionId,
      active.id,
    );
  });

  test('5. Text note attaches to active session', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final id = await session.controller.preserveTextNote('Scene detail');

    final active =
        CaptureSessionService.instance.activeSessionFor(incidentId)!;
    expect(active.evidenceIds, contains(id));
    expect(
      session.controller.evidenceRepository
          .supportingById(id)
          ?.captureSessionId,
      active.id,
    );
  });

  test('6. File attachment attaches to active session', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final id = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.file,
      media: await mediaFor('report.pdf'),
      mimeType: 'application/pdf',
    );

    final active =
        CaptureSessionService.instance.activeSessionFor(incidentId)!;
    expect(active.evidenceIds, contains(id));
    expect(
      session.controller.evidenceRepository
          .supportingById(id)
          ?.captureSessionId,
      active.id,
    );
  });

  test('7. Closing app and reopening restores active session', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final photoId = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: await mediaFor('restart.jpg'),
    );
    final sessionId =
        CaptureSessionService.instance.activeSessionFor(incidentId)!.id;

    // Simulate process death: clear RAM, keep durable indexes.
    CaptureSessionService.instance.clearMemory();
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace'),
    );
    expect(
      CaptureSessionService.instance.activeSessionFor(incidentId),
      isNull,
    );

    final restored = await CaptureSessionService.instance.restoreForIncident(
      incidentId: incidentId,
      userId: 'user-6c',
    );
    expect(restored?.id, sessionId);
    expect(restored?.status, CaptureSessionStatus.active);
    expect(restored?.evidenceIds, contains(photoId));
    expect(
      CaptureSessionService.instance.activeSessionFor(incidentId)?.id,
      sessionId,
    );
  });

  test('8. Logout/login restores active session', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    session.controller.updateIncidentName('Workplace incident');
    final photoId = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: await mediaFor('logout.jpg'),
    );
    final sessionId =
        CaptureSessionService.instance.activeSessionFor(incidentId)!.id;

    await session.flushBeforeSignOut();
    session.onSignedOut();
    expect(session.controller.currentIncident.id, isNot(incidentId));
    expect(
      CaptureSessionService.instance.activeSessionFor(incidentId),
      isNull,
    );

    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-6c',
    );
    final recalled = await LocalIncidentPointer.recall('user-6c');
    expect(recalled, incidentId);

    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace incident'),
    );
    await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: session.controller.evidenceRepository,
      userId: 'user-6c',
    );
    final restored = await CaptureSessionService.instance.restoreForIncident(
      incidentId: incidentId,
      userId: 'user-6c',
    );

    expect(restored?.id, sessionId);
    expect(restored?.evidenceIds, contains(photoId));
    expect(
      session.controller.evidenceRepository
          .capturedById(photoId)
          ?.captureSessionId,
      sessionId,
    );
  });

  test('9. Legacy evidence without session remains visible', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    const legacyId = 'ev-legacy-no-session';
    final legacyFile = await seedFile('legacy.jpg');

    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: legacyId,
        incidentId: incidentId,
        userId: 'user-6c',
        evidenceType: EvidenceRecordType.photo,
        createdAt: DateTime.now(),
        capturedAt: DateTime.now(),
        syncStatus: EvidenceSyncStatus.localCaptured,
        localFilePath: legacyFile.path,
        fileName: 'legacy.jpg',
        // captureSessionId intentionally null — pre-6C row.
      ),
    );

    final inserted = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: session.controller.evidenceRepository,
      userId: 'user-6c',
    );
    expect(inserted, 1);
    session.controller.scheduleCaptureMetadataPersist();

    final legacy =
        session.controller.evidenceRepository.capturedById(legacyId);
    expect(legacy, isNotNull);
    expect(legacy!.captureSessionId, isNull);
    expect(session.controller.currentIncident.evidenceCount, 1);
    expect(
      session.controller.currentIncident.evidence
          .any((item) => item.id == legacyId),
      isTrue,
    );
    expect(
      session.controller.journeyEvidenceItems
          .any((WorkspaceEvidenceItem item) => item.id == legacyId),
      isTrue,
    );
  });

  test('10. Multiple captures share one active session', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;

    final photo = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: await mediaFor('shared-a.jpg'),
    );
    final note = await session.controller.preserveTextNote('shared note');
    final file = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.file,
      media: await mediaFor('shared.pdf'),
      mimeType: 'application/pdf',
    );

    final active =
        CaptureSessionService.instance.activeSessionFor(incidentId)!;
    expect(active.evidenceIds, containsAll([photo, note, file]));
    expect(
      (await LocalCaptureSessionStore.forIncident(incidentId)).length,
      1,
    );
  });
}
