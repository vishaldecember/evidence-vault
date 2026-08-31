import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/reconstruction/narrative_event.dart';
import 'package:evidence_vault/domain/relationship/relationship_group.dart';
import 'package:evidence_vault/domain/timeline/timeline_anchor.dart';
import 'package:evidence_vault/engines/narrative_builder.dart';
import 'package:evidence_vault/models/connection_group_node.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/relationship_group_confidence.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/timeline_anchor_node.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/investigation_workspace_screen.dart';
import 'package:evidence_vault/screens/trust_package_screen.dart';
import 'package:evidence_vault/services/narrative_validation_service.dart';
import 'package:evidence_vault/services/relationship/relationship_engine.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigate_incident_scope.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/timeline/timeline_anchor_card_metadata.dart';
import 'package:evidence_vault/widgets/timeline/timeline_anchor_entry.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail(
      'EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual',
    );
  }
}

WorkspaceEvidenceItem _item({
  required String id,
  required String incidentId,
  DateTime? lastPreservedAt,
  String? deviceModel,
  double? latitude,
  double? longitude,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Evidence $id',
    lastPreservedAt: lastPreservedAt ?? DateTime(2026, 8, 13, 9, 13, 5),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
    deviceModel: deviceModel,
    latitude: latitude,
    longitude: longitude,
  );
}

TimelineAnchorNode _node({
  required WorkspaceEvidenceItem item,
  required int sequenceOrder,
  DateTime? anchoredAt,
  List<WorkspaceEvidenceItem> supporting = const [],
}) {
  return TimelineAnchorNode(
    anchor: TimelineAnchor(
      id: 'anchor-${item.id}',
      incidentId: item.incidentId,
      capturedEvidenceId: item.id,
      anchoredAt: anchoredAt ?? item.lastPreservedAt,
      sequenceOrder: sequenceOrder,
    ),
    capturedItem: item,
    supportingItems: supporting,
  );
}

CapturedEvidence _captured({
  required String id,
  required String incidentId,
  required DateTime capturedAt,
  required String timelineAnchorId,
}) {
  return CapturedEvidence(
    id: id,
    incidentId: incidentId,
    type: CapturedEvidenceType.photo,
    capturedAt: capturedAt,
    title: 'Evidence $id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    timelineAnchorId: timelineAnchorId,
  );
}

