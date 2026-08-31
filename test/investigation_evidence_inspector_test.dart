import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/presentation/evidence_inspector_semantics.dart';
import 'package:evidence_vault/widgets/investigation/inspector_context_section.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:evidence_vault/widgets/timeline/timeline_anchor_entry.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({required String id}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

Finder get _inspectorContextField => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == InspectorContextSection.placeholder,
    );

Finder get _addObservation =>
    find.byKey(const Key('evidence_inspector_add_observation'));

Future<void> _revealObservationEditor(WidgetTester tester) async {
  if (_inspectorContextField.evaluate().isEmpty) {
    await tester.ensureVisible(_addObservation);
    await tester.tap(_addObservation);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('timeline evidence opens elevated inspector without navigation',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(
        items: [_item(id: 'photo'), _item(id: 'video')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.investigation,
          initialInvestigationTab: InvestigationWorkspaceTab.timeline,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evidence Record'), findsNothing);

    await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
    await tester.tap(find.byType(TimelineAnchorEntry).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.text('Metadata'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('View complete record →'), findsOneWidget);
    expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
    expect(_addObservation, findsOneWidget);
    expect(find.text(EvidenceInspectorSemantics.addObservationAffordance),
        findsOneWidget);
    expect(find.text('Advanced Details'), findsNothing);
  });

  testWidgets('inspector does not overflow on compact devices', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 640));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.capture,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail));
    await tester.tap(find.byType(JourneyEvidenceThumbnail));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(
      find.text(EvidenceInspectorSemantics.addObservationAffordance),
      findsOneWidget,
    );
  });

  testWidgets('context field stays two lines then expands while editing',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.investigation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
    await tester.tap(find.byType(TimelineAnchorEntry).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_addObservation, findsOneWidget);
    expect(
      find.text(EvidenceInspectorSemantics.addObservationAffordance),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('evidence_inspector_timeline_role')),
      findsNothing,
    );
    expect(find.text('Chronological'), findsNothing);
    expect(find.text('Part of the event timeline'), findsNothing);

    await _revealObservationEditor(tester);
    final collapsed = tester.widget<TextField>(_inspectorContextField);
    expect(collapsed.expands, isFalse);
    expect(find.text(InspectorContextSection.placeholder), findsOneWidget);

    await tester.tap(_inspectorContextField);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final expanded = tester.widget<TextField>(_inspectorContextField);
    expect(expanded.expands, isFalse);
    expect(expanded.maxLines, 3);
    expect(expanded.keyboardType, TextInputType.multiline);
    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
    expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
  });

  testWidgets('context composer stays visible when keyboard opens',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.investigation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
    await tester.tap(find.byType(TimelineAnchorEntry).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _revealObservationEditor(tester);
    final contextField = _inspectorContextField;
    expect(contextField, findsOneWidget);

    final contextBeforeKeyboard = tester.getTopLeft(contextField).dy;
    expect(contextBeforeKeyboard, greaterThan(0));

    await tester.tap(contextField);
    await tester.pump();
    await tester.showKeyboard(contextField);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(tester.getTopLeft(contextField).dy, greaterThan(0));

    final fieldTop = tester.getTopLeft(contextField).dy;
    expect(fieldTop, greaterThan(0));
    expect(find.text(InspectorContextSection.placeholder), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('description autosaves and close retains edits',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );
    final incidentId = controller.currentIncident.id;
    final evidenceId = controller.state.items.single.id;

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.investigation,
          initialInvestigationTab: InvestigationWorkspaceTab.timeline,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
    await tester.tap(find.byType(TimelineAnchorEntry).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _revealObservationEditor(tester);
    await tester.tap(_inspectorContextField);
    await tester.pump();
    await tester.enterText(
      _inspectorContextField,
      'Witness observed the event.',
    );
    await tester.pump();
    await tester.pump(InvestigationEvidenceInspectorModal.persistDebounce);
    await tester.pump();

    expect(find.text('Witness observed the event.'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(
      controller.evidenceRepository.supportingEvidence,
      isNotEmpty,
    );
    expect(controller.currentIncident.id, incidentId);
    expect(controller.state.items.singleWhere((e) => e.id == evidenceId).id,
        evidenceId);

    await tester.tap(find.byKey(const Key('evidence_inspector_close')));
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Timeline'), findsWidgets);
    expect(
      controller.evidenceRepository.supportingEvidence,
      isNotEmpty,
    );

    await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
    await tester.tap(find.byType(TimelineAnchorEntry).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Witness observed the event.'), findsWidgets);
    expect(controller.currentIncident.id, incidentId);
  });

  testWidgets('close dismisses inspector without leaving investigation workspace',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.investigation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
    await tester.tap(find.byType(TimelineAnchorEntry).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsNothing);
    expect(find.text('Investigation Workspace'), findsOneWidget);
  });

  testWidgets('preview is the dominant region on open', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.capture,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail));
    await tester.tap(find.byType(JourneyEvidenceThumbnail));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.text('Photo evidence'), findsOneWidget);
    expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
    expect(_addObservation, findsOneWidget);
  });

  testWidgets('capture stage journey evidence opens inspector without navigation',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.capture,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail));
    await tester.tap(find.byType(JourneyEvidenceThumbnail));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.text('Evidence Record'), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Capture'), findsWidgets);
  });

  testWidgets('inspector links related person inline without new navigation',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController();
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final evidence = controller.journeyEvidenceItems.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showInvestigationEvidenceInspectorModal(
                      context: context,
                      evidence: evidence,
                      controller: controller,
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Inspector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Related People'), findsOneWidget);
    expect(find.text('Add Person'), findsOneWidget);

    await tester.ensureVisible(find.text('Add Person'));
    await tester.tap(find.text('Add Person'));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Relationship'), findsOneWidget);
    expect(find.text('Person Involved'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('related_person_name_field')),
      'Sarah Johnson',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('related_person_relationship_witness')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sarah Johnson'), findsWidgets);
    expect(find.text('Witness'), findsOneWidget);
    expect(find.text('Add Person'), findsWidgets);

    final linked = controller.state.items.singleWhere(
      (item) => item.id == evidence.id,
    );
    expect(linked.participantId, isNotNull);
    expect(
      controller.participantDisplayName(linked.participantId),
      'Sarah Johnson',
    );
  });

  testWidgets('inspector is centered with close as the only bottom action',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          controller: controller,
          initialStage: InvestigationMethodologyStage.capture,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail));
    await tester.tap(find.byType(JourneyEvidenceThumbnail));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final surface =
        tester.getRect(find.byKey(const Key('evidence_inspector_surface')));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect((surface.center.dx - screen.center.dx).abs(), lessThan(16));
    expect((surface.center.dy - screen.center.dy).abs(), lessThan(56));
    expect(surface.top, greaterThan(8));
    expect(surface.bottom, lessThan(screen.bottom - 8));

    expect(find.text('Save'), findsNothing);
    expect(find.byKey(const Key('evidence_inspector_close')), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byKey(const Key('evidence_inspector_preview_divider')),
        findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('related person persists without Save and survives reopen',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = WorkspaceEvidenceController();
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final evidence = controller.journeyEvidenceItems.first;
    final incidentId = controller.currentIncident.id;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showInvestigationEvidenceInspectorModal(
                      context: context,
                      evidence: evidence,
                      controller: controller,
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Inspector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Add Person'));
    await tester.tap(find.text('Add Person'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('related_person_name_field')),
      'Sarah Johnson',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('related_person_relationship_witness')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsNothing);
    expect(
      controller.participantDisplayName(
        controller.state.items.singleWhere((item) => item.id == evidence.id)
            .participantId,
      ),
      'Sarah Johnson',
    );

    await tester.tap(find.byKey(const Key('evidence_inspector_close')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Inspector'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sarah Johnson'), findsWidgets);
    expect(find.text('Witness'), findsOneWidget);
    expect(find.text('Add Person'), findsWidgets);
    expect(controller.currentIncident.id, incidentId);
    expect(evidence.id, controller.journeyEvidenceItems.first.id);
  });
}
