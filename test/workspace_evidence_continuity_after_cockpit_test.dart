import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Reproduces Sprint 6C P0: after Continue Preserving, a new CaptureSession
/// only tracks newly captured ids. Workspace must still show the full journey.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final manager = CaptureSessionManager.instance;
  const userId = 'user-continuity-p0';

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_continuity_');
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
  }

  Future<void> cleanupEnv() async {
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
  }

  Future<void> pumpWorkspace(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();
  }

  /// Seeds E1..En, completes that CaptureSession (DONE), then opens a fresh
  /// active session — matching Continue Preserving after DONE.
  Future<(String incidentId, List<String> priorIds)> seedExistingIncident(
    WidgetTester tester, {
    required int priorCount,
    List<WorkspaceCaptureMode>? modes,
  }) async {
    late String incidentId;
    late List<String> priorIds;
    await tester.runAsync(() async {
      final session = WorkspaceSession.instance;
      incidentId = session.controller.currentIncident.id;
      session.controller.replaceAggregate(
        IncidentAggregate.shell(id: incidentId, title: 'Existing incident'),
      );
      final firstSession = await manager.getOrCreateActiveSession(
        incidentId: incidentId,
        userId: userId,
      );

      priorIds = <String>[];
      final captureModes = modes ??
          List<WorkspaceCaptureMode>.generate(
            priorCount,
            (_) => WorkspaceCaptureMode.photo,
          );
      for (final mode in captureModes) {
        final id = session.controller.preserveForWidgetTest(mode);
        priorIds.add(id);
        await manager.attachEvidenceToSession(
          sessionId: firstSession.id,
          evidenceId: id,
        );
      }
      expect(session.controller.currentIncident.evidenceCount, priorCount);

      await manager.completeSession(sessionId: firstSession.id);
      expect(manager.getOpenSession(incidentId), isNull);

      final resumed = await manager.getOrCreateActiveSession(
        incidentId: incidentId,
        userId: userId,
      );
      expect(resumed.id, isNot(firstSession.id));
      expect(resumed.evidenceIds, isEmpty);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, priorCount);
    });
    return (incidentId, priorIds);
  }

  Future<String> captureIntoNewSession(
    WidgetTester tester, {
    required String incidentId,
    WorkspaceCaptureMode mode = WorkspaceCaptureMode.photo,
  }) async {
    late String id;
    await tester.runAsync(() async {
      final controller = WorkspaceSession.instance.controller;
      final open = manager.getOpenSession(incidentId) ??
          await manager.getOrCreateActiveSession(
            incidentId: incidentId,
            userId: userId,
          );
      id = controller.preserveForWidgetTest(mode);
      await manager.attachEvidenceToSession(
        sessionId: open.id,
        evidenceId: id,
      );
      final active = manager.getOpenSession(incidentId)!;
      expect(active.evidenceIds, contains(id));
      expect(
        active.evidenceIds.length,
        lessThan(controller.currentIncident.evidenceCount),
      );
    });
    return id;
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets(
    'A. existing 3 evidence + E4 after Cockpit → Workspace shows all 4',
    (tester) async {
      final (incidentId, priorIds) =
          await seedExistingIncident(tester, priorCount: 3);
      expect(priorIds, hasLength(3));

      await pumpWorkspace(tester);
      expect(find.text('3 evidence'), findsOneWidget);
      for (final id in priorIds) {
        expect(find.byKey(Key('live_timeline_item_$id')), findsOneWidget);
      }

      final e4 = await captureIntoNewSession(tester, incidentId: incidentId);
      await pumpWorkspace(tester);

      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        incidentId,
      );
      expect(
        WorkspaceSession.instance.controller.currentIncident.evidenceCount,
        4,
      );
      expect(find.text('4 evidence'), findsOneWidget);
      for (final id in [...priorIds, e4]) {
        expect(
          find.byKey(Key('live_timeline_item_$id')),
          findsOneWidget,
          reason: 'missing $id after cockpit-style capture',
        );
      }
    },
  );

  testWidgets(
    'B. existing 1 evidence + another → both remain visible',
    (tester) async {
      final (incidentId, priorIds) =
          await seedExistingIncident(tester, priorCount: 1);
      final e2 = await captureIntoNewSession(tester, incidentId: incidentId);
      await pumpWorkspace(tester);

      expect(find.text('2 evidence'), findsOneWidget);
      expect(
        find.byKey(Key('live_timeline_item_${priorIds.first}')),
        findsOneWidget,
      );
      expect(find.byKey(Key('live_timeline_item_$e2')), findsOneWidget);
    },
  );

  testWidgets(
    'C. photo+video+voice prior + another modality → all remain',
    (tester) async {
      final (incidentId, priorIds) = await seedExistingIncident(
        tester,
        priorCount: 3,
        modes: const [
          WorkspaceCaptureMode.photo,
          WorkspaceCaptureMode.video,
          WorkspaceCaptureMode.voice,
        ],
      );
      final e4 = await captureIntoNewSession(
        tester,
        incidentId: incidentId,
        mode: WorkspaceCaptureMode.note,
      );
      await pumpWorkspace(tester);

      final controller = WorkspaceSession.instance.controller;
      expect(controller.currentIncident.evidenceCount, 4);
      expect(find.text('4 evidence'), findsOneWidget);
      final kinds = controller.journeyEvidenceItems.map((e) => e.kind).toSet();
      expect(kinds, contains(WorkspaceEvidenceKind.image));
      expect(kinds, contains(WorkspaceEvidenceKind.video));
      expect(kinds, contains(WorkspaceEvidenceKind.voice));
      expect(kinds, contains(WorkspaceEvidenceKind.note));
      for (final id in [...priorIds, e4]) {
        expect(find.byKey(Key('live_timeline_item_$id')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'D/E/F. count never resets; incidentId + evidence.incidentId stable',
    (tester) async {
      final (incidentId, priorIds) =
          await seedExistingIncident(tester, priorCount: 3);
      await pumpWorkspace(tester);
      expect(find.text('3 evidence'), findsOneWidget);

      final e4 = await captureIntoNewSession(tester, incidentId: incidentId);
      await pumpWorkspace(tester);
      expect(find.text('1 evidence'), findsNothing);
      expect(find.text('4 evidence'), findsOneWidget);

      final controller = WorkspaceSession.instance.controller;
      expect(controller.currentIncident.id, incidentId);
      final store = controller.aggregate.store;
      for (final e in store.capturedEvidence) {
        expect(e.incidentId, incidentId);
      }
      for (final e in store.supportingEvidence) {
        expect(e.incidentId, incidentId);
      }
      expect(
        {...priorIds, e4}.every(
          (id) => controller.evidenceRepository.containsEvidenceId(id),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'G. Continue Preserving after session complete still restores full set',
    (tester) async {
      final (incidentId, priorIds) =
          await seedExistingIncident(tester, priorCount: 2);
      final e3 = await captureIntoNewSession(tester, incidentId: incidentId);
      await tester.runAsync(() async {
        final open = manager.getOpenSession(incidentId)!;
        await manager.completeSession(sessionId: open.id);
        await manager.getOrCreateActiveSession(
          incidentId: incidentId,
          userId: userId,
        );
      });
      await pumpWorkspace(tester);

      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        incidentId,
      );
      expect(find.text('3 evidence'), findsOneWidget);
      for (final id in [...priorIds, e3]) {
        expect(find.byKey(Key('live_timeline_item_$id')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'H. Capture Now new incident still shows only its own evidence',
    (tester) async {
      late String newId;
      late String a;
      late String b;
      await tester.runAsync(() async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        newId = session.controller.currentIncident.id;
        expect(session.controller.currentIncident.evidenceCount, 0);
        a = session.controller.preserveForWidgetTest(
          WorkspaceCaptureMode.photo,
        );
        b = session.controller.preserveForWidgetTest(
          WorkspaceCaptureMode.video,
        );
        await manager.getOrCreateActiveSession(
          incidentId: newId,
          userId: userId,
        );
      });
      await pumpWorkspace(tester);

      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        newId,
      );
      expect(find.text('2 evidence'), findsOneWidget);
      expect(find.byKey(Key('live_timeline_item_$a')), findsOneWidget);
      expect(find.byKey(Key('live_timeline_item_$b')), findsOneWidget);
    },
  );

  testWidgets(
    'I. sticky-bar style capture on existing incident keeps prior + new',
    (tester) async {
      final (incidentId, priorIds) = await seedExistingIncident(
        tester,
        priorCount: 2,
        modes: const [
          WorkspaceCaptureMode.photo,
          WorkspaceCaptureMode.voice,
        ],
      );
      await pumpWorkspace(tester);

      final e3 = await captureIntoNewSession(
        tester,
        incidentId: incidentId,
        mode: WorkspaceCaptureMode.video,
      );
      await pumpWorkspace(tester);

      expect(find.text('3 evidence'), findsOneWidget);
      for (final id in [...priorIds, e3]) {
        expect(find.byKey(Key('live_timeline_item_$id')), findsOneWidget);
      }
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        incidentId,
      );
    },
  );
}
