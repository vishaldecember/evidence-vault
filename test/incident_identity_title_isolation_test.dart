import 'dart:io';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/library_incident_record.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/investigation_data_deletion_service.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/persistence/local_incident_pointer.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/services/vault_reset_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

Future<void> _noop() async {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-identity-8b';
  late Directory tempRoot;
  final manager = CaptureSessionManager.instance;

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_identity_8b_');
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
    await LocalIncidentPointer.clearAllForUser(userId);
    IncidentLibraryService.instance.clear();
    VaultResetService.resetForTests();
  }

  Future<void> cleanupEnv() async {
    await EvidenceSyncManager.instance.resetForTests();
    await manager.resetForTests();
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    await LocalIncidentPointer.clearAllForUser(userId);
    IncidentLibraryService.instance.clear();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    VaultResetService.resetForTests();
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {}
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  test('1. new incident gets new id', () async {
    final session = WorkspaceSession.instance;
    final a = session.controller.currentIncident.id;
    await session.beginNewCaptureIncident();
    final b = session.controller.currentIncident.id;
    expect(a, isNot(b));
    expect(b.startsWith('incident-'), isTrue);
  });

  test('2. new incident starts untitled after prior rename', () async {
    final session = WorkspaceSession.instance;
    session.controller.updateIncidentName('Street Fight');
    final aId = session.controller.currentIncident.id;
    expect(session.controller.currentIncident.title, 'Street Fight');

    await session.beginNewCaptureIncident();
    final bId = session.controller.currentIncident.id;

    expect(bId, isNot(aId));
    expect(session.controller.currentIncident.title, isEmpty);
    expect(
      await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: bId,
      ),
      isNull,
    );
    expect(
      await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: aId,
      ),
      'Street Fight',
    );
  });

  test('3. title never bleeds across switches', () async {
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-A',
      title: 'Street Fight',
    );
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-C',
      title: 'Workplace Incident',
    );

    final session = WorkspaceSession.instance;
    for (final id in ['incident-A', 'incident-B', 'incident-C', 'incident-A', 'incident-B']) {
      final title = await session.resolveTitleForIncidentForTests(
        userId: userId,
        incidentId: id,
      );
      session.controller.replaceAggregate(
        IncidentAggregate.shell(id: id, title: title),
      );
    }

    expect(
      await session.resolveTitleForIncidentForTests(
        userId: userId,
        incidentId: 'incident-A',
      ),
      'Street Fight',
    );
    expect(
      await session.resolveTitleForIncidentForTests(
        userId: userId,
        incidentId: 'incident-B',
      ),
      isEmpty,
    );
    expect(
      await session.resolveTitleForIncidentForTests(
        userId: userId,
        incidentId: 'incident-C',
      ),
      'Workplace Incident',
    );
  });

  test('4. Library isolation by incidentId', () async {
    IncidentLibraryService.instance.restoreSnapshot(
      summaries: const [
        LibraryIncidentSummary(
          id: 'incident-A',
          title: 'Street Fight',
          evidenceCount: 1,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'Just now',
          isInProgress: true,
        ),
        LibraryIncidentSummary(
          id: 'incident-B',
          title: 'Untitled Incident',
          evidenceCount: 0,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'Just now',
          isInProgress: true,
        ),
        LibraryIncidentSummary(
          id: 'incident-C',
          title: 'Workplace Incident',
          evidenceCount: 1,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'Just now',
          isInProgress: true,
        ),
      ],
      records: [
        LibraryIncidentRecord(
          id: 'incident-A',
          title: 'Street Fight',
          preservedAt: DateTime(2026, 1, 1),
        ),
        LibraryIncidentRecord(
          id: 'incident-B',
          title: 'Untitled Incident',
          preservedAt: DateTime(2026, 1, 2),
        ),
        LibraryIncidentRecord(
          id: 'incident-C',
          title: 'Workplace Incident',
          preservedAt: DateTime(2026, 1, 3),
        ),
      ],
    );

    WorkspaceSession.instance.controller.updateIncidentName('Street Fight');
    IncidentLibraryService.instance.patchTitle('incident-B', 'Should Not Matter');
    // Only B card changes — A/C untouched.
    final byId = {
      for (final s in IncidentLibraryService.instance.summaries) s.id: s.title,
    };
    expect(byId['incident-A'], 'Street Fight');
    expect(byId['incident-B'], 'Should Not Matter');
    expect(byId['incident-C'], 'Workplace Incident');
  });

  test('5. restart isolation — A titled, B untitled', () async {
    final a = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-A'),
    );
    a.updateIncidentName('Street Fight');
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-A',
      title: 'Street Fight',
    );
    await LocalIncidentPointer.remember(
      userId: userId,
      incidentId: 'incident-B',
    );

    WorkspaceSession.instance.reset();

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
  });

  test('6. recovery id mismatch — no title cross-copy', () async {
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'cloud-active',
      title: 'Street Fight',
    );
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'recovered',
      title: 'Workplace Incident',
    );
    // Active aggregate holds cloud title — recovery asks for recovered id.
    WorkspaceSession.instance.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'cloud-active', title: 'Street Fight'),
    );

    final resolved =
        await WorkspaceSession.instance.resolveTitleForIncidentForTests(
      userId: userId,
      incidentId: 'recovered',
    );
    expect(resolved, 'Workplace Incident');
    expect(resolved, isNot('Street Fight'));
  });

  test(
    '7. Vault clear — new incident must not inherit Street Fight',
    () async {
      final session = WorkspaceSession.instance;
      final aId = session.controller.currentIncident.id;
      session.controller.updateIncidentName('Street Fight');
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: aId,
        title: 'Street Fight',
      );
      // Simulate pre-fix legacy contamination still present in prefs.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ev_last_capture_title_v1_$userId', 'Street Fight');

      const vault = VaultResetService(
        investigationDataDeletionService: InvestigationDataDeletionService(
          deletePersistedMedia: _noop,
          removeCloudBackups: _noop,
          removeSearchIndexes: _noop,
        ),
      );
      await vault.clearVault();

      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: aId,
        ),
        isNull,
      );
      expect(prefs.getString('ev_last_capture_title_v1_$userId'), isNull);

      await session.beginNewCaptureIncident();
      final bId = session.controller.currentIncident.id;
      expect(bId, isNot(aId));
      expect(session.controller.currentIncident.title, isEmpty);

      // Pointer rotation alone must never resurrect legacy title onto B.
      await LocalIncidentPointer.remember(userId: userId, incidentId: bId);
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: bId,
        ),
        isNull,
      );
      final resolved = await session.resolveTitleForIncidentForTests(
        userId: userId,
        incidentId: bId,
      );
      expect(resolved, isEmpty);
    },
  );

  test('8. evidence stays with incident after rename', () async {
    final controller = WorkspaceSession.instance.controller;
    final aId = controller.currentIncident.id;
    await manager.getOrCreateActiveSession(incidentId: aId, userId: userId);
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

    expect(controller.currentIncident.id, aId);
    expect(
      controller.evidenceRepository.recordById(evidenceId)?.incidentId,
      aId,
    );
    expect(controller.currentIncident.title, 'Street Fight');
  });

  test('9. explicit rename only affects that incident', () async {
    final a = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-A'),
    );
    final b = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'incident-B'),
    );
    a.updateIncidentName('Street Fight');
    expect(a.currentIncident.title, 'Street Fight');
    expect(b.currentIncident.title, isEmpty);
  });

  test('10. multiple new incidents — unique ids, all untitled', () async {
    final session = WorkspaceSession.instance;
    final ids = <String>{};
    for (var i = 0; i < 5; i++) {
      await session.beginNewCaptureIncident();
      final id = session.controller.currentIncident.id;
      expect(ids.add(id), isTrue, reason: 'duplicate id $id');
      expect(session.controller.currentIncident.title, isEmpty);
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: id,
        ),
        isNull,
      );
    }
  });

  test(
    'legacy user-scoped title never contaminates a rotated last-capture id',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ev_last_capture_incident_v1_$userId', 'incident-NEW');
      await prefs.setString('ev_last_capture_title_v1_$userId', 'Street Fight');

      final title = await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: 'incident-NEW',
      );
      expect(title, isNull);
      expect(prefs.getString('ev_last_capture_title_v1_$userId'), isNull);
    },
  );

  test(
    'in-flight rememberTitle after Clear Vault cannot resurrect Street Fight',
    () async {
      final aId = WorkspaceSession.instance.controller.currentIncident.id;
      // Start write, then clear before it completes — epoch must drop it.
      final pending = LocalIncidentPointer.rememberTitle(
        userId: userId,
        incidentId: aId,
        title: 'Street Fight',
      );
      await LocalIncidentPointer.clearAllForUser(userId);
      await pending;

      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: aId,
        ),
        isNull,
      );

      await WorkspaceSession.instance.beginNewCaptureIncident();
      final bId = WorkspaceSession.instance.controller.currentIncident.id;
      expect(bId, isNot(aId));
      expect(WorkspaceSession.instance.controller.currentIncident.title, isEmpty);
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: bId,
        ),
        isNull,
      );
    },
  );
}
