import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/evidence_artifact_model.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_preview_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/attachment_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/photo_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/text_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/video_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/voice_evidence_renderer.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/reconstruction/evidence_inspector_panel.dart';
import 'package:evidence_vault/widgets/timeline/timeline_anchor_entry.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WorkspaceSession.instance.reset());

  test('9-10 autoplay runs seek then play after the source is ready', () async {
    final calls = <String>[];
    await InspectorAutoplay.startWhenReady(
      seekToStart: () async => calls.add('seek'),
      play: () async => calls.add('play'),
    );
    expect(calls, ['seek', 'play']);
  });

  test('11 photo/note/document keep non-player renderers', () {
    expect(
      EvidencePreviewRegistry.resolve(EvidenceArtifactType.photo),
      isA<PhotoEvidenceRenderer>(),
    );
    expect(
      EvidencePreviewRegistry.resolve(EvidenceArtifactType.note),
      isA<TextEvidenceRenderer>(),
    );
    expect(
      EvidencePreviewRegistry.resolve(EvidenceArtifactType.document),
      isA<AttachmentEvidenceRenderer>(),
    );
    expect(
      EvidencePreviewRegistry.resolve(EvidenceArtifactType.video),
      isA<VideoEvidenceRenderer>(),
    );
    expect(
      EvidencePreviewRegistry.resolve(EvidenceArtifactType.voiceRecording),
      isA<VoiceEvidenceRenderer>(),
    );
  });

  test('18 carousel order stays incident-scoped', () {
    final photo = WorkspaceEvidenceItem(
      id: 'a-photo',
      kind: WorkspaceEvidenceKind.image,
      title: 'Photo',
      lastPreservedAt: DateTime(2026, 8, 14, 10),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      incidentId: 'inc-A',
    );
    final foreign = WorkspaceEvidenceItem(
      id: 'b-video',
      kind: WorkspaceEvidenceKind.video,
      title: 'Foreign',
      lastPreservedAt: DateTime(2026, 8, 14, 11),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      incidentId: 'inc-B',
    );
    final voice = WorkspaceEvidenceItem(
      id: 'a-voice',
      kind: WorkspaceEvidenceKind.voice,
      title: 'Voice',
      lastPreservedAt: DateTime(2026, 8, 14, 12),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      incidentId: 'inc-A',
    );
    final ordered = evidenceInspectorOrder(
      [photo, foreign, voice],
      incidentId: 'inc-A',
    );
    expect(ordered.map((item) => item.id), ['a-photo', 'a-voice']);
  });

  testWidgets('13 Timeline opens the same Inspector', (tester) async {
    await _pumpShell(
      tester,
      stage: InvestigationMethodologyStage.investigation,
      tab: InvestigationWorkspaceTab.timeline,
    );
    await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
    await tester.tap(find.byType(TimelineAnchorEntry).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(InvestigationEvidenceInspectorModal), findsOneWidget);
    expect(find.byType(EvidenceInspectorPanel), findsNothing);
  });

  testWidgets('16 Organize opens the same Inspector', (tester) async {
    final controller = await _pumpShell(
      tester,
      stage: InvestigationMethodologyStage.evidence,
    );
    final first = controller.journeyEvidenceItems.first;
    await tester.ensureVisible(
      find.byKey(OrganizeWorkspaceView.rowKey(first.id)),
    );
    await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey(first.id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(InvestigationEvidenceInspectorModal), findsOneWidget);
    expect(find.byType(EvidenceInspectorPanel), findsNothing);
  });

  testWidgets('17 Capture opens the same Inspector', (tester) async {
    await _pumpShell(
      tester,
      stage: InvestigationMethodologyStage.capture,
    );
    await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail).first);
    await tester.tap(find.byType(JourneyEvidenceThumbnail).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(InvestigationEvidenceInspectorModal), findsOneWidget);
  });

  testWidgets('12 carousel thumbs stay on bound-incident evidence', (tester) async {
    await _pumpShell(
      tester,
      stage: InvestigationMethodologyStage.capture,
    );
    await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail).first);
    await tester.tap(find.byType(JourneyEvidenceThumbnail).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(InvestigationEvidenceInspectorModal), findsOneWidget);
    expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
    expect(find.byKey(const Key('evidence_inspector_thumb_foreign')), findsNothing);
  });
}

Future<WorkspaceEvidenceController> _pumpShell(
  WidgetTester tester, {
  required InvestigationMethodologyStage stage,
  InvestigationWorkspaceTab? tab,
}) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
  );
  controller.preserveEvidence(WorkspaceCaptureMode.photo);
  controller.preserveEvidence(WorkspaceCaptureMode.video);
  controller.preserveEvidence(WorkspaceCaptureMode.voice);
  WorkspaceSession.instance.controller = controller;

  await tester.pumpWidget(
    MaterialApp(
      home: IncidentWorkspaceShell(
        incidentId: controller.currentIncident.id,
        controller: controller,
        initialStage: stage,
        initialInvestigationTab: tab,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}
