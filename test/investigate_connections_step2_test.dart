import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/timeline/timeline_anchor.dart';
import 'package:evidence_vault/mappers/connections_presentation_mapper.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/trust_package_screen.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigation_connections_canvas.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:evidence_vault/services/investigation/user_connection_overlay_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail('EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual');
  }
}

WorkspaceEvidenceItem _item({
  required String id,
  required String incidentId,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? parentEvidenceId,
  DateTime? lastPreservedAt,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: lastPreservedAt ?? DateTime(2026, 8, 14, 9, 13, 5),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
    parentEvidenceId: parentEvidenceId,
    relationshipType: parentEvidenceId == null
        ? null
        : RelationshipType.supports,
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

void _flush(WorkspaceEvidenceController controller) {
  final id = controller.journeyEvidenceItems.first.id;
  final current = controller.aggregate.store.capturedEvidence.firstWhere(
    (item) => item.id == id,
  );
  controller.setPrimaryEvidence(
    evidenceId: id,
    isPrimary: !current.isPrimaryEvidence,
  );
  controller.setPrimaryEvidence(
    evidenceId: id,
    isPrimary: current.isPrimaryEvidence,
  );
}

Future<void> _pumpConnections(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(412, 915));
  WorkspaceSession.instance.controller = controller;
  await tester.pumpWidget(
    MaterialApp(
      home: IncidentWorkspaceShell(
        incidentId: controller.currentIncident.id,
        controller: controller,
        initialStage: InvestigationMethodologyStage.investigation,
        initialInvestigationTab: InvestigationWorkspaceTab.connections,
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

Future<void> _tapConnectionsTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(InvestigationWorkspaceTabBar),
      matching: find.text('Connections'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
    SharedPreferences.setMockInitialValues({});
    UserConnectionOverlayStore.instance.resetForTests();
  });

  group('ConnectionsPresentationMapper', () {
    test('1–2 excludes foreign evidence and foreign relationships', () {
      final owned = _item(id: 'owned', incidentId: 'inc-A');
      final foreign = _item(id: 'foreign', incidentId: 'inc-B');
      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc-A',
        items: [owned, foreign],
        relationships: [
          EvidenceRelationship(
            id: 'rel-foreign',
            sourceEvidenceId: 'owned',
            targetEvidenceId: 'foreign',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
          ),
        ],
        collections: const [],
        groupNodes: const [],
        suggestions: const [],
      );

      expect(presentation.linked, isEmpty);
      expect(presentation.suggested, isEmpty);
      expect(
        presentation.supporting.any((pair) => pair.from.id == 'foreign'),
        isFalse,
      );
    });

    test('3 parentEvidenceId appears as supporting, not causal', () {
      final photo = _item(id: 'photo', incidentId: 'inc-A');
      final note = _item(
        id: 'note',
        incidentId: 'inc-A',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
      );
      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc-A',
        items: [photo, note],
        relationships: const [],
        collections: const [],
        groupNodes: const [],
        suggestions: const [],
      );

      expect(presentation.supporting, hasLength(1));
      expect(presentation.supporting.single.from.id, 'photo');
      expect(presentation.supporting.single.to.id, 'note');
      expect(presentation.supporting.single.label, 'Supporting evidence');
      expect(presentation.supporting.single.label, isNot(contains('Caused')));
    });

    test('4 explicit linked evidence appears as Linked evidence', () {
      final a = _item(id: 'a', incidentId: 'inc-A');
      final b = _item(id: 'b', incidentId: 'inc-A');
      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc-A',
        items: [a, b],
        relationships: [
          EvidenceRelationship(
            id: 'link-1',
            sourceEvidenceId: 'a',
            targetEvidenceId: 'b',
            type: RelationshipType.references,
            createdAt: DateTime(2026, 8, 14),
            source: 'user',
          ),
        ],
        collections: const [],
        groupNodes: const [],
        suggestions: const [],
      );

      expect(presentation.linked, hasLength(1));
      expect(presentation.linked.single.label, 'Linked evidence');
    });

    test('5–6 collection membership is grouping context, not causal', () {
      final a = _item(id: 'a', incidentId: 'inc-A');
      final b = _item(id: 'b', incidentId: 'inc-A');
      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc-A',
        items: [a, b],
        relationships: [
          EvidenceRelationship(
            id: 'col-rel',
            sourceEvidenceId: 'a',
            targetEvidenceId: 'b',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
            reason: 'Related through Media.',
            source: 'metadata',
          ),
        ],
        collections: [
          EvidenceCollection(
            id: 'col-media',
            incidentId: 'inc-A',
            name: 'Media',
            systemGenerated: true,
            displayOrder: 0,
            createdAt: DateTime(2026, 8, 14),
            updatedAt: DateTime(2026, 8, 14),
            memberEvidenceIds: const ['a', 'b'],
          ),
        ],
        groupNodes: const [],
        suggestions: const [],
      );

      expect(presentation.collections, hasLength(1));
      expect(presentation.collections.single.name, 'Media');
      expect(presentation.suggested, isEmpty);
      expect(presentation.linked, isEmpty);
      expect(presentation.supporting, isEmpty);
    });

    test('7 heuristic RELATED is suggested, not established fact', () {
      final a = _item(
        id: 'a',
        incidentId: 'inc-A',
        lastPreservedAt: DateTime(2026, 8, 14, 9, 13, 5),
      );
      final b = _item(
        id: 'b',
        incidentId: 'inc-A',
        lastPreservedAt: DateTime(2026, 8, 14, 9, 13, 47),
      );
      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc-A',
        items: [a, b],
        relationships: [
          EvidenceRelationship(
            id: 'heur-1',
            sourceEvidenceId: 'a',
            targetEvidenceId: 'b',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
            reason: 'Related because these were captured 42 seconds apart.',
            source: 'metadata',
          ),
        ],
        collections: const [],
        groupNodes: const [],
        suggestions: const [],
      );

      expect(presentation.suggested, hasLength(1));
      expect(presentation.suggested.single.label, 'Suggested relationship');
      expect(presentation.suggested.single.detail, 'Captured 42 seconds apart');
      expect(presentation.linked, isEmpty);
      expect(presentation.hasStructural, isFalse);
    });

    test('9 empty structural when only unrelated evidence exists', () {
      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc-A',
        items: [_item(id: 'solo', incidentId: 'inc-A')],
        relationships: const [],
        collections: const [],
        groupNodes: const [],
        suggestions: const [],
      );
      expect(presentation.hasStructural, isFalse);
      expect(presentation.hasSuggested, isFalse);
    });

    test('20 does not reassign foreign evidence to the bound incident', () {
      final owned = _item(id: 'owned', incidentId: 'inc-A');
      final foreign = _item(
        id: 'foreign',
        incidentId: 'inc-B',
        parentEvidenceId: 'owned',
      );
      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc-A',
        items: [owned, foreign],
        relationships: const [],
        collections: const [],
        groupNodes: const [],
        suggestions: const [],
      );
      expect(presentation.supporting, isEmpty);
      expectIncident('inc-B', foreign.incidentId);
    });
  });

  group('Connections workspace', () {
    testWidgets('3, 12, 14 connection node opens Inspector and returns', (
      tester,
    ) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
      );
      final photoId = controller.journeyEvidenceItems.single.id;
      controller.addContextTextNote(
        parentEvidenceId: photoId,
        text: 'Heard shouting.',
      );
      final incidentId = controller.currentIncident.id;
      final evidenceIds = controller.journeyEvidenceItems
          .map((e) => e.id)
          .toList();
      final count = evidenceIds.length;

      await _pumpConnections(tester, controller: controller);

      expect(find.byType(InvestigationConnectionsCanvas), findsOneWidget);
      expect(find.text('My Connections'), findsNothing);
      expect(find.text('No explicit connections yet.'), findsNothing);

      await tester.ensureVisible(
        find.byKey(InvestigationConnectionsCanvas.nodeKey(photoId)),
      );
      await tester.tap(
        find.byKey(InvestigationConnectionsCanvas.nodeKey(photoId)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationEvidenceInspectorModal), findsOneWidget);
      expect(find.text('Evidence Inspector'), findsOneWidget);
      expectIncident(incidentId, controller.currentIncident.id);

      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      expect(find.text('Evidence Inspector'), findsNothing);
      expect(find.byType(InvestigationConnectionsCanvas), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeInvestigationTab,
        InvestigationWorkspaceTab.connections,
      );
      expect(controller.journeyEvidenceItems.map((e) => e.id), evidenceIds);
      expect(controller.journeyEvidenceItems, hasLength(count));
    });

    testWidgets('4, 7–8 linked is structural, heuristic is suggested', (
      tester,
    ) async {
      final t0 = DateTime(2026, 8, 14, 9, 13, 5);
      final t1 = DateTime(2026, 8, 14, 9, 13, 47);
      final store = IncidentStore(
        incident: Incident(
          id: 'inc-A',
          title: 'Alpha Case',
          status: IncidentStatus.draft,
          createdAt: t0,
          updatedAt: t1,
        ),
        capturedEvidence: [
          _captured(
            id: 'photo',
            incidentId: 'inc-A',
            capturedAt: t0,
            timelineAnchorId: 'anchor-photo',
          ),
          _captured(
            id: 'video',
            incidentId: 'inc-A',
            capturedAt: t1,
            timelineAnchorId: 'anchor-video',
          ),
          _captured(
            id: 'extra',
            incidentId: 'inc-A',
            capturedAt: t1,
            timelineAnchorId: 'anchor-extra',
          ),
        ],
        timelineAnchors: [
          TimelineAnchor(
            id: 'anchor-photo',
            incidentId: 'inc-A',
            capturedEvidenceId: 'photo',
            anchoredAt: t0,
            sequenceOrder: 0,
          ),
          TimelineAnchor(
            id: 'anchor-video',
            incidentId: 'inc-A',
            capturedEvidenceId: 'video',
            anchoredAt: t1,
            sequenceOrder: 1,
          ),
          TimelineAnchor(
            id: 'anchor-extra',
            incidentId: 'inc-A',
            capturedEvidenceId: 'extra',
            anchoredAt: t1,
            sequenceOrder: 2,
          ),
        ],
        relationships: [
          EvidenceRelationship(
            id: 'user-link',
            sourceEvidenceId: 'photo',
            targetEvidenceId: 'video',
            type: RelationshipType.references,
            createdAt: t0,
            source: 'user',
          ),
          EvidenceRelationship(
            id: 'heur-link',
            sourceEvidenceId: 'video',
            targetEvidenceId: 'extra',
            type: RelationshipType.relatedTo,
            createdAt: t1,
            reason: 'Related because these were captured 42 seconds apart.',
            source: 'metadata',
          ),
        ],
      );
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.fromStore(store),
      );

      await _pumpConnections(tester, controller: controller);

      expect(find.byType(InvestigationConnectionsCanvas), findsOneWidget);
      expect(
        find.byKey(InvestigationConnectionsCanvas.nodeKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(InvestigationConnectionsCanvas.nodeKey('video')),
        findsOneWidget,
      );
      expect(find.text('Linked evidence'), findsNothing);
      expect(find.text('Caused by'), findsNothing);
      expect(find.text('Proves'), findsNothing);
    });

    testWidgets('5–6, 9 collection context and empty causal claims', (
      tester,
    ) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      final ids = controller.journeyEvidenceItems.map((e) => e.id).toList();
      final store = controller.aggregate.store;
      store.evidenceCollections.add(
        EvidenceCollection(
          id: 'col-media',
          incidentId: store.incident.id,
          name: 'Media',
          systemGenerated: true,
          displayOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          memberEvidenceIds: ids,
        ),
      );
      for (var i = 0; i < store.capturedEvidence.length; i++) {
        final item = store.capturedEvidence[i];
        if (ids.contains(item.id)) {
          store.capturedEvidence[i] = item.copyWith(collectionId: 'col-media');
        }
      }
      _flush(controller);

      await _pumpConnections(tester, controller: controller);

      expect(find.byType(InvestigationConnectionsCanvas), findsOneWidget);
      expect(find.textContaining('supports Evidence'), findsNothing);
      expect(find.text('Caused by'), findsNothing);
      for (final id in ids) {
        expect(
          find.byKey(InvestigationConnectionsCanvas.nodeKey(id)),
          findsOneWidget,
        );
      }
    });

    testWidgets('9 empty structural copy when nothing is linked', (
      tester,
    ) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
      );
      await _pumpConnections(tester, controller: controller);
      expect(find.byType(InvestigationConnectionsCanvas), findsOneWidget);
      expect(find.text('My Connections'), findsNothing);
      expect(find.textContaining('Go to Organize'), findsNothing);
    });

    testWidgets('10 RelationshipGroups still render when persisted', (
      tester,
    ) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      final ids = controller.journeyEvidenceItems.map((e) => e.id).toList();
      controller.commitRelationshipGroup(evidenceIds: ids);

      await _pumpConnections(tester, controller: controller);

      expect(find.byType(InvestigationConnectionsCanvas), findsOneWidget);
      expect(controller.state.relationshipGroups, hasLength(1));
      expect(find.text('Group 1'), findsNothing);
    });

    testWidgets('11 Connections is distinct from Workspace Organize', (
      tester,
    ) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      controller.commitRelationshipGroup(
        evidenceIds: controller.journeyEvidenceItems.map((e) => e.id).toList(),
      );
      await _pumpConnections(tester, controller: controller);

      expect(find.byType(InvestigationConnectionsCanvas), findsOneWidget);
      expect(find.text('My Connections'), findsNothing);
      expect(find.text('Create Group'), findsNothing);
      expect(find.byType(OrganizeWorkspaceView), findsNothing);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.investigation,
      );
    });

    testWidgets('13 Inspector swipe stays on the bound incident', (
      tester,
    ) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 3,
      );
      final photoId = controller.journeyEvidenceItems.first.id;
      controller.addContextTextNote(parentEvidenceId: photoId, text: 'Context');
      final incidentId = controller.currentIncident.id;
      final ordered = evidenceInspectorOrder(
        controller.journeyEvidenceItems,
        incidentId: incidentId,
      );

      await _pumpConnections(tester, controller: controller);
      await tester.ensureVisible(
        find.byKey(InvestigationConnectionsCanvas.nodeKey(photoId)),
      );
      await tester.tap(
        find.byKey(InvestigationConnectionsCanvas.nodeKey(photoId)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Evidence Inspector'), findsOneWidget);
      tester
          .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
          .onSelected(1);
      await tester.pumpAndSettle();

      final preview = tester.widget<EvidenceInspectorPreview>(
        find.byType(EvidenceInspectorPreview),
      );
      expectIncident(incidentId, preview.record.evidence.incidentId);
      expect(ordered.map((item) => item.incidentId).toSet(), {incidentId});
    });

    testWidgets(
      '15–19 Capture → Organize → Investigate → Connections → Trust identity',
      (tester) async {
        final controller = _controllerFor(
          id: 'inc-A',
          title: 'Alpha Case',
          photos: 2,
        );
        final incidentId = controller.currentIncident.id;
        final title = controller.currentIncident.title;
        final ids = controller.journeyEvidenceItems.map((e) => e.id).toList();
        final count = ids.length;

        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(412, 915));
        WorkspaceSession.instance.controller = controller;
        await tester.pumpWidget(
          MaterialApp(
            home: IncidentWorkspaceShell(
              incidentId: incidentId,
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final shell = tester.state<IncidentWorkspaceShellState>(
          find.byType(IncidentWorkspaceShell),
        );

        void assertUnchanged() {
          expectIncident(incidentId, shell.boundIncidentId);
          expectIncident(incidentId, controller.currentIncident.id);
          expect(controller.currentIncident.title, title);
          expect(controller.journeyEvidenceItems.map((e) => e.id), ids);
          expect(controller.journeyEvidenceItems, hasLength(count));
        }

        await _tapStage(tester, 'Organize');
        expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
        assertUnchanged();

        await _tapStage(tester, 'Investigate');
        await _tapConnectionsTab(tester);
        expect(find.byType(InvestigationConnectionsCanvas), findsOneWidget);
        expect(find.text('My Connections'), findsNothing);
        assertUnchanged();

        await _tapStage(tester, 'Trust Package');
        expect(find.byType(TrustPackageScreen), findsOneWidget);
        assertUnchanged();
      },
    );
  });
}
