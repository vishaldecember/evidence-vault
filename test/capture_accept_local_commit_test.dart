import 'dart:io';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_session.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
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
  late WorkspaceEvidenceController controller;

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_31_accept_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    await EvidenceSyncManager.instance.resetForTests();
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-31',
    );
    ContinuousCaptureSession.debugFailVoiceDurability = false;
    ContinuousCaptureSession.debugFailLocalCommit = false;
    controller = WorkspaceSession.instance.controller;
  }

  Future<void> cleanupEnv() async {
    ContinuousCaptureSession.debugFailVoiceDurability = false;
    ContinuousCaptureSession.debugFailLocalCommit = false;
    await EvidenceSyncManager.instance.resetForTests();
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

  Future<void> pumpSession(
    WidgetTester tester,
    WorkspaceCaptureMode mode,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureSession(
          controller: controller,
          mode: mode,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpCockpit(
    WidgetTester tester,
    WorkspaceCaptureMode mode,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureCockpitScreen(
          initialMode: mode,
          controller: controller,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> acceptPreview(WidgetTester tester) async {
    final accept = find.byTooltip('Accept');
    if (accept.evaluate().isNotEmpty) {
      await tester.tap(accept);
    } else {
      await tester.tap(find.text('Accept'));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets('1. successful Accept dismisses photo preview after local commit',
      (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.photo);
    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();
    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(controller.currentIncident.evidenceCount, 0);

    await acceptPreview(tester);

    expect(controller.currentIncident.evidenceCount, 1);
    expect(find.byTooltip('Accept'), findsNothing);
    expect(find.byKey(const Key('photo_shutter')), findsOneWidget);
    expect(
      find.text(ContinuousCaptureSession.localCommitFailureMessage),
      findsNothing,
    );
  });

  testWidgets(
    '2. durability failure keeps photo preview and shows error',
    (tester) async {
      ContinuousCaptureSession.debugFailLocalCommit = true;
      await pumpSession(tester, WorkspaceCaptureMode.photo);
      await tester.tap(find.byKey(const Key('photo_shutter')));
      await tester.pump();

      await acceptPreview(tester);

      expect(controller.currentIncident.evidenceCount, 0);
      expect(find.byTooltip('Accept'), findsOneWidget);
      expect(
        find.text(ContinuousCaptureSession.localCommitFailureMessage),
        findsOneWidget,
      );
    },
  );

  testWidgets('3. retry after durability failure preserves once', (tester) async {
    ContinuousCaptureSession.debugFailLocalCommit = true;
    await pumpSession(tester, WorkspaceCaptureMode.photo);
    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();
    await acceptPreview(tester);
    expect(controller.currentIncident.evidenceCount, 0);
    expect(find.byTooltip('Accept'), findsOneWidget);

    ContinuousCaptureSession.debugFailLocalCommit = false;
    await acceptPreview(tester);

    expect(controller.currentIncident.evidenceCount, 1);
    expect(find.byTooltip('Accept'), findsNothing);
    expect(
      controller.currentIncident.evidence.map((e) => e.id).toSet(),
      hasLength(1),
    );
  });

  testWidgets(
    '4. stale incident keeps preview and does not attach to the new incident',
    (tester) async {
      await pumpSession(tester, WorkspaceCaptureMode.photo);
      final openedId = controller.currentIncident.id;
      await tester.tap(find.byKey(const Key('photo_shutter')));
      await tester.pump();

      controller.replaceAggregate(
        IncidentAggregate.shell(id: 'incident-other', title: 'Other'),
      );
      expect(controller.currentIncident.id, isNot(openedId));

      await acceptPreview(tester);

      expect(controller.currentIncident.id, 'incident-other');
      expect(controller.currentIncident.evidenceCount, 0);
      expect(find.byTooltip('Accept'), findsOneWidget);
      expect(
        find.text(ContinuousCaptureSession.staleIncidentFailureMessage),
        findsOneWidget,
      );
    },
  );

  testWidgets('5. successful video Accept dismisses preview after commit',
      (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.video);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(find.byTooltip('Accept'), findsOneWidget);

    await acceptPreview(tester);

    expect(controller.currentIncident.evidenceCount, 1);
    expect(find.byTooltip('Accept'), findsNothing);
  });

  testWidgets('6. video durability failure keeps preview and shows error',
      (tester) async {
    ContinuousCaptureSession.debugFailLocalCommit = true;
    await pumpSession(tester, WorkspaceCaptureMode.video);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    await acceptPreview(tester);

    expect(controller.currentIncident.evidenceCount, 0);
    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(
      find.text(ContinuousCaptureSession.localCommitFailureMessage),
      findsOneWidget,
    );
  });

  testWidgets('7. successful voice Accept dismisses preview after commit',
      (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.voice);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(find.text('Accept'), findsOneWidget);

    await acceptPreview(tester);

    expect(controller.currentIncident.evidenceCount, 1);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('8. voice durability failure keeps preview and shows error',
      (tester) async {
    ContinuousCaptureSession.debugFailLocalCommit = true;
    await pumpSession(tester, WorkspaceCaptureMode.voice);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    await acceptPreview(tester);

    expect(controller.currentIncident.evidenceCount, 0);
    expect(find.text('Accept'), findsOneWidget);
    expect(
      find.text(ContinuousCaptureSession.localCommitFailureMessage),
      findsOneWidget,
    );
  });

  testWidgets(
    '9. Cockpit DONE stays on failed commit so the user can retry',
    (tester) async {
      ContinuousCaptureSession.debugFailLocalCommit = true;
      await pumpCockpit(tester, WorkspaceCaptureMode.photo);
      await tester.tap(find.byKey(const Key('photo_shutter')));
      await tester.pump();
      expect(find.byKey(const Key('capture_preview_accept')), findsOneWidget);

      await tester.tap(find.byKey(const Key('capture_cockpit_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
      expect(find.byKey(const Key('capture_preview_accept')), findsOneWidget);
      expect(controller.currentIncident.evidenceCount, 0);
      expect(
        find.text(ContinuousCaptureSession.localCommitFailureMessage),
        findsOneWidget,
      );

      ContinuousCaptureSession.debugFailLocalCommit = false;
      await tester.tap(find.byKey(const Key('capture_preview_accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.currentIncident.evidenceCount, 1);
      expect(find.byKey(const Key('capture_preview_accept')), findsNothing);
    },
  );

  test('10. Accept production path still registers canonical sync', () async {
    final source = File(p.join(tempRoot.path, 'shot.jpg'));
    await source.writeAsBytes(List<int>.filled(48, 9));
    final incidentId = controller.currentIncident.id;

    final id = await controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.photo,
      media: CapturedMediaFile(
        localPath: source.path,
        fileName: 'shot.jpg',
        fileSizeBytes: 48,
        thumbnailPath: source.path,
      ),
    );

    expect(id, isNotEmpty);
    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.evidenceCount, 1);
    expect(controller.currentIncident.evidence.single.id, id);
    expect(await LocalEvidenceCache.byId(id), isNotNull);
    expect(
      EvidenceSyncManager.instance.queue.items.any((e) => e.evidenceId == id),
      isTrue,
    );
  });
}
