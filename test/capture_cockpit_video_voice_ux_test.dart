import 'dart:async';
import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_session.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/capture/capture_preview_overlay.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_12b_cockpit_');
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
      userId: 'user-12b',
    );
    ContinuousCaptureSession.debugFailVoiceDurability = false;
    ContinuousCaptureSession.debugFailLocalCommit = false;
  }

  Future<void> cleanupEnv() async {
    ContinuousCaptureSession.debugFailVoiceDurability = false;
    ContinuousCaptureSession.debugFailLocalCommit = false;
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
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();
  }

  /// Tap the ring surface outside the small central Play/Pause.
  Future<void> tapVoiceRing(WidgetTester tester) async {
    final surface = tester.getRect(find.byKey(const Key('voice_record')));
    await tester.tapAt(Offset(surface.center.dx, surface.center.dy + 72));
  }

  setUp(() async {
    await prepareEnv();
    await manager.getOrCreateActiveSession(
      incidentId: WorkspaceSession.instance.controller.currentIncident.id,
      userId: 'user-12b',
    );
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets(
    'TEST 1 voice DONE saves without playback',
    (tester) async {
      final controller = WorkspaceSession.instance.controller;
      await pumpCockpit(tester, WorkspaceCaptureMode.voice);

      await tapVoiceRing(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('voice_stop')));
      await tester.pump();

      expect(find.byTooltip('Play preview'), findsWidgets);
      expect(controller.currentIncident.evidenceCount, 0);

      await tester.tap(find.byKey(const Key('capture_cockpit_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.currentIncident.evidenceCount, 1);
    },
  );

  testWidgets(
    'TEST 1b voice DONE finalizes an in-progress recording without Stop or Play',
    (tester) async {
      final controller = WorkspaceSession.instance.controller;
      await pumpCockpit(tester, WorkspaceCaptureMode.voice);

      await tapVoiceRing(tester);
      await tester.pump();
      expect(find.byKey(const Key('voice_stop')), findsOneWidget);
      expect(controller.currentIncident.evidenceCount, 0);

      await tester.tap(find.byKey(const Key('capture_cockpit_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.currentIncident.evidenceCount, 1);
    },
  );

  testWidgets(
    'TEST 2 voice preview play remains optional and does not block save',
    (tester) async {
      final controller = WorkspaceSession.instance.controller;
      await pumpCockpit(tester, WorkspaceCaptureMode.voice);

      await tapVoiceRing(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('voice_stop')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('voice_center_play_pause')));
      await tester.pump();
      expect(find.byTooltip('Pause preview'), findsWidgets);

      await tester.tap(find.byKey(const Key('capture_cockpit_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.currentIncident.evidenceCount, 1);
    },
  );

  testWidgets(
    'TEST 3 voice discard does not save',
    (tester) async {
      final controller = WorkspaceSession.instance.controller;
      await pumpCockpit(tester, WorkspaceCaptureMode.voice);

      await tapVoiceRing(tester);
      await tester.pump();
      await tester.tap(find.byTooltip('Discard'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('capture_cockpit_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.currentIncident.evidenceCount, 0);
    },
  );

  testWidgets(
    'TEST 3b Close during recording does not save',
    (tester) async {
      final controller = WorkspaceSession.instance.controller;
      await pumpCockpit(tester, WorkspaceCaptureMode.voice);

      await tapVoiceRing(tester);
      await tester.pump();

      await tester.tap(find.byKey(const Key('capture_cockpit_close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.currentIncident.evidenceCount, 0);
    },
  );

  testWidgets(
    'TEST 4 voice durability failure does not create evidence',
    (tester) async {
      ContinuousCaptureSession.debugFailVoiceDurability = true;
      final controller = WorkspaceSession.instance.controller;
      await pumpCockpit(tester, WorkspaceCaptureMode.voice);

      await tapVoiceRing(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('voice_stop')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('capture_cockpit_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.currentIncident.evidenceCount, 0);
    },
  );

  testWidgets(
    'video DONE while recording finalizes one Preview, then Accept',
    (tester) async {
      final delayed = Completer<String?>();
      ContinuousCaptureSession.debugGenerateVideoThumbnail =
          (_) => delayed.future;
      addTearDown(() {
        ContinuousCaptureSession.debugGenerateVideoThumbnail = null;
        ContinuousCaptureSession.debugLastAttachedVideoThumbnail = null;
      });

      final controller = WorkspaceSession.instance.controller;
      final incidentId = controller.currentIncident.id;
      await pumpCockpit(tester, WorkspaceCaptureMode.video);

      await tester.tap(find.byKey(const Key('video_record')));
      await tester.pump();
      expect(find.byKey(const Key('video_stop')), findsOneWidget);
      expect(controller.currentIncident.evidenceCount, 0);

      await tester.tap(find.byKey(const Key('capture_cockpit_done')));
      await tester.pump();

      expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
      expect(find.byKey(const Key('capture_preview_accept')), findsOneWidget);
      expect(find.byKey(const Key('capture_video_preview_play')), findsOneWidget);
      expect(controller.currentIncident.evidenceCount, 0);
      expect(controller.currentIncident.id, incidentId);
      expect(ContinuousCaptureSession.debugLastAttachedVideoThumbnail, isNull);

      delayed.complete('test://thumb-done');
      await tester.pump();

      await tester.tap(find.byKey(const Key('capture_preview_accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.currentIncident.evidenceCount, 1);
      expect(controller.currentIncident.id, incidentId);
    },
  );

  testWidgets(
    'TEST 5 video preview has no standalone timer or preparing copy',
    (tester) async {
      await pumpCockpit(tester, WorkspaceCaptureMode.video);

      await tester.tap(find.byKey(const Key('video_record')));
      await tester.pump();
      expect(find.byKey(const Key('video_control_timer')), findsOneWidget);

      await tester.tap(find.byKey(const Key('video_stop')));
      await tester.pump();

      expect(find.byKey(const Key('capture_video_preview_play')), findsOneWidget);
      expect(find.byKey(const Key('video_control_timer')), findsNothing);
      expect(find.text('Preparing capture…'), findsNothing);
      expect(find.textContaining('00:'), findsNothing);
    },
  );

  testWidgets(
    'TEST 5b video preview widget itself does not paint a duration label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 320,
              child: CaptureVideoPreviewPlaceholder(
                durationLabel: '00:05',
                videoPath: 'test://video',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('capture_video_preview_play')), findsOneWidget);
      expect(find.text('00:05'), findsNothing);
      expect(find.textContaining('00:05'), findsNothing);
    },
  );

  testWidgets(
    'TEST 6 voice Play/Pause is a small centered affordance; rings stay tappable',
    (tester) async {
      await pumpCockpit(tester, WorkspaceCaptureMode.voice);

      expect(find.byType(CockpitVoiceVisualizer), findsOneWidget);
      expect(find.byKey(const Key('voice_record')), findsOneWidget);
      expect(find.byKey(const Key('voice_center_play_pause')), findsOneWidget);
      expect(find.byKey(const Key('capture_cockpit_done')), findsOneWidget);

      final visualizer = tester.getRect(
        find.byKey(const Key('cockpit_voice_visualizer')),
      );
      final control = tester.getRect(
        find.byKey(const Key('voice_center_play_pause')),
      );
      final timer = tester.getRect(find.byKey(const Key('voice_center_timer')));

      expect((control.center.dx - visualizer.center.dx).abs(), lessThan(8));
      expect((control.center.dy - visualizer.center.dy).abs(), lessThan(8));
      expect(visualizer.contains(control.center), isTrue);
      expect(
        control.shortestSide,
        lessThanOrEqualTo(
          ContinuousCaptureSession.previousVoiceCenterControlDiameter * 0.70,
        ),
      );
      expect(
        control.shortestSide,
        lessThanOrEqualTo(
          ContinuousCaptureSession.voiceCenterControlMaxDiameter,
        ),
      );
      expect(
        timer.overlaps(control),
        isFalse,
        reason: 'timer must not sit on the Play/Pause control',
      );

      final ringIcons = find.descendant(
        of: find.byKey(const Key('voice_ring_surface')),
        matching: find.byIcon(Icons.mic),
      );
      expect(ringIcons, findsNothing);

      await tapVoiceRing(tester);
      await tester.pump();
      expect(find.byKey(const Key('voice_stop')), findsOneWidget);
    },
  );
}
