import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:evidence_vault/widgets/workspace/product_concept_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _ev({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  String? contentHash,
  String incidentId = 'inc-ready',
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    contentHash: contentHash,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
  String id = 'inc-ready',
  IncidentStatus status = IncidentStatus.active,
}) {
  return CurrentIncident(
    id: id,
    title: 'Case',
    status: status,
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

Future<void> _openGuide(
  WidgetTester tester, {
  required CurrentIncident incident,
  List<String> orderedCapturedEvidenceIds = const [],
  Set<String> organizeCreatedIds = const {},
  VoidCallback? onCreateGroup,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: incident,
          orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
          organizeCreatedIds: organizeCreatedIds,
          onEvidenceSelected: (_) {},
          onCreateGroup: onCreateGroup,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
  await tester.pumpAndSettle();
}

void main() {
  final t0 = DateTime.utc(2026, 8, 24, 10);
  final t1 = DateTime.utc(2026, 8, 24, 11);
  final t2 = DateTime.utc(2026, 8, 24, 12);

  test('A/B/G composition and copy use the same assess() snapshot', () {
    final evidence = [
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0, contentHash: 'h-p'),
      _ev(id: 'p2', kind: WorkspaceEvidenceKind.image, at: t1, contentHash: 'h-2'),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t2, contentHash: 'h-n'),
    ];
    final assessed = OrganizeReadiness.assess(
      evidence: evidence,
      orderedCapturedEvidenceIds: const ['p1', 'p2'],
    );
    expect(assessed.isReady, isTrue);
    expect(assessed.composition.summary, '2 Photos · 1 Text');
    expect(
      OrganizeReadinessCopy.compositionBody(assessed),
      contains(assessed.composition.summary),
    );
    expect(OrganizeReadinessCopy.nextStep(assessed), isNull);
    expect(
      OrganizeReadinessCopy.structureBody(assessed),
      contains(OrganizeReadinessCopy.contextMet),
    );
    expect(assessed.matchedPattern.toString(), isNot(contains('Ready to organize')));
  });

  testWidgets('A information section is product-level, not incident composition',
      (tester) async {
    final evidence = [
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0, contentHash: 'h-p'),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t1, contentHash: 'h-n'),
      _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t2, contentHash: 'h-v'),
    ];
    await _openGuide(
      tester,
      incident: _incident(evidence: evidence),
      orderedCapturedEvidenceIds: const ['v1', 'p1'],
    );
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
    expect(find.textContaining('This incident'), findsNothing);
    expect(find.textContaining('Your evidence'), findsNothing);
    expect(
      find.byKey(OrganizeReadinessGuideSheet.compositionKey),
      findsNothing,
    );
  });

  testWidgets('C information section does not present incident readiness copy',
      (tester) async {
    final evidence = [
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(id: 'w1', kind: WorkspaceEvidenceKind.witness, at: t1),
    ];
    await _openGuide(
      tester,
      incident: _incident(evidence: evidence),
      orderedCapturedEvidenceIds: const ['p1'],
    );
    expect(find.text(OrganizeReadinessCopy.readyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.readyBody), findsNothing);
    expect(find.text(OrganizeReadinessCopy.notReadyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.nextStepLabel), findsNothing);
    expect(find.textContaining(OrganizeReadinessCopy.contextMet), findsNothing);
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
    expect(find.textContaining('AI'), findsNothing);
    expect(find.textContaining('Coach'), findsNothing);
    expect(find.text(OrganizeReadinessPattern.photoWitness.name), findsNothing);
  });

  testWidgets('D not-ready assess() still exists; Information is not a checklist',
      (tester) async {
    final evidence = [
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0, contentHash: 'h-p'),
    ];
    final assessed = OrganizeReadiness.assess(
      evidence: evidence,
      orderedCapturedEvidenceIds: const ['p1'],
    );
    expect(assessed.isReady, isFalse);
    expect(assessed.nextUsefulMaterial, isNotNull);

    await _openGuide(
      tester,
      incident: _incident(evidence: evidence),
      orderedCapturedEvidenceIds: const ['p1'],
    );
    expect(find.text(OrganizeReadinessCopy.readyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.notReadyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.nextStepLabel), findsNothing);
    expect(find.text(assessed.nextUsefulMaterial!), findsNothing);
    expect(
      OrganizeReadinessCopy.nextStep(assessed),
      assessed.nextUsefulMaterial,
    );
    expect(find.textContaining('You need this.'), findsNothing);
    expect(find.textContaining('AI recommends'), findsNothing);
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
  });

  testWidgets('E unevaluable readiness does not invent a recommendation',
      (tester) async {
    await _openGuide(
      tester,
      incident: _incident(evidence: const [], id: ''),
    );
    expect(
      find.text(OrganizeReadinessCopy.unevaluableHeadline),
      findsNothing,
    );
    expect(find.text(OrganizeReadinessCopy.readyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.notReadyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.nextStepLabel), findsNothing);
    expect(
      find.byKey(OrganizeReadinessGuideSheet.compositionKey),
      findsNothing,
    );
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
  });

  testWidgets('D not-ready without a model hint does not invent one',
      (tester) async {
    final evidence = [
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t1),
    ];
    final assessed = OrganizeReadiness.assess(
      evidence: evidence,
      orderedCapturedEvidenceIds: const ['p1', 'v1'],
    );
    expect(assessed.isReady, isFalse);
    expect(assessed.nextUsefulMaterial, isNull);
    expect(OrganizeReadinessCopy.nextStep(assessed), isNull);

    await _openGuide(
      tester,
      incident: _incident(evidence: evidence),
      orderedCapturedEvidenceIds: const ['p1', 'v1'],
    );
    expect(find.text(OrganizeReadinessCopy.notReadyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.nextStepLabel), findsNothing);
    expect(find.textContaining('Consider adding'), findsNothing);
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
  });

  testWidgets('F sequence-sensitive ready state stays in assess() copy only',
      (tester) async {
    final evidence = [
      _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t0),
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t1),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t2),
    ];
    final assessed = OrganizeReadiness.assess(
      evidence: evidence,
      orderedCapturedEvidenceIds: const ['v1', 'p1'],
    );
    expect(assessed.matchedPattern, OrganizeReadinessPattern.photoVoiceText);
    expect(
      OrganizeReadinessCopy.structureBody(assessed),
      contains(OrganizeReadinessCopy.sequenceMet),
    );

    await _openGuide(
      tester,
      incident: _incident(evidence: evidence),
      orderedCapturedEvidenceIds: const ['v1', 'p1'],
    );
    expect(find.textContaining(OrganizeReadinessCopy.sequenceMatters), findsNothing);
    expect(find.textContaining(OrganizeReadinessCopy.sequenceMet), findsNothing);
    expect(find.textContaining('sequenceOrder'), findsNothing);
    expect(find.textContaining('photoVoiceText'), findsNothing);
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
  });

  testWidgets('H capture-origin note stays captured while composition counts it',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final evidence = [
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(id: 'note-capture', kind: WorkspaceEvidenceKind.note, at: t1),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: _incident(evidence: evidence),
            orderedCapturedEvidenceIds: const ['p1'],
            organizeCreatedIds: const {},
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('note-capture')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-capture')),
      findsNothing,
    );

    await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
    expect(find.textContaining('1 Text'), findsNothing);
  });

  testWidgets('I opening the guide does not mutate evidence or chronology',
      (tester) async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-ready', title: 'Case'),
    );
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final store = controller.aggregate.store;
    final idsBefore = [for (final item in store.capturedEvidence) item.id];
    final hashesBefore = [
      for (final item in store.capturedEvidence) item.contentHash,
    ];
    final capturedBefore = [
      for (final item in store.capturedEvidence) item.capturedAt,
    ];
    final sequenceBefore = [
      for (final anchor in controller.timelineRepository.anchors)
        '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
    ];
    final statusBefore = controller.organizeReadiness.status;

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: controller.currentIncident,
            orderedCapturedEvidenceIds:
                controller.timelineRepository.orderedCapturedEvidenceIds(),
            organizeCreatedIds: controller.organizeCreatedEvidenceIds,
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
    await tester.pumpAndSettle();

    expect(controller.organizeReadiness.status, statusBefore);
    expect([for (final item in store.capturedEvidence) item.id], idsBefore);
    expect(
      [for (final item in store.capturedEvidence) item.contentHash],
      hashesBefore,
    );
    expect(
      [for (final item in store.capturedEvidence) item.capturedAt],
      capturedBefore,
    );
    expect(
      [
        for (final anchor in controller.timelineRepository.anchors)
          '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
      ],
      sequenceBefore,
    );
  });

  testWidgets('J archived Organize still shows the guide without mutation controls',
      (tester) async {
    final evidence = [
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
    ];
    await _openGuide(
      tester,
      incident: _incident(
        evidence: evidence,
        status: IncidentStatus.archived,
      ),
      orderedCapturedEvidenceIds: const ['p1'],
    );
    expect(find.byKey(OrganizeReadinessGuideSheet.sheetKey), findsOneWidget);
    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(OrganizeReadinessGuideSheet.sheetKey),
        matching: find.byType(ElevatedButton),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(OrganizeReadinessGuideSheet.sheetKey),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(OrganizeReadinessGuideSheet.sheetKey),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );
  });
}
