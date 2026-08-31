import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/common/section_info_button.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:evidence_vault/widgets/workspace/product_concept_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _ev({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime lastPreservedAt,
  DateTime? capturedAt,
  DateTime? recordedAt,
  String? contentHash,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: lastPreservedAt,
    capturedAt: capturedAt,
    recordedAt: recordedAt,
    contentHash: contentHash,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-o7r',
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
  List<EvidenceCollection> collections = const [],
}) {
  return CurrentIncident(
    id: 'inc-o7r',
    title: 'Case',
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
    evidenceCollections: collections,
    trustPackageReady: evidence.isNotEmpty,
    trustPackageProgressPercent: 40,
  );
}

Future<void> _pumpOrganize(
  WidgetTester tester, {
  required CurrentIncident incident,
  List<String> orderedCapturedEvidenceIds = const [],
  Map<String, DateTime> capturedAnchoredAtById = const {},
  Set<String> organizeCreatedIds = const {},
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: incident,
          orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
          capturedAnchoredAtById: capturedAnchoredAtById,
          organizeCreatedIds: organizeCreatedIds,
          onEvidenceSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final t0 = DateTime.utc(2026, 8, 24, 10);
  final t1 = DateTime.utc(2026, 8, 24, 11);
  final tLatePreserve = DateTime.utc(2026, 8, 24, 18);

  test('B/C/H composition and copy use one assess() snapshot', () {
    final evidence = [
      _ev(
        id: 'p1',
        kind: WorkspaceEvidenceKind.image,
        lastPreservedAt: tLatePreserve,
        capturedAt: t0,
        contentHash: 'h-p',
      ),
      _ev(
        id: 'n1',
        kind: WorkspaceEvidenceKind.note,
        lastPreservedAt: t1,
        recordedAt: t1,
        contentHash: 'h-n',
      ),
    ];
    final assessed = OrganizeReadiness.assess(
      evidence: evidence,
      orderedCapturedEvidenceIds: const ['p1'],
    );
    expect(
      OrganizeReadinessCopy.compositionBody(assessed),
      contains(assessed.composition.summary),
    );
    expect(OrganizeReadinessCopy.nextStep(assessed), assessed.nextUsefulMaterial);
    expect(assessed.composition.summary, '1 Photo · 1 Text');
  });

  test('J/K/L clock source prefers anchoredAt, then capturedAt, never lastPreservedAt',
      () {
    final item = _ev(
      id: 'p1',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: tLatePreserve,
      capturedAt: t0,
    );
    expect(
      OrganizeChronologyClock.captureInstant(item: item),
      t0,
    );
    expect(
      OrganizeChronologyClock.captureInstant(
        item: item,
        anchoredAtByEvidenceId: {'p1': t1},
      ),
      t1,
    );
    expect(
      OrganizeChronologyClock.tileLabel(
        item: item,
        isAddedContext: false,
        anchoredAtByEvidenceId: {'p1': t1},
      ),
      WorkspaceEvidenceFormatters.evidenceClock(t1),
    );
    expect(
      OrganizeChronologyClock.tileLabel(
        item: item,
        isAddedContext: false,
        anchoredAtByEvidenceId: {'p1': t1},
      ),
      isNot(WorkspaceEvidenceFormatters.evidenceClock(tLatePreserve)),
    );

    final legacy = _ev(
      id: 'legacy',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: tLatePreserve,
    );
    expect(OrganizeChronologyClock.captureInstant(item: legacy), isNull);
    expect(
      OrganizeChronologyClock.tileLabel(
        item: legacy,
        isAddedContext: false,
      ),
      OrganizeChronologyClock.missingCaptureLabel,
    );
  });

  testWidgets('A one primary information surface on Organize', (tester) async {
    await _pumpOrganize(
      tester,
      incident: _incident(
        evidence: [
          _ev(
            id: 'p1',
            kind: WorkspaceEvidenceKind.image,
            lastPreservedAt: t0,
            capturedAt: t0,
          ),
        ],
      ),
      orderedCapturedEvidenceIds: const ['p1'],
    );
    expect(find.byType(OrganizeReadinessInfoButton), findsOneWidget);
    expect(find.byType(SectionInfoButton), findsNothing);
    expect(find.byKey(OrganizeReadinessInfoButton.buttonKey), findsOneWidget);
  });

  testWidgets('D/E/F/G information surface is the product-level concept chart',
      (tester) async {
    final evidence = [
      _ev(
        id: 'p1',
        kind: WorkspaceEvidenceKind.image,
        lastPreservedAt: t0,
        capturedAt: t0,
      ),
    ];
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: evidence),
      orderedCapturedEvidenceIds: const ['p1'],
    );
    await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(OrganizeReadinessGuideSheet.sheetKey), findsOneWidget);
    expect(find.byType(OrganizeReadinessGuideSheet), findsOneWidget);
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
    expect(find.text(OrganizeReadinessCopy.notReadyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.nextStepLabel), findsNothing);
    expect(find.text('Useful combinations'), findsNothing);
    expect(find.textContaining('AI'), findsNothing);
    expect(find.textContaining('This incident'), findsNothing);
  });

  testWidgets('F unknown state does not invent readiness', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OrganizeReadinessGuideSheet()),
      ),
    );
    expect(find.text(OrganizeReadinessCopy.unevaluableHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.readyHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.nextStepLabel), findsNothing);
    expect(
      find.byKey(OrganizeReadinessGuideSheet.compositionKey),
      findsNothing,
    );
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
  });

  testWidgets('I/J/K displayed clock follows canonical capture time, not lastPreservedAt',
      (tester) async {
    final a = _ev(
      id: 'A',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: tLatePreserve,
      capturedAt: t0,
      contentHash: 'hash-A',
    );
    final b = _ev(
      id: 'B',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: t1,
      capturedAt: t1,
      contentHash: 'hash-B',
    );
    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: [b, a],
      orderedCapturedEvidenceIds: const ['A', 'B'],
      incidentId: 'inc-o7r',
    );
    expect([for (final item in ordered) item.id], ['A', 'B']);

    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [b, a]),
      orderedCapturedEvidenceIds: const ['A', 'B'],
      capturedAnchoredAtById: {'A': t0, 'B': t1},
    );

    expect(
      find.text(WorkspaceEvidenceFormatters.evidenceClock(t0)),
      findsWidgets,
    );
    expect(
      find.text(WorkspaceEvidenceFormatters.evidenceClock(tLatePreserve)),
      findsNothing,
    );
  });

  testWidgets('L missing capture metadata fails closed without inventing a time',
      (tester) async {
    final item = _ev(
      id: 'bare',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: tLatePreserve,
    );
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [item]),
      orderedCapturedEvidenceIds: const ['bare'],
    );
    expect(
      find.text(OrganizeChronologyClock.missingCaptureLabel),
      findsWidgets,
    );
    expect(
      find.text(WorkspaceEvidenceFormatters.evidenceClock(tLatePreserve)),
      findsNothing,
    );
  });

  testWidgets('M context stays off capture chronology and does not use lastPreservedAt',
      (tester) async {
    final photo = _ev(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: t0,
      capturedAt: t0,
    );
    final note = _ev(
      id: 'org-note',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: tLatePreserve,
      recordedAt: t1,
    );
    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: [photo, note],
      orderedCapturedEvidenceIds: const ['photo'],
      organizeCreatedIds: const {'org-note'},
      incidentId: 'inc-o7r',
    );
    expect([for (final item in ordered) item.id], ['photo', 'org-note']);
    expect(
      OrganizeChronologyCanvas.isContextSpineItem(
        note,
        organizeCreatedIds: const {'org-note'},
      ),
      isTrue,
    );
    expect(
      OrganizeChronologyClock.instant(
        item: note,
        isAddedContext: true,
      ),
      t1,
    );

    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, note]),
      orderedCapturedEvidenceIds: const ['photo'],
      organizeCreatedIds: const {'org-note'},
      capturedAnchoredAtById: {'photo': t0},
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('org-note')),
      findsOneWidget,
    );
    expect(
      find.text(WorkspaceEvidenceFormatters.evidenceClock(tLatePreserve)),
      findsNothing,
    );
  });

  test('N group member ordering remains displayOrder()', () {
    final a = _ev(
      id: 'A',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: t1,
      capturedAt: t1,
    );
    final b = _ev(
      id: 'B',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: t0,
      capturedAt: t0,
    );
    final members = OrganizeChronologyCanvas.displayOrder(
      items: [a, b],
      orderedCapturedEvidenceIds: const ['B', 'A'],
      incidentId: 'inc-o7r',
    );
    expect([for (final item in members) item.id], ['B', 'A']);
  });

  testWidgets('O–T opening Organize clocks and ⓘ does not mutate evidence',
      (tester) async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-o7r', title: 'Case'),
    );
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.note);
    final store = controller.aggregate.store;
    final idsBefore = [for (final item in store.capturedEvidence) item.id];
    final hashesBefore = [
      for (final item in store.capturedEvidence) item.contentHash,
    ];
    final capturedBefore = [
      for (final item in store.capturedEvidence) item.capturedAt,
    ];
    final createdBefore = [
      for (final item in store.capturedEvidence) item.createdAt,
    ];
    final sequenceBefore = [
      for (final anchor in controller.timelineRepository.anchors)
        '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}:${anchor.anchoredAt.toIso8601String()}',
    ];
    final timelineBefore = [
      for (final item in store.capturedEvidence) '${item.id}:${item.timelineOrder}',
    ];
    final collectionsBefore = [
      for (final collection in controller.evidenceCollections)
        '${collection.id}:${collection.memberEvidenceIds.join(',')}',
    ];
    final readinessBefore = controller.organizeReadiness.status;

    await _pumpOrganize(
      tester,
      incident: controller.currentIncident,
      orderedCapturedEvidenceIds:
          controller.timelineRepository.orderedCapturedEvidenceIds(),
      capturedAnchoredAtById: {
        for (final anchor in controller.timelineRepository.anchors)
          anchor.capturedEvidenceId: anchor.anchoredAt,
      },
    );
    await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
    await tester.pumpAndSettle();

    expect(controller.organizeReadiness.status, readinessBefore);
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
      [for (final item in store.capturedEvidence) item.createdAt],
      createdBefore,
    );
    expect(
      [
        for (final anchor in controller.timelineRepository.anchors)
          '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}:${anchor.anchoredAt.toIso8601String()}',
      ],
      sequenceBefore,
    );
    expect(
      [
        for (final item in store.capturedEvidence)
          '${item.id}:${item.timelineOrder}',
      ],
      timelineBefore,
    );
    expect(
      [
        for (final collection in controller.evidenceCollections)
          '${collection.id}:${collection.memberEvidenceIds.join(',')}',
      ],
      collectionsBefore,
    );
  });
}
