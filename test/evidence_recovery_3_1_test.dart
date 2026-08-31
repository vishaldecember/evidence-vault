import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/models/workspace_resume_target.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/local_evidence_hydrator.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/widgets/capture/text_note_capture_sheet.dart';
import 'package:flutter/material.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_recovery_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    await EvidenceSyncManager.instance.resetForTests();
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
    WorkspaceSession.instance.reset();
  });

  tearDown(() async {
    await EvidenceSyncManager.instance.resetForTests();
    LocalEvidenceCache.resetForTests();
    WorkspaceSession.instance.reset();
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {
      // Windows may lock temp files briefly — ignore.
    }
  });

  Future<File> seedFile(String name) async {
    final file = File(p.join(tempRoot.path, name));
    await file.writeAsBytes(List<int>.filled(12, 3));
    return file;
  }

  test('A. Text Note creates dedicated evidence without parent', () async {
    final session = WorkspaceSession.instance;
    final id = await session.controller.preserveTextNote('Witness saw red car');
    final note = session.controller.evidenceRepository.supportingById(id);
    expect(note, isNotNull);
    expect(note!.notePreview, 'Witness saw red car');
    expect(note.parentEvidenceId, isNull);
    expect(
      session.controller.journeyEvidenceItems.any((e) => e.id == id),
      isTrue,
    );
  });

  testWidgets('B. Text Note opens text input sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    final future = TextNoteCaptureSheet.open(
      tester.element(find.byType(Scaffold)),
    );
    await tester.pump(); // sheet route
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Text Note'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Saved note body');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await future, 'Saved note body');
  });

  test('C. Text Note appears as journey thumbnail kind note', () async {
    final session = WorkspaceSession.instance;
    session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final noteId =
        await session.controller.preserveTextNote('Chronology note');
    final journey = session.controller.journeyEvidenceItems;
    expect(
      journey.any(
        (e) => e.id == noteId && e.kind == WorkspaceEvidenceKind.note,
      ),
      isTrue,
    );
    final noteItem = journey.firstWhere((e) => e.id == noteId);
    expect(noteItem.notePreview, contains('Chronology'));
  });

  test('E. File attachment creates dedicated evidence', () async {
    final session = WorkspaceSession.instance;
    final file = await seedFile('report.pdf');
    final id = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.file,
      media: CapturedMediaFile(
        localPath: file.path,
        fileName: 'report.pdf',
        fileSizeBytes: 12,
      ),
      mimeType: 'application/pdf',
      linkToNearestPrimary: false,
    );
    final item = session.controller.evidenceRepository.supportingById(id);
    expect(item, isNotNull);
    expect(item!.parentEvidenceId, isNull);
    expect(item.fileName, 'report.pdf');
  });

  test('F. Workspace reconstructs evidence from local cache', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'cached-photo',
        incidentId: incidentId,
        userId: 'u1',
        evidenceType: EvidenceRecordType.photo,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.queuedForUpload,
        localFilePath: p.join(tempRoot.path, 'p.jpg'),
        captureMode: WorkspaceCaptureMode.photo,
      ),
    );
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'cached-note',
        incidentId: incidentId,
        userId: 'u1',
        evidenceType: EvidenceRecordType.note,
        createdAt: now.add(const Duration(seconds: 1)),
        capturedAt: now.add(const Duration(seconds: 1)),
        syncStatus: EvidenceSyncStatus.ready,
        noteText: 'Recovered note',
        captureMode: WorkspaceCaptureMode.note,
      ),
    );

    final count = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: session.controller.evidenceRepository,
    );
    expect(count, 2);
    expect(
      session.controller.evidenceRepository.containsEvidenceId('cached-note'),
      isTrue,
    );
    final note =
        session.controller.evidenceRepository.supportingById('cached-note');
    expect(note?.notePreview, 'Recovered note');
  });

  test('G. Five evidence types survive wipe + hydrate (restart)', () async {
    final session = WorkspaceSession.instance;
    final photo = await seedFile('a.jpg');
    final video = await seedFile('b.mp4');
    final voice = await seedFile('c.m4a');
    final file = await seedFile('d.pdf');

    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'a.jpg',
        fileSizeBytes: 12,
        thumbnailPath: photo.path,
      ),
    );
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.video,
      media: CapturedMediaFile(
        localPath: video.path,
        fileName: 'b.mp4',
        fileSizeBytes: 12,
      ),
    );
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.voice,
      media: CapturedMediaFile(
        localPath: voice.path,
        fileName: 'c.m4a',
        fileSizeBytes: 12,
      ),
    );
    await session.controller.preserveTextNote('Fifth is text');
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.file,
      media: CapturedMediaFile(
        localPath: file.path,
        fileName: 'd.pdf',
        fileSizeBytes: 12,
      ),
      mimeType: 'application/pdf',
    );

    final incidentId = session.controller.currentIncident.id;
    expect(session.controller.currentIncident.evidenceCount, 5);

    final cached = await LocalEvidenceCache.forIncident(incidentId);
    expect(cached.length, 5);

    // Simulate restart: new empty aggregate with same incident id, then
    // reopen via the production openIncident → hydrate path.
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Recovered'),
    );
    expect(session.controller.currentIncident.evidenceCount, 0);

    final opened = await session.openIncident(incidentId);
    expect(opened, isTrue);
    await session.waitForPendingOpenWork();
    expect(session.controller.currentIncident.evidenceCount, 5);
    expect(
      session.controller.journeyEvidenceItems
          .map((e) => e.kind)
          .toSet()
          .length,
      greaterThanOrEqualTo(4),
    );
  });

  test('D. File attachment keeps incident identity (no Home reset)', () async {
    final session = WorkspaceSession.instance;
    session.enterCapture();
    final beforeId = session.controller.currentIncident.id;
    final file = await seedFile('keep.pdf');
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.file,
      media: CapturedMediaFile(
        localPath: file.path,
        fileName: 'keep.pdf',
        fileSizeBytes: 12,
      ),
      mimeType: 'application/pdf',
      linkToNearestPrimary: false,
    );
    expect(session.controller.currentIncident.id, beforeId);
    expect(session.resumeTarget, WorkspaceResumeTarget.incidentWorkspace);
    expect(session.controller.currentIncident.evidenceCount, 1);
  });

  test('H. openIncident same-id still hydrates from cache', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'reopen-1',
        incidentId: incidentId,
        userId: 'u',
        evidenceType: EvidenceRecordType.note,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.ready,
        noteText: 'Still here',
        captureMode: WorkspaceCaptureMode.note,
      ),
    );

    // Wipe RAM but keep same id.
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId),
    );
    expect(session.controller.currentIncident.evidenceCount, 0);

    final opened = await session.openIncident(incidentId);
    expect(opened, isTrue);
    await session.waitForPendingOpenWork();
    expect(
      session.controller.evidenceRepository.containsEvidenceId('reopen-1'),
      isTrue,
    );
  });

  test('I. Logout/login restores authorized local evidence', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'auth-note-1',
        incidentId: incidentId,
        userId: 'user-a',
        evidenceType: EvidenceRecordType.note,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.ready,
        noteText: 'Mine',
        captureMode: WorkspaceCaptureMode.note,
      ),
    );
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'auth-note-foreign',
        incidentId: incidentId,
        userId: 'user-b',
        evidenceType: EvidenceRecordType.note,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.ready,
        noteText: 'Not mine',
        captureMode: WorkspaceCaptureMode.note,
      ),
    );

    session.onSignedOut();
    expect(session.controller.currentIncident.evidenceCount, 0);

    // Same device cache survives; reopen incident as authorized user.
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId),
    );
    final restored = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: session.controller.evidenceRepository,
      userId: 'user-a',
    );
    expect(restored, 1);
    expect(
      session.controller.evidenceRepository.containsEvidenceId('auth-note-1'),
      isTrue,
    );
    expect(
      session.controller.evidenceRepository
          .containsEvidenceId('auth-note-foreign'),
      isFalse,
    );
  });

  test('J. Capture commit survives immediate termination barrier', () async {
    final session = WorkspaceSession.instance;
    final photo = await seedFile('crash.jpg');
    final id = await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'crash.jpg',
        fileSizeBytes: 12,
        thumbnailPath: photo.path,
      ),
    );
    // Local commit completed before return — cache must already contain row.
    final cached = await LocalEvidenceCache.byId(id);
    expect(cached, isNotNull);
    expect(cached!.incidentId, session.controller.currentIncident.id);

    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: cached.incidentId),
    );
    final n = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: cached.incidentId,
      repository: session.controller.evidenceRepository,
    );
    expect(n, 1);
  });

  test('K. Evidence maintains chronological capture order', () async {
    final session = WorkspaceSession.instance;
    session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await session.controller.preserveTextNote('middle note');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    session.controller.preserveEvidence(WorkspaceCaptureMode.voice);
    final journey = session.controller.journeyEvidenceItems;
    expect(journey.length, greaterThanOrEqualTo(3));
    final noteIndex =
        journey.indexWhere((e) => e.kind == WorkspaceEvidenceKind.note);
    final photoIndex =
        journey.indexWhere((e) => e.kind == WorkspaceEvidenceKind.image);
    final voiceIndex =
        journey.indexWhere((e) => e.kind == WorkspaceEvidenceKind.voice);
    expect(noteIndex, isNot(-1));
    expect(photoIndex, isNot(-1));
    expect(voiceIndex, isNot(-1));
    expect(photoIndex, lessThan(noteIndex));
    expect(noteIndex, lessThan(voiceIndex));
  });

  test('L. Multiple captures never overwrite each other', () async {
    final session = WorkspaceSession.instance;
    final a = await session.controller.preserveTextNote('One');
    final b = await session.controller.preserveTextNote('Two');
    expect(a, isNot(b));
    expect(session.controller.currentIncident.evidenceCount, 2);
  });

  test('M. Local reconstruction does not require Firebase', () async {
    final session = WorkspaceSession.instance;
    final id = session.controller.currentIncident.id;
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'offline-1',
        incidentId: id,
        userId: 'u',
        evidenceType: EvidenceRecordType.photo,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.localCaptured,
        localFilePath: p.join(tempRoot.path, 'off.jpg'),
        captureMode: WorkspaceCaptureMode.photo,
      ),
    );
    final n = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: id,
      repository: session.controller.evidenceRepository,
    );
    expect(n, 1);
    expect(
      session.controller.evidenceRepository.containsEvidenceId('offline-1'),
      isTrue,
    );
  });
}
