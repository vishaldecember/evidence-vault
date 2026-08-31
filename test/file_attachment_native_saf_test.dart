import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/navigation/app_navigator.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/durable_attach_intent.dart';
import 'package:evidence_vault/services/storage/durable_attach_intent_store.dart';
import 'package:evidence_vault/services/storage/file_attach_flow.dart';
import 'package:evidence_vault/services/storage/file_attach_recovery.dart';
import 'package:evidence_vault/services/storage/file_attachment_persist.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/saf_staging_bridge.dart';
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
  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(root, 'support');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final manager = CaptureSessionManager.instance;
  const userId = 'user-file-native-saf';

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_native_saf_');
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
    FileAttachFlow.workspaceRouteVisible = false;
    FileAttachmentPersist.debugAfterDialogShown = null;
    FileAttachRecovery.debugReset();
    DurableAttachIntentStore.debugReset();
    SafStagingBridge.debugReset();
  }

  Future<void> cleanupEnv() async {
    FileAttachmentPersist.debugAfterDialogShown = null;
    FileAttachFlow.endAttach();
    FileAttachFlow.workspaceRouteVisible = false;
    FileAttachRecovery.debugReset();
    DurableAttachIntentStore.debugReset();
    SafStagingBridge.debugReset();
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

  Future<void> pumpShell(WidgetTester tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );
  }

  Future<void> bindSession({required String incidentId}) async {
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: userId,
    );
  }

  Future<DurableAttachIntent> seedIntent({
    required String incidentId,
    String origin = DurableAttachIntent.originWorkspaceSticky,
    String operationId = 'op-native',
    int? createdAtMs,
  }) async {
    final intent = DurableAttachIntent(
      userId: userId,
      sourceIncidentId: incidentId,
      origin: origin,
      operationId: operationId,
      createdAtMs: createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    await DurableAttachIntentStore.savePendingIntent(intent);
    return intent;
  }

  Future<void> simulateProcessDeathAndRestore({
    required String mustNotRemain,
  }) async {
    FileAttachFlow.endAttach();
    FileAttachFlow.workspaceRouteVisible = false;
    WorkspaceSession.instance.reset();
    expect(
      WorkspaceSession.instance.controller.currentIncident.id,
      isNot(mustNotRemain),
    );
    await WorkspaceSession.instance.restoreForSignedInUser();
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets('1. Complete native artifact is persisted exactly once', (
    tester,
  ) async {
    await pumpShell(tester);
    late String sourceId;
    late FileAttachRecoveryOutcome outcome;
    await tester.runAsync(() async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      sourceId = session.controller.currentIncident.id;
      await bindSession(incidentId: sourceId);
      await seedIntent(incidentId: sourceId, operationId: 'op-complete');
      final media = await seedPdf(name: 'native-complete.pdf', bytes: 128);
      final requested = <String>[];
      SafStagingBridge.debugGetArtifact = (id) async {
        requested.add(id);
        if (id != 'op-complete') {
          return null;
        }
        return SafStagedArtifact(
          operationId: id,
          path: media.localPath,
          size: media.fileSizeBytes,
          fileName: media.fileName,
          mimeType: 'application/pdf',
          sha256: 'abc123',
        );
      };
      await simulateProcessDeathAndRestore(mustNotRemain: sourceId);
      outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.persistedFromNative);
      expect(requested, contains('op-complete'));
      expect(session.controller.currentIncident.id, sourceId);
      expect(session.controller.currentIncident.evidenceCount, 1);
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
      outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.none);
      expect(session.controller.currentIncident.evidenceCount, 1);
    });
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.text(FileAttachRecovery.reselectMessage), findsNothing);
  });

  testWidgets('2. No native artifact falls back to reselect', (tester) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final sourceId = session.controller.currentIncident.id;
    late FileAttachRecoveryOutcome outcome;
    await tester.runAsync(() async {
      await bindSession(incidentId: sourceId);
      await seedIntent(incidentId: sourceId, operationId: 'op-none');
      SafStagingBridge.debugGetArtifact = (id) async => null;
      await simulateProcessDeathAndRestore(mustNotRemain: sourceId);
      outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.restoredReselectRequired);
      expect(session.controller.currentIncident.id, sourceId);
      expect(session.controller.currentIncident.evidenceCount, 0);
      final pending = await DurableAttachIntentStore.readPendingIntent(
        userId: userId,
      );
      expect(pending, isNotNull);
      expect(pending!.status, DurableAttachIntent.reselectRequired);
    });
    await tester.pump();
    expect(find.text(FileAttachRecovery.reselectMessage), findsOneWidget);
  });

  testWidgets('3. Partial native artifact is never attached', (tester) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final sourceId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await bindSession(incidentId: sourceId);
      await seedIntent(incidentId: sourceId, operationId: 'op-partial');
      SafStagingBridge.debugGetArtifact = (id) async => null;
      await simulateProcessDeathAndRestore(mustNotRemain: sourceId);
      final outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.restoredReselectRequired);
      expect(session.controller.currentIncident.evidenceCount, 0);
    });
    await tester.pump();
    expect(find.text(FileAttachRecovery.reselectMessage), findsOneWidget);
  });

  testWidgets('4. Recovery uses only the intent operationId', (tester) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final sourceId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await bindSession(incidentId: sourceId);
      await seedIntent(incidentId: sourceId, operationId: 'op-keep');
      final foreign = await seedPdf(name: 'foreign.pdf');
      final requested = <String>[];
      SafStagingBridge.debugGetArtifact = (id) async {
        requested.add(id);
        if (id == 'op-other') {
          return SafStagedArtifact(
            operationId: id,
            path: foreign.localPath,
            size: foreign.fileSizeBytes,
            fileName: foreign.fileName,
            mimeType: 'application/pdf',
          );
        }
        return null;
      };
      await simulateProcessDeathAndRestore(mustNotRemain: sourceId);
      final outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.restoredReselectRequired);
      expect(requested, ['op-keep']);
      expect(session.controller.currentIncident.evidenceCount, 0);
    });
  });

  testWidgets('5. Living success clears intent and discards staging', (
    tester,
  ) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final discarded = <String>[];
    await tester.runAsync(() async {
      await bindSession(incidentId: incidentId);
      SafStagingBridge.debugDiscard = (id) async => discarded.add(id);
      final media = await seedPdf(name: 'live-success.pdf');
      SafStagingBridge.debugGetArtifact = (id) async => SafStagedArtifact(
        operationId: id,
        path: media.localPath,
        size: media.fileSizeBytes,
        fileName: media.fileName,
        mimeType: 'application/pdf',
      );
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () async => media,
      );
      expect(result.outcome, FileAttachOutcome.succeeded);
      expect(session.controller.currentIncident.evidenceCount, 1);
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
      expect(discarded, isNotEmpty);
    });
  });

  testWidgets('6. Failed native persist keeps reselect recovery state', (
    tester,
  ) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final sourceId = session.controller.currentIncident.id;
    final discarded = <String>[];
    await tester.runAsync(() async {
      await bindSession(incidentId: sourceId);
      await seedIntent(incidentId: sourceId, operationId: 'op-fail');
      SafStagingBridge.debugDiscard = (id) async => discarded.add(id);
      SafStagingBridge.debugGetArtifact = (id) async => SafStagedArtifact(
        operationId: id,
        path: p.join(tempRoot.path, 'missing-native.pdf'),
        size: 12,
        fileName: 'missing-native.pdf',
        mimeType: 'application/pdf',
      );
      await simulateProcessDeathAndRestore(mustNotRemain: sourceId);
      final outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.restoredReselectRequired);
      expect(session.controller.currentIncident.id, sourceId);
      expect(session.controller.currentIncident.evidenceCount, 0);
      expect(discarded, contains('op-fail'));
      final pending = await DurableAttachIntentStore.readPendingIntent(
        userId: userId,
      );
      expect(pending, isNotNull);
      expect(pending!.status, DurableAttachIntent.reselectRequired);
    });
  });

  testWidgets('7. Explicit cancel discards staging and clears intent', (
    tester,
  ) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final discarded = <String>[];
    await tester.runAsync(() async {
      await bindSession(incidentId: incidentId);
      SafStagingBridge.debugDiscard = (id) async => discarded.add(id);
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () async => null,
      );
      expect(result.outcome, FileAttachOutcome.cancelled);
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
      expect(discarded, isNotEmpty);
      expect(session.controller.currentIncident.evidenceCount, 0);
    });
  });

  testWidgets('8. Native living path does not create duplicate evidence', (
    tester,
  ) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await bindSession(incidentId: incidentId);
      final media = await seedPdf(name: 'no-dup.pdf', bytes: 32);
      SafStagingBridge.debugGetArtifact = (id) async => SafStagedArtifact(
        operationId: id,
        path: media.localPath,
        size: media.fileSizeBytes,
        fileName: media.fileName,
        mimeType: 'application/pdf',
      );
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () async => media,
      );
      expect(result.outcome, FileAttachOutcome.succeeded);
      expect(session.controller.currentIncident.evidenceCount, 1);
    });
  });

  testWidgets('9. Cross-user recovery cannot consume another user artifact', (
    tester,
  ) async {
    await pumpShell(tester);
    late String ownerIncident;
    var artifactReads = 0;
    await tester.runAsync(() async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      ownerIncident = session.controller.currentIncident.id;
      await bindSession(incidentId: ownerIncident);
      await seedIntent(incidentId: ownerIncident, operationId: 'op-owner');
      final media = await seedPdf(name: 'owner.pdf');
      SafStagingBridge.debugGetArtifact = (id) async {
        artifactReads += 1;
        return SafStagedArtifact(
          operationId: id,
          path: media.localPath,
          size: media.fileSizeBytes,
          fileName: media.fileName,
          mimeType: 'application/pdf',
        );
      };

      UserSessionService.resetForTests();
      UserSessionService.establishSession(
        email: 'other@example.com',
        name: 'Other',
        userId: 'user-native-saf-other',
      );
      await simulateProcessDeathAndRestore(mustNotRemain: ownerIncident);
      final outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.none);
      expect(session.controller.currentIncident.id, isNot(ownerIncident));
      expect(session.controller.currentIncident.evidenceCount, 0);
      expect(artifactReads, 0);
    });
  });
}
