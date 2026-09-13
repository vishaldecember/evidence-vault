import 'dart:async';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
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

  Future<void> pumpSession(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ContinuousCaptureSession(
          controller: controller,
          mode: WorkspaceCaptureMode.video,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('1–2 Stop shows Preview before a delayed thumbnail arrives',
      (tester) async {
    final delayed = Completer<String?>();
    ContinuousCaptureSession.debugGenerateVideoThumbnail = (_) => delayed.future;

    await pumpSession(tester);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(find.byKey(const Key('capture_video_preview_play')), findsOneWidget);
    expect(ContinuousCaptureSession.debugLastAttachedVideoThumbnail, isNull);

    delayed.complete('test://thumb-late');
    await tester.pump();

    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(
      ContinuousCaptureSession.debugLastAttachedVideoThumbnail,
      'test://thumb-late',
    );
  });

  testWidgets('3 thumbnail failure leaves Preview usable', (tester) async {
    ContinuousCaptureSession.debugGenerateVideoThumbnail = (_) async => null;

    await pumpSession(tester);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(find.byTooltip('Discard'), findsOneWidget);
    expect(ContinuousCaptureSession.debugLastAttachedVideoThumbnail, isNull);
    expect(controller.currentIncident.evidenceCount, 0);
  });

  testWidgets('4 Accept before thumbnail still preserves one video',
      (tester) async {
    final delayed = Completer<String?>();
    ContinuousCaptureSession.debugGenerateVideoThumbnail = (_) => delayed.future;

    await pumpSession(tester);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(find.byTooltip('Accept'), findsOneWidget);

    await tester.tap(find.byTooltip('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.currentIncident.evidenceCount, 1);
    expect(find.byTooltip('Accept'), findsNothing);

    delayed.complete('test://thumb-after-accept');
    await tester.pump();

    expect(controller.currentIncident.evidenceCount, 1);
    expect(ContinuousCaptureSession.debugLastAttachedVideoThumbnail, isNull);
  });

  testWidgets('5 late thumbnail for video A does not update video B',
      (tester) async {
    final first = Completer<String?>();
    final second = Completer<String?>();
    var calls = 0;
    ContinuousCaptureSession.debugGenerateVideoThumbnail = (_) {
      calls += 1;
      return calls == 1 ? first.future : second.future;
    };

    await pumpSession(tester);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    await tester.tap(find.byTooltip('Discard'));
    await tester.pump();

    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(ContinuousCaptureSession.debugLastAttachedVideoThumbnail, isNull);

    first.complete('test://thumb-a');
    await tester.pump();

    expect(ContinuousCaptureSession.debugLastAttachedVideoThumbnail, isNull);
    expect(find.byTooltip('Accept'), findsOneWidget);

    second.complete('test://thumb-b');
    await tester.pump();

    expect(
      ContinuousCaptureSession.debugLastAttachedVideoThumbnail,
      'test://thumb-b',
    );
  });

  testWidgets('6 leaving Preview drops a late thumbnail without crashing',
      (tester) async {
    final delayed = Completer<String?>();
    ContinuousCaptureSession.debugGenerateVideoThumbnail = (_) => delayed.future;

    await pumpSession(tester);
    await tester.tap(find.byTooltip('Record'));
    await tester.pump();
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    delayed.complete('test://thumb-orphan');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.currentIncident.evidenceCount, 0);
    expect(ContinuousCaptureSession.debugLastAttachedVideoThumbnail, isNull);
  });
}
