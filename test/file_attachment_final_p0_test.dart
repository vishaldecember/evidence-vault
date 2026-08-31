import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/navigation/app_navigator.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/home_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/file_attach_flow.dart';
import 'package:evidence_vault/services/storage/file_attachment_classifier.dart';
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
  const userId = 'user-file-final';

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_file_final_');
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
  }

  Future<void> cleanupEnv() async {
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

  Future<CapturedMediaFile> seedFile({
    required String name,
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

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  group('FileAttachmentClassifier', () {
    test('maps mpg/mpeg/mp4 to video persist mode', () {
      expect(
        FileAttachmentClassifier.persistMode(fileName: 'a.mpg'),
        WorkspaceCaptureMode.video,
      );
      expect(
        FileAttachmentClassifier.persistMode(fileName: 'a.mpeg'),
        WorkspaceCaptureMode.video,
      );
      expect(
        FileAttachmentClassifier.persistMode(fileName: 'a.mp4'),
        WorkspaceCaptureMode.video,
      );
      expect(
        FileAttachmentClassifier.guessMimeType('clip.mpg'),
        'video/mpeg',
      );
    });

    test('pdf stays file; txt supported; exe blocked', () {
      expect(
        FileAttachmentClassifier.persistMode(fileName: 'x.pdf'),
        WorkspaceCaptureMode.file,
      );
      expect(
        FileAttachmentClassifier.isSupported(fileName: 'x.pdf'),
        isTrue,
      );
      expect(
        FileAttachmentClassifier.isSupported(fileName: 'v3r_verify.txt'),
        isTrue,
      );
      expect(
        FileAttachmentClassifier.persistMode(fileName: 'v3r_verify.txt'),
        WorkspaceCaptureMode.file,
      );
      expect(
        FileAttachmentClassifier.isSupported(fileName: 'bad.exe'),
        isFalse,
      );
    });
  });

  testWidgets('A. Home Capture Now File small PDF → same incident Workspace',
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

    late FileAttachResult result;
    await tester.runAsync(() async {
      final media = await seedFile(name: 'small.pdf');
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: ctx,
        buildWorkspace: () => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
        acquireFile: () async => media,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.succeeded);
    expect(result.sourceIncidentId, incidentId);
    expect(session.controller.currentIncident.id, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 1);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(FileAttachFlow.attachInProgress, isFalse);
  });

  testWidgets('B. Workspace File small PDF keeps incident', (tester) async {
    late BuildContext ctx;
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: Builder(
          builder: (context) {
            ctx = context;
            return ContinuousCaptureScreen(controller: session.controller);
          },
        ),
      ),
    );
    await tester.pump();

    late FileAttachResult result;
    await tester.runAsync(() async {
      final media = await seedFile(name: 'ws.pdf');
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: ctx,
        buildWorkspace: () => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
        acquireFile: () async => media,
      );
    });
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.succeeded);
    expect(result.sourceIncidentId, incidentId);
    expect(session.controller.currentIncident.id, incidentId);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });

  testWidgets('C/D. Large PDF local-first + Workspace remains', (tester) async {
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

    late FileAttachResult result;
    await tester.runAsync(() async {
      final media =
          await seedFile(name: 'large.pdf', bytes: 6 * 1024 * 1024);
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: ctx,
        buildWorkspace: () => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
        acquireFile: () async => media,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.succeeded);
    expect(result.sourceIncidentId, incidentId);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(FileAttachFlow.attachInProgress, isFalse);
  });

  testWidgets('E/F/G. MP4/MPG/MPEG preserved as VIDEO', (tester) async {
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

    for (final name in ['clip.mp4', 'old.mpg', 'tape.mpeg']) {
      await tester.runAsync(() async {
        final media = await seedFile(name: name, bytes: 128);
        final result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.workspaceSticky,
          context: ctx,
          buildWorkspace: () => ContinuousCaptureScreen(
            controller: WorkspaceSession.instance.controller,
          ),
          acquireFile: () async => media,
        );
        expect(result.outcome, FileAttachOutcome.succeeded);
        expect(result.sourceIncidentId, incidentId);
      });
    }

    final videos = session.controller.aggregate.store.capturedEvidence
        .where((e) => e.type == CapturedEvidenceType.video)
        .toList();
    expect(videos.length, 3);
    for (final v in videos) {
      expect(v.incidentId, incidentId);
    }
  });

  testWidgets('H. Unsupported exe → failed + Workspace restored',
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
    });
    final incidentId = session.controller.currentIncident.id;

    late FileAttachResult result;
    await tester.runAsync(() async {
      final media = await seedFile(name: 'malware.exe');
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: ctx,
        buildWorkspace: () => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
        acquireFile: () async => media,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.failed);
    expect(result.userMessage, contains('supported'));
    expect(result.sourceIncidentId, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 0);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });

  testWidgets('I. Picker cancel → Workspace ensured, no evidence',
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
    });
    final incidentId = session.controller.currentIncident.id;

    late FileAttachResult result;
    await tester.runAsync(() async {
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: ctx,
        buildWorkspace: () => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
        acquireFile: () async => null,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.cancelled);
    expect(result.sourceIncidentId, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 0);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });

  testWidgets('J/K. Unmounted context still persists same incidentId',
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

    late CapturedMediaFile media;
    await tester.runAsync(() async {
      media = await seedFile(name: 'saf.pdf');
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: const Scaffold(body: Text('Shell')),
      ),
    );
    expect(ctx.mounted, isFalse);

    late FileAttachResult result;
    await tester.runAsync(() async {
      result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: ctx,
        buildWorkspace: () => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
        acquireFile: () async => media,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.succeeded);
    expect(result.sourceIncidentId, incidentId);
    expect(session.controller.currentIncident.id, incidentId);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
  });

  testWidgets('L. Cloud sync disabled — evidence still local', (tester) async {
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
    await tester.runAsync(() async {
      final media = await seedFile(name: 'offline.pdf');
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.workspaceSticky,
        context: ctx,
        buildWorkspace: () => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
        acquireFile: () async => media,
      );
      expect(result.outcome, FileAttachOutcome.succeeded);
    });
    expect(session.controller.currentIncident.id, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 1);
  });

  testWidgets('M. Five consecutive attaches — no Home, same incident',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: Builder(
          builder: (context) {
            ctx = context;
            return ContinuousCaptureScreen(
              controller: WorkspaceSession.instance.controller,
            );
          },
        ),
      ),
    );
    await tester.pump();
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;

    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() async {
        final media = await seedFile(name: 'seq_$i.pdf');
        final result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.workspaceSticky,
          context: ctx,
          buildWorkspace: () => ContinuousCaptureScreen(
            controller: WorkspaceSession.instance.controller,
          ),
          acquireFile: () async => media,
        );
        expect(result.outcome, FileAttachOutcome.succeeded);
        expect(result.sourceIncidentId, incidentId);
      });
      await tester.pump();
      expect(session.controller.currentIncident.id, incidentId);
      expect(find.byType(HomeScreen), findsNothing);
    }
    expect(session.controller.currentIncident.evidenceCount, 5);
    expect(FileAttachFlow.attachInProgress, isFalse);
  });

  testWidgets(
    'Organize File txt is Added context, not chronology-authoritative',
    (tester) async {
      late BuildContext ctx;
      final session = WorkspaceSession.instance;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: Text('organize'));
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        await session.beginNewCaptureIncident();
        await manager.getOrCreateActiveSession(
          incidentId: session.controller.currentIncident.id,
          userId: userId,
        );
      });
      FileAttachFlow.workspaceRouteVisible = true;
      final beforeCount = session.controller.currentIncident.evidenceCount;

      late FileAttachResult result;
      await tester.runAsync(() async {
        final media = await seedFile(name: 'v3r_verify.txt', bytes: 27);
        result = await FileAttachFlow.attach(
          origin: FileAttachOrigin.workspaceSticky,
          context: ctx,
          asOrganizeContext: true,
          buildWorkspace: () => const Scaffold(body: Text('restored-organize')),
          acquireFile: () async => media,
        );
      });
      await tester.pump();

      expect(result.outcome, FileAttachOutcome.succeeded);
      expect(session.controller.currentIncident.evidenceCount, beforeCount + 1);
      expect(session.controller.organizeCreatedEvidenceIds, hasLength(1));
      final created = session.controller.organizeCreatedEvidenceIds.single;
      expect(
        session.controller.currentIncident.evidence.any((e) => e.id == created),
        isTrue,
      );
      FileAttachFlow.workspaceRouteVisible = false;
    },
  );
}
