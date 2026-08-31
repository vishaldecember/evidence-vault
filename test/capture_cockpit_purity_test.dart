import 'dart:io';
import 'dart:math' as math;

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/capture/capture_session_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/capture/capture_cockpit_modality_bar.dart';
import 'package:evidence_vault/widgets/capture/cockpit_immersive_preview.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_cockpit_purity_');
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
      userId: 'user-6c2',
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

  Future<void> seed() async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c2',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace incident'),
    );
  }

  Future<void> pumpCockpit(
    WidgetTester tester, {
    WorkspaceCaptureMode? initialMode,
  }) async {
    await tester.runAsync(seed);
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureCockpitScreen(
          controller: WorkspaceSession.instance.controller,
          initialMode: initialMode,
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets('A-C. Cockpit contains Photo, Video, Voice', (tester) async {
    await pumpCockpit(tester);
    expect(find.byKey(const Key('capture_modality_photo')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_video')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_voice')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_modality_bar')), findsOneWidget);
  });

  testWidgets('D-E. Cockpit does NOT contain Note or File', (tester) async {
    await pumpCockpit(tester);
    expect(find.byKey(const Key('capture_sticky_note')), findsNothing);
    expect(find.byKey(const Key('capture_sticky_file')), findsNothing);
    expect(find.byKey(const Key('capture_action_note')), findsNothing);
    expect(find.byKey(const Key('capture_action_file')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('capture_cockpit_modality_bar')),
        matching: find.text('Note'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('capture_cockpit_modality_bar')),
        matching: find.text('File'),
      ),
      findsNothing,
    );
  });

  testWidgets('F-G. DONE returns to workspace without completing session',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.runAsync(seed);
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open_workspace'),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ContinuousCaptureScreen(
                      controller: WorkspaceSession.instance.controller,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_workspace')));
    await tester.pump();
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

    expect(find.byKey(const Key('capture_cockpit_screen')), findsNothing);
    expect(find.byKey(const Key('incident_workspace_screen')), findsOneWidget);
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
    expect(
      manager.getActiveSession(incidentId)?.status,
      CaptureSessionStatus.active,
    );
  });

  testWidgets('H-I. Cockpit captures append to same incident stream',
      (tester) async {
    await pumpCockpit(tester);
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.runAsync(() async {
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      await manager.attachEvidenceToSession(
        sessionId: sessionId,
        evidenceId: controller.journeyEvidenceItems.last.id,
      );
      controller.preserveForWidgetTest(WorkspaceCaptureMode.video);
      await manager.attachEvidenceToSession(
        sessionId: sessionId,
        evidenceId: controller.journeyEvidenceItems.last.id,
      );
    });
    await tester.pump();

    expect(controller.currentIncident.id, incidentId);
    expect(controller.currentIncident.evidenceCount, greaterThanOrEqualTo(2));
    expect(controller.journeyEvidenceItems.length, greaterThanOrEqualTo(2));
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
  });

  testWidgets('J. Modality switching recreates session widget key only once',
      (tester) async {
    await pumpCockpit(tester);
    final incidentId =
        WorkspaceSession.instance.controller.currentIncident.id;
    final sessionId = manager.getActiveSession(incidentId)!.id;

    await tester.tap(find.byKey(const Key('capture_modality_video')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('cockpit-modality-video')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('cockpit-modality-photo')), findsNothing);

    await tester.tap(find.byKey(const Key('capture_modality_voice')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('cockpit-modality-voice')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('capture_modality_photo')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('cockpit-modality-photo')),
      findsOneWidget,
    );
    expect(manager.getActiveSession(incidentId)?.id, sessionId);
  });

  testWidgets('K. Workspace still exposes Note and File actions', (tester) async {
    await tester.runAsync(seed);
    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('capture_action_note')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_file')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_photo')), findsOneWidget);
  });

  testWidgets(
      'A–E. Live surfaces upright; preview-only tilt + orange border',
      (tester) async {
    await pumpCockpit(tester);
    expect(find.byKey(const Key('cockpit_live_capture_surface')), findsOneWidget);
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsNothing);

    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsOneWidget);
    expect(
      CockpitImmersivePreview.tiltRadians,
      closeTo(-5 * math.pi / 180, 0.0001),
    );
    expect(CockpitImmersivePreview.borderWidth, inInclusiveRange(2.5, 3.0));

    final preview = find.byKey(const Key('cockpit_immersive_preview'));
    expect(preview, findsOneWidget);
    // Frame fills chrome-safe area (no fixed 3:4 AspectRatio lock).
    final previewSize = tester.getSize(preview);
    expect(previewSize.width, greaterThan(200));
    expect(previewSize.height, greaterThan(280));

    final decorated = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    final previewBorder = decorated
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where(
          (d) =>
              d.border != null &&
              d.border is Border &&
              (d.border! as Border).top.width ==
                  CockpitImmersivePreview.borderWidth,
        )
        .first;
    final border = previewBorder.border! as Border;
    expect(border.top.color, AppColors.warning);
    expect(border.right.color, AppColors.warning);
    expect(border.bottom.color, AppColors.warning);
    expect(border.left.color, AppColors.warning);
    expect(border.top.width, inInclusiveRange(2.5, 3.0));

    final headerBottom =
        tester.getBottomLeft(find.text('Capture Cockpit')).dy;
    final previewTop =
        tester.getTopLeft(find.byKey(const Key('cockpit_immersive_preview'))).dy;
    expect(previewTop, greaterThan(headerBottom));

    // Delete / Accept must sit above the translucent modality bar.
    final acceptBottom =
        tester.getBottomLeft(find.byKey(const Key('capture_preview_accept'))).dy;
    final barTop = tester
        .getTopLeft(find.byKey(const Key('capture_cockpit_modality_bar')))
        .dy;
    expect(acceptBottom, lessThanOrEqualTo(barTop));
  });

  testWidgets('B. Live video surface has no preview tilt until stop',
      (tester) async {
    await pumpCockpit(tester, initialMode: WorkspaceCaptureMode.video);
    expect(find.byKey(const Key('cockpit_live_capture_surface')), findsOneWidget);
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsNothing);

    await tester.tap(find.byKey(const Key('video_record')));
    await tester.pump();
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsNothing);

    await tester.tap(find.byKey(const Key('video_stop')));
    await tester.pump();
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsOneWidget);
    // Captured video preview wires play affordance (path passed in widget tree).
    expect(find.byKey(const Key('capture_video_preview_play')), findsOneWidget);
    expect(find.byKey(const Key('capture_preview_accept')), findsOneWidget);
  });

  testWidgets('C. Voice surface never uses immersive tilt preview',
      (tester) async {
    await pumpCockpit(tester, initialMode: WorkspaceCaptureMode.voice);
    expect(find.byKey(const Key('cockpit_live_capture_surface')), findsOneWidget);
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsNothing);

    await tester.tap(find.byKey(const Key('voice_record')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice_stop')));
    await tester.pump();
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsNothing);
  });

  testWidgets('G. Modality bar is translucent (20–35% dark overlay)',
      (tester) async {
    await pumpCockpit(tester);
    final bar = tester.widget<Container>(
      find.byKey(const Key('capture_cockpit_modality_bar')),
    );
    final decoration = bar.decoration! as BoxDecoration;
    final color = decoration.color!;
    expect(color.a, inInclusiveRange(0.20, 0.35));
    expect(CaptureCockpitModalityBar.overlayOpacity, inInclusiveRange(0.20, 0.35));
  });

  testWidgets('immersive preview settles with orange border + tilt',
      (tester) async {
    await pumpCockpit(tester);
    expect(find.byKey(const Key('cockpit_immersive_preview')), findsNothing);

    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();

    expect(find.byKey(const Key('cockpit_immersive_preview')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_close')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_done')), findsOneWidget);
    expect(find.text('Capture Cockpit'), findsOneWidget);

    expect(
      CockpitImmersivePreview.tiltRadians,
      closeTo(-5 * math.pi / 180, 0.0001),
    );
    expect(CockpitImmersivePreview.borderWidth, inInclusiveRange(2.5, 3.0));

    final preview = find.byKey(const Key('cockpit_immersive_preview'));
    expect(preview, findsOneWidget);
    // Frame fills chrome-safe area (no fixed 3:4 AspectRatio lock).
    final previewSize = tester.getSize(preview);
    expect(previewSize.width, greaterThan(200));
    expect(previewSize.height, greaterThan(280));

    final headerBottom =
        tester.getBottomLeft(find.text('Capture Cockpit')).dy;
    final previewTop =
        tester.getTopLeft(find.byKey(const Key('cockpit_immersive_preview'))).dy;
    expect(previewTop, greaterThan(headerBottom));
  });
}
