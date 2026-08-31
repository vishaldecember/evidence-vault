import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/capture/capture_session_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/persistence/local_incident_pointer.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/local_evidence_hydrator.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/home/session_resume_card.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
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

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_cc_ux_');
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
      userId: 'user-6c31',
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

  Future<void> seedActiveSession() async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c31',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace incident'),
    );
  }

  Future<void> rebuildCaptureScreen(
    WidgetTester tester, {
    bool pushRoute = false,
  }) async {
    final screen = ContinuousCaptureScreen(
      controller: WorkspaceSession.instance.controller,
    );
    if (pushRoute) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open_continuous_capture'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => screen),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open_continuous_capture')));
      await tester.pump();
      await tester.pump();
      return;
    }
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
  }

  Future<void> pumpCaptureScreen(
    WidgetTester tester, {
    bool pushRoute = false,
  }) async {
    await tester.runAsync(seedActiveSession);
    await rebuildCaptureScreen(tester, pushRoute: pushRoute);
  }

  group('Clean Continuous Capture UX', () {
    setUp(() async {
      await prepareEnv();
    });

    tearDown(() async {
      await cleanupEnv();
    });

    testWidgets('1. opens without timer', (tester) async {
      await pumpCaptureScreen(tester);
      expect(find.byKey(const Key('continuous_capture_screen')), findsOneWidget);
      expect(find.byKey(const Key('continuous_capture_duration')), findsNothing);
      expect(find.textContaining(RegExp(r'^\d{2}:\d{2}')), findsNothing);
    });

    testWidgets('2-3. does not expose Pause or Resume Session', (tester) async {
      await pumpCaptureScreen(tester);
      expect(find.text('Pause Session'), findsNothing);
      expect(find.text('Resume Session'), findsNothing);
      expect(find.byKey(const Key('session_pause_button')), findsNothing);
      expect(find.byKey(const Key('session_resume_button')), findsNothing);
      expect(find.text('Complete Session'), findsNothing);
    });

    testWidgets('4. header displays PRESERVING', (tester) async {
      await pumpCaptureScreen(tester);
      expect(find.text('PRESERVING'), findsOneWidget);
      expect(
        find.byKey(const Key('continuous_capture_preserving_label')),
        findsOneWidget,
      );
      expect(find.text('Active'), findsNothing);
      expect(find.text('Paused'), findsNothing);
    });

    testWidgets('5. evidence count equals live timeline count', (tester) async {
      await pumpCaptureScreen(tester);
      final controller = WorkspaceSession.instance.controller;
      await tester.runAsync(() async {
        await controller.preserveTextNote('First');
        await controller.preserveTextNote('Second');
        await manager.restoreForIncident(
          incidentId: controller.currentIncident.id,
          userId: 'user-6c31',
        );
      });
      await rebuildCaptureScreen(tester);

      final timeline = find.byKey(const Key('live_evidence_timeline'));
      expect(timeline, findsOneWidget);
      final itemCount = find
          .descendant(
            of: timeline,
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                        'live_timeline_item_',
                      ),
            ),
          )
          .evaluate()
          .length;
      expect(find.text('$itemCount evidence'), findsOneWidget);
      expect(itemCount, 2);
    });

    testWidgets('6-10. each capture mode appears in timeline', (tester) async {
      await pumpCaptureScreen(tester);
      final controller = WorkspaceSession.instance.controller;
      final photo = await tester.runAsync(() async {
        final file = File(p.join(tempRoot.path, 'shot.jpg'));
        await file.writeAsBytes(List<int>.filled(32, 7));
        return file;
      });

      await tester.runAsync(() async {
        controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
        controller.preserveForWidgetTest(WorkspaceCaptureMode.video);
        controller.preserveForWidgetTest(WorkspaceCaptureMode.voice);
        await controller.preserveTextNote('Timeline note');
        controller.preserveForWidgetTest(WorkspaceCaptureMode.file);
        await manager.restoreForIncident(
          incidentId: controller.currentIncident.id,
          userId: 'user-6c31',
        );
      });
      expect(photo, isNotNull);
      await rebuildCaptureScreen(tester);
      // Newest-at-bottom ListView — scroll so all kinds are built/visible.
      await tester.drag(
        find.byKey(const Key('live_evidence_timeline')),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsWidgets);
      expect(find.text('Video'), findsWidgets);
      expect(find.text('Voice Note'), findsWidgets);
      expect(find.text('Note'), findsWidgets);
      expect(find.text('Attachment'), findsWidgets);
      expect(find.byKey(const Key('live_timeline_voice_wave')), findsWidgets);
      expect(find.byKey(const Key('live_timeline_video_play_icon')), findsWidgets);

      final count = controller.journeyEvidenceItems.length;
      expect(find.text('$count evidence'), findsOneWidget);
      expect(count, greaterThanOrEqualTo(5));
    });

    testWidgets('11. file remains attachment semantic type', (tester) async {
      await pumpCaptureScreen(tester);
      final controller = WorkspaceSession.instance.controller;
      await tester.runAsync(() async {
        final imageAsFile = File(p.join(tempRoot.path, 'scan.png'));
        await imageAsFile.writeAsBytes(List<int>.filled(24, 1));
        controller.preserveForWidgetTest(WorkspaceCaptureMode.file);
        await manager.restoreForIncident(
          incidentId: controller.currentIncident.id,
          userId: 'user-6c31',
        );
      });
      await rebuildCaptureScreen(tester);

      final files = controller.journeyEvidenceItems
          .where((e) => e.kind == WorkspaceEvidenceKind.attachment)
          .toList();
      expect(files, isNotEmpty);
      await tester.drag(
        find.byKey(const Key('live_evidence_timeline')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attachment'), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>)
                  .value
                  .startsWith('live_timeline_file_visual_'),
        ),
        findsWidgets,
      );
    });

    testWidgets('12-13. adding evidence keeps prior items', (tester) async {
      await pumpCaptureScreen(tester);
      final controller = WorkspaceSession.instance.controller;
      await tester.runAsync(() async {
        await controller.preserveTextNote('Keep me');
        await manager.restoreForIncident(
          incidentId: controller.currentIncident.id,
          userId: 'user-6c31',
        );
      });
      await rebuildCaptureScreen(tester);
      final firstId = controller.journeyEvidenceItems.first.id;

      await tester.runAsync(() async {
        controller.preserveForWidgetTest(WorkspaceCaptureMode.file);
        await manager.restoreForIncident(
          incidentId: controller.currentIncident.id,
          userId: 'user-6c31',
        );
      });
      await rebuildCaptureScreen(tester);

      expect(find.byKey(Key('live_timeline_item_$firstId')), findsOneWidget);
      expect(controller.journeyEvidenceItems.length, greaterThanOrEqualTo(2));
    });

    testWidgets('14-16. leave and DONE preserve evidence', (tester) async {
      await pumpCaptureScreen(tester, pushRoute: true);
      final controller = WorkspaceSession.instance.controller;
      final incidentId = controller.currentIncident.id;
      await tester.runAsync(() async {
        await controller.preserveTextNote('Survives leave');
        await manager.restoreForIncident(
          incidentId: incidentId,
          userId: 'user-6c31',
        );
      });
      final countBefore = controller.currentIncident.evidenceCount;
      expect(countBefore, greaterThan(0));

      // Leave without DONE (system pop of route).
      Navigator.of(
        tester.element(find.byKey(const Key('continuous_capture_screen'))),
      ).pop();
      await tester.pump();
      expect(controller.currentIncident.evidenceCount, countBefore);

      await rebuildCaptureScreen(tester, pushRoute: true);
      expect(find.text('Survives leave'), findsOneWidget);

      final sessionId = manager.getActiveSession(incidentId)!.id;
      // DONE completes the internal CaptureSession quietly, then pops.
      await tester.runAsync(() => manager.completeSession(sessionId: sessionId));
      Navigator.of(
        tester.element(find.byKey(const Key('continuous_capture_screen'))),
      ).pop();
      await tester.pump();
      await tester.pump();

      expect(controller.currentIncident.evidenceCount, countBefore);
      final completed = await tester.runAsync(
        () => LocalCaptureSessionStore.byId(sessionId),
      );
      expect(completed?.status, CaptureSessionStatus.completed);
    });

    testWidgets('Next continues the same incident into Organize', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await pumpCaptureScreen(tester, pushRoute: true);
      final controller = WorkspaceSession.instance.controller;
      await tester.runAsync(() async {
        controller.preserveEvidence(WorkspaceCaptureMode.photo);
        controller.preserveEvidence(WorkspaceCaptureMode.photo);
      });
      await tester.pump();

      final incidentId = controller.currentIncident.id;
      final ids = controller.journeyEvidenceItems.map((e) => e.id).toList();
      final hashes =
          controller.journeyEvidenceItems.map((e) => e.contentHash).toList();
      final times = controller.journeyEvidenceItems
          .map((e) => e.lastPreservedAt)
          .toList();
      expect(ids, isNotEmpty);
      expect(find.text('Next'), findsOneWidget);

      final next = tester.widget<TextButton>(
        find.byKey(const Key('continuous_capture_done')),
      );
      expect(next.onPressed, isNotNull);
      await tester.runAsync(() async {
        next.onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(controller.currentIncident.id, incidentId);
      expect(controller.journeyEvidenceItems.map((e) => e.id), ids);
      expect(
        controller.journeyEvidenceItems.map((e) => e.contentHash),
        hashes,
      );
      expect(
        controller.journeyEvidenceItems.map((e) => e.lastPreservedAt),
        times,
      );
    });

    testWidgets('15. reopen does not duplicate incident', (tester) async {
      await pumpCaptureScreen(tester);
      final controller = WorkspaceSession.instance.controller;
      final incidentId = controller.currentIncident.id;
      await tester.runAsync(() async {
        await controller.preserveTextNote('Original');
      });
      final before = controller.journeyEvidenceItems.length;

      await rebuildCaptureScreen(tester);
      expect(controller.currentIncident.id, incidentId);
      expect(controller.journeyEvidenceItems.length, before);
      expect(find.text('Original'), findsOneWidget);
    });

    testWidgets('17. CaptureSession remains available internally',
        (tester) async {
      await pumpCaptureScreen(tester);
      final incidentId =
          WorkspaceSession.instance.controller.currentIncident.id;
      final active = manager.getActiveSession(incidentId);
      expect(active, isNotNull);
      expect(active!.status, CaptureSessionStatus.active);
      expect(find.text('PRESERVING'), findsOneWidget);
    });

    testWidgets('20. hub remains the Incident Workspace surface', (tester) async {
      await pumpCaptureScreen(tester);
      expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
      expect(find.byKey(const Key('continuous_capture_screen')), findsOneWidget);
      expect(find.byKey(const Key('capture_sticky_bar')), findsOneWidget);
      expect(find.byKey(const Key('capture_action_photo')), findsOneWidget);
      expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    });
  });

  testWidgets('Continue preserving card language', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionResumeCard(
            incidentTitle: 'Workplace incident',
            evidenceCount: 3,
            lastActivityLabel: 'just now',
            onContinueCapture: () {},
          ),
        ),
      ),
    );
    expect(find.text('Continue preserving'), findsWidgets);
    expect(find.text('Active Capture Session'), findsNothing);
    expect(find.text('Session active'), findsNothing);
    expect(find.text('Resume Session'), findsNothing);
  });

  test('recovery compatibility restores internal session', () async {
    await prepareEnv();
    addTearDown(cleanupEnv);

    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace'),
    );
    final started = await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c31',
    );
    await session.controller.preserveEvidenceWithMedia(
      mode: WorkspaceCaptureMode.note,
      noteText: 'recovery note',
    );

    await session.flushBeforeSignOut();
    session.onSignedOut();
    expect(manager.getActiveSession(incidentId), isNull);

    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: 'user-6c31',
    );
    expect(await LocalIncidentPointer.recall('user-6c31'), incidentId);
    expect(
      await LocalIncidentPointer.recallCaptureSession('user-6c31'),
      started.id,
    );

    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace'),
    );
    await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: session.controller.evidenceRepository,
      userId: 'user-6c31',
    );
    final restored = await manager.restoreForIncident(
      incidentId: incidentId,
      userId: 'user-6c31',
    );
    expect(restored?.id, started.id);
    expect(restored?.status, CaptureSessionStatus.active);
  });
}
