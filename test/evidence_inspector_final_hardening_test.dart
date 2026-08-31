import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/capture/live_evidence_timeline.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/inspector_context_section.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _attachment({
  required String id,
  required String fileName,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.attachment,
    title: fileName,
    lastPreservedAt: DateTime(2026, 8, 13, 13, 18, 5),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    fileName: fileName,
  );
}

Finder get _inspectorContextField => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == InspectorContextSection.placeholder,
    );

Future<void> _revealObservationEditor(WidgetTester tester) async {
  if (_inspectorContextField.evaluate().isEmpty) {
    await tester.ensureVisible(
      find.byKey(const Key('evidence_inspector_add_observation')),
    );
    await tester.tap(find.byKey(const Key('evidence_inspector_add_observation')));
    await tester.pump();
  }
}

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required WorkspaceEvidenceItem evidence,
  List<WorkspaceEvidenceItem>? ordered,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  showInvestigationEvidenceInspectorModal(
                    context: context,
                    evidence: evidence,
                    controller: controller,
                    orderedEvidence: ordered ??
                        evidenceInspectorOrder(controller.journeyEvidenceItems),
                  );
                },
                child: const Text('Open Inspector'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open Inspector'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  test('Inspector and vertical Workspace share one evidence instant', () {
    final instant = DateTime.utc(2026, 8, 13, 7, 34, 5);
    final inspector = WorkspaceEvidenceFormatters.inspectorTimestamp(instant);
    final workspace = LiveEvidenceTimeline.formatClock(instant);
    final investigation =
        WorkspaceEvidenceFormatters.timelineCaptureTime(instant);
    final expected = WorkspaceEvidenceFormatters.evidenceClock(instant);

    expect(inspector, expected);
    expect(workspace, expected);
    expect(investigation, expected);
    expect(inspector, contains(RegExp(r'\d{2}:\d{2}:\d{2}')));
    expect(inspector.contains(RegExp(r'• \d{2}:\d{2}$')), isFalse);
  });

  testWidgets('video preview stays constrained and play control remains',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController();
    controller.preserveEvidence(WorkspaceCaptureMode.video);
    await _openInspector(
      tester,
      controller: controller,
      evidence: controller.journeyEvidenceItems.first,
    );

    final preview = tester.getSize(find.byType(EvidenceInspectorPreview));
    expect(preview.height, greaterThanOrEqualTo(160));
    expect(preview.width, lessThanOrEqualTo(412));
    expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('document preview does not overflow long PDF filenames',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 640));

    final item = _attachment(
      id: 'pdf',
      fileName:
          'very_long_incident_statement_annexure_final_revision_v12.pdf',
    );
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [item]),
    );

    await _openInspector(tester, controller: controller, evidence: item);
    expect(tester.takeException(), isNull);
    expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
  });

  testWidgets('xlsx preview does not overflow', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 640));

    final item = _attachment(id: 'xlsx', fileName: 'budget_breakdown_q3.xlsx');
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [item]),
    );

    await _openInspector(tester, controller: controller, evidence: item);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('xlsx'), findsWidgets);
  });

  testWidgets('description editor and keyboard dismiss do not pop Inspector',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController();
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final incidentId = controller.currentIncident.id;
    await _openInspector(
      tester,
      controller: controller,
      evidence: controller.journeyEvidenceItems.first,
    );

    await _revealObservationEditor(tester);
    await tester.tap(_inspectorContextField);
    await tester.pump();
    await tester.showKeyboard(_inspectorContextField);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
    expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
    expect(
      tester.getSize(find.byType(EvidenceInspectorPreview)).height,
      greaterThanOrEqualTo(160),
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(controller.currentIncident.id, incidentId);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('carousel swipe flushes description and keeps incident',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController();
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final ordered = evidenceInspectorOrder(controller.journeyEvidenceItems);
    final firstId = ordered.first.id;
    final incidentId = controller.currentIncident.id;

    await _openInspector(
      tester,
      controller: controller,
      evidence: ordered.first,
      ordered: ordered,
    );

    await _revealObservationEditor(tester);
    await tester.enterText(_inspectorContextField, 'Ksjdodkd kriorkrr');
    await tester.pump();

    tester
        .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
        .onSelected(1);
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(controller.currentIncident.id, incidentId);
    expect(
      controller.evidenceRepository.supportingEvidence
          .where((item) => item.notePreview == 'Ksjdodkd kriorkrr')
          .length,
      1,
    );

    tester
        .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
        .onSelected(0);
    await tester.pumpAndSettle();
    expect(find.text('Ksjdodkd kriorkrr'), findsWidgets);
    expect(firstId, ordered.first.id);
  });

  testWidgets('Inspector Close returns to the same Workspace instance',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController();
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final incidentId = controller.currentIncident.id;

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          incidentId: incidentId,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail).first);
    await tester.tap(find.byType(JourneyEvidenceThumbnail).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsOneWidget);

    await tester.tap(find.byKey(const Key('evidence_inspector_close')));
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsNothing);
    expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
    expect(controller.currentIncident.id, incidentId);
  });
}
