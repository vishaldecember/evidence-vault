import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/evidence_artifact_model.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/persistence/local_incident_pointer.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/local_evidence_hydrator.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/workspace/living_evidence_preview.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_recovery_33_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    await EvidenceSyncManager.instance.resetForTests();
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-33',
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
    await file.writeAsBytes(List<int>.filled(24, 9));
    return file;
  }

  test('1. named incident survives logout/login with same id + evidence',
      () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    session.controller.updateIncidentName('workplace incident');
    final photo = await seedFile('scene.jpg');
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'scene.jpg',
        fileSizeBytes: 24,
        thumbnailPath: photo.path,
      ),
    );

    expect(session.controller.currentIncident.title, 'workplace incident');
    expect(await LocalIncidentPointer.recall('user-33'), incidentId);
    expect(
      await LocalIncidentPointer.recallTitle('user-33'),
      'workplace incident',
    );

    session.onSignedOut();
    expect(session.controller.currentIncident.id, isNot(incidentId));

    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-33',
    );
    final recalled = await LocalIncidentPointer.recall('user-33');
    expect(recalled, incidentId);
    final title = await LocalIncidentPointer.recallTitle('user-33');
    expect(title, 'workplace incident');

    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: title ?? ''),
    );
    final n = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: session.controller.evidenceRepository,
      userId: 'user-33',
    );
    session.controller.scheduleCaptureMetadataPersist();
    expect(n, 1);
    expect(session.controller.currentIncident.id, incidentId);
    expect(session.controller.currentIncident.title, 'workplace incident');
    expect(session.controller.currentIncident.evidenceCount, 1);
  });

  test('2. incident name persists across repository reinit', () async {
    final session = WorkspaceSession.instance;
    final id = session.controller.currentIncident.id;
    session.controller.updateIncidentName('workplace incident');
    await LocalIncidentPointer.remember(
      userId: 'user-33',
      incidentId: id,
      title: 'workplace incident',
    );

    session.controller.replaceAggregate(IncidentAggregate.shell(id: id));
    expect(session.controller.currentIncident.title, isEmpty);

    final restored = await LocalIncidentPointer.recallTitleForIncident(
      userId: 'user-33',
      incidentId: id,
    );
    session.controller.updateIncidentName(restored!);
    expect(session.controller.currentIncident.title, 'workplace incident');
  });

  test('4. separate incident ids stay separate even with same title', () {
    final a = IncidentAggregate.shell(id: 'incident-a', title: 'Same Title');
    final b = IncidentAggregate.shell(id: 'incident-b', title: 'Same Title');
    expect(a.incident.id, isNot(b.incident.id));
    expect(a.incident.title, b.incident.title);
  });

  test('5-9. capture method is authoritative for semantic kinds', () async {
    final session = WorkspaceSession.instance;
    final photo = await seedFile('p.jpg');
    final video = await seedFile('v.mp4');
    final voice = await seedFile('a.m4a');
    final imageAsFile = await seedFile('picked.jpg');

    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'p.jpg',
        fileSizeBytes: 24,
        thumbnailPath: photo.path,
      ),
    );
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.video,
      media: CapturedMediaFile(
        localPath: video.path,
        fileName: 'v.mp4',
        fileSizeBytes: 24,
      ),
    );
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.voice,
      media: CapturedMediaFile(
        localPath: voice.path,
        fileName: 'a.m4a',
        fileSizeBytes: 24,
      ),
    );
    await session.controller.preserveTextNote('typed note');
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.file,
      media: CapturedMediaFile(
        localPath: imageAsFile.path,
        fileName: 'picked.jpg',
        fileSizeBytes: 24,
        thumbnailPath: imageAsFile.path,
      ),
      mimeType: 'image/jpeg',
    );

    final journey = session.controller.journeyEvidenceItems;
    expect(
      journey.where((e) => e.kind == WorkspaceEvidenceKind.image),
      hasLength(1),
    );
    expect(
      journey.where((e) => e.kind == WorkspaceEvidenceKind.video),
      hasLength(1),
    );
    expect(
      journey.where((e) => e.kind == WorkspaceEvidenceKind.voice),
      hasLength(1),
    );
    expect(
      journey.where((e) => e.kind == WorkspaceEvidenceKind.note),
      hasLength(1),
    );
    final fileItem = journey.firstWhere(
      (e) => e.kind == WorkspaceEvidenceKind.attachment,
    );
    expect(fileItem.mimeType, 'image/jpeg');
    expect(fileItem.kind, isNot(WorkspaceEvidenceKind.image));
    expect(
      EvidenceArtifactModel.fromWorkspaceItem(fileItem).type,
      EvidenceArtifactType.document,
    );
  });

  test('10. FILE with image MIME stays attachment after hydrate', () async {
    const incidentId = 'incident-file-type';
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: 'ev-file-img',
        incidentId: incidentId,
        userId: 'user-33',
        evidenceType: EvidenceRecordType.document,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.localCaptured,
        localFilePath: p.join(tempRoot.path, 'picked.jpg'),
        fileName: 'picked.jpg',
        mimeType: 'image/jpeg',
        captureMode: WorkspaceCaptureMode.file,
      ),
    );

    final session = WorkspaceSession.instance;
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId),
    );
    final n = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: session.controller.evidenceRepository,
      userId: 'user-33',
    );
    expect(n, 1);
    // Same refresh production openIncident uses after a successful hydrate.
    session.controller.scheduleCaptureMetadataPersist();
    final item = session.controller.journeyEvidenceItems.single;
    expect(item.kind, WorkspaceEvidenceKind.attachment);
    expect(item.mimeType, 'image/jpeg');
  });

  testWidgets('FILE tile never uses photo Image widget for image MIME',
      (tester) async {
    final item = WorkspaceEvidenceItem(
      id: 'file-1',
      kind: WorkspaceEvidenceKind.attachment,
      title: 'Attachment',
      lastPreservedAt: DateTime(2026, 8, 9, 12),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      fileName: 'picked.jpg',
      filePath: p.join(tempRoot.path, 'picked.jpg'),
      thumbnailPath: p.join(tempRoot.path, 'picked.jpg'),
      mimeType: 'image/jpeg',
      fileSizeBytes: 24,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LivingEvidencePreview(item: item),
        ),
      ),
    );

    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    expect(find.textContaining('FILE'), findsOneWidget);
    expect(find.textContaining('picked.jpg'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('VIDEO tile always shows play overlay', (tester) async {
    final item = WorkspaceEvidenceItem(
      id: 'vid-1',
      kind: WorkspaceEvidenceKind.video,
      title: 'Video',
      lastPreservedAt: DateTime(2026, 8, 9, 12),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      fileName: 'clip.mp4',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LivingEvidencePreview(item: item),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
