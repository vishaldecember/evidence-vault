import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_suggestion_rail.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  String? contentHash,
  String incidentId = 'inc-origin',
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
  List<EvidenceCollection> collections = const [],
  IncidentStatus status = IncidentStatus.active,
}) {
  return CurrentIncident(
    id: 'inc-origin',
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
    evidenceCollections: collections,
    trustPackageReady: true,
    trustPackageProgressPercent: 40,
  );
}

Future<void> _pumpCanvas(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> ordered,
  Set<String> organizeCreatedIds = const {},
  List<String> orderedCapturedEvidenceIds = const [],
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final display = OrganizeChronologyCanvas.displayOrder(
    items: ordered,
    orderedCapturedEvidenceIds: orderedCapturedEvidenceIds.isEmpty
        ? [for (final item in ordered) item.id]
        : orderedCapturedEvidenceIds,
    organizeCreatedIds: organizeCreatedIds,
    incidentId: 'inc-origin',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeChronologyCanvas(
          ordered: display,
          allEvidence: ordered,
          organizeCreatedIds: organizeCreatedIds,
          onEvidenceSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final t0 = DateTime(2026, 8, 24, 10);
  final a = _item(
    id: 'A',
    kind: WorkspaceEvidenceKind.image,
    at: t0.add(const Duration(minutes: 2)),
    contentHash: 'hash-A',
  );
  final b = _item(
    id: 'B',
    kind: WorkspaceEvidenceKind.video,
    at: t0.add(const Duration(minutes: 3)),
    contentHash: 'hash-B',
  );
  final c = _item(
    id: 'C',
    kind: WorkspaceEvidenceKind.voice,
    at: t0,
    contentHash: 'hash-C',
  );

  testWidgets('A captured evidence when organizeCreatedEvidenceIds is empty', (
    tester,
  ) async {
    await _pumpCanvas(tester, ordered: [c, a, b], organizeCreatedIds: const {});

    expect(
      find.byKey(OrganizeChronologyCanvas.capturedLaneHeaderKey),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextLaneHeaderKey),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('A')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('B')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('C')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextCaptionKey('A')),
      findsNothing,
    );
  });

  testWidgets('B authored context is presented as Added context', (
    tester,
  ) async {
    final x = _item(
      id: 'X',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
      contentHash: 'hash-X',
    );
    await _pumpCanvas(
      tester,
      ordered: [a, x],
      organizeCreatedIds: const {'X'},
      orderedCapturedEvidenceIds: const ['A'],
    );

    expect(find.text(OrganizeChronologyCanvas.addedContextLabel), findsNothing);
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextLaneHeaderKey),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('X')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('X')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextCaptionKey('X')),
      findsNothing,
    );
  });

  testWidgets('C kind does not determine authored context', (tester) async {
    final capturedNote = _item(
      id: 'note-capture',
      kind: WorkspaceEvidenceKind.note,
      at: t0.add(const Duration(seconds: 5)),
    );
    final capturedVoice = _item(
      id: 'voice-capture',
      kind: WorkspaceEvidenceKind.voice,
      at: t0.add(const Duration(seconds: 6)),
      contentHash: 'hash-voice',
    );
    await _pumpCanvas(
      tester,
      ordered: [a, capturedNote, capturedVoice],
      organizeCreatedIds: const {},
      orderedCapturedEvidenceIds: const ['A', 'voice-capture'],
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('note-capture')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('voice-capture')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-capture')),
      findsNothing,
    );
    expect(
      find.byKey(
        OrganizeChronologyCanvas.addedContextCaptionKey('note-capture'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextLaneHeaderKey),
      findsNothing,
    );
  });

  testWidgets('D mixed incident keeps captured and authored spines distinct', (
    tester,
  ) async {
    final x = _item(id: 'X', kind: WorkspaceEvidenceKind.note, at: t0);
    final y = _item(
      id: 'Y',
      kind: WorkspaceEvidenceKind.attachment,
      at: t0.add(const Duration(seconds: 1)),
    );
    await _pumpCanvas(
      tester,
      ordered: [c, x, a, y, b],
      organizeCreatedIds: const {'X', 'Y'},
      orderedCapturedEvidenceIds: const ['A', 'B', 'C'],
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('A')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('B')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('C')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('X')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('Y')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('X')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('A')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.capturedLaneHeaderKey),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextSpineKey),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextLaneHeaderKey),
      findsNothing,
    );
  });

  test('E O-2 canonical order still applies to captured evidence', () {
    final x = _item(id: 'X', kind: WorkspaceEvidenceKind.note, at: t0);
    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: [c, x, a, b],
      orderedCapturedEvidenceIds: const ['A', 'B', 'C'],
      organizeCreatedIds: const {'X'},
      incidentId: 'inc-origin',
    );
    expect([for (final item in ordered) item.id], ['A', 'B', 'C', 'X']);
  });

  testWidgets('F classification does not mutate evidence or chronology', (
    tester,
  ) async {
    final items = [a, b, c];
    final idsBefore = [for (final item in items) item.id];
    final hashesBefore = [for (final item in items) item.contentHash];
    final capturedBefore = [for (final item in items) item.capturedAt];
    final preservedBefore = [for (final item in items) item.lastPreservedAt];

    await _pumpCanvas(
      tester,
      ordered: items,
      organizeCreatedIds: const {},
      orderedCapturedEvidenceIds: const ['A', 'B', 'C'],
    );

    expect([for (final item in items) item.id], idsBefore);
    expect([for (final item in items) item.contentHash], hashesBefore);
    expect([for (final item in items) item.capturedAt], capturedBefore);
    expect([for (final item in items) item.lastPreservedAt], preservedBefore);
  });

  testWidgets(
    'F live controller: labels do not mutate anchors or collections',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(
          id: 'inc-origin-live',
          title: 'Case',
        ),
      );
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      controller.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
      controller.ensureEvidenceCollections();

      final store = controller.aggregate.store;
      final sequenceBefore = [
        for (final anchor in controller.timelineRepository.anchors)
          '${anchor.id}:${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
      ];
      final timelineOrderBefore = [
        for (final item in store.capturedEvidence)
          '${item.id}:${item.timelineOrder}',
      ];
      final hashesBefore = [
        for (final item in store.capturedEvidence)
          '${item.id}:${item.contentHash}',
      ];
      final collectionsBefore = [
        for (final collection in controller.evidenceCollections)
          '${collection.id}:${collection.memberEvidenceIds.join(',')}',
      ];
      final createdIds = Set<String>.from(
        controller.organizeCreatedEvidenceIds,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(
                right: OrganizeSuggestionRail.width,
              ),
              child: OrganizeWorkspaceView(
                incident: controller.currentIncident,
                orderedCapturedEvidenceIds: controller.timelineRepository
                    .orderedCapturedEvidenceIds(),
                organizeCreatedIds: controller.organizeCreatedEvidenceIds,
                contextAnchors: controller.organizeContextAnchors,
                onEvidenceSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(OrganizeChronologyCanvas.capturedEvidenceLabel),
        findsNothing,
      );
      expect(find.byKey(OrganizeWorkspaceView.groupsBrowseKey), findsOneWidget);
      expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(
        find.byKey(OrganizeChronologyCanvas.addedContextLaneHeaderKey),
        findsNothing,
      );
      for (final id in createdIds) {
        expect(
          find.byKey(OrganizeChronologyCanvas.contextTileKey(id)),
          findsOneWidget,
        );
      }
      expect(controller.organizeCreatedEvidenceIds, createdIds);
      expect([
        for (final anchor in controller.timelineRepository.anchors)
          '${anchor.id}:${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
      ], sequenceBefore);
      expect([
        for (final item in store.capturedEvidence)
          '${item.id}:${item.timelineOrder}',
      ], timelineOrderBefore);
      expect([
        for (final item in store.capturedEvidence)
          '${item.id}:${item.contentHash}',
      ], hashesBefore);
      expect([
        for (final collection in controller.evidenceCollections)
          '${collection.id}:${collection.memberEvidenceIds.join(',')}',
      ], collectionsBefore);
    },
  );

  testWidgets('G archived Organize does not expose editing actions', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: _incident(
              evidence: [a, b],
              status: IncidentStatus.archived,
            ),
            orderedCapturedEvidenceIds: const ['A', 'B'],
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsNothing);
    expect(find.text('Create Group'), findsNothing);
    expect(
      find.text(OrganizeChronologyCanvas.capturedEvidenceLabel),
      findsNothing,
    );
    expect(find.byKey(OrganizeWorkspaceView.groupsBrowseKey), findsOneWidget);
    expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
  });

  testWidgets('empty canvas does not show origin headers', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrganizeChronologyCanvas(
            ordered: [],
            allEvidence: [],
            onEvidenceSelected: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.capturedLaneHeaderKey),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextLaneHeaderKey),
      findsNothing,
    );
    expect(find.text('fake'), findsNothing);
    expect(find.textContaining('unverified'), findsNothing);
    expect(find.textContaining('less reliable'), findsNothing);
  });

  testWidgets('group members use origin, not kind, for Added context', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final capturedNote = _item(
      id: 'note-capture',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
    );
    final addedNote = _item(
      id: 'note-org',
      kind: WorkspaceEvidenceKind.note,
      at: t0.add(const Duration(seconds: 1)),
    );
    final collection = EvidenceCollection(
      id: 'col-1',
      incidentId: 'inc-origin',
      name: 'Group',
      systemGenerated: false,
      pending: false,
      displayOrder: 0,
      createdAt: t0,
      updatedAt: t0,
      memberEvidenceIds: const ['note-capture', 'note-org', 'A'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: _incident(
              evidence: [a, capturedNote, addedNote],
              collections: [collection],
            ),
            orderedCapturedEvidenceIds: const ['A'],
            organizeCreatedIds: const {'note-org'},
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(collection.memberEvidenceIds, containsAll(['A', 'note-capture', 'note-org']));
    expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
    expect(find.text('Create Group'), findsNothing);
  });
}

void _noop(WorkspaceEvidenceItem _) {}
