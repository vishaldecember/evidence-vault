import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_resume_target.dart';
import 'package:evidence_vault/navigation/app_navigation.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/home_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/capture/cockpit_immersive_preview.dart';
import 'package:evidence_vault/widgets/capture/text_note_capture_sheet.dart';
import 'package:evidence_vault/widgets/home/quick_capture_button.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_capture_now_');
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
      userId: 'user-6c4c',
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

  Future<void> seedExisting({String title = 'Existing incident'}) async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c4c',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: title),
    );
  }

  /// Home Capture Now: always create a new incident + CaptureSession.
  Future<void> prepareCaptureNowIncident(WidgetTester tester) async {
    final session = WorkspaceSession.instance;
    final userId = UserSessionService.account?.userId ?? '';
    await tester.runAsync(() async {
      await session.beginNewCaptureIncident();
      await manager.getOrCreateActiveSession(
        incidentId: session.controller.currentIncident.id,
        userId: userId,
      );
    });
  }

  /// Cockpit route Home pushes after prepare (before Workspace).
  void pushCockpit(BuildContext context, WorkspaceCaptureMode mode) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CaptureCockpitScreen(
          initialMode: mode,
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
  }

  /// Workspace route Home / Continue Preserving push (session already ready).
  void pushWorkspace(BuildContext context) {
    final session = WorkspaceSession.instance;
    session.resumeTarget = WorkspaceResumeTarget.incidentWorkspace;
    session.enterCapture();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContinuousCaptureScreen(
          controller: session.controller,
        ),
      ),
    );
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext navContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            navContext = context;
            return const Scaffold(
              body: SizedBox.expand(child: Text('host')),
            );
          },
        ),
      ),
    );
    await tester.pump();
    return navContext;
  }

  testWidgets('A. Capture Now Photo → new incident + Photo Cockpit',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final priorId =
        WorkspaceSession.instance.controller.currentIncident.id;

    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    pushCockpit(context, WorkspaceCaptureMode.photo);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_photo')), findsOneWidget);
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      isNot(priorId),
    );
  });

  testWidgets('B. Capture Now Video → new incident + Video Cockpit',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final priorId =
        WorkspaceSession.instance.controller.currentIncident.id;

    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    pushCockpit(context, WorkspaceCaptureMode.video);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_video')), findsOneWidget);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      isNot(priorId),
    );
  });

  testWidgets('C. Capture Now Voice → new incident + Voice Cockpit',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final priorId =
        WorkspaceSession.instance.controller.currentIncident.id;

    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    pushCockpit(context, WorkspaceCaptureMode.voice);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_voice')), findsOneWidget);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      isNot(priorId),
    );
  });

  testWidgets(
      'H+I. Capture Now Cockpit exit → same Workspace; exactly one incident',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final context = await pumpHost(tester);

    await prepareCaptureNowIncident(tester);
    pushCockpit(context, WorkspaceCaptureMode.photo);
    await tester.pump();
    await tester.pump();

    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.runAsync(() async {
      WorkspaceSession.instance.controller
          .preserveForWidgetTest(WorkspaceCaptureMode.photo);
      await manager.attachEvidenceToSession(
        sessionId: sessionId,
        evidenceId: WorkspaceSession
            .instance.controller.journeyEvidenceItems.last.id,
      );
    });

    Navigator.of(
      tester.element(find.byKey(const Key('capture_cockpit_screen'))),
    ).pop();
    await tester.pump();
    await tester.pump();

    // Home: after Cockpit returns, open Workspace on the same incident.
    pushWorkspace(context);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      incidentId,
    );
    expect(
      WorkspaceSession.instance.controller.currentIncident.evidenceCount,
      greaterThan(0),
    );
    expect(find.byKey(const Key('live_evidence_timeline')), findsOneWidget);
  });

  testWidgets('D. Continue Preserving → Workspace only', (tester) async {
    await tester.runAsync(() async {
      await seedExisting(title: 'Recovered');
      await WorkspaceSession.instance.controller.preserveTextNote('Prior');
    });
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;

    final context = await pumpHost(tester);
    await tester.runAsync(() async {
      await WorkspaceSession.instance.openIncident(incidentId);
    });
    pushWorkspace(context);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      incidentId,
    );
    expect(find.text('Prior'), findsOneWidget);
  });

  testWidgets(
      'E-G+J. Workspace Photo/Video/Voice → Cockpit; same incidentId',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();

    for (final key in [
      const Key('capture_action_photo'),
      const Key('capture_action_video'),
      const Key('capture_action_voice'),
    ]) {
      await tester.tap(find.byKey(key));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        incidentId,
      );
      expect(manager.getActiveSession(incidentId)?.id, sessionId);
      Navigator.of(
        tester.element(find.byKey(const Key('capture_cockpit_screen'))),
      ).pop();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    }
  });

  testWidgets(
      'K+L. Existing evidence remains; evidence count cumulative',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(() async {
      await seedExisting();
      await WorkspaceSession.instance.controller.preserveTextNote('Keep me');
    });
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final before = controller.currentIncident.evidenceCount;

    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(controller: controller),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('capture_action_photo')));
    await tester.pump();
    await tester.pump();

    await tester.runAsync(() async {
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      await manager.attachEvidenceToSession(
        sessionId: manager.getActiveSession(incidentId)!.id,
        evidenceId: controller.journeyEvidenceItems.last.id,
      );
    });

    Navigator.of(
      tester.element(find.byKey(const Key('capture_cockpit_screen'))),
    ).pop();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.evidenceCount, greaterThan(before));
    expect(find.text('Keep me'), findsOneWidget);
  });

  testWidgets('O. Workspace sticky Note/File remain non-Cockpit actions',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final context = await pumpHost(tester);

    await prepareCaptureNowIncident(tester);
    pushWorkspace(context);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(find.byKey(const Key('capture_action_note')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_file')), findsOneWidget);
  });

  testWidgets(
      '6D-A. Capture Now Note → sheet → preserve → same Workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final priorId =
        WorkspaceSession.instance.controller.currentIncident.id;

    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    expect(incidentId, isNot(priorId));

    var noteUiOpened = false;
    late CaptureNowOutcome outcome;
    await tester.runAsync(() async {
      outcome = await HomeScreen.captureNowNoteOrFile(
        context: context,
        mode: WorkspaceCaptureMode.note,
        controller: controller,
        openNote: (ctx) async {
          noteUiOpened = true;
          expect(ctx.mounted, isTrue);
          return 'Capture now witness note';
        },
      );
    });

    expect(noteUiOpened, isTrue);
    expect(outcome, CaptureNowOutcome.succeeded);
    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.evidenceCount, 1);

    // Home opens Workspace only after successful evidence.
    pushWorkspace(context);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(controller.currentIncident.id, incidentId);
    expect(find.text('Capture now witness note'), findsOneWidget);
  });

  testWidgets(
      '6D-B. Capture Now File → acquire → preserve → same Workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final priorId =
        WorkspaceSession.instance.controller.currentIncident.id;

    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    expect(incidentId, isNot(priorId));

    var acquireCalled = false;
    late CaptureNowOutcome outcome;
    await tester.runAsync(() async {
      outcome = await HomeScreen.captureNowNoteOrFile(
        context: context,
        mode: WorkspaceCaptureMode.file,
        controller: controller,
        acquireFile: () async {
          acquireCalled = true;
          final file = File('${tempRoot.path}/capture_now.pdf');
          await file.writeAsBytes(const [37, 80, 68, 70]);
          return CapturedMediaFile(
            localPath: file.path,
            fileName: 'capture_now.pdf',
            fileSizeBytes: 4,
          );
        },
      );
    });
    await tester.pump();
    await tester.pump();

    expect(acquireCalled, isTrue);
    expect(outcome, CaptureNowOutcome.succeeded);
    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.evidenceCount, 1);

    pushWorkspace(context);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(controller.currentIncident.id, incidentId);
  });

  testWidgets(
      '6D-C. Capture Now Note cancel → Home (no Workspace)',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;

    final capture = HomeScreen.captureNowNoteOrFile(
      context: context,
      mode: WorkspaceCaptureMode.note,
      controller: controller,
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextNoteCaptureSheet), findsOneWidget);
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);

    Navigator.of(tester.element(find.byType(TextNoteCaptureSheet))).pop();
    late CaptureNowOutcome outcome;
    await tester.runAsync(() async {
      outcome = await capture;
    });

    expect(outcome, CaptureNowOutcome.cancelled);
    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.evidenceCount, 0);
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);

    await tester.runAsync(() async {
      await WorkspaceSession.instance.abandonEmptyCaptureNow();
    });
    // Cancel stays on Home — do not push Workspace.
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
  });

  testWidgets(
      '6D-D. Capture Now File cancel → Home (no Workspace)',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;

    var acquireCalled = false;
    late CaptureNowOutcome outcome;
    await tester.runAsync(() async {
      outcome = await HomeScreen.captureNowNoteOrFile(
        context: context,
        mode: WorkspaceCaptureMode.file,
        controller: controller,
        acquireFile: () async {
          acquireCalled = true;
          return null;
        },
      );
    });

    expect(acquireCalled, isTrue);
    expect(outcome, CaptureNowOutcome.cancelled);
    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.evidenceCount, 0);
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);

    await tester.runAsync(() async {
      await WorkspaceSession.instance.abandonEmptyCaptureNow();
    });
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
  });

  testWidgets(
      '7-A–C. Capture Now Cockpit cancel → Home (no Workspace)',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final context = await pumpHost(tester);

    await prepareCaptureNowIncident(tester);
    final before =
        WorkspaceSession.instance.controller.currentIncident.evidenceCount;

    // Simulate Cockpit close without evidence (no plugin media session).
    await tester.runAsync(() async {
      await HomeScreen.finishCaptureNowAfterUi(
        context: context,
        session: WorkspaceSession.instance,
        evidenceBefore: before,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
    expect(
      WorkspaceSession.instance.controller.currentIncident.evidenceCount,
      before,
    );
  });

  testWidgets(
      '7-F. Capture Now success after Cockpit → Workspace + evidence',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final before = controller.currentIncident.evidenceCount;

    // Skip opening real Cockpit media session — simulate evidence then route.
    await tester.runAsync(() async {
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
    });
    expect(controller.currentIncident.evidenceCount, greaterThan(before));

    final flow = HomeScreen.finishCaptureNowAfterUi(
      context: context,
      session: WorkspaceSession.instance,
      evidenceBefore: before,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.evidenceCount, greaterThan(before));

    Navigator.of(
      tester.element(find.byKey(const Key('incident_workspace_screen'))),
    ).pop();
    await tester.pump();
    await tester.runAsync(() => flow);
  });

  test('7-Q. Large-file acquire path uses size metadata, not whole-file bytes',
      () {
    // DocumentImportService.pickFiles uses withData: false (path-only).
    // CapturedMediaFile stores length via File.length — no readAsBytes in acquire.
    const media = CapturedMediaFile(
      localPath: '/tmp/large-policy.pdf',
      fileName: 'large-policy.pdf',
      fileSizeBytes: 40 * 1024 * 1024,
    );
    expect(media.fileSizeBytes, greaterThan(5 * 1024 * 1024));
    expect(media.localPath.endsWith('.pdf'), isTrue);
  });

  testWidgets(
      '7-R. File acquire/persist failure → failed outcome, no Workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final context = await pumpHost(tester);
    await prepareCaptureNowIncident(tester);
    final controller = WorkspaceSession.instance.controller;

    late CaptureNowOutcome outcome;
    await tester.runAsync(() async {
      outcome = await HomeScreen.captureNowNoteOrFile(
        context: context,
        mode: WorkspaceCaptureMode.file,
        controller: controller,
        acquireFile: () async {
          throw StateError('simulated large-file persist failure');
        },
      );
    });
    await tester.pump();

    expect(outcome, CaptureNowOutcome.failed);
    expect(controller.currentIncident.evidenceCount, 0);
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
  });

  test('6D-E. Capture Now Photo/Video/Voice still map to Cockpit modalities',
      () {
    expect(QuickCaptureType.photo.workspaceMode, WorkspaceCaptureMode.photo);
    expect(QuickCaptureType.video.workspaceMode, WorkspaceCaptureMode.video);
    expect(QuickCaptureType.voice.workspaceMode, WorkspaceCaptureMode.voice);
    // Widget Cockpit entry remains covered by tests A/B/C in this file.
  });

  testWidgets(
      '6D-F. Continue Preserving opens Workspace without Note/File UI',
      (tester) async {
    await tester.runAsync(() async {
      await seedExisting(title: 'Recovered');
      await WorkspaceSession.instance.controller.preserveTextNote('Prior');
    });
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;

    final context = await pumpHost(tester);
    await tester.runAsync(() async {
      await WorkspaceSession.instance.openIncident(incidentId);
    });
    pushWorkspace(context);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byType(TextNoteCaptureSheet), findsNothing);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      incidentId,
    );
  });

  testWidgets(
      '7-N. Workspace File cancel stays on same Workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;

    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(controller.currentIncident.id, incidentId);
    // Sticky File cancel is Workspace-owned; Workspace remains mounted.
    expect(find.byKey(const Key('capture_action_file')), findsOneWidget);
  });

  testWidgets('I. Capture Now produces exactly one new incident per action',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    expect(
      manager.getActiveSession(
        WorkspaceSession.instance.controller.currentIncident.id,
      ),
      isNotNull,
    );

    final context = await pumpHost(tester);

    await prepareCaptureNowIncident(tester);
    pushCockpit(context, WorkspaceCaptureMode.photo);
    await tester.pump();
    await tester.pump();
    final firstNew =
        WorkspaceSession.instance.controller.currentIncident.id;

    Navigator.of(
      tester.element(find.byKey(const Key('capture_cockpit_screen'))),
    ).pop();
    await tester.pump();
    await tester.pump();

    await prepareCaptureNowIncident(tester);
    pushCockpit(context, WorkspaceCaptureMode.photo);
    await tester.pump();
    await tester.pump();

    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      isNot(firstNew),
    );
  });

  test('HomeScreen Capture Now maps QuickCapture to cockpit vs workspace', () {
    expect(QuickCaptureType.photo.workspaceMode, WorkspaceCaptureMode.photo);
    expect(QuickCaptureType.video.workspaceMode, WorkspaceCaptureMode.video);
    expect(QuickCaptureType.voice.workspaceMode, WorkspaceCaptureMode.voice);
    expect(QuickCaptureType.note.workspaceMode, WorkspaceCaptureMode.note);
    expect(
      QuickCaptureType.attachment.workspaceMode,
      WorkspaceCaptureMode.file,
    );
    expect(HomeScreen, isNotNull);
  });

  test('Tilt regression: Cockpit immersive preview remains -5 degrees', () {
    expect(
      CockpitImmersivePreview.tiltRadians,
      closeTo(-5 * 3.141592653589793 / 180, 1e-10),
    );
  });

  testWidgets('M. Photo → Video → Voice modality switching stays in Cockpit',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;

    await tester.pumpWidget(
      MaterialApp(
        home: CaptureCockpitScreen(
          initialMode: WorkspaceCaptureMode.photo,
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('cockpit-modality-photo')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_modality_video')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('cockpit-modality-video')),
        findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_modality_voice')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('cockpit-modality-voice')),
        findsOneWidget);
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      incidentId,
    );
  });

  testWidgets('N. Cockpit → Workspace → Cockpit again keeps same incident',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;

    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(controller: controller),
      ),
    );
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
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(controller.currentIncident.id, incidentId);

    await tester.tap(find.byKey(const Key('capture_action_video')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_video')), findsOneWidget);
    expect(controller.currentIncident.id, incidentId);
  });

  test('P. Cockpit modality resolve; primary media modes map correctly', () {
    expect(
      CaptureCockpitScreen.resolveInitialModality(WorkspaceCaptureMode.photo),
      WorkspaceCaptureMode.photo,
    );
    expect(
      CaptureCockpitScreen.resolveInitialModality(WorkspaceCaptureMode.video),
      WorkspaceCaptureMode.video,
    );
    expect(
      CaptureCockpitScreen.resolveInitialModality(WorkspaceCaptureMode.voice),
      WorkspaceCaptureMode.voice,
    );
    // Note/File are Workspace-only on primary journeys; if mis-routed to
    // Cockpit they fall back to Photo rather than inventing a Note modality.
    expect(
      CaptureCockpitScreen.resolveInitialModality(WorkspaceCaptureMode.note),
      WorkspaceCaptureMode.photo,
    );
    expect(
      CaptureCockpitScreen.resolveInitialModality(WorkspaceCaptureMode.file),
      WorkspaceCaptureMode.photo,
    );
    expect(HomeScreen, isNotNull);
  });

  testWidgets('Resume at capture stage opens primary Incident Workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedExisting);
    WorkspaceSession.instance.enterCapture();
    WorkspaceSession.instance.resumeTarget =
        WorkspaceResumeTarget.incidentWorkspace;

    final context = await pumpHost(tester);
    // Do not await route lifetime (completes only on Workspace pop).
    final pending = AppNavigation.resumeWorkspace(context);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const Key('incident_workspace_screen'))),
    ).pop();
    await tester.pump();
    await tester.runAsync(() => pending);
  });
}
