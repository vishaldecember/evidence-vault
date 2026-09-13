import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkspaceEvidenceController controller;

  setUp(() {
    ContinuousCaptureSession.debugGenerateVideoThumbnail = null;
    ContinuousCaptureSession.debugLastAttachedVideoThumbnail = null;
    controller = WorkspaceEvidenceController();
  });

  tearDown(() {
    ContinuousCaptureSession.debugGenerateVideoThumbnail = null;
    ContinuousCaptureSession.debugLastAttachedVideoThumbnail = null;
  });

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

  testWidgets('photo preview accept keeps camera session and adds evidence',
      (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.photo);
    expect(find.text('Camera'), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();

    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(find.byTooltip('Close preview'), findsNothing);
    await tester.tap(find.byTooltip('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.currentIncident.evidenceCount, 1);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.byTooltip('Accept'), findsNothing);
    expect(find.byKey(const Key('photo_shutter')), findsOneWidget);
  });

  testWidgets('photo discard does not add evidence', (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.photo);
    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();
    await tester.tap(find.byTooltip('Discard'));
    await tester.pump();
    expect(controller.currentIncident.evidenceCount, 0);
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('video pause flips to play; stop shows preview', (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.video);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Play'), findsOneWidget);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(find.byTooltip('Accept'), findsOneWidget);

    await tester.tap(find.byTooltip('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.currentIncident.evidenceCount, 1);
  });

  testWidgets('video discard from preview adds no evidence', (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.video);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    await tester.tap(find.byTooltip('Discard'));
    await tester.pump();
    expect(controller.currentIncident.evidenceCount, 0);
  });

  testWidgets('voice recording stop opens compact preview panel', (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.voice);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Play'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    expect(find.byTooltip('Play preview'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.currentIncident.evidenceCount, 1);
  });

  testWidgets('voice discard mid-recording adds no evidence', (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.voice);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Discard'));
    await tester.pump();
    expect(controller.currentIncident.evidenceCount, 0);
  });

  testWidgets('photo flip control switches facing without capturing',
      (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.photo);
    expect(find.byKey(const Key('camera_flip')), findsOneWidget);
    expect(find.byTooltip('Switch to front camera'), findsOneWidget);

    await tester.tap(find.byKey(const Key('camera_flip')));
    await tester.pump();

    expect(find.byTooltip('Switch to back camera'), findsOneWidget);
    expect(find.byKey(const Key('photo_shutter')), findsOneWidget);
    expect(controller.currentIncident.evidenceCount, 0);

    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();
    await tester.tap(find.byTooltip('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.currentIncident.evidenceCount, 1);
  });

  testWidgets('video flip before record does not start a session',
      (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.video);
    expect(find.byKey(const Key('camera_flip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('camera_flip')));
    await tester.pump();

    expect(find.byTooltip('Switch to back camera'), findsOneWidget);
    expect(find.byKey(const Key('video_record')), findsOneWidget);
    expect(controller.currentIncident.evidenceCount, 0);
  });

  testWidgets('video flip during recording keeps one evidence session',
      (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.video);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    expect(find.byKey(const Key('video_stop')), findsOneWidget);
    expect(find.byKey(const Key('video_control_timer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('camera_flip')));
    await tester.pump();
    expect(find.byTooltip('Switch to back camera'), findsOneWidget);
    expect(find.byKey(const Key('video_stop')), findsOneWidget);
    expect(controller.currentIncident.evidenceCount, 0);

    await tester.tap(find.byKey(const Key('camera_flip')));
    await tester.pump();
    expect(find.byTooltip('Switch to front camera'), findsOneWidget);
    expect(find.byKey(const Key('video_stop')), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(find.byTooltip('Accept'), findsOneWidget);
    await tester.tap(find.byTooltip('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.currentIncident.evidenceCount, 1);
  });

  testWidgets('accepted photo starts as local then queues lifecycle',
      (tester) async {
    await pumpSession(tester, WorkspaceCaptureMode.photo);
    await tester.tap(find.byKey(const Key('photo_shutter')));
    await tester.pump();
    await tester.tap(find.byTooltip('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final record = controller.evidenceRepository.recordById(
      controller.currentIncident.evidence.first.id,
    );
    expect(record, isNotNull);
    // After preserve, media path queues upload (or stays localCaptured for notes).
    expect(
      record!.syncStatus == EvidenceSyncStatus.localCaptured ||
          record.syncStatus == EvidenceSyncStatus.queuedForUpload ||
          record.syncStatus == EvidenceSyncStatus.ready,
      isTrue,
    );
  });
}
