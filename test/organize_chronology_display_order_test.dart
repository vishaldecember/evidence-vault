import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime lastPreservedAt,
  DateTime? capturedAt,
  DateTime? recordedAt,
  String? contentHash,
  String incidentId = 'inc-chrono',
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
    incidentId: incidentId,
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
  List<EvidenceCollection> collections = const [],
}) {
  return CurrentIncident(
    id: 'inc-chrono',
    title: 'Case',
    status: IncidentStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    manuallyComplete: false,
    journeyStage: JourneyStage.building,
    captureProgressPercent: 0,
    timelineAnchorCount: 3,
    relationshipGroupCount: 0,
    narrativeEventCount: 0,
    evidence: evidence,
    journeyEvidence: evidence,
    relationshipGroups: const [],
    evidenceCollections: collections,
    trustPackageReady: true,
    trustPackageProgressPercent: 40,
  );
}

List<String> _ids(List<WorkspaceEvidenceItem> items) =>
    [for (final item in items) item.id];

void main() {
  test('A/B canonical sequenceOrder wins over lastPreservedAt', () {
    final tEarly = DateTime(2026, 8, 22, 9);
    final tMid = DateTime(2026, 8, 22, 10);
    final tLate = DateTime(2026, 8, 22, 11);
    final a = _item(
      id: 'A',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: tMid,
      capturedAt: tMid,
      contentHash: 'hash-A',
    );
    final b = _item(
      id: 'B',
      kind: WorkspaceEvidenceKind.video,
      lastPreservedAt: tLate,
      capturedAt: tLate,
      contentHash: 'hash-B',
    );
    final c = _item(
      id: 'C',
      kind: WorkspaceEvidenceKind.voice,
      lastPreservedAt: tEarly,
      capturedAt: tEarly,
      contentHash: 'hash-C',
    );
    final scrambled = [c, a, b];

    expect(
      _ids(evidenceInspectorOrder(scrambled, incidentId: 'inc-chrono')),
      ['C', 'A', 'B'],
    );

    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: scrambled,
      orderedCapturedEvidenceIds: const ['A', 'B', 'C'],
      incidentId: 'inc-chrono',
    );
    expect(_ids(ordered), ['A', 'B', 'C']);
  });

  test('C display sorting does not mutate evidence or chronology fields', () {
    final a = _item(
      id: 'A',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 11),
      capturedAt: DateTime(2026, 8, 22, 11),
      contentHash: 'hash-A',
    );
    final b = _item(
      id: 'B',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 9),
      capturedAt: DateTime(2026, 8, 22, 9),
      contentHash: 'hash-B',
    );
    final items = [a, b];
    final idsBefore = _ids(items);
    final hashesBefore = [for (final item in items) item.contentHash];
    final preservedBefore = [for (final item in items) item.lastPreservedAt];
    final capturedBefore = [for (final item in items) item.capturedAt];

    OrganizeChronologyCanvas.displayOrder(
      items: items,
      orderedCapturedEvidenceIds: const ['A', 'B'],
      incidentId: 'inc-chrono',
    );

    expect(_ids(items), idsBefore);
    expect([for (final item in items) item.contentHash], hashesBefore);
    expect([for (final item in items) item.lastPreservedAt], preservedBefore);
    expect([for (final item in items) item.capturedAt], capturedBefore);
    expect(a.id, 'A');
    expect(b.id, 'B');
  });

  test('D Organize-created context stays out of the canonical capture sequence',
      () {
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 12),
      capturedAt: DateTime(2026, 8, 22, 12),
    );
    final contextNote = _item(
      id: 'org-note',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: DateTime(2026, 8, 22, 8),
      recordedAt: DateTime(2026, 8, 22, 8),
    );
    final laterPhoto = _item(
      id: 'photo-2',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 13),
      capturedAt: DateTime(2026, 8, 22, 13),
    );

    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: [contextNote, laterPhoto, photo],
      orderedCapturedEvidenceIds: const ['photo', 'org-note', 'photo-2'],
      organizeCreatedIds: const {'org-note'},
      incidentId: 'inc-chrono',
    );

    expect(_ids(ordered), ['photo', 'photo-2', 'org-note']);
    expect(
      OrganizeChronologyCanvas.isContextSpineItem(
        contextNote,
        organizeCreatedIds: const {'org-note'},
      ),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isFixedSpineItem(
        contextNote,
        organizeCreatedIds: const {'org-note'},
      ),
      isFalse,
    );
  });

  test('E OrganizeContextAnchor identities are not rewritten by display order',
      () {
    const anchors = [
      OrganizeContextAnchor(
        contextEvidenceId: 'org-note',
        capturedEvidenceId: 'photo',
      ),
    ];
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 10),
      capturedAt: DateTime(2026, 8, 22, 10),
    );
    final note = _item(
      id: 'org-note',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: DateTime(2026, 8, 22, 9),
      recordedAt: DateTime(2026, 8, 22, 9),
    );

    OrganizeChronologyCanvas.displayOrder(
      items: [note, photo],
      orderedCapturedEvidenceIds: const ['photo'],
      organizeCreatedIds: const {'org-note'},
      incidentId: 'inc-chrono',
    );

    expect(anchors, hasLength(1));
    expect(anchors.single.contextEvidenceId, 'org-note');
    expect(anchors.single.capturedEvidenceId, 'photo');
  });

  test('F EvidenceCollection membership is not a chronology and is unchanged',
      () {
    final a = _item(
      id: 'A',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 12),
      capturedAt: DateTime(2026, 8, 22, 12),
    );
    final b = _item(
      id: 'B',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 10),
      capturedAt: DateTime(2026, 8, 22, 10),
    );
    final c = _item(
      id: 'C',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 8),
      capturedAt: DateTime(2026, 8, 22, 8),
    );
    final collection = EvidenceCollection(
      id: 'col-1',
      incidentId: 'inc-chrono',
      name: 'Group',
      systemGenerated: false,
      displayOrder: 0,
      createdAt: DateTime(2026, 8, 22),
      updatedAt: DateTime(2026, 8, 22),
      memberEvidenceIds: const ['C', 'A', 'B'],
    );
    final membershipBefore = List<String>.from(collection.memberEvidenceIds);

    final displayed = OrganizeChronologyCanvas.displayOrder(
      items: [c, a, b],
      orderedCapturedEvidenceIds: const ['A', 'B', 'C'],
      incidentId: 'inc-chrono',
    );

    expect(_ids(displayed), ['A', 'B', 'C']);
    expect(collection.memberEvidenceIds, membershipBefore);
    expect(collection.memberEvidenceIds, ['C', 'A', 'B']);
  });

  test('G missing canonical id uses deterministic timestamp/id fallback', () {
    final anchored = _item(
      id: 'anchored',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: DateTime(2026, 8, 22, 12),
      capturedAt: DateTime(2026, 8, 22, 12),
    );
    final missingLate = _item(
      id: 'missing-z',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: DateTime(2026, 8, 22, 11),
      recordedAt: DateTime(2026, 8, 22, 11),
    );
    final missingEarly = _item(
      id: 'missing-a',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: DateTime(2026, 8, 22, 10),
      recordedAt: DateTime(2026, 8, 22, 10),
    );

    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: [missingLate, missingEarly, anchored],
      orderedCapturedEvidenceIds: const ['anchored'],
      incidentId: 'inc-chrono',
    );

    expect(_ids(ordered), ['anchored', 'missing-a', 'missing-z']);
    expect(anchored.id, 'anchored');
    expect(missingEarly.contentHash, isNull);
    expect(missingLate.contentHash, isNull);
  });

  test('G same-timestamp leftover fallback is by id, not invented sequenceOrder',
      () {
    final t = DateTime(2026, 8, 22, 10);
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      lastPreservedAt: t,
      capturedAt: t,
    );
    final noteB = _item(
      id: 'note-b',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: t,
      recordedAt: t,
    );
    final noteA = _item(
      id: 'note-a',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: t,
      recordedAt: t,
    );

    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: [noteB, noteA, photo],
      orderedCapturedEvidenceIds: const ['photo'],
      incidentId: 'inc-chrono',
    );
    expect(_ids(ordered), ['photo', 'note-a', 'note-b']);
  });

  testWidgets(
      'Organize view spine follows sequenceOrder when lastPreservedAt disagrees',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final tEarly = DateTime(2026, 8, 22, 9);
    final tMid = DateTime(2026, 8, 22, 10);
    final tLate = DateTime(2026, 8, 22, 11);
    final evidence = [
      _item(
        id: 'C',
        kind: WorkspaceEvidenceKind.voice,
        lastPreservedAt: tEarly,
        capturedAt: tEarly,
        contentHash: 'hash-C',
      ),
      _item(
        id: 'A',
        kind: WorkspaceEvidenceKind.image,
        lastPreservedAt: tMid,
        capturedAt: tMid,
        contentHash: 'hash-A',
      ),
      _item(
        id: 'B',
        kind: WorkspaceEvidenceKind.video,
        lastPreservedAt: tLate,
        capturedAt: tLate,
        contentHash: 'hash-B',
      ),
    ];
    const canonical = ['A', 'B', 'C'];
    const anchors = [
      OrganizeContextAnchor(
        contextEvidenceId: 'ctx',
        capturedEvidenceId: 'A',
      ),
    ];
    final collection = EvidenceCollection(
      id: 'col-1',
      incidentId: 'inc-chrono',
      name: 'Group',
      systemGenerated: false,
      pending: false,
      displayOrder: 0,
      createdAt: DateTime(2026, 8, 22),
      updatedAt: DateTime(2026, 8, 22),
      memberEvidenceIds: const ['C', 'A', 'B'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: _incident(
              evidence: evidence,
              collections: [collection],
            ),
            orderedCapturedEvidenceIds: canonical,
            contextAnchors: anchors,
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final aY = tester
        .getTopLeft(find.byKey(OrganizeChronologyCanvas.fixedTileKey('A')))
        .dy;
    final bY = tester
        .getTopLeft(find.byKey(OrganizeChronologyCanvas.fixedTileKey('B')))
        .dy;
    final cY = tester
        .getTopLeft(find.byKey(OrganizeChronologyCanvas.fixedTileKey('C')))
        .dy;
    expect(aY, lessThan(bY));
    expect(bY, lessThan(cY));

    expect(collection.memberEvidenceIds, ['C', 'A', 'B']);
    expect(anchors.single.contextEvidenceId, 'ctx');
    expect(anchors.single.capturedEvidenceId, 'A');
    expect(evidence.map((e) => e.contentHash), ['hash-C', 'hash-A', 'hash-B']);
    expect(evidence.map((e) => e.id), ['C', 'A', 'B']);
  });

  testWidgets(
      'D/E live controller: context stays on context spine; anchors and chronology unchanged',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-live', title: 'Case'),
    );
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final extra = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final contextNote = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    controller.setOrganizeContextAnchor(
      contextEvidenceId: contextNote,
      capturedEvidenceId: photo,
    );

    final store = controller.aggregate.store;
    final sequenceBefore = [
      for (final anchor in controller.timelineRepository.anchors)
        '${anchor.id}:${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
    ];
    final timelineOrderBefore = [
      for (final item in store.capturedEvidence) '${item.id}:${item.timelineOrder}',
    ];
    final idsBefore = [
      for (final item in store.capturedEvidence) item.id,
      for (final item in store.supportingEvidence) item.id,
    ];
    final hashesBefore = [
      for (final item in store.capturedEvidence) '${item.id}:${item.contentHash}',
      for (final item in store.supportingEvidence) '${item.id}:${item.contentHash}',
    ];
    final anchorsBefore = [
      for (final anchor in controller.organizeContextAnchors)
        '${anchor.contextEvidenceId}->${anchor.capturedEvidenceId}',
    ];
    final collectionsBefore = [
      for (final collection in controller.evidenceCollections)
        '${collection.id}:${collection.memberEvidenceIds.join(',')}',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return OrganizeWorkspaceView(
                incident: controller.currentIncident,
                orderedCapturedEvidenceIds: controller.timelineRepository
                    .orderedCapturedEvidenceIds(),
                organizeCreatedIds: controller.organizeCreatedEvidenceIds,
                contextAnchors: controller.organizeContextAnchors,
                dismissedCollectionIds: controller.dismissedCollectionIds,
                onEvidenceSelected: (_) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo)),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey(extra)),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(contextNote)),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey(contextNote)),
      findsNothing,
    );

    expect(
      [
        for (final anchor in controller.timelineRepository.anchors)
          '${anchor.id}:${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
      ],
      sequenceBefore,
    );
    expect(
      [
        for (final item in store.capturedEvidence) '${item.id}:${item.timelineOrder}',
      ],
      timelineOrderBefore,
    );
    expect(
      [
        for (final item in store.capturedEvidence) item.id,
        for (final item in store.supportingEvidence) item.id,
      ],
      idsBefore,
    );
    expect(
      [
        for (final item in store.capturedEvidence) '${item.id}:${item.contentHash}',
        for (final item in store.supportingEvidence) '${item.id}:${item.contentHash}',
      ],
      hashesBefore,
    );
    expect(
      [
        for (final anchor in controller.organizeContextAnchors)
          '${anchor.contextEvidenceId}->${anchor.capturedEvidenceId}',
      ],
      anchorsBefore,
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
