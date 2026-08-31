import 'dart:async';
import 'dart:convert';
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
  const userId = 'user-file-13d';

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_file_13d_');
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
  }

  Future<void> cleanupEnv() async {
    FileAttachmentPersist.debugAfterDialogShown = null;
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
    String operationId = 'op-13d',
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

  testWidgets('1. Attach intent is saved before picker and cleared on success', (
    tester,
  ) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await bindSession(incidentId: incidentId);
      final gate = Completer<CapturedMediaFile?>();
      final future = FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () => gate.future,
      );

      DurableAttachIntent? saved;
      for (var i = 0; i < 40 && saved == null; i++) {
        saved = await DurableAttachIntentStore.readPendingIntent(
          userId: userId,
        );
        if (saved == null) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }
      expect(saved, isNotNull);
      expect(saved!.sourceIncidentId, incidentId);
      expect(saved.origin, DurableAttachIntent.originWorkspaceSticky);
      expect(saved.modality, 'file');
      expect(saved.status, DurableAttachIntent.awaitingPicker);
      expect(saved.operationId, isNotEmpty);

      gate.complete(await seedPdf(name: 'saved-before-picker.pdf'));
      final result = await future;
      expect(result.outcome, FileAttachOutcome.succeeded);
      expect(result.sourceIncidentId, incidentId);
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
    });
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });

  testWidgets('2. Intent survives simulated process/session restart', (
    tester,
  ) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await bindSession(incidentId: incidentId);
      await seedIntent(
        incidentId: incidentId,
        operationId: 'op-survive',
      );
      await simulateProcessDeathAndRestore(mustNotRemain: incidentId);
      final restored = await DurableAttachIntentStore.readPendingIntent(
        userId: userId,
      );
      expect(restored, isNotNull);
      expect(restored!.sourceIncidentId, incidentId);
      expect(restored.operationId, 'op-survive');
    });
  });

  testWidgets(
    '3. Home Capture Now recovery restores the exact source incident',
    (tester) async {
      await pumpShell(tester);
      late String sourceId;
      late FileAttachRecoveryOutcome outcome;
      await tester.runAsync(() async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        sourceId = session.controller.currentIncident.id;
        await bindSession(incidentId: sourceId);
        await seedIntent(
          incidentId: sourceId,
          origin: DurableAttachIntent.originHomeCaptureNow,
          operationId: 'op-home',
        );
        final evidenceBefore = session.controller.currentIncident.evidenceCount;
        await simulateProcessDeathAndRestore(mustNotRemain: sourceId);
        outcome = await FileAttachRecovery.recoverIfNeeded();
        expect(outcome, FileAttachRecoveryOutcome.restoredReselectRequired);
        expect(session.controller.currentIncident.id, sourceId);
        expect(
          session.controller.currentIncident.evidenceCount,
          evidenceBefore,
        );
        final pending = await DurableAttachIntentStore.readPendingIntent(
          userId: userId,
        );
        expect(pending, isNotNull);
        expect(pending!.status, DurableAttachIntent.reselectRequired);
      });
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
      expect(find.text(FileAttachRecovery.reselectMessage), findsOneWidget);
    },
  );

  testWidgets(
    '4. Workspace File recovery restores the exact existing incident',
    (tester) async {
      await pumpShell(tester);
      final session = WorkspaceSession.instance;
      final sourceId = session.controller.currentIncident.id;
      late FileAttachRecoveryOutcome outcome;
      await tester.runAsync(() async {
        await bindSession(incidentId: sourceId);
        await seedIntent(
          incidentId: sourceId,
          origin: DurableAttachIntent.originWorkspaceSticky,
          operationId: 'op-workspace',
        );
        await simulateProcessDeathAndRestore(mustNotRemain: sourceId);
        outcome = await FileAttachRecovery.recoverIfNeeded();
        expect(outcome, FileAttachRecoveryOutcome.restoredReselectRequired);
        expect(session.controller.currentIncident.id, sourceId);
      });
      await tester.pump();
      await tester.pump();
      expect(outcome, FileAttachRecoveryOutcome.restoredReselectRequired);
      expect(
        find.byKey(const Key('incident_workspace_screen')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '5. Recovery does not create a new incident or duplicate evidence',
    (tester) async {
      await pumpShell(tester);
      late String sourceId;
      await tester.runAsync(() async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        sourceId = session.controller.currentIncident.id;
        await bindSession(incidentId: sourceId);
        await seedIntent(incidentId: sourceId, operationId: 'op-no-dup');
        await simulateProcessDeathAndRestore(mustNotRemain: sourceId);
        final idAfterDeath = session.controller.currentIncident.id;
        await FileAttachRecovery.recoverIfNeeded();
        expect(session.controller.currentIncident.id, sourceId);
        expect(session.controller.currentIncident.id, isNot(idAfterDeath));
        expect(session.controller.currentIncident.evidenceCount, 0);
      });
    },
  );

  testWidgets(
    '6. Recovery does not reopen the most recent incident in place of source',
    (tester) async {
      await pumpShell(tester);
      late String idA;
      late String idB;
      await tester.runAsync(() async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        idA = session.controller.currentIncident.id;
        await bindSession(incidentId: idA);
        await session.beginNewCaptureIncident();
        idB = session.controller.currentIncident.id;
        await bindSession(incidentId: idB);
        expect(idA, isNot(idB));
        await seedIntent(
          incidentId: idA,
          origin: DurableAttachIntent.originHomeCaptureNow,
          operationId: 'op-not-latest',
        );
        await simulateProcessDeathAndRestore(mustNotRemain: idA);
        await FileAttachRecovery.recoverIfNeeded();
        expect(session.controller.currentIncident.id, idA);
        expect(session.controller.currentIncident.id, isNot(idB));
      });
    },
  );

  testWidgets('7. Explicit picker cancellation clears intent and stays', (
    tester,
  ) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await bindSession(incidentId: incidentId);
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () async => null,
      );
      expect(result.outcome, FileAttachOutcome.cancelled);
      expect(result.sourceIncidentId, incidentId);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 0);
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
    });
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });

  testWidgets(
    '8. Process-death / null picker result does not clear intent automatically',
    (tester) async {
      await pumpShell(tester);
      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      await tester.runAsync(() async {
        await bindSession(incidentId: incidentId);
        await seedIntent(incidentId: incidentId, operationId: 'op-death-null');
        FileAttachFlow.endAttach();
        expect(
          await DurableAttachIntentStore.readPendingIntent(userId: userId),
          isNotNull,
        );
      });
    },
  );

  testWidgets('9. Ownership mismatch fails closed', (tester) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final originalId = session.controller.currentIncident.id;
    late FileAttachRecoveryOutcome outcome;
    await tester.runAsync(() async {
      await bindSession(incidentId: originalId);
      await seedIntent(
        incidentId: 'inc-foreign-unproven',
        operationId: 'op-foreign',
      );
      await session.restoreForSignedInUser();
      outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.abandoned);
      expect(session.controller.currentIncident.id, originalId);
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
    });
    await tester.pump();
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
  });

  testWidgets('10. Signed-in user cannot recover another user intent', (
    tester,
  ) async {
    await pumpShell(tester);
    late String ownerIncident;
    late FileAttachRecoveryOutcome outcome;
    await tester.runAsync(() async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      ownerIncident = session.controller.currentIncident.id;
      await bindSession(incidentId: ownerIncident);
      await seedIntent(incidentId: ownerIncident, operationId: 'op-owner-a');

      UserSessionService.resetForTests();
      UserSessionService.establishSession(
        email: 'other@example.com',
        name: 'Other',
        userId: 'user-file-13d-other',
      );
      await simulateProcessDeathAndRestore(mustNotRemain: ownerIncident);
      final otherIncident = session.controller.currentIncident.id;
      outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.none);
      expect(session.controller.currentIncident.id, otherIncident);
      expect(session.controller.currentIncident.id, isNot(ownerIncident));
    });
  });

  testWidgets('11. Stale intent is abandoned safely', (tester) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await bindSession(incidentId: incidentId);
      final created = DateTime.now()
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch;
      await seedIntent(
        incidentId: incidentId,
        operationId: 'op-stale',
        createdAtMs: created,
      );
      DurableAttachIntentStore.now = () => DateTime.now();
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
      await session.restoreForSignedInUser();
      final outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.none);
      expect(session.controller.currentIncident.id, incidentId);
    });
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
  });

  testWidgets('12. Malformed intent is discarded', (tester) async {
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'ev_durable_attach_intent_v1_$userId',
        '{not-json',
      );
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
      await prefs.setString(
        'ev_durable_attach_intent_v1_$userId',
        jsonEncode({'userId': userId, 'sourceIncidentId': ''}),
      );
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
    });
  });

  testWidgets(
    '13. Successful PDF attach clears intent at the local commit point',
    (tester) async {
      await pumpShell(tester);
      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      await tester.runAsync(() async {
        await bindSession(incidentId: incidentId);
        final media = await seedPdf(name: 'commit.pdf');
        final result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.homeCaptureNow,
          context: appNavigatorKey.currentContext,
          buildWorkspace: () =>
              ContinuousCaptureScreen(controller: session.controller),
          acquireFile: () async => media,
        );
        expect(result.outcome, FileAttachOutcome.succeeded);
        expect(session.controller.currentIncident.id, incidentId);
        expect(session.controller.currentIncident.evidenceCount, greaterThan(0));
        expect(
          await DurableAttachIntentStore.readPendingIntent(userId: userId),
          isNull,
        );
      });
    },
  );

  testWidgets('14. Failed durability does not claim preservation', (
    tester,
  ) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await bindSession(incidentId: incidentId);
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: appNavigatorKey.currentContext,
        buildWorkspace: () =>
            ContinuousCaptureScreen(controller: session.controller),
        acquireFile: () async => const CapturedMediaFile(
          localPath: '/missing/ephemeral-13d.pdf',
          fileName: 'ephemeral-13d.pdf',
          fileSizeBytes: 12,
        ),
      );
      expect(result.outcome, FileAttachOutcome.failed);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 0);
      expect(
        await DurableAttachIntentStore.readPendingIntent(userId: userId),
        isNull,
      );
    });
  });

  testWidgets('15. Rapid attach attempts cannot clobber a newer intent', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedIntent(incidentId: 'inc-a', operationId: 'op-old');
      await seedIntent(incidentId: 'inc-b', operationId: 'op-new');
      await DurableAttachIntentStore.clearPendingIntent(
        userId: userId,
        operationId: 'op-old',
        reason: 'stale_attempt',
      );
      final kept = await DurableAttachIntentStore.readPendingIntent(
        userId: userId,
      );
      expect(kept, isNotNull);
      expect(kept!.operationId, 'op-new');
      expect(kept.sourceIncidentId, 'inc-b');
    });
  });

  testWidgets('16. No pending intent does nothing', (tester) async {
    await pumpShell(tester);
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await session.restoreForSignedInUser();
      final outcome = await FileAttachRecovery.recoverIfNeeded();
      expect(outcome, FileAttachRecoveryOutcome.none);
      expect(session.controller.currentIncident.id, incidentId);
    });
    expect(find.byKey(const Key('incident_workspace_screen')), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
