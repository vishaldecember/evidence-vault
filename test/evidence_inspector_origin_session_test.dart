import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/capture/continuous_capture_screen.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/capture/live_evidence_timeline.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/timeline/timeline_anchor_entry.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceController _controllerWithPhoto() {
  final controller = WorkspaceEvidenceController();
  controller.preserveEvidence(WorkspaceCaptureMode.photo);
  WorkspaceSession.instance.controller = controller;
  return controller;
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required InvestigationMethodologyStage stage,
  required WorkspaceEvidenceController controller,
}) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: IncidentWorkspaceShell(
        incidentId: controller.currentIncident.id,
        controller: controller,
        initialStage: stage,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openInspectorFromCaptureThumb(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail));
  await tester.tap(find.byType(JourneyEvidenceThumbnail));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
  });

  testWidgets('Capture hub inspector Close returns to the same Capture session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controllerWithPhoto();
    WorkspaceSession.instance.enterCapture();

    await tester.pumpWidget(
      MaterialApp(home: ContinuousCaptureScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('continuous_capture_screen')), findsOneWidget);
    await tester.tap(find.byKey(Key('live_timeline_item_${controller.state.items.first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Evidence Inspector'), findsOneWidget);

    await tester.tap(find.byKey(const Key('evidence_inspector_close')));
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsNothing);
    expect(find.byKey(const Key('continuous_capture_screen')), findsOneWidget);
    expect(find.byType(LiveEvidenceTimeline), findsOneWidget);
    expect(
      WorkspaceSession.instance.activeMethodologyStage,
      InvestigationMethodologyStage.capture,
    );
  });

  testWidgets('Capture hub inspector system Back returns to Capture', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controllerWithPhoto();
    WorkspaceSession.instance.enterCapture();

    await tester.pumpWidget(
      MaterialApp(home: ContinuousCaptureScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('live_timeline_item_${controller.state.items.first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Evidence Inspector'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsNothing);
    expect(find.byKey(const Key('continuous_capture_screen')), findsOneWidget);
    expect(
      WorkspaceSession.instance.activeMethodologyStage,
      InvestigationMethodologyStage.capture,
    );
  });

  testWidgets('Capture → Inspector → Back repeats without drifting to Organize', (
    tester,
  ) async {
    final controller = _controllerWithPhoto();
    await _pumpShell(
      tester,
      stage: InvestigationMethodologyStage.capture,
      controller: controller,
    );

    for (var i = 0; i < 2; i++) {
      await _openInspectorFromCaptureThumb(tester);
      expect(find.text('Evidence Inspector'), findsOneWidget);
      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();
      expect(find.text('Evidence Inspector'), findsNothing);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(find.text('Capture what happened clearly'), findsOneWidget);
      expect(find.text('Organize and enrich your records'), findsNothing);
    }
  });

  testWidgets('Organize inspector Close returns to Organize', (tester) async {
    final controller = _controllerWithPhoto();
    await _pumpShell(
      tester,
      stage: InvestigationMethodologyStage.evidence,
      controller: controller,
    );

    final first = controller.journeyEvidenceItems.first;
    await tester.ensureVisible(find.byKey(OrganizeWorkspaceView.rowKey(first.id)));
    await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey(first.id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Evidence Inspector'), findsOneWidget);

    await tester.tap(find.byKey(const Key('evidence_inspector_close')));
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsNothing);
    expect(
      WorkspaceSession.instance.activeMethodologyStage,
      InvestigationMethodologyStage.evidence,
    );
    expect(find.text('Organize and enrich your records'), findsOneWidget);
  });

  testWidgets('Investigate inspector Close returns to Investigate', (
    tester,
  ) async {
    final controller = _controllerWithPhoto();
    controller.preserveEvidence(WorkspaceCaptureMode.video);
    controller.preserveEvidence(WorkspaceCaptureMode.voice);
    await _pumpShell(
      tester,
      stage: InvestigationMethodologyStage.investigation,
      controller: controller,
    );

    await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
    await tester.tap(find.byType(TimelineAnchorEntry).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Evidence Inspector'), findsOneWidget);

    await tester.tap(find.byKey(const Key('evidence_inspector_close')));
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsNothing);
    expect(
      WorkspaceSession.instance.activeMethodologyStage,
      InvestigationMethodologyStage.investigation,
    );
    expect(find.text('Investigation Workspace'), findsOneWidget);
    expect(
      WorkspaceSession.instance.activeInvestigationTab,
      InvestigationWorkspaceTab.timeline,
    );
  });

  testWidgets('Organize advanced record Back stays on Organize', (tester) async {
    final controller = _controllerWithPhoto();
    await _pumpShell(
      tester,
      stage: InvestigationMethodologyStage.evidence,
      controller: controller,
    );

    final first = controller.journeyEvidenceItems.first;
    await tester.ensureVisible(find.byKey(OrganizeWorkspaceView.rowKey(first.id)));
    await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey(first.id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('View complete record →'));
    await tester.tap(find.text('View complete record →'));
    await tester.pumpAndSettle();
    expect(find.text('Evidence Record'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      WorkspaceSession.instance.activeMethodologyStage,
      InvestigationMethodologyStage.evidence,
    );
    expect(find.text('Organize and enrich your records'), findsOneWidget);
    expect(find.byType(InvestigationJourneyHeader), findsOneWidget);
  });
}
