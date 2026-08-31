import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/capture/capture_session_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/capture/capture_action_grid.dart';
import 'package:evidence_vault/widgets/capture/cockpit_incident_header.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_ws_surface_');
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
      userId: 'user-6c3',
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

  Future<void> seed({String title = 'Workplace incident'}) async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c3',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: title),
    );
  }

  Future<void> pumpWorkspace(WidgetTester tester) async {
    await tester.runAsync(seed);
    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
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

  testWidgets('A-B. exactly one sticky bar with five actions', (tester) async {
    await pumpWorkspace(tester);
    expect(find.byKey(const Key('capture_sticky_bar')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_photo')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_video')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_voice')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_note')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_file')), findsOneWidget);
    expect(find.byType(CaptureActionGrid), findsNothing);
  });

  testWidgets('C-D. Photo opens Cockpit; exit returns to Workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seed);
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open_ws'),
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
    await tester.tap(find.byKey(const Key('open_ws')));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('capture_action_photo')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);

    Navigator.of(
      tester.element(find.byKey(const Key('capture_cockpit_screen'))),
    ).pop();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
    expect(
      manager.getActiveSession(incidentId)?.status,
      CaptureSessionStatus.active,
    );
  });

  testWidgets('E-F. Note and File remain Workspace-only', (tester) async {
    await pumpWorkspace(tester);
    expect(find.byKey(const Key('capture_action_note')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_file')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_action_photo')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('capture_cockpit_screen')),
        matching: find.byKey(const Key('capture_action_note')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('capture_cockpit_screen')),
        matching: find.byKey(const Key('capture_action_file')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('capture_cockpit_modality_bar')),
        matching: find.text('Note'),
      ),
      findsNothing,
    );
  });

  testWidgets('G-I. newest evidence at bottom and becomes visible',
      (tester) async {
    await pumpWorkspace(tester);
    final controller = WorkspaceSession.instance.controller;

    await tester.runAsync(() async {
      await controller.preserveTextNote('Oldest');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.preserveTextNote('Newest');
      await manager.restoreForIncident(
        incidentId: controller.currentIncident.id,
        userId: 'user-6c3',
      );
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final timeline = find.byKey(const Key('live_evidence_timeline'));
    expect(timeline, findsOneWidget);

    final oldestY = tester.getTopLeft(find.text('Oldest')).dy;
    final newestY = tester.getTopLeft(find.text('Newest')).dy;
    expect(newestY, greaterThan(oldestY));

    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Evidence 1'), findsOneWidget);
    expect(find.text('Evidence 2'), findsOneWidget);
  });

  testWidgets('J-K. title edit keeps same incident and session', (tester) async {
    await tester.runAsync(() => seed(title: ''));
    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();

    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    expect(CockpitIncidentHeader.isUntitled(''), isTrue);
    expect(find.byKey(const Key('cockpit_untitled_indicator')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cockpit_incident_title_tap')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('cockpit_incident_title_field')),
      'Named workplace',
    );
    await tester.tap(find.byKey(const Key('cockpit_incident_title_save')));
    await tester.pump();

    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.title, 'Named workplace');
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
  });

  testWidgets('L. evidence count matches timeline length', (tester) async {
    await pumpWorkspace(tester);
    final controller = WorkspaceSession.instance.controller;
    await tester.runAsync(() async {
      await controller.preserveTextNote('One');
      await controller.preserveTextNote('Two');
      await manager.restoreForIncident(
        incidentId: controller.currentIncident.id,
        userId: 'user-6c3',
      );
    });
    await tester.pump();

    final timeline = find.byKey(const Key('live_evidence_timeline'));
    final itemCount = find
        .descendant(
          of: timeline,
          matching: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>)
                    .value
                    .startsWith('live_timeline_item_'),
          ),
        )
        .evaluate()
        .length;
    expect(find.text('$itemCount evidence'), findsOneWidget);
    expect(itemCount, 2);
  });

  testWidgets('M. Organize remains reachable', (tester) async {
    await pumpWorkspace(tester);
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
  });

  testWidgets('N. no duplicate capture surfaces', (tester) async {
    await pumpWorkspace(tester);
    expect(find.byKey(const Key('capture_sticky_bar')), findsOneWidget);
    expect(find.byType(CaptureActionGrid), findsNothing);
    expect(find.text('Capture'), findsNothing);
    expect(find.byKey(const Key('continuous_capture_done_footer')), findsNothing);
    expect(find.byKey(const Key('cockpit_incident_title')), findsOneWidget);
    expect(
      find.byKey(const Key('continuous_capture_incident_title')),
      findsNothing,
    );
  });
}
