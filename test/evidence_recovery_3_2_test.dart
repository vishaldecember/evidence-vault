import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/evidence_maturity.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_recovery_32_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    await EvidenceSyncManager.instance.resetForTests();
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-32',
    );
  });

  tearDown(() async {
    await EvidenceSyncManager.instance.resetForTests();
    LocalEvidenceCache.resetForTests();
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
    await file.writeAsBytes(List<int>.filled(16, 7));
    return file;
  }

  test('text note and attachment appear in Captured maturity lane', () async {
    final session = WorkspaceSession.instance;
    await session.controller.preserveTextNote('Visible note body');
    final file = await seedFile('brief.pdf');
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.file,
      media: CapturedMediaFile(
        localPath: file.path,
        fileName: 'brief.pdf',
        fileSizeBytes: 16,
      ),
      mimeType: 'application/pdf',
    );

    final journey = session.controller.journeyEvidenceItems;
    final note = journey.firstWhere((e) => e.kind == WorkspaceEvidenceKind.note);
    final attachment =
        journey.firstWhere((e) => e.kind == WorkspaceEvidenceKind.attachment);

    expect(note.maturity, EvidenceMaturity.capture);
    expect(attachment.maturity, EvidenceMaturity.capture);
    expect(note.notePreview, contains('Visible note'));
    expect(attachment.fileName, 'brief.pdf');
  });

  test(
    'logout/login simulation recovers six types after repository reinit',
    () async {
      final session = WorkspaceSession.instance;
      final photo = await seedFile('p1.jpg');
      final photo2 = await seedFile('p2.jpg');
      final video = await seedFile('v.mp4');
      final voice = await seedFile('a.m4a');
      final file = await seedFile('doc.pdf');

      await session.controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.photo,
        media: CapturedMediaFile(
          localPath: photo.path,
          fileName: 'p1.jpg',
          fileSizeBytes: 16,
          thumbnailPath: photo.path,
        ),
      );
      await session.controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.photo,
        media: CapturedMediaFile(
          localPath: photo2.path,
          fileName: 'p2.jpg',
          fileSizeBytes: 16,
          thumbnailPath: photo2.path,
        ),
      );
      await session.controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.video,
        media: CapturedMediaFile(
          localPath: video.path,
          fileName: 'v.mp4',
          fileSizeBytes: 16,
        ),
      );
      await session.controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.voice,
        media: CapturedMediaFile(
          localPath: voice.path,
          fileName: 'a.m4a',
          fileSizeBytes: 16,
        ),
      );
      await session.controller.preserveTextNote('Recovery note');
      await session.controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.file,
        media: CapturedMediaFile(
          localPath: file.path,
          fileName: 'doc.pdf',
          fileSizeBytes: 16,
        ),
        mimeType: 'application/pdf',
      );

      final incidentId = session.controller.currentIncident.id;
      expect(session.controller.currentIncident.evidenceCount, 6);

      await LocalIncidentPointer.remember(
        userId: 'user-32',
        incidentId: incidentId,
      );

      // Simulate logout: wipe RAM working set (cache survives).
      session.onSignedOut();
      expect(session.controller.currentIncident.evidenceCount, 0);
      expect(session.controller.currentIncident.id, isNot(incidentId));

      // Simulate same-user login + repository reinitialization.
      UserSessionService.establishSession(
        email: 'investigator@example.com',
        name: 'Investigator',
        userId: 'user-32',
      );
      final recalled = await LocalIncidentPointer.recall('user-32');
      expect(recalled, incidentId);

      session.controller.replaceAggregate(
        IncidentAggregate.shell(id: incidentId, title: 'Recovered'),
      );
      final hydrated = await LocalEvidenceHydrator.hydrateIncident(
        incidentId: incidentId,
        repository: session.controller.evidenceRepository,
        userId: 'user-32',
      );
      session.controller.scheduleCaptureMetadataPersist();

      expect(hydrated, 6);
      expect(session.controller.currentIncident.evidenceCount, 6);

      final kinds = session.controller.journeyEvidenceItems
          .map((e) => e.kind)
          .toSet();
      expect(kinds.contains(WorkspaceEvidenceKind.image), isTrue);
      expect(kinds.contains(WorkspaceEvidenceKind.video), isTrue);
      expect(kinds.contains(WorkspaceEvidenceKind.voice), isTrue);
      expect(kinds.contains(WorkspaceEvidenceKind.note), isTrue);
      expect(kinds.contains(WorkspaceEvidenceKind.attachment), isTrue);
    },
  );

  test('empty cloud active recovers richest local incident id', () async {
    const captureId = 'incident-captured-real';
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'ev-photo-1',
        incidentId: captureId,
        userId: 'user-32',
        evidenceType: EvidenceRecordType.photo,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.localCaptured,
        captureMode: WorkspaceCaptureMode.photo,
        localFilePath: p.join(tempRoot.path, 'x.jpg'),
      ),
    );
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'ev-note-1',
        incidentId: captureId,
        userId: 'user-32',
        evidenceType: EvidenceRecordType.note,
        createdAt: now.add(const Duration(seconds: 1)),
        capturedAt: now.add(const Duration(seconds: 1)),
        syncStatus: EvidenceSyncStatus.ready,
        noteText: 'Offline note',
        captureMode: WorkspaceCaptureMode.note,
      ),
    );
    await LocalIncidentPointer.remember(
      userId: 'user-32',
      incidentId: captureId,
    );

    final session = WorkspaceSession.instance;
    // Post-logout empty draft (wrong id).
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-empty-draft'),
    );
    expect(session.controller.currentIncident.evidenceCount, 0);

    final recovered =
        await LocalEvidenceCache.richestIncidentId(userId: 'user-32');
    expect(recovered, captureId);

    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: recovered!),
    );
    final n = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: recovered,
      repository: session.controller.evidenceRepository,
      userId: 'user-32',
    );
    session.controller.scheduleCaptureMetadataPersist();
    expect(n, 2);
    expect(session.controller.currentIncident.evidenceCount, 2);
  });

  test('crash barrier: dispose/reinit repository keeps committed evidence',
      () async {
    final session = WorkspaceSession.instance;
    final photo = await seedFile('crash2.jpg');
    final id = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'crash2.jpg',
        fileSizeBytes: 16,
        thumbnailPath: photo.path,
      ),
    );
    final incidentId = session.controller.currentIncident.id;
    expect(await LocalEvidenceCache.byId(id), isNotNull);

    // Dispose working set and reinit empty repository.
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId),
    );
    expect(session.controller.currentIncident.evidenceCount, 0);

    final restored = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: session.controller.evidenceRepository,
    );
    expect(restored, 1);
  });
}
