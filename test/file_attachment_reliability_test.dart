import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/models/workspace_resume_target.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/home_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/navigation/app_navigator.dart';
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
  const userId = 'user-file-reliability';

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_file_rel_');
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

  /// Mirrors Home `_handleCaptureTap` File success/cancel → Workspace open.
  void pushIncidentWorkspace(BuildContext context) {
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
    FileAttachFlow.endAttach();
    await cleanupEnv();
  });

  testWidgets(
    'A. Capture Now File select → same new incident Workspace',
    (tester) async {
      late BuildContext navContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              navContext = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );

      final session = WorkspaceSession.instance;
      await tester.runAsync(() async {
        await session.beginNewCaptureIncident();
        await manager.getOrCreateActiveSession(
          incidentId: session.controller.currentIncident.id,
          userId: userId,
        );
      });
      final incidentId = session.controller.currentIncident.id;

      late CaptureNowOutcome outcome;
      await tester.runAsync(() async {
        outcome = await HomeScreen.captureNowNoteOrFile(
          context: navContext,
          mode: WorkspaceCaptureMode.file,
          controller: session.controller,
          acquireFile: () async => seedPdf(),
        );
      });
      expect(outcome, CaptureNowOutcome.succeeded);
      expect(session.controller.currentIncident.id, incidentId);

      // Production always opens Workspace after File (success/cancel/fail).
      pushIncidentWorkspace(navContext);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 1);
      expect(
        session.controller.aggregate.store.supportingEvidence.single.incidentId,
        incidentId,
      );
    },
  );

  testWidgets(
    'B. Capture Now File cancel → new incident Workspace (not Home)',
    (tester) async {
      late BuildContext navContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              navContext = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );

      final session = WorkspaceSession.instance;
      await tester.runAsync(() async {
        await session.beginNewCaptureIncident();
        await manager.getOrCreateActiveSession(
          incidentId: session.controller.currentIncident.id,
          userId: userId,
        );
      });
      final incidentId = session.controller.currentIncident.id;

      late CaptureNowOutcome outcome;
      await tester.runAsync(() async {
        outcome = await HomeScreen.captureNowNoteOrFile(
          context: navContext,
          mode: WorkspaceCaptureMode.file,
          controller: session.controller,
          acquireFile: () async => null,
        );
      });
      expect(outcome, CaptureNowOutcome.cancelled);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 0);

      // Product: cancel opens the created incident Workspace — never Home.
      pushIncidentWorkspace(navContext);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 0);
    },
  );

  testWidgets(
    'C/D/E. Workspace File select keeps Workspace; cancel stays; priors remain',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      session.controller.replaceAggregate(
        IncidentAggregate.shell(id: incidentId, title: 'Existing'),
      );
      await tester.runAsync(() async {
        await manager.getOrCreateActiveSession(
          incidentId: incidentId,
          userId: userId,
        );
      });
      final prior = session.controller.preserveForWidgetTest(
        WorkspaceCaptureMode.photo,
      );
      final before = session.controller.currentIncident.evidenceCount;

      await tester.pumpWidget(
        MaterialApp(
          home: ContinuousCaptureScreen(controller: session.controller),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(find.byKey(Key('live_timeline_item_$prior')), findsOneWidget);

      // D — cancel: no attach, same Workspace.
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, before);

      // C — select file on same incident.
      late CapturedMediaFile media;
      await tester.runAsync(() async {
        media = await seedPdf(name: 'workspace.pdf');
        final ok = await FileAttachmentPersist.persistWithProgress(
          context: tester.element(
            find.byKey(const Key('continuous_capture_screen')),
          ),
          controller: session.controller,
          media: media,
        );
        expect(ok, FilePersistDialogResult.success);
      });
      await tester.pump();

      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, before + 1);
      expect(find.byKey(Key('live_timeline_item_$prior')), findsOneWidget);
      expect(
        session.controller.journeyEvidenceItems
            .where((e) => e.kind == WorkspaceEvidenceKind.attachment)
            .length,
        1,
      );
    },
  );

  test('F/G. File evidence incidentId; Capture Now creates one incident',
      () async {
    final session = WorkspaceSession.instance;
    final priorId = session.controller.currentIncident.id;
    await session.beginNewCaptureIncident();
    final newId = session.controller.currentIncident.id;
    expect(newId, isNot(priorId));
    await manager.getOrCreateActiveSession(
      incidentId: newId,
      userId: userId,
    );

    session.controller.preserveForWidgetTest(WorkspaceCaptureMode.file);
    expect(session.controller.currentIncident.id, newId);
    expect(session.controller.currentIncident.evidenceCount, 1);
    expect(
      session.controller.aggregate.store.supportingEvidence.single.incidentId,
      newId,
    );
  });

  testWidgets(
    'H/I. Large file persist + failure stay on Workspace (no Home)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      session.controller.preserveForWidgetTest(WorkspaceCaptureMode.note);

      await tester.pumpWidget(
        MaterialApp(
          home: ContinuousCaptureScreen(controller: session.controller),
        ),
      );
      await tester.pump();

      // Just over the large-file progress / off-UI copy threshold (5 MiB).
      final large = await tester.runAsync(
        () => seedPdf(name: 'terms.pdf', bytes: 5 * 1024 * 1024 + 8),
      );
      final ok = await tester.runAsync(() async {
        return FileAttachmentPersist.persistWithProgress(
          context: tester.element(
            find.byKey(const Key('continuous_capture_screen')),
          ),
          controller: session.controller,
          media: large!,
        );
      });
      await tester.pump();
      expect(ok, FilePersistDialogResult.success);
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, greaterThan(1));

      // I — import failure does not navigate Home.
      late CaptureNowOutcome failed;
      await tester.runAsync(() async {
        failed = await HomeScreen.captureNowNoteOrFile(
          context: tester.element(
            find.byKey(const Key('continuous_capture_screen')),
          ),
          mode: WorkspaceCaptureMode.file,
          controller: session.controller,
          acquireFile: () async {
            throw StateError('simulated import failure');
          },
        );
      });
      expect(failed, CaptureNowOutcome.failed);
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets(
    'J/K. Picker cancel (null) + multiple file attaches stay on same incident',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      await tester.pumpWidget(
        MaterialApp(
          home: ContinuousCaptureScreen(controller: session.controller),
        ),
      );
      await tester.pump();

      late CaptureNowOutcome cancelled;
      await tester.runAsync(() async {
        cancelled = await HomeScreen.captureNowNoteOrFile(
          context: tester.element(
            find.byKey(const Key('continuous_capture_screen')),
          ),
          mode: WorkspaceCaptureMode.file,
          controller: session.controller,
          acquireFile: () async => null,
        );
      });
      expect(cancelled, CaptureNowOutcome.cancelled);
      expect(session.controller.currentIncident.id, incidentId);
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() async {
          final media = await seedPdf(name: 'doc_$i.pdf');
          final ok = await FileAttachmentPersist.persistWithProgress(
            context: tester.element(
              find.byKey(const Key('continuous_capture_screen')),
            ),
            controller: session.controller,
            media: media,
          );
          expect(ok, FilePersistDialogResult.success);
        });
        await tester.pump();
        expect(session.controller.currentIncident.id, incidentId);
      }
      expect(session.controller.currentIncident.evidenceCount, 3);
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    },
  );

  test('L. Restart preserves file evidence via LocalEvidenceCache', () async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    final media = await seedPdf(name: 'restart.pdf');
    final id = session.controller.preserveForWidgetTest(
      WorkspaceCaptureMode.file,
    );
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: id,
        incidentId: incidentId,
        userId: userId,
        evidenceType: EvidenceRecordType.document,
        createdAt: DateTime.now(),
        capturedAt: DateTime.now(),
        syncStatus: EvidenceSyncStatus.localCaptured,
        localFilePath: media.localPath,
        fileName: media.fileName,
        fileSizeBytes: media.fileSizeBytes,
        captureMode: WorkspaceCaptureMode.file,
      ),
    );

    LocalEvidenceCache.resetForTests();
    final restored = await LocalEvidenceCache.forIncident(
      incidentId,
      userId: userId,
    );
    expect(restored, hasLength(1));
    expect(restored.single.evidenceId, id);
    expect(restored.single.incidentId, incidentId);
  });

  test('M. Offline/local attach keeps incident identity (no route dependency)',
      () async {
    final session = WorkspaceSession.instance;
    await session.beginNewCaptureIncident();
    final incidentId = session.controller.currentIncident.id;
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);

    session.controller.preserveForWidgetTest(WorkspaceCaptureMode.file);
    session.controller.preserveForWidgetTest(WorkspaceCaptureMode.file);

    expect(session.controller.currentIncident.id, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 2);
    for (final e in session.controller.aggregate.store.supportingEvidence) {
      expect(e.incidentId, incidentId);
    }
  });

  testWidgets(
    'N. Headless persist after SAF unmounts originating context',
    (tester) async {
      // Proven device failure: after document picker resume, Home/Workspace
      // BuildContext is unmounted. Persist must still commit via session.
      late BuildContext navContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Builder(
            builder: (context) {
              navContext = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );

      final session = WorkspaceSession.instance;
      await tester.runAsync(() async {
        await session.beginNewCaptureIncident();
        await manager.getOrCreateActiveSession(
          incidentId: session.controller.currentIncident.id,
          userId: userId,
        );
      });
      final incidentId = session.controller.currentIncident.id;

      late CapturedMediaFile media;
      await tester.runAsync(() async {
        media = await seedPdf(name: 'saf-resume.pdf');
      });

      // Drop the originating route so navContext is unmounted (SAF resume).
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Rebuilt shell')),
        ),
      );
      await tester.pump();
      expect(navContext.mounted, isFalse);

      late bool ok;
      await tester.runAsync(() async {
        ok = await FileAttachFlow.persistSelected(
          media,
          context: navContext,
        );
      });
      expect(ok, isTrue);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 1);
      expect(
        session.controller.aggregate.store.supportingEvidence.single.incidentId,
        incidentId,
      );
    },
  );

  testWidgets(
    'O. Home File after unmounted context still reaches Workspace',
    (tester) async {
      late BuildContext navContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Builder(
            builder: (context) {
              navContext = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );

      final session = WorkspaceSession.instance;
      await tester.runAsync(() async {
        await session.beginNewCaptureIncident();
        await manager.getOrCreateActiveSession(
          incidentId: session.controller.currentIncident.id,
          userId: userId,
        );
      });
      final incidentId = session.controller.currentIncident.id;

      late CaptureNowOutcome outcome;
      await tester.runAsync(() async {
        outcome = await HomeScreen.captureNowNoteOrFile(
          context: navContext,
          mode: WorkspaceCaptureMode.file,
          controller: session.controller,
          acquireFile: () async {
            // Simulate activity resume disposing Home before pick returns.
            await Future<void>.delayed(Duration.zero);
            return seedPdf(name: 'home-unmount.pdf');
          },
        );
      });

      // Force unmount before Workspace navigation (device: SAF killed route).
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Shell after SAF')),
        ),
      );
      await tester.pump();
      expect(navContext.mounted, isFalse);
      expect(outcome, CaptureNowOutcome.succeeded);

      // Success path keeps latch until Workspace reveal completes.
      FileAttachFlow.beginAttachForTests(
        origin: FileAttachOrigin.homeCaptureNow,
        incidentId: incidentId,
      );
      expect(FileAttachFlow.attachInProgress, isTrue);
      expect(FileAttachFlow.expectedIncidentId, incidentId);

      await tester.runAsync(() async {
        await FileAttachFlow.ensureWorkspaceVisibleThenEnd(
          buildWorkspace: () => ContinuousCaptureScreen(
            controller: WorkspaceSession.instance.controller,
          ),
        );
      });
      await tester.pump();
      await tester.pump();

      expect(FileAttachFlow.attachInProgress, isFalse);
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 1);
    },
  );

  testWidgets(
    'P. Consecutive FileAttachFlow attaches keep same incident',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: Text('ws'));
            },
          ),
        ),
      );

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      session.controller.preserveForWidgetTest(WorkspaceCaptureMode.note);

      await tester.runAsync(() async {
        final a = await seedPdf(name: 'a.pdf');
        final b = await seedPdf(name: 'b.pdf');
        expect(
          await FileAttachFlow.persistSelected(a, context: ctx),
          isTrue,
        );
        expect(
          await FileAttachFlow.persistSelected(b, context: ctx),
          isTrue,
        );
      });

      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 3);
    },
  );

  testWidgets(
    'Q. attachInProgress stays true until endAttach (blocks mid-durableize pop)',
    (tester) async {
      FileAttachFlow.endAttach();
      expect(FileAttachFlow.attachInProgress, isFalse);

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: Text('ws'));
            },
          ),
        ),
      );

      FileAttachFlow.attachInProgress = true;
      expect(FileAttachFlow.pickerActive, isTrue);

      late bool ok;
      await tester.runAsync(() async {
        final media =
            await seedPdf(name: 'latch.pdf', bytes: 6 * 1024 * 1024);
        ok = await FileAttachFlow.persistSelected(media, context: ctx);
      });

      expect(ok, isTrue);
      expect(
        FileAttachFlow.attachInProgress,
        isTrue,
        reason: 'persist must not clear latch before endAttach',
      );
      FileAttachFlow.endAttach();
      expect(FileAttachFlow.attachInProgress, isFalse);
    },
  );

  testWidgets(
    'R. Large file local-first with cloud sync disabled still attaches',
    (tester) async {
      EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: Text('ws'));
            },
          ),
        ),
      );

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      late CapturedMediaFile media;
      await tester.runAsync(() async {
        media = await seedPdf(name: 'large.bin', bytes: 6 * 1024 * 1024);
        expect(
          await FileAttachFlow.persistSelected(media, context: ctx),
          isTrue,
        );
      });

      expect(session.controller.currentIncident.id, incidentId);
      expect(session.controller.currentIncident.evidenceCount, 1);
      final item =
          session.controller.aggregate.store.supportingEvidence.single;
      expect(item.incidentId, incidentId);
      expect(item.filePath, isNotNull);
    },
  );

  test('S. endAttach clears latch after simulated cancel', () {
    FileAttachFlow.attachInProgress = true;
    FileAttachFlow.endAttach();
    expect(FileAttachFlow.attachInProgress, isFalse);
    FileAttachFlow.endAttach(); // idempotent
    expect(FileAttachFlow.attachInProgress, isFalse);
  });

  testWidgets(
    'T. Full transaction: pick latch → large persist → Workspace → unlock',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );

      final session = WorkspaceSession.instance;
      await tester.runAsync(() async {
        await session.beginNewCaptureIncident();
        await manager.getOrCreateActiveSession(
          incidentId: session.controller.currentIncident.id,
          userId: userId,
        );
      });
      final incidentId = session.controller.currentIncident.id;

      FileAttachFlow.beginAttachForTests(
        origin: FileAttachOrigin.workspaceSticky,
        incidentId: incidentId,
      );
      expect(FileAttachFlow.attachInProgress, isTrue);

      late CapturedMediaFile media;
      await tester.runAsync(() async {
        media =
            await seedPdf(name: 'txn-large.pdf', bytes: 6 * 1024 * 1024);
      });

      // Unmount originating context (SAF resume).
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Shell')),
        ),
      );
      await tester.pump();
      expect(ctx.mounted, isFalse);

      late bool ok;
      await tester.runAsync(() async {
        ok = await FileAttachFlow.persistSelected(media, context: ctx);
      });
      expect(ok, isTrue);
      expect(FileAttachFlow.attachInProgress, isTrue,
          reason: 'lock held through persist');
      expect(session.controller.currentIncident.id, incidentId);
      expect(
        session.controller.aggregate.store.supportingEvidence.single.incidentId,
        incidentId,
      );

      await tester.runAsync(() async {
        await FileAttachFlow.ensureWorkspaceVisibleThenEnd(
          buildWorkspace: () => ContinuousCaptureScreen(
            controller: WorkspaceSession.instance.controller,
          ),
        );
      });
      await tester.pump();
      await tester.pump();

      expect(FileAttachFlow.attachInProgress, isFalse);
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(session.controller.currentIncident.id, incidentId);
    },
  );

  testWidgets(
    'U. Dialog contextLost falls back headless; failed does not duplicate',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: Text('ws'));
            },
          ),
        ),
      );

      final session = WorkspaceSession.instance;
      final incidentId = session.controller.currentIncident.id;
      FileAttachFlow.beginAttachForTests(
        origin: FileAttachOrigin.workspaceSticky,
        incidentId: incidentId,
      );

      // Unmounted context → contextLost → headless persist.
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('gone')),
        ),
      );
      expect(ctx.mounted, isFalse);

      await tester.runAsync(() async {
        final media = await seedPdf(name: 'headless-small.pdf');
        expect(
          await FileAttachFlow.persistSelected(media, context: ctx),
          isTrue,
        );
      });
      expect(session.controller.currentIncident.evidenceCount, 1);
      expect(
        session.controller.aggregate.store.supportingEvidence.single.incidentId,
        incidentId,
      );
      FileAttachFlow.endAttach();
    },
  );
}
