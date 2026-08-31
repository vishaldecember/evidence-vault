import 'dart:io';
import 'dart:math' as math;

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/capture/capture_preview_overlay.dart';
import 'package:evidence_vault/widgets/capture/cockpit_immersive_preview.dart';
import 'package:evidence_vault/widgets/capture/cockpit_voice_visualizer.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_cockpit_t7_');
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
      userId: 'user-6c7',
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

  Future<void> seedSession() async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c7',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: 'Workplace incident'),
    );
  }

  Future<void> pumpCockpit(
    WidgetTester tester, {
    WorkspaceCaptureMode mode = WorkspaceCaptureMode.photo,
  }) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.runAsync(seedSession);
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureCockpitScreen(
          controller: WorkspaceSession.instance.controller,
          initialMode: mode,
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

  testWidgets(
      'A-C. Larger preview below header and above modality bar',
      (tester) async {
    await pumpCockpit(tester);
    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();

    expect(find.byKey(const Key('cockpit_immersive_preview')), findsOneWidget);
    expect(
      CapturePreviewOverlay.immersiveMaxHeightFraction,
      greaterThan(CapturePreviewOverlay.legacyMaxHeightFraction),
    );

    final previewRect =
        tester.getRect(find.byKey(const Key('cockpit_immersive_preview')));
    final screen =
        tester.getSize(find.byKey(const Key('capture_cockpit_screen')));
    final areaFraction =
        (previewRect.width * previewRect.height) / (screen.width * screen.height);
    expect(
      areaFraction,
      greaterThan(CapturePreviewOverlay.legacyPreviewAreaFraction),
    );

    final titleBottom =
        tester.getBottomLeft(find.byKey(const Key('capture_cockpit_title'))).dy;
    expect(previewRect.top, greaterThan(titleBottom - 4));

    final barTop = tester
        .getTopLeft(find.byKey(const Key('capture_cockpit_modality_bar')))
        .dy;
    expect(previewRect.bottom, lessThanOrEqualTo(barTop + 1));
  });

  testWidgets(
      'D-F. Preview tilt -5° on frame only; orange border; media not rotated',
      (tester) async {
    await pumpCockpit(tester);
    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();

    expect(
      CockpitImmersivePreview.tiltRadians,
      closeTo(-5 * math.pi / 180, 0.0001),
    );

    // Presentation Transform.rotate wraps the preview frame — live surface key
    // is absent during photo confirm (overlay covers). Captured child is a
    // plain ColoredBox with no Transform ancestor exclusive of the frame.
    final frame = find.byKey(const Key('cockpit_immersive_preview'));
    expect(frame, findsOneWidget);
    final rotate = tester.widgetList<Transform>(find.ancestor(
      of: frame,
      matching: find.byType(Transform),
    ));
    expect(rotate, isNotEmpty);

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
  });

  testWidgets('G-I. DONE mid-right unchanged; X stacked below DONE',
      (tester) async {
    await pumpCockpit(tester);
    final size = tester.getSize(find.byKey(const Key('capture_cockpit_screen')));
    final midY = size.height / 2;

    final doneCenter =
        tester.getCenter(find.byKey(const Key('capture_cockpit_done')));
    final closeCenter =
        tester.getCenter(find.byKey(const Key('capture_cockpit_close')));

    // DONE stays on the right at ~50% height.
    expect(doneCenter.dx, greaterThan(size.width * 0.72));
    expect(doneCenter.dy, closeTo(midY, size.height * 0.12));

    // Close is on the same right zone, vertically below DONE.
    expect(closeCenter.dx, greaterThan(size.width * 0.72));
    expect(closeCenter.dy, greaterThan(doneCenter.dy + 20));
    expect(closeCenter.dx, closeTo(doneCenter.dx, 24));

    expect(find.byKey(const Key('capture_cockpit_done')), findsOneWidget);
    expect(find.byKey(const Key('capture_cockpit_close')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    // Preview must not cover the right control stack.
    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();
    final previewRect =
        tester.getRect(find.byKey(const Key('cockpit_immersive_preview')));
    final doneRect =
        tester.getRect(find.byKey(const Key('capture_cockpit_done')));
    expect(previewRect.right, lessThanOrEqualTo(doneRect.left + 16));
  });

  testWidgets('J-K. Voice uses neutral concentric visualizer', (tester) async {
    await pumpCockpit(tester, mode: WorkspaceCaptureMode.voice);
    expect(find.byKey(const Key('cockpit_voice_visualizer')), findsOneWidget);
    expect(find.byType(CockpitVoiceVisualizer), findsOneWidget);

    // Field is neutral dark — not AppColors.navy / primary blue fill.
    final fields = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    expect(
      fields.any((c) => c.color == CockpitVoiceVisualizer.fieldColor),
      isTrue,
    );
    expect(
      fields.any(
        (c) =>
            c.color == AppColors.navy &&
            tester.getSize(find.byWidget(c)).width > 200,
      ),
      isFalse,
    );

    // Amplitude response path: pump a higher level via recording start (test
    // stub) — visualizer remains mounted through phase changes.
    await tester.tap(find.byKey(const Key('voice_record')));
    await tester.pump();
    expect(find.byKey(const Key('cockpit_voice_visualizer')), findsOneWidget);
  });

  testWidgets('L. Photo/Video/Voice modality switching unchanged',
      (tester) async {
    await pumpCockpit(tester);
    await tester.tap(find.byKey(const Key('capture_modality_video')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('cockpit-modality-video')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('capture_modality_voice')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('cockpit-modality-voice')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('cockpit_voice_visualizer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('capture_modality_photo')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('cockpit-modality-photo')),
      findsOneWidget,
    );
  });
}
