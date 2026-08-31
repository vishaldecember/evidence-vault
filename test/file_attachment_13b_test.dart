import 'dart:async';
import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/navigation/app_navigator.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/home_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/file_attach_flow.dart';
import 'package:evidence_vault/services/storage/file_attachment_persist.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
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
  final manager = CaptureSessionManager.instance;
  const userId = 'user-file-13b';

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_file_13b_');
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
    FileAttachFlow.endAttach();
    FileAttachmentPersist.debugAfterDialogShown = null;
  }

  Future<void> cleanupEnv() async {
    FileAttachmentPersist.debugAfterDialogShown = null;
    FileAttachFlow.endAttach();
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

  Future<CapturedMediaFile> seedPdf({
    String name = 'policy.pdf',
    int bytes = 64,
  }) async {
    final file = File(p.join(tempRoot.path, name));
    await file.writeAsBytes(List<int>.filled(bytes, 1));
    return CapturedMediaFile(
      localPath: file.path,
      fileName: name,
      fileSizeBytes: bytes,
    );
  }

  Future<void> pumpHomeOverWorkspace(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );
  }

  Future<void> pushWorkspace(WidgetTester tester) async {
    final session = WorkspaceSession.instance;
    appNavigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'ContinuousCaptureScreen'),
        builder: (_) => ContinuousCaptureScreen(controller: session.controller),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets(
    '1. Dialog already gone — persist cleanup does not pop Workspace',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);
      await pushWorkspace(tester);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
      expect(appNavigatorKey.currentState!.canPop(), isTrue);

      final hold = Completer<void>();
      FileAttachmentPersist.debugAfterDialogShown = () => hold.future;

      late CapturedMediaFile media;
      await tester.runAsync(() async {
        media = await seedPdf(name: 'gone-dialog.pdf');
      });

      final persistFuture = tester.runAsync(() async {
        return FileAttachmentPersist.persistWithProgress(
          context: appNavigatorKey.currentContext!,
          controller: WorkspaceSession.instance.controller,
          media: media,
        );
      });

      await tester.pump();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      appNavigatorKey.currentState!.pop();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );

      hold.complete();
      await persistFuture;
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
      expect(appNavigatorKey.currentState!.canPop(), isTrue);
    },
  );

  testWidgets('2. Dialog is current — cleanup closes only the dialog', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await pumpHomeOverWorkspace(tester);
    await pushWorkspace(tester);

    late FilePersistDialogResult result;
    await tester.runAsync(() async {
      final media = await seedPdf(name: 'dialog-current.pdf');
      result = await FileAttachmentPersist.persistWithProgress(
        context: appNavigatorKey.currentContext!,
        controller: WorkspaceSession.instance.controller,
        media: media,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result, FilePersistDialogResult.success);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(appNavigatorKey.currentState!.canPop(), isTrue);
  });

  testWidgets('3. Successful PDF remains on Incident Workspace', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await pumpHomeOverWorkspace(tester);

    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    late FileAttachResult result;
    var lockDuringWorkspaceBuild = false;
    await tester.runAsync(() async {
      final media = await seedPdf(name: 'ok.pdf');
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () {
          lockDuringWorkspaceBuild = FileAttachFlow.attachInProgress;
          return ContinuousCaptureScreen(controller: session.controller);
        },
        acquireFile: () async => media,
      );
    });
    expect(result.outcome, FileAttachOutcome.succeeded);
    expect(result.sourceIncidentId, incidentId);
    expect(FileAttachFlow.attachInProgress, isTrue);
    await tester.pump();
    await tester.pump();
    expect(lockDuringWorkspaceBuild, isTrue);
    expect(FileAttachFlow.attachInProgress, isFalse);
    expect(session.controller.currentIncident.id, incidentId);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('4. Cancelled PDF remains on Incident Workspace', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await pumpHomeOverWorkspace(tester);
    await pushWorkspace(tester);

    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    late FileAttachResult result;
    await tester.runAsync(() async {
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () async => null,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.cancelled);
    expect(result.sourceIncidentId, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 0);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(FileAttachFlow.attachInProgress, isFalse);
  });

  testWidgets('5. Persist failure remains on Incident Workspace', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await pumpHomeOverWorkspace(tester);
    await pushWorkspace(tester);

    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    late FileAttachResult result;
    await tester.runAsync(() async {
      final media = await seedPdf(name: 'payload.exe');
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () async => media,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.failed);
    expect(session.controller.currentIncident.id, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 0);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });

  testWidgets('6. Durability failure remains on Incident Workspace', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await pumpHomeOverWorkspace(tester);
    await pushWorkspace(tester);

    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    FileAttachFlow.beginAttachForTests(
      origin: FileAttachOrigin.workspaceSticky,
      incidentId: incidentId,
    );

    late bool preserved;
    await tester.runAsync(() async {
      preserved = await FileAttachFlow.persistSelected(
        const CapturedMediaFile(
          localPath: '/missing/ephemeral.pdf',
          fileName: 'ephemeral.pdf',
          fileSizeBytes: 12,
        ),
        context: appNavigatorKey.currentContext,
        lockedIncidentId: incidentId,
      );
    });
    await tester.pump();

    expect(preserved, isFalse);
    expect(session.controller.currentIncident.id, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 0);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(appNavigatorKey.currentState!.canPop(), isTrue);
  });

  testWidgets(
    '7. Workspace disposed during picker — source incident remains authoritative',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      late FileAttachResult result;
      await tester.runAsync(() async {
        final media = await seedPdf(name: 'disposed.pdf');
        result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.homeCaptureNow,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async {
            FileAttachFlow.workspaceRouteVisible = false;
            return media;
          },
        );
      });
      await tester.pump();
      await tester.pump();

      expect(result.outcome, FileAttachOutcome.succeeded);
      expect(result.sourceIncidentId, incidentId);
      expect(session.controller.currentIncident.id, incidentId);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets('8. Incident switch during picker — no write to destination', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await pumpHomeOverWorkspace(tester);

    final session = WorkspaceSession.instance;
    session.controller.preserveForWidgetTest(
      WorkspaceCaptureMode.note,
      noteText: 'Prior on A',
    );
    final sourceId = session.controller.currentIncident.id;
    final sourceCount = session.controller.currentIncident.evidenceCount;

    late FileAttachResult result;
    late String destinationId;
    await tester.runAsync(() async {
      final media = await seedPdf(name: 'switch-pick.pdf');
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () async {
          await session.beginNewCaptureIncident();
          destinationId = session.controller.currentIncident.id;
          return media;
        },
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.failed);
    expect(result.sourceIncidentId, sourceId);
    expect(destinationId, isNot(sourceId));
    expect(session.controller.currentIncident.id, sourceId);
    expect(
      session.controller.currentIncident.evidenceCount,
      lessThanOrEqualTo(sourceCount),
    );
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });

  test('9. Incident switch during persist — no write to destination', () async {
    final session = WorkspaceSession.instance;
    session.controller.preserveForWidgetTest(
      WorkspaceCaptureMode.note,
      noteText: 'A',
    );
    final sourceId = session.controller.currentIncident.id;
    FileAttachFlow.beginAttachForTests(
      origin: FileAttachOrigin.workspaceSticky,
      incidentId: sourceId,
    );

    await session.beginNewCaptureIncident();
    final destinationId = session.controller.currentIncident.id;
    expect(destinationId, isNot(sourceId));
    final destCount = session.controller.currentIncident.evidenceCount;

    final media = await seedPdf(name: 'switch-persist.pdf');
    final preserved = await FileAttachFlow.persistSelected(
      media,
      lockedIncidentId: sourceId,
    );

    expect(preserved, isFalse);
    expect(session.controller.currentIncident.id, destinationId);
    expect(session.controller.currentIncident.evidenceCount, destCount);
  });

  testWidgets(
    '10. ensureWorkspaceVisible after disappearance restores SOURCE',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);

      final session = WorkspaceSession.instance;
      final sourceId = session.controller.currentIncident.id;
      FileAttachFlow.beginAttachForTests(
        origin: FileAttachOrigin.workspaceSticky,
        incidentId: sourceId,
      );
      FileAttachFlow.workspaceRouteVisible = false;

      await tester.runAsync(() async {
        await session.beginNewCaptureIncident();
        expect(session.controller.currentIncident.id, isNot(sourceId));
        await FileAttachFlow.ensureWorkspaceVisible(
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          sourceIncidentId: sourceId,
        );
      });
      await tester.pump();
      await tester.pump();

      expect(session.controller.currentIncident.id, sourceId);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
      expect(appNavigatorKey.currentState!.canPop(), isTrue);
    },
  );

  testWidgets(
    '11-12. attachInProgress holds through restore; endAttach after settle',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);

      var lockAtEnsureBuild = false;
      await tester.runAsync(() async {
        final media = await seedPdf(name: 'latch.pdf');
        await FileAttachFlow.attach(
          origin: FileAttachOrigin.homeCaptureNow,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () {
            lockAtEnsureBuild = FileAttachFlow.attachInProgress;
            return ContinuousCaptureScreen(
              controller: WorkspaceSession.instance.controller,
            );
          },
          acquireFile: () async => media,
        );
      });

      expect(FileAttachFlow.attachInProgress, isTrue);
      await tester.pump();
      await tester.pump();
      expect(lockAtEnsureBuild, isTrue);
      expect(FileAttachFlow.attachInProgress, isFalse);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Delayed system pop is absorbed while attachInProgress; lock clears after frame',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);
      await pushWorkspace(tester);

      final incidentId =
          WorkspaceSession.instance.controller.currentIncident.id;
      FileAttachFlow.beginAttachForTests(
        origin: FileAttachOrigin.workspaceSticky,
        incidentId: incidentId,
      );
      await tester.pump();
      expect(FileAttachFlow.attachInProgress, isTrue);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );

      // Android SAF/system back → WidgetsApp.didPopRoute → maybePop.
      // PopScope must have rebuilt with canPop:false while the lock is held.
      // maybePop returns true when the pop is *handled* by not popping.
      final delayedPopHandled = await appNavigatorKey.currentState!.maybePop();
      await tester.pump();

      expect(delayedPopHandled, isTrue);
      expect(FileAttachFlow.attachInProgress, isTrue);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
      expect(appNavigatorKey.currentState!.canPop(), isTrue);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        FileAttachFlow.endAttach();
      });
      expect(FileAttachFlow.attachInProgress, isTrue);
      await tester.pump();
      expect(FileAttachFlow.attachInProgress, isFalse);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '13A. Immediate maybePop before PopScope rebuild cannot remove Workspace',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);
      await pushWorkspace(tester);

      FileAttachFlow.beginAttachForTests(
        origin: FileAttachOrigin.workspaceSticky,
        incidentId: WorkspaceSession.instance.controller.currentIncident.id,
      );
      // No pump — PopScope has not rebuilt; live PopEntry must still block.
      expect(FileAttachFlow.attachInProgress, isTrue);
      expect(FileAttachFlow.fileAttachSettling, isTrue);

      final handled = await appNavigatorKey.currentState!.maybePop();
      expect(handled, isTrue);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets(
    '13A. Delayed maybePop after attachInProgress is false is absorbed '
    'while settling',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      late FileAttachResult result;
      await tester.runAsync(() async {
        final media = await seedPdf(name: 'delayed-pop.pdf');
        result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.homeCaptureNow,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async => media,
        );
      });
      expect(result.outcome, FileAttachOutcome.succeeded);
      expect(FileAttachFlow.attachInProgress, isTrue);

      await tester.pump();
      expect(FileAttachFlow.attachInProgress, isFalse);
      expect(FileAttachFlow.fileAttachSettling, isTrue);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );

      final handled = await appNavigatorKey.currentState!.maybePop();
      expect(handled, isTrue);
      expect(FileAttachFlow.fileAttachSettling, isTrue);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
      expect(session.controller.currentIncident.id, incidentId);
    },
  );

  testWidgets(
    '13A. Home Capture Now File success remains on Workspace',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      late FileAttachResult result;
      await tester.runAsync(() async {
        final media = await seedPdf(name: 'home-success.pdf');
        result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.homeCaptureNow,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async => media,
        );
      });
      await tester.pump();
      final delayedPop = await appNavigatorKey.currentState!.maybePop();
      await tester.pump();
      await tester.pump();

      expect(result.outcome, FileAttachOutcome.succeeded);
      expect(delayedPop, isTrue);
      expect(result.sourceIncidentId, incidentId);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 1);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets(
    '13A. Home Capture Now File cancel remains on Workspace',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      late FileAttachResult result;
      await tester.runAsync(() async {
        result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.homeCaptureNow,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async => null,
        );
      });
      await tester.pump();
      final delayedPop = await appNavigatorKey.currentState!.maybePop();
      await tester.pump();
      await tester.pump();

      expect(result.outcome, FileAttachOutcome.cancelled);
      expect(delayedPop, isTrue);
      expect(result.sourceIncidentId, incidentId);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 0);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '13A. Workspace File success remains on the same Workspace',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);
      await pushWorkspace(tester);

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      late FileAttachResult result;
      await tester.runAsync(() async {
        final media = await seedPdf(name: 'ws-success.pdf');
        result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.workspaceSticky,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async => media,
        );
      });
      await tester.pump();
      final delayedPop = await appNavigatorKey.currentState!.maybePop();
      await tester.pump();
      await tester.pump();

      expect(result.outcome, FileAttachOutcome.succeeded);
      expect(delayedPop, isTrue);
      expect(session.controller.currentIncident.id, incidentId);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '13A. Workspace File cancel remains on the same Workspace',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);
      await pushWorkspace(tester);

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      late FileAttachResult result;
      await tester.runAsync(() async {
        result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.workspaceSticky,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async => null,
        );
      });
      await tester.pump();
      final delayedPop = await appNavigatorKey.currentState!.maybePop();
      await tester.pump();
      await tester.pump();

      expect(result.outcome, FileAttachOutcome.cancelled);
      expect(delayedPop, isTrue);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 0);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '13A. Persist/type failure remains on Workspace',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);
      await pushWorkspace(tester);

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      late FileAttachResult result;
      await tester.runAsync(() async {
        final media = await seedPdf(name: 'bad.exe');
        result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.workspaceSticky,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async => media,
        );
      });
      await tester.pump();
      final delayedPop = await appNavigatorKey.currentState!.maybePop();
      await tester.pump();
      await tester.pump();

      expect(result.outcome, FileAttachOutcome.failed);
      expect(delayedPop, isTrue);
      expect(session.controller.currentIncident.id, incidentId);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '13A. After attach has settled, explicit maybePop still pops Workspace',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await pumpHomeOverWorkspace(tester);
      await pushWorkspace(tester);

      final session = WorkspaceSession.instance;
      await tester.runAsync(() async {
        final media = await seedPdf(name: 'settled-back.pdf');
        await FileAttachFlow.attach(
          origin: FileAttachOrigin.workspaceSticky,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async => media,
        );
      });
      await tester.pump();
      await tester.pump();
      expect(FileAttachFlow.attachInProgress, isFalse);
      expect(FileAttachFlow.fileAttachSettling, isFalse);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );

      final popped = await appNavigatorKey.currentState!.maybePop();
      await tester.pump();
      expect(popped, isTrue);
      expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
    },
  );
}
