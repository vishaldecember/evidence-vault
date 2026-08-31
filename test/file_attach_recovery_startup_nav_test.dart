import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/navigation/app_navigator.dart';
import 'package:evidence_vault/providers/authentication_state_provider.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/home_screen.dart';
import 'package:evidence_vault/screens/main_shell_screen.dart';
import 'package:evidence_vault/services/auth/firebase_bootstrap.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/durable_attach_intent.dart';
import 'package:evidence_vault/services/storage/durable_attach_intent_store.dart';
import 'package:evidence_vault/services/storage/file_attach_flow.dart';
import 'package:evidence_vault/services/storage/file_attach_recovery.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

class _NamedRouteLog extends NavigatorObserver {
  final List<String> names = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      names.add(name);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final manager = CaptureSessionManager.instance;
  const userId = 'user-14b-home-flash';
  final routes = _NamedRouteLog();

  bool homeVisibleWithoutWorkspace() {
    final home = find.byType(HomeScreen).evaluate().isNotEmpty;
    final workspace =
        find.byKey(const Key('incident_workspace_screen')).evaluate().isNotEmpty;
    if (!home || workspace) {
      return false;
    }
    final nav = appNavigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      return false;
    }
    return true;
  }

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_14b_home_flash_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    await manager.resetForTests();
    await EvidenceSyncManager.instance.resetForTests();
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    FirebaseBootstrap.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: userId,
    );
    FileAttachFlow.endAttach();
    FileAttachFlow.workspaceRouteVisible = false;
    FileAttachRecovery.debugReset();
    DurableAttachIntentStore.debugReset();
    routes.names.clear();
  }

  Future<void> cleanupEnv() async {
    FileAttachFlow.endAttach();
    FileAttachFlow.workspaceRouteVisible = false;
    FileAttachRecovery.debugReset();
    DurableAttachIntentStore.debugReset();
    await EvidenceSyncManager.instance.resetForTests();
    await manager.resetForTests();
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    FirebaseBootstrap.resetForTests();
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> pumpAuthGate(WidgetTester tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final authState = AuthenticationStateProvider(
      authRepository: FakeAuthRepository(),
    );
    addTearDown(authState.dispose);
    authState.setAuthenticatedForTests(true);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        navigatorObservers: [routes],
        home: AuthGate(authState: authState),
      ),
    );
  }

  Future<void> pumpStartup(WidgetTester tester) async {
    for (var i = 0; i < 80; i++) {
      final homeReady = find.byType(MainShellScreen).evaluate().isNotEmpty &&
          find.byType(HomeScreen).evaluate().isNotEmpty;
      final workspaceReady =
          find.byKey(const Key('incident_workspace_screen')).evaluate().isNotEmpty;
      if (homeReady || workspaceReady) {
        await tester.pump();
        return;
      }
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets('1. Normal startup with no pending recovery still opens Home', (
    tester,
  ) async {
    await pumpAuthGate(tester);
    await pumpStartup(tester);

    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
    expect(find.byType(ContinuousCaptureScreen), findsNothing);
    expect(routes.names, isNot(contains('ContinuousCaptureScreen')));
  });

  testWidgets(
    '2–7. Pending recovery restores source Workspace without a Home flash',
    (tester) async {
      late String sourceId;
      await tester.runAsync(() async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        sourceId = session.controller.currentIncident.id;
        await manager.getOrCreateActiveSession(
          incidentId: sourceId,
          userId: userId,
        );
        await DurableAttachIntentStore.savePendingIntent(
          DurableAttachIntent(
            userId: userId,
            sourceIncidentId: sourceId,
            origin: DurableAttachIntent.originWorkspaceSticky,
            operationId: 'op-14b-home-flash',
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        FileAttachFlow.endAttach();
        FileAttachFlow.workspaceRouteVisible = false;
        WorkspaceSession.instance.reset();
        FileAttachRecovery.debugReset();
        expect(session.controller.currentIncident.id, isNot(sourceId));
      });

      var sawHomeAlone = false;
      await pumpAuthGate(tester);
      for (var i = 0; i < 80; i++) {
        if (homeVisibleWithoutWorkspace()) {
          sawHomeAlone = true;
        }
        if (find.byKey(const Key('incident_workspace_screen')).evaluate().isNotEmpty) {
          break;
        }
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }

      expect(
        sawHomeAlone,
        isFalse,
        reason: 'Home must not be the visible intermediate route during recovery',
      );
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(find.byType(ContinuousCaptureScreen), findsOneWidget);
      expect(
        routes.names.where((name) => name == 'ContinuousCaptureScreen').length,
        1,
      );
      expect(WorkspaceSession.instance.controller.currentIncident.id, sourceId);
      expect(find.byType(MainShellScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
      expect(find.byType(ContinuousCaptureScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(MainShellScreen), findsOneWidget);
      expect(WorkspaceSession.instance.controller.currentIncident.id, sourceId);
    },
  );

  testWidgets(
    '3. AuthGate waits for install() in-flight recovery; Home is not released early',
    (tester) async {
      late String sourceId;
      await tester.runAsync(() async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        sourceId = session.controller.currentIncident.id;
        await manager.getOrCreateActiveSession(
          incidentId: sourceId,
          userId: userId,
        );
        await DurableAttachIntentStore.savePendingIntent(
          DurableAttachIntent(
            userId: userId,
            sourceIncidentId: sourceId,
            origin: DurableAttachIntent.originWorkspaceSticky,
            operationId: 'op-14b-overlap',
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        FileAttachFlow.endAttach();
        FileAttachFlow.workspaceRouteVisible = false;
        WorkspaceSession.instance.reset();
        FileAttachRecovery.debugReset();
        FileAttachRecovery.debugForceInstallInTests = true;
        FileAttachRecovery.install();
        expect(session.controller.currentIncident.id, isNot(sourceId));
      });

      var sawHomeAlone = false;
      await pumpAuthGate(tester);
      for (var i = 0; i < 80; i++) {
        if (homeVisibleWithoutWorkspace()) {
          sawHomeAlone = true;
        }
        if (find
            .byKey(const Key('incident_workspace_screen'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }

      expect(
        sawHomeAlone,
        isFalse,
        reason: 'install()/AuthGate overlap must not paint Home first',
      );
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(find.byType(ContinuousCaptureScreen), findsOneWidget);
      expect(
        routes.names.where((name) => name == 'ContinuousCaptureScreen').length,
        1,
      );
      expect(FileAttachRecovery.debugRecoveryBodyRuns, 1);
      expect(WorkspaceSession.instance.controller.currentIncident.id, sourceId);
      expect(find.byType(MainShellScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(WorkspaceSession.instance.controller.currentIncident.id, sourceId);
    },
  );

  testWidgets(
    '4. Overlapping recoverIfNeeded awaits in-flight and does not skip',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      late String sourceId;
      await tester.runAsync(() async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        sourceId = session.controller.currentIncident.id;
        await manager.getOrCreateActiveSession(
          incidentId: sourceId,
          userId: userId,
        );
        await DurableAttachIntentStore.savePendingIntent(
          DurableAttachIntent(
            userId: userId,
            sourceIncidentId: sourceId,
            origin: DurableAttachIntent.originWorkspaceSticky,
            operationId: 'op-14b-await',
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        FileAttachFlow.endAttach();
        FileAttachFlow.workspaceRouteVisible = false;
        WorkspaceSession.instance.reset();
        FileAttachRecovery.debugReset();
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: [routes],
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pump();

      late FileAttachRecoveryOutcome first;
      late FileAttachRecoveryOutcome second;
      await tester.runAsync(() async {
        await WorkspaceSession.instance.restoreForSignedInUser();
        final started = FileAttachRecovery.recoverIfNeeded();
        second = await FileAttachRecovery.recoverIfNeeded();
        first = await started;
      });
      await tester.pump();
      await tester.pump();

      expect(first, FileAttachRecoveryOutcome.restoredReselectRequired);
      expect(second, FileAttachRecoveryOutcome.restoredReselectRequired);
      expect(first, second);
      expect(FileAttachRecovery.debugRecoveryBodyRuns, 1);
      expect(WorkspaceSession.instance.controller.currentIncident.id, sourceId);
      expect(
        routes.names.where((name) => name == 'ContinuousCaptureScreen').length,
        1,
      );
    },
  );

  testWidgets(
    '5. Abandoned recovery still releases the Home gate',
    (tester) async {
      await tester.runAsync(() async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        final sourceId = session.controller.currentIncident.id;
        await manager.getOrCreateActiveSession(
          incidentId: sourceId,
          userId: userId,
        );
        await DurableAttachIntentStore.savePendingIntent(
          DurableAttachIntent(
            userId: userId,
            sourceIncidentId: sourceId,
            origin: DurableAttachIntent.originWorkspaceSticky,
            operationId: 'op-14b-stale',
            createdAtMs: DateTime.now()
                .subtract(const Duration(hours: 25))
                .millisecondsSinceEpoch,
          ),
        );
        FileAttachFlow.endAttach();
        FileAttachFlow.workspaceRouteVisible = false;
        WorkspaceSession.instance.reset();
        FileAttachRecovery.debugReset();
      });

      await pumpAuthGate(tester);
      await pumpStartup(tester);

      expect(find.byType(MainShellScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
      expect(find.byType(ContinuousCaptureScreen), findsNothing);
    },
  );
}
