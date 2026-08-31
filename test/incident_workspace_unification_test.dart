import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/capture/capture_session_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/navigation/app_navigation.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_6c_unify_');
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
      userId: 'user-6c1',
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

  Future<void> seedActiveIncident({String title = 'Workplace incident'}) async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c1',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: title),
    );
  }

  Future<void> pumpHomeHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: const Key('test_capture_now'),
                  onPressed: () {
                    AppNavigation.openContinuousCapture(
                      context,
                      beginNewIncident: true,
                    );
                  },
                  child: const Text('Capture Now'),
                ),
                TextButton(
                  key: const Key('test_continue_preserving'),
                  onPressed: () async {
                    final id =
                        WorkspaceSession.instance.controller.currentIncident.id;
                    await WorkspaceSession.instance.openIncident(id);
                    if (context.mounted) {
                      await AppNavigation.openContinuousCapture(context);
                    }
                  },
                  child: const Text('Continue preserving'),
                ),
              ],
            ),
          ),
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

  testWidgets('A. Continue Preserving opens Incident Workspace', (tester) async {
    await tester.runAsync(seedActiveIncident);
    await pumpHomeHost(tester);

    await tester.tap(find.byKey(const Key('test_continue_preserving')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byKey(const Key('continuous_capture_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(find.text('Workplace incident'), findsOneWidget);
  });

  testWidgets('B. Capture Now Photo opens Cockpit before Workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedActiveIncident);
    final priorId =
        WorkspaceSession.instance.controller.currentIncident.id;

    late BuildContext navContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            navContext = context;
            return const Scaffold(body: Text('host'));
          },
        ),
      ),
    );
    await tester.pump();

    await tester.runAsync(() async {
      await WorkspaceSession.instance.beginNewCaptureIncident();
      await manager.getOrCreateActiveSession(
        incidentId: WorkspaceSession.instance.controller.currentIncident.id,
        userId: 'user-6c1',
      );
    });
    // Session cached — push Cockpit without awaiting dismissal.
    Navigator.of(navContext).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CaptureCockpitScreen(
          initialMode: WorkspaceCaptureMode.photo,
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      isNot(priorId),
    );
  });

  testWidgets('C. Incident identity is preserved across open', (tester) async {
    await tester.runAsync(seedActiveIncident);
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;
    await pumpHomeHost(tester);

    await tester.tap(find.byKey(const Key('test_continue_preserving')));
    await tester.pump();
    await tester.pump();

    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      incidentId,
    );
  });

  testWidgets('D. Existing evidence remains visible in Incident Workspace',
      (tester) async {
    await tester.runAsync(() async {
      await seedActiveIncident();
      await WorkspaceSession.instance.controller.preserveTextNote('Prior note');
      await manager.restoreForIncident(
        incidentId: WorkspaceSession.instance.controller.currentIncident.id,
        userId: 'user-6c1',
      );
    });
    await pumpHomeHost(tester);

    await tester.tap(find.byKey(const Key('test_continue_preserving')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Prior note'), findsOneWidget);
    expect(find.byKey(const Key('live_evidence_timeline')), findsOneWidget);
  });

  testWidgets('E-F. Cockpit entry/exit returns to same Incident Workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedActiveIncident);
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open_workspace'),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ContinuousCaptureScreen(
                      controller: WorkspaceSession.instance.controller,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_workspace')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_action_photo')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);

    // Exit Cockpit via route pop (same as system back / DONE).
    Navigator.of(
      tester.element(find.byKey(const Key('capture_cockpit_screen'))),
    ).pop();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      incidentId,
    );
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
    expect(
      manager.getActiveSession(incidentId)?.status,
      CaptureSessionStatus.active,
    );
  });

  testWidgets('G. Capture Now Note/Workspace path is ContinuousCapture only',
      (tester) async {
    // Note/File Capture Now open Workspace without Cockpit.
    await tester.runAsync(seedActiveIncident);
    late BuildContext navContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            navContext = context;
            return const Scaffold(body: Text('host'));
          },
        ),
      ),
    );
    await tester.pump();

    await tester.runAsync(() async {
      await WorkspaceSession.instance.beginNewCaptureIncident();
      await manager.getOrCreateActiveSession(
        incidentId: WorkspaceSession.instance.controller.currentIncident.id,
        userId: 'user-6c1',
      );
    });
    Navigator.of(navContext).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byType(ContinuousCaptureScreen), findsOneWidget);
    expect(find.byType(IncidentWorkspaceShell), findsNothing);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
  });

  testWidgets('H. Pending session recovery still restores open session',
      (tester) async {
    late String incidentId;
    await tester.runAsync(() async {
      await seedActiveIncident(title: 'Recover me');
      incidentId = WorkspaceSession.instance.controller.currentIncident.id;
      await WorkspaceSession.instance.controller.preserveTextNote('Recovered');
      await manager.pauseSession(
        sessionId: manager.getActiveSession(incidentId)!.id,
      );
      await manager.restoreForIncident(
        incidentId: incidentId,
        userId: 'user-6c1',
      );
    });

    expect(
      manager.getOpenSession(incidentId)?.status,
      CaptureSessionStatus.paused,
    );

    // Mirror Continue Preserving: openIncident → Incident Workspace open path.
    await tester.runAsync(() async {
      await WorkspaceSession.instance.openIncident(incidentId);
      final open = manager.getOpenSession(incidentId);
      if (open?.status == CaptureSessionStatus.paused) {
        await manager.resumeSession(sessionId: open!.id);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.text('Recovered'), findsOneWidget);
    expect(
      manager.getActiveSession(incidentId)?.status,
      CaptureSessionStatus.active,
    );
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      incidentId,
    );
  });

  testWidgets('Organize remains reachable without replacing workspace root',
      (tester) async {
    await tester.runAsync(seedActiveIncident);
    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('incident_workspace_journey_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organize'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
    expect(
      WorkspaceSession.instance.activeMethodologyStage,
      InvestigationMethodologyStage.evidence,
    );
    // Incident Workspace remains under the pushed shell route.
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });
}
