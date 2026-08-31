import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_resume_target.dart';
import 'package:evidence_vault/providers/authentication_state_provider.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/home_screen.dart';
import 'package:evidence_vault/services/auth/firebase_bootstrap.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final manager = CaptureSessionManager.instance;

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_file_nav_');
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
      userId: 'user-file-nav',
    );
  }

  Future<void> cleanupEnv() async {
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

  Future<void> seedIncident({String title = 'Workplace'}) async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-file-nav',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: title),
    );
    session.enterCapture();
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets(
      'A. Workspace File action stays on same incident workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seedIncident);

    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;
    controller.preserveForWidgetTest(WorkspaceCaptureMode.note, noteText: 'Prior');
    final beforeCount = controller.currentIncident.evidenceCount;

    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_action_file')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(controller.currentIncident.id, incidentId);
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
    expect(controller.currentIncident.evidenceCount, greaterThan(beforeCount));
    expect(find.text('Prior'), findsOneWidget);
  });

  test('B. File cancel leaves incident/session identity intact', () async {
    await seedIncident();
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;
    final beforeCount = controller.currentIncident.evidenceCount;

    // Cancel == no preserve call; identity must remain.
    expect(controller.currentIncident.id, incidentId);
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
    expect(controller.currentIncident.evidenceCount, beforeCount);
    expect(
      WorkspaceSession.instance.resumeTarget,
      WorkspaceResumeTarget.incidentWorkspace,
    );
  });

  test('C–G. Capture Now File attaches to new incident only (no duplicate)',
      () async {
    await seedIncident();
    final session = WorkspaceSession.instance;
    final priorId = session.controller.currentIncident.id;

    await session.beginNewCaptureIncident();
    await manager.getOrCreateActiveSession(
      incidentId: session.controller.currentIncident.id,
      userId: 'user-file-nav',
    );
    final newId = session.controller.currentIncident.id;
    expect(newId, isNot(priorId));

    session.controller.preserveForWidgetTest(WorkspaceCaptureMode.file);

    expect(session.controller.currentIncident.id, newId);
    expect(session.controller.currentIncident.evidenceCount, 1);
    expect(manager.getActiveSession(newId)?.id, isNotNull);
    expect(manager.getActiveSession(newId)!.incidentId, newId);
    expect(session.resumeTarget, WorkspaceResumeTarget.incidentWorkspace);
  });

  testWidgets(
      'AuthGate keeps MainShell through long transient auth null (picker)',
      (tester) async {
    final repository = FakeAuthRepository();
    final authState = AuthenticationStateProvider(authRepository: repository);
    addTearDown(authState.dispose);

    UserSessionService.establishSession(
      userId: 'uid-1',
      email: 'user@example.com',
      name: 'User',
    );
    authState.setAuthenticatedForTests(true);
    WorkspaceSession.instance.reset();
    await WorkspaceSession.instance.restoreForSignedInUser();

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authState: authState)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);

    // Simulate Firebase flicker while user browses SAF for > grace window.
    authState.setAuthenticatedForTests(false);
    await tester.pump();
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Create Account'), findsNothing);

    // Still in picker after several seconds — must NOT tear down to Home.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Create Account'), findsNothing);
    expect(UserSessionService.isSignedIn, isTrue);

    // Auth recovers when picker closes.
    authState.setAuthenticatedForTests(true);
    await tester.pump();
    expect(find.text('Home'), findsWidgets);

    // Repeated flicker (subsequent File attempts).
    authState.setAuthenticatedForTests(false);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Home'), findsWidgets);
    authState.setAuthenticatedForTests(true);
    await tester.pump();
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets(
      'AuthGate clears shell only when local session cleared (sign-out)',
      (tester) async {
    final repository = FakeAuthRepository();
    final authState = AuthenticationStateProvider(authRepository: repository);
    addTearDown(authState.dispose);

    UserSessionService.establishSession(
      userId: 'uid-1',
      email: 'user@example.com',
      name: 'User',
    );
    authState.setAuthenticatedForTests(true);
    WorkspaceSession.instance.reset();
    await WorkspaceSession.instance.restoreForSignedInUser();

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authState: authState)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);

    // Explicit sign-out clears local session then provider.
    UserSessionService.signOut();
    WorkspaceSession.instance.onSignedOut();
    authState.setAuthenticatedForTests(false);
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
  });
}