WorkspaceEvidenceController _controllerFor({
  required String id,
  required String title,
  int photos = 0,
}) {
  final controller = WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: id, title: title),
  );
  for (var i = 0; i < photos; i++) {
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
  }
  return controller;
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  InvestigationMethodologyStage? initialStage,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(412, 915));
  WorkspaceSession.instance.controller = controller;

  await tester.pumpWidget(
    MaterialApp(
      home: IncidentWorkspaceShell(
        incidentId: controller.currentIncident.id,
        controller: controller,
        initialStage: initialStage,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapStage(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(InvestigationJourneyHeader),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
  });

  group('InvestigateIncidentScope ownership', () {
    test('keeps bound-incident evidence and excludes foreign items', () {
      final owned = _item(id: 'owned', incidentId: 'inc-A');
      final foreign = _item(id: 'foreign', incidentId: 'inc-B');

      final scoped = InvestigateIncidentScope.evidence(
        [owned, foreign],
        'inc-A',
      );

      expect(scoped, hasLength(1));
      expect(scoped.single.id, 'owned');
      expectIncident('inc-A', scoped.single.incidentId);
    });

    test('timeline excludes foreign anchors without reordering', () {
      final evening = _item(
        id: 'seq-0',
        incidentId: 'inc-A',
        lastPreservedAt: DateTime(2026, 8, 13, 18, 0, 0),
      );
      final morning = _item(
        id: 'seq-1',
        incidentId: 'inc-A',
        lastPreservedAt: DateTime(2026, 8, 13, 8, 0, 0),
      );
      final foreign = _item(id: 'foreign', incidentId: 'inc-B');

      final scoped = InvestigateIncidentScope.timeline(
        [
          _node(item: evening, sequenceOrder: 0),
          _node(item: morning, sequenceOrder: 1),
          _node(item: foreign, sequenceOrder: 2),
        ],
        'inc-A',
      );

      expect(scoped.map((node) => node.capturedItem.id), ['seq-0', 'seq-1']);
      expect(
        scoped.map((node) => node.anchor.sequenceOrder),
        [0, 1],
      );
    });

    test('connections, graph, and reconstruction drop foreign evidence', () {
      final owned = _item(id: 'owned', incidentId: 'inc-A');
      final foreign = _item(id: 'foreign', incidentId: 'inc-B');

      final connectionScoped = InvestigateIncidentScope.connections(
        [
          ConnectionGroupNode(
            group: RelationshipGroup(
              id: 'g1',
              incidentId: 'inc-A',
              type: RelationshipType.relatedTo,
              createdAt: DateTime(2026, 8, 13),
              colorIndex: 0,
            ),
            capturedEntries: [
              ConnectionGroupCapturedEntry(
                captured: owned,
                supportingItems: [foreign],
              ),
              ConnectionGroupCapturedEntry(
                captured: foreign,
                supportingItems: const [],
              ),
            ],
            standaloneSupporting: [foreign],
          ),
        ],
        'inc-A',
      );
      expect(connectionScoped.single.capturedEntries, hasLength(1));
      expect(connectionScoped.single.capturedEntries.single.captured.id, 'owned');
      expect(connectionScoped.single.standaloneSupporting, isEmpty);

      final graphScoped = InvestigateIncidentScope.graph(
        InvestigationGraphView(
          primaryEvidenceIds: ['owned', 'foreign'],
          supportingByPrimaryId: {
            'owned': ['foreign'],
            'foreign': ['owned'],
          },
          edges: const [
            InvestigationGraphEdge(
              id: 'e1',
              sourceEvidenceId: 'owned',
              targetEvidenceId: 'foreign',
              kind: InvestigationGraphEdgeKind.related,
            ),
          ],
          collections: [
            EvidenceCollection(
              id: 'c-foreign',
              incidentId: 'inc-B',
              name: 'Other incident',
              systemGenerated: true,
              displayOrder: 0,
              createdAt: DateTime(2026, 8, 13),
              updatedAt: DateTime(2026, 8, 13),
            ),
          ],
          evidenceById: {
            'owned': owned,
            'foreign': foreign,
          },
        ),
        'inc-A',
      );
      expect(graphScoped.primaryEvidenceIds, ['owned']);
      expect(graphScoped.evidenceById.containsKey('foreign'), isFalse);
      expect(graphScoped.edges, isEmpty);
      expect(graphScoped.collections, isEmpty);

      final reconstructionScoped = InvestigateIncidentScope.reconstruction(
        [
          NarrativeEventViewModel(
            event: const NarrativeEvent(
              id: 'n-owned',
              incidentId: 'inc-A',
              sortOrder: 0,
              title: 'Event 1',
              timelineAnchorEvidenceId: 'owned',
            ),
            anchorNode: _node(item: owned, sequenceOrder: 0),
            relationshipGroups: const [],
            reconstructionNotes: const [],
            supportingEvidence: [foreign],
            displayEvidence: [owned, foreign],
            validation: const NarrativeEventValidation(
              status: RelationshipGroupConfidence.low,
              typeCounts: [],
              recommendations: [],
            ),
          ),
          NarrativeEventViewModel(
            event: const NarrativeEvent(
              id: 'n-foreign',
              incidentId: 'inc-B',
              sortOrder: 1,
              title: 'Foreign event',
              timelineAnchorEvidenceId: 'foreign',
            ),
            anchorNode: _node(item: foreign, sequenceOrder: 1),
            relationshipGroups: const [],
            reconstructionNotes: const [],
            supportingEvidence: const [],
            displayEvidence: [foreign],
            validation: const NarrativeEventValidation(
              status: RelationshipGroupConfidence.low,
              typeCounts: [],
              recommendations: [],
            ),
          ),
        ],
        'inc-A',
      );
      expect(reconstructionScoped, hasLength(1));
      expect(
        reconstructionScoped.single.displayEvidence.map((item) => item.id),
        ['owned'],
      );
    });
  });

  group('Investigate chronology semantics', () {
    test('timeline is capture chronology, not lastPreservedAt', () {
      final evening = _item(
        id: 'seq-0',
        incidentId: 'inc-A',
        lastPreservedAt: DateTime(2026, 8, 13, 18, 0, 0),
      );
      final morning = _item(
        id: 'seq-1',
        incidentId: 'inc-A',
        lastPreservedAt: DateTime(2026, 8, 13, 8, 0, 0),
      );
      final nodes = [
        _node(item: evening, sequenceOrder: 0),
        _node(item: morning, sequenceOrder: 1),
      ];

      final timeline = InvestigateIncidentScope.timeline(nodes, 'inc-A');
      final inspector = evidenceInspectorOrder(
        timeline.map((node) => node.capturedItem),
        incidentId: 'inc-A',
      );

      expect(timeline.map((node) => node.capturedItem.id), ['seq-0', 'seq-1']);
      expect(inspector.map((item) => item.id), ['seq-1', 'seq-0']);
    });

    test('clock uses shared evidenceClock of lastPreservedAt', () {
      final instant = DateTime(2026, 8, 13, 9, 13, 5);
      final node = _node(
        item: _item(
          id: 'photo',
          incidentId: 'inc-A',
          lastPreservedAt: instant,
        ),
        sequenceOrder: 0,
      );
      final metadata = TimelineAnchorCardMetadata.fromNode(node);
      final expected = WorkspaceEvidenceFormatters.evidenceClock(instant);

      expect(metadata.captureTime, expected);
      expect(metadata.captureTime, WorkspaceEvidenceFormatters.inspectorTimestamp(instant));
      expect(metadata.captureTime, contains(RegExp(r'\d{2}:\d{2}:\d{2}')));
    });
  });

  group('Investigate presentation', () {
    testWidgets('excludes foreign evidence from the bound-incident Timeline',
        (tester) async {
      final evening = DateTime(2026, 8, 13, 18, 0, 5);
      final store = IncidentStore(
        incident: Incident(
          id: 'inc-A',
          title: 'Alpha Case',
          status: IncidentStatus.draft,
          createdAt: evening,
          updatedAt: evening,
        ),
        capturedEvidence: [
          _captured(
            id: 'owned',
            incidentId: 'inc-A',
            capturedAt: evening,
            timelineAnchorId: 'anchor-owned',
          ),
          _captured(
            id: 'foreign',
            incidentId: 'inc-B',
            capturedAt: evening,
            timelineAnchorId: 'anchor-foreign',
          ),
        ],
        timelineAnchors: [
          TimelineAnchor(
            id: 'anchor-owned',
            incidentId: 'inc-A',
            capturedEvidenceId: 'owned',
            anchoredAt: evening,
            sequenceOrder: 0,
          ),
          TimelineAnchor(
            id: 'anchor-foreign',
            incidentId: 'inc-B',
            capturedEvidenceId: 'foreign',
            anchoredAt: evening,
            sequenceOrder: 1,
          ),
        ],
      );
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.fromStore(store),
      );

      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.investigation,
      );

      expectIncident('inc-A', controller.currentIncident.id);
      expect(find.byType(InvestigationWorkspaceScreen), findsOneWidget);
      expect(find.byType(TimelineAnchorEntry), findsOneWidget);
      expect(
        find.byKey(const Key('investigate_timeline_clock_owned')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('investigate_timeline_clock_foreign')),
        findsNothing,
      );
    });

    testWidgets(
        'same incident remains visible Capture → Organize → Investigate → Trust',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
      );
      final incidentId = controller.currentIncident.id;
      final evidenceId = controller.journeyEvidenceItems.single.id;

      await _pumpShell(tester, controller: controller);
      final shell = tester.state<IncidentWorkspaceShellState>(
        find.byType(IncidentWorkspaceShell),
      );
      expectIncident(incidentId, shell.boundIncidentId);

      await _tapStage(tester, 'Organize');
      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expectIncident(incidentId, shell.boundIncidentId);
      expectIncident(incidentId, controller.currentIncident.id);

      await _tapStage(tester, 'Investigate');
      expect(find.byType(InvestigationWorkspaceScreen), findsOneWidget);
      expect(
        find.byKey(Key('investigate_timeline_clock_$evidenceId')),
        findsOneWidget,
      );
      expectIncident(incidentId, shell.boundIncidentId);

      await _tapStage(tester, 'Trust Package');
      expect(find.byType(TrustPackageScreen), findsOneWidget);
      expectIncident(incidentId, shell.boundIncidentId);
      expectIncident(incidentId, controller.currentIncident.id);

      await _tapStage(tester, 'Capture');
      expectIncident(incidentId, shell.boundIncidentId);
      expectIncident(incidentId, controller.currentIncident.id);
      expect(controller.currentIncident.evidence, hasLength(1));
    });

    testWidgets('investigator clock includes seconds and matches Inspector',
        (tester) async {
      final instant = DateTime(2026, 8, 13, 9, 13, 5);
      final store = IncidentStore(
        incident: Incident(
          id: 'inc-A',
          title: 'Alpha Case',
          status: IncidentStatus.draft,
          createdAt: instant,
          updatedAt: instant,
        ),
        capturedEvidence: [
          _captured(
            id: 'photo-1',
            incidentId: 'inc-A',
            capturedAt: instant,
            timelineAnchorId: 'anchor-photo-1',
          ),
        ],
        timelineAnchors: [
          TimelineAnchor(
            id: 'anchor-photo-1',
            incidentId: 'inc-A',
            capturedEvidenceId: 'photo-1',
            anchoredAt: instant,
            sequenceOrder: 0,
          ),
        ],
      );
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.fromStore(store),
      );
      final expected = WorkspaceEvidenceFormatters.evidenceClock(instant);

      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.investigation,
      );

      expect(expected, contains(RegExp(r'\d{2}:\d{2}:\d{2}')));
      expect(find.textContaining(expected), findsWidgets);
      expect(find.textContaining('Moto G35 5G'), findsNothing);
      expect(find.textContaining('Pokhara, Nepal'), findsNothing);

      await tester.ensureVisible(find.byType(TimelineAnchorEntry).first);
      await tester.tap(find.byType(TimelineAnchorEntry).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(InvestigationEvidenceInspectorModal), findsOneWidget);
      expect(find.byKey(const Key('evidence_inspector_timestamp')), findsOneWidget);
      expect(
        find.text(expected),
        findsWidgets,
      );
      expect(
        WorkspaceEvidenceFormatters.inspectorTimestamp(instant),
        expected,
      );
    });

    testWidgets('timeline order follows sequenceOrder not lastPreservedAt',
        (tester) async {
      final evening = DateTime(2026, 8, 13, 18, 0, 5);
      final morning = DateTime(2026, 8, 13, 8, 0, 5);
      final store = IncidentStore(
        incident: Incident(
          id: 'inc-A',
          title: 'Alpha Case',
          status: IncidentStatus.draft,
          createdAt: morning,
          updatedAt: evening,
        ),
        capturedEvidence: [
          _captured(
            id: 'seq-0',
            incidentId: 'inc-A',
            capturedAt: evening,
            timelineAnchorId: 'anchor-seq-0',
          ),
          _captured(
            id: 'seq-1',
            incidentId: 'inc-A',
            capturedAt: morning,
            timelineAnchorId: 'anchor-seq-1',
          ),
        ],
        timelineAnchors: [
          TimelineAnchor(
            id: 'anchor-seq-0',
            incidentId: 'inc-A',
            capturedEvidenceId: 'seq-0',
            anchoredAt: evening,
            sequenceOrder: 0,
          ),
          TimelineAnchor(
            id: 'anchor-seq-1',
            incidentId: 'inc-A',
            capturedEvidenceId: 'seq-1',
            anchoredAt: morning,
            sequenceOrder: 1,
          ),
        ],
      );
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.fromStore(store),
      );

      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.investigation,
      );

      final first = tester.getTopLeft(
        find.byKey(const Key('investigate_timeline_clock_seq-0')),
      );
      final second = tester.getTopLeft(
        find.byKey(const Key('investigate_timeline_clock_seq-1')),
      );
      expect(first.dy < second.dy, isTrue);

      final inspector = evidenceInspectorOrder(
        controller.journeyEvidenceItems,
        incidentId: 'inc-A',
      );
      expect(inspector.map((item) => item.id), ['seq-1', 'seq-0']);
    });
  });
}
