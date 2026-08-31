import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/domain/organize/organize_floating_context_layout.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/theme/organize_visuals.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/inspector_atmosphere_background.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:evidence_vault/widgets/workspace/product_concept_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    contentHash: 'hash-$id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-v4',
  );
}

CurrentIncident _incident({required List<WorkspaceEvidenceItem> evidence}) {
  return CurrentIncident(
    id: 'inc-v4',
    title: 'Street',
    status: IncidentStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    manuallyComplete: false,
    journeyStage: JourneyStage.building,
    captureProgressPercent: 0,
    timelineAnchorCount: evidence.length,
    relationshipGroupCount: 0,
    narrativeEventCount: 0,
    evidence: evidence,
    journeyEvidence: evidence,
    relationshipGroups: const [],
    evidenceCollections: const [],
    trustPackageReady: evidence.isNotEmpty,
    trustPackageProgressPercent: 40,
  );
}

Future<void> _pumpOrganize(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> evidence,
  Set<String> organizeCreatedIds = const {},
  List<OrganizeContextAnchor> anchors = const [],
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: _incident(evidence: evidence),
          orderedCapturedEvidenceIds: [
            for (final item in evidence)
              if (item.kind.isPrimaryChronology &&
                  !organizeCreatedIds.contains(item.id))
                item.id,
          ],
          organizeCreatedIds: organizeCreatedIds,
          contextAnchors: anchors,
          onEvidenceSelected: (_) {},
          onAddOrganizeContext: (_) {},
          onSetContextAnchor: (_, _) {},
          onDiscardUnsnappedContext: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpCanvas(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> ordered,
  Set<String> organizeCreatedIds = const {},
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeChronologyCanvas(
          ordered: ordered,
          allEvidence: ordered,
          organizeCreatedIds: organizeCreatedIds,
          onEvidenceSelected: (_) {},
          onSetContextAnchor: (_, _) {},
          onDiscardUnsnapped: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceItem item,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(412, 915));
  final controller = WorkspaceEvidenceController(
    initialState: WorkspaceEvidenceState(items: [item]),
  );
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
                    evidence: item,
                    controller: controller,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  final t0 = DateTime(2026, 8, 26, 10);
  final photo = _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0);
  final note = _item(
    id: 'note-org',
    kind: WorkspaceEvidenceKind.note,
    at: t0.add(const Duration(seconds: 20)),
  );

  testWidgets('A/B floating context remove control hinges outside top-left',
      (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [photo, note],
      organizeCreatedIds: const {'note-org'},
    );

    final thumb = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.contextFrameKey('note-org')),
    );
    final remove = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
    );

    expect(remove.center.dx, lessThan(thumb.left));
    expect(remove.center.dy, lessThan(thumb.top));
    expect(
      (thumb.left - remove.center.dx).abs(),
      lessThan(OrganizeFloatingContextLayout.removeControlExtent),
    );
    expect(
      (thumb.top - remove.center.dy).abs(),
      lessThan(OrganizeFloatingContextLayout.removeControlExtent),
    );
    final overlap = thumb.intersect(remove);
    final overlapArea =
        overlap.width.clamp(0, double.infinity) *
        overlap.height.clamp(0, double.infinity);
    expect(
      overlapArea,
      lessThan(remove.width * remove.height * 0.4),
    );
  });

  test('C toolbar copy is exact', () {
    expect(
      OrganizeWorkspaceView.addContextCaption,
      'Drag the context on the moments preserved',
    );
  });

  testWidgets('D/E instruction uses fluorescent purple and no rainbow',
      (tester) async {
    await _pumpOrganize(
      tester,
      evidence: [photo, note],
      organizeCreatedIds: const {'note-org'},
    );

    final instruction = tester.widget<Text>(
      find.descendant(
        of: find.byKey(OrganizeWorkspaceView.addContextInstructionWobbleKey),
        matching: find.text(OrganizeWorkspaceView.addContextCaption),
      ),
    );
    expect(instruction.style?.color, OrganizeVisuals.contextInstruction);
    expect(
      find.descendant(
        of: find.byKey(OrganizeWorkspaceView.addContextInstructionWobbleKey),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<OrganizePlacementWobble>(
            find.byKey(OrganizeWorkspaceView.addContextInstructionWobbleKey),
          )
          .active,
      isTrue,
    );
  });

  testWidgets('F Inspector has a soft 3D atmosphere layer behind content',
      (tester) async {
    await _openInspector(tester, item: photo);
    expect(find.byType(InspectorAtmosphereBackground), findsOneWidget);
    expect(
      find.byKey(InspectorAtmosphereBackground.layerKey),
      findsOneWidget,
    );
    final atmosphere = tester.getRect(
      find.byKey(InspectorAtmosphereBackground.layerKey),
    );
    final preview = tester.getRect(find.byType(EvidenceInspectorPreview));
    expect(atmosphere.contains(preview.center), isTrue);
  });

  testWidgets('G/H photo gutters are light blue and aspect ratio is contain',
      (tester) async {
    await _openInspector(tester, item: photo);
    final frame = tester.widget<DecoratedBox>(
      find.byKey(const Key('evidence_inspector_preview_frame')),
    );
    final decoration = frame.decoration as BoxDecoration;
    expect(decoration.color, EvidenceInspectorPreview.mediaGutter);
    expect(
      EvidenceInspectorPreview.frameColorFor(WorkspaceEvidenceKind.image),
      EvidenceInspectorPreview.mediaGutter,
    );
    expect(
      EvidenceInspectorPreview.frameColorFor(WorkspaceEvidenceKind.video),
      EvidenceInspectorPreview.mediaGutter,
    );
    expect(
      EvidenceInspectorPreview.frameColorFor(WorkspaceEvidenceKind.note),
      EvidenceInspectorPreview.surface,
    );
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      expect(image.fit, BoxFit.contain);
    }
  });

  testWidgets('I/J/K/L Information is the generic product concept chart',
      (tester) async {
    await _pumpOrganize(
      tester,
      evidence: [photo, note],
      organizeCreatedIds: const {'note-org'},
    );
    await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
    expect(find.text(ProductConceptCopy.title), findsOneWidget);
    expect(find.text(ProductConceptCopy.caption), findsOneWidget);
    expect(find.text(ProductConceptCopy.captureTitle), findsOneWidget);
    expect(find.text(ProductConceptCopy.organizeTitle), findsOneWidget);
    expect(find.text(ProductConceptCopy.investigateTitle), findsOneWidget);
    expect(find.text(ProductConceptCopy.reconstructTitle), findsOneWidget);
    expect(find.text(ProductConceptCopy.groupsQuote), findsOneWidget);
    expect(find.text(ProductConceptCopy.connectionsQuote), findsOneWidget);
    expect(find.text(ProductConceptCopy.distinctionCapture), findsOneWidget);
    expect(find.text(ProductConceptCopy.distinctionOrganize), findsOneWidget);
    expect(find.text(ProductConceptCopy.distinctionInvestigate), findsOneWidget);
    expect(find.text(ProductConceptCopy.distinctionReconstruct), findsOneWidget);

    expect(find.textContaining('This incident'), findsNothing);
    expect(find.textContaining('Your evidence'), findsNothing);
    expect(find.textContaining('This incident is ready'), findsNothing);
    expect(find.textContaining('equals event'), findsNothing);
    expect(
      find.textContaining('not when an event occurred'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Placement does not change chronology'),
      findsOneWidget,
    );
    expect(
      find.textContaining('without asserting a relationship or causal'),
      findsOneWidget,
    );
    expect(
      find.textContaining('stronger and more specific than simple group'),
      findsOneWidget,
    );
  });

  test('M evidence identity fields are untouched by presentation constants', () {
    expect(photo.id, 'photo');
    expect(photo.contentHash, 'hash-photo');
    expect(photo.capturedAt, t0);
    expect(photo.lastPreservedAt, t0);
  });

  testWidgets('M/N opening Information does not mutate chronology',
      (tester) async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-v4', title: 'Street'),
    );
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final idsBefore = [
      for (final item in controller.currentIncident.evidence) item.id,
    ];
    final hashesBefore = [
      for (final item in controller.currentIncident.evidence) item.contentHash,
    ];
    final capturedBefore = [
      for (final item in controller.currentIncident.evidence) item.capturedAt,
    ];
    final sequenceBefore =
        controller.timelineRepository.orderedCapturedEvidenceIds();

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: controller.currentIncident,
            orderedCapturedEvidenceIds: sequenceBefore,
            organizeCreatedIds: controller.organizeCreatedEvidenceIds,
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
    await tester.pumpAndSettle();

    expect(
      [for (final item in controller.currentIncident.evidence) item.id],
      idsBefore,
    );
    expect(
      [for (final item in controller.currentIncident.evidence) item.contentHash],
      hashesBefore,
    );
    expect(
      [for (final item in controller.currentIncident.evidence) item.capturedAt],
      capturedBefore,
    );
    expect(
      controller.timelineRepository.orderedCapturedEvidenceIds(),
      sequenceBefore,
    );
  });
}
