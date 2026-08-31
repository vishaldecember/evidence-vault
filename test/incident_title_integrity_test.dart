import 'dart:io';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/library_incident_record.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/persistence/local_incident_pointer.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:flutter_test/flutter_test.dart';
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

  const userId = 'user-title-integrity';
  late Directory tempRoot;
  final manager = CaptureSessionManager.instance;

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_title_integrity_');
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
      userId: userId,
    );
    await LocalIncidentPointer.clearForTests(userId);
    IncidentLibraryService.instance.clear();
  }

  Future<void> cleanupEnv() async {
    await EvidenceSyncManager.instance.resetForTests();
    await manager.resetForTests();
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    await LocalIncidentPointer.clearForTests(userId);
    IncidentLibraryService.instance.clear();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {}
  }

  void seedLibrary({
    required String a,
    required String b,
    required String c,
  }) {
    IncidentLibraryService.instance.restoreSnapshot(
      summaries: [
        LibraryIncidentSummary(
          id: 'incident-A',
          title: a,
          evidenceCount: 1,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'Just now',
          isInProgress: true,
        ),
        LibraryIncidentSummary(
          id: 'incident-B',
          title: b,
          evidenceCount: 1,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'Just now',
          isInProgress: true,
        ),
        LibraryIncidentSummary(
          id: 'incident-C',
          title: c,
          evidenceCount: 0,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'Just now',
          isInProgress: true,
        ),
      ],
      records: [
        LibraryIncidentRecord(
          id: 'incident-A',
          title: a,
          preservedAt: DateTime(2026, 1, 1),
        ),
        LibraryIncidentRecord(
          id: 'incident-B',
          title: b,
          preservedAt: DateTime(2026, 1, 2),
        ),
        LibraryIncidentRecord(
          id: 'incident-C',
          title: c,
          preservedAt: DateTime(2026, 1, 3),
        ),
      ],
    );
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  test('A. title isolation — rename C does not change A or B', () async {
    final a = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-A'),
    );
    final b = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-B'),
    );
    final c = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-C'),
    );

    a.updateIncidentName('Street Fight');
    b.updateIncidentName('Workplace Incident');
    expect(c.currentIncident.title, isEmpty);

    c.updateIncidentName('Apartment Dispute');

    expect(a.currentIncident.title, 'Street Fight');
    expect(b.currentIncident.title, 'Workplace Incident');
    expect(c.currentIncident.title, 'Apartment Dispute');
    expect(
      await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: 'incident-A',
      ),
      'Street Fight',
    );
    expect(
      await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: 'incident-B',
      ),
      'Workplace Incident',
    );
    expect(
      await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: 'incident-C',
      ),
      'Apartment Dispute',
    );
  });

  test(
    'B. cross-id recovery never applies another incident title',
    () async {
      await LocalIncidentPointer.rememberTitle(
        userId: userId,
        incidentId: 'incident-A',
        title: 'Street Fight',
      );
      await LocalIncidentPointer.rememberTitle(
        userId: userId,
        incidentId: 'incident-B',
        title: 'Workplace Incident',
      );
      // Simulate recoveredId != cloudId: active aggregate holds A's title,
      // but recovery asks for B — must never receive "Street Fight".
      WorkspaceSession.instance.controller.replaceAggregate(
        IncidentAggregate.shell(id: 'incident-A', title: 'Street Fight'),
      );

      final resolvedB =
          await WorkspaceSession.instance.resolveTitleForIncidentForTests(
        userId: userId,
        incidentId: 'incident-B',
      );
      expect(resolvedB, 'Workplace Incident');
      expect(resolvedB, isNot('Street Fight'));

      final resolvedUnknown =
          await WorkspaceSession.instance.resolveTitleForIncidentForTests(
        userId: userId,
        incidentId: 'incident-C',
      );
      expect(resolvedUnknown, isEmpty);
    },
  );

  test(
    'C. empty hydration does not bleed into another incident title',
    () async {
      await LocalIncidentPointer.rememberTitle(
        userId: userId,
        incidentId: 'incident-A',
        title: 'Street Fight',
      );

      // Hydration-style remember with empty title for B — must not wipe A,
      // and must not invent a title for B from A.
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: 'incident-B',
        title: '',
      );

      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: 'incident-A',
        ),
        'Street Fight',
      );
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: 'incident-B',
        ),
        isNull,
      );

      final shellB = IncidentAggregate.shell(id: 'incident-B', title: '');
      expect(shellB.incident.title, isEmpty);
      expect(
        await WorkspaceSession.instance.resolveTitleForIncidentForTests(
          userId: userId,
          incidentId: 'incident-B',
        ),
        isEmpty,
      );
    },
  );

  test('D. title survives restart / persistence reinit', () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-A'),
    );
    controller.updateIncidentName('Street Fight');
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-A',
      title: 'Street Fight',
    );

    // Recreate session/controller — simulate app restart.
    WorkspaceSession.instance.reset();
    final restoredTitle = await LocalIncidentPointer.recallTitleForIncident(
      userId: userId,
      incidentId: 'incident-A',
    );
    expect(restoredTitle, 'Street Fight');

    WorkspaceSession.instance.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-A', title: restoredTitle ?? ''),
    );
    expect(
      WorkspaceSession.instance.controller.currentIncident.title,
      'Street Fight',
    );
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      'incident-A',
    );
  });

  test('E. Library isolation — only matching card updates', () async {
    seedLibrary(
      a: 'Street Fight',
      b: 'Workplace Incident',
      c: 'Untitled Incident',
    );

    IncidentLibraryService.instance.patchTitle(
      'incident-C',
      'Apartment Dispute',
    );

    final byId = {
      for (final s in IncidentLibraryService.instance.summaries) s.id: s.title,
    };
    expect(byId['incident-A'], 'Street Fight');
    expect(byId['incident-B'], 'Workplace Incident');
    expect(byId['incident-C'], 'Apartment Dispute');
    expect(byId.length, 3);
  });

  test('F. evidence identity unchanged after rename', () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-A'),
    );
    await manager.getOrCreateActiveSession(
      incidentId: 'incident-A',
      userId: userId,
    );
    final photo = File('${tempRoot.path}/a.jpg')
      ..writeAsBytesSync(List<int>.filled(16, 1));
    final evidenceId = await controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: photo.path,
        fileName: 'a.jpg',
        fileSizeBytes: 16,
        thumbnailPath: photo.path,
      ),
    );

    controller.updateIncidentName('Street Fight');

    expect(controller.currentIncident.id, 'incident-A');
    expect(
      controller.evidenceRepository.recordById(evidenceId)?.incidentId,
      'incident-A',
    );
    expect(controller.currentIncident.evidenceCount, 1);
    expect(controller.currentIncident.title, 'Street Fight');
  });

  test('G. multiple incident switching — no title contamination', () async {
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-A',
      title: 'Street Fight',
    );
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-B',
      title: 'Workplace Incident',
    );
    seedLibrary(
      a: 'Street Fight',
      b: 'Workplace Incident',
      c: 'Untitled Incident',
    );

    final session = WorkspaceSession.instance;

    final titleA1 = await session.resolveTitleForIncidentForTests(
      userId: userId,
      incidentId: 'incident-A',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-A', title: titleA1),
    );
    expect(session.controller.currentIncident.title, 'Street Fight');

    final titleB = await session.resolveTitleForIncidentForTests(
      userId: userId,
      incidentId: 'incident-B',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-B', title: titleB),
    );
    expect(session.controller.currentIncident.title, 'Workplace Incident');

    final titleA2 = await session.resolveTitleForIncidentForTests(
      userId: userId,
      incidentId: 'incident-A',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-A', title: titleA2),
    );
    expect(session.controller.currentIncident.title, 'Street Fight');

    final titleB2 = await session.resolveTitleForIncidentForTests(
      userId: userId,
      incidentId: 'incident-B',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-B', title: titleB2),
    );
    expect(session.controller.currentIncident.title, 'Workplace Incident');
  });

  test('H. explicit clear only affects that incident', () async {
    final a = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-A', title: 'Street Fight'),
    );
    final b = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(
        id: 'incident-B',
        title: 'Workplace Incident',
      ),
    );
    final c = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(
        id: 'incident-C',
        title: 'Apartment Dispute',
      ),
    );
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-A',
      title: 'Street Fight',
    );
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-B',
      title: 'Workplace Incident',
    );
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-C',
      title: 'Apartment Dispute',
    );
    seedLibrary(
      a: 'Street Fight',
      b: 'Workplace Incident',
      c: 'Apartment Dispute',
    );

    a.updateIncidentName('');

    expect(a.currentIncident.title, isEmpty);
    expect(b.currentIncident.title, 'Workplace Incident');
    expect(c.currentIncident.title, 'Apartment Dispute');
    expect(
      await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: 'incident-A',
      ),
      isNull,
    );
    expect(
      await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: 'incident-B',
      ),
      'Workplace Incident',
    );
    expect(
      await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: 'incident-C',
      ),
      'Apartment Dispute',
    );

    final byId = {
      for (final s in IncidentLibraryService.instance.summaries) s.id: s.title,
    };
    expect(byId['incident-A'], 'Untitled Incident');
    expect(byId['incident-B'], 'Workplace Incident');
    expect(byId['incident-C'], 'Apartment Dispute');
  });
}
