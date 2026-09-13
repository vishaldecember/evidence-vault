import 'dart:async';
import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/capture/capture_session_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final manager = CaptureSessionManager.instance;

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_cockpit_');
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
      userId: 'user-6c4',
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

  Future<void> seedSession() async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c4',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace incident'),
    );
  }

  Future<void> pumpCockpit(
    WidgetTester tester, {
    WorkspaceCaptureMode? initialMode,
  }) async {
    await tester.runAsync(seedSession);
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureCockpitScreen(
          controller: WorkspaceSession.instance.controller,
          initialMode: initialMode,
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets(
    'open presents Cockpit on the bound incident without awaiting session I/O',
    (tester) async {
      final incidentId =
          WorkspaceSession.instance.controller.currentIncident.id;
      expect(incidentId, isNotEmpty);
      expect(manager.getActiveSession(incidentId), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    unawaited(
                      CaptureCockpitScreen.open(
                        context,
                        initialMode: WorkspaceCaptureMode.photo,
                        boundIncidentId: incidentId,
                      ),
                    );
                  },
                  child: const Text('open-cockpit'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open-cockpit'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        incidentId,
      );
      expect(find.text('Preparing capture…'), findsOneWidget);

      Navigator.of(
        tester.element(find.byKey(const Key('capture_cockpit_screen'))),
      ).pop();
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets('1. Capture Cockpit renders straight live surface + modality bar',
      (tester) async {
    await pumpCockpit(tester);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_modality_bar')), findsOneWidget);
    expect(find.byKey(const Key('cockpit_live_capture_surface')), findsOneWidget);
    // Live open: no tilted preview frame yet.
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsNothing);
    expect(find.text('Capture Cockpit'), findsOneWidget);
  });

  testWidgets('2. Capture Cockpit defaults to Photo mode', (tester) async {
    await pumpCockpit(tester);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_photo')), findsOneWidget);
    expect(
      CaptureCockpitScreen.resolveInitialModality(null),
      WorkspaceCaptureMode.photo,
    );
  });

  testWidgets('3. Photo → Video switches without leaving Cockpit',
      (tester) async {
    await pumpCockpit(tester);
    expect(find.text('Camera'), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_modality_video')));
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.text('Video'), findsWidgets);
    expect(find.text('Camera'), findsNothing);
  });

  testWidgets('4. Video → Voice switches without leaving Cockpit',
      (tester) async {
    await pumpCockpit(tester, initialMode: WorkspaceCaptureMode.video);
    expect(find.text('Video'), findsWidgets);

    await tester.tap(find.byKey(const Key('capture_modality_voice')));
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.text('Voice'), findsWidgets);
  });

  testWidgets('5. Voice → Photo switches without leaving Cockpit',
      (tester) async {
    await pumpCockpit(tester, initialMode: WorkspaceCaptureMode.voice);
    expect(find.text('Voice'), findsWidgets);

    await tester.tap(find.byKey(const Key('capture_modality_photo')));
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('6-7. modality switch preserves incidentId and captureSessionId',
      (tester) async {
    await pumpCockpit(tester);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.tap(find.byKey(const Key('capture_modality_video')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture_modality_voice')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture_modality_photo')));
    await tester.pump();

    expect(controller.currentIncident.id, incidentId);
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
    expect(
      manager.getActiveSession(incidentId)?.status,
      CaptureSessionStatus.active,
    );
  });

  testWidgets('8. existing evidence remains after modality switch',
      (tester) async {
    await pumpCockpit(tester);
    final controller = WorkspaceSession.instance.controller;
    await tester.runAsync(() async {
      await controller.preserveTextNote('Before switch');
      await manager.restoreForIncident(
        incidentId: controller.currentIncident.id,
        userId: 'user-6c4',
      );
    });
    final countBefore = controller.currentIncident.evidenceCount;
    expect(countBefore, greaterThan(0));

    await tester.tap(find.byKey(const Key('capture_modality_video')));
    await tester.pump();

    expect(controller.currentIncident.evidenceCount, countBefore);
    expect(
      controller.journeyEvidenceItems.any((e) => e.title.contains('Before') ||
          (e.notePreview?.contains('Before') ?? false)),
      isTrue,
    );
  });

  testWidgets('9. capturing in each modality appends to same stream',
      (tester) async {
    await pumpCockpit(tester);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.runAsync(() async {
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      await manager.attachEvidenceToSession(
        sessionId: sessionId,
        evidenceId: controller.journeyEvidenceItems.last.id,
      );
    });

    await tester.tap(find.byKey(const Key('capture_modality_video')));
    await tester.pump();
    await tester.runAsync(() async {
      controller.preserveForWidgetTest(WorkspaceCaptureMode.video);
      await manager.attachEvidenceToSession(
        sessionId: sessionId,
        evidenceId: controller.journeyEvidenceItems.last.id,
      );
    });

    await tester.tap(find.byKey(const Key('capture_modality_voice')));
    await tester.pump();
    await tester.runAsync(() async {
      controller.preserveForWidgetTest(WorkspaceCaptureMode.voice);
      await manager.attachEvidenceToSession(
        sessionId: sessionId,
        evidenceId: controller.journeyEvidenceItems.last.id,
      );
    });

    expect(controller.currentIncident.id, incidentId);
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
    expect(controller.currentIncident.evidenceCount, greaterThanOrEqualTo(3));
    final stored = await tester.runAsync(
      () => LocalCaptureSessionStore.byId(sessionId),
    );
    expect(stored?.evidenceIds.length, greaterThanOrEqualTo(3));
  });
}
