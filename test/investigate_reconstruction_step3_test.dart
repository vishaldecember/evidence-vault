import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/reconstruction/narrative_event.dart';
import 'package:evidence_vault/domain/timeline/timeline_anchor.dart';
import 'package:evidence_vault/engines/narrative_builder.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/relationship_group_confidence.dart';
import 'package:evidence_vault/models/timeline_anchor_node.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/services/narrative_validation_service.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigate_incident_scope.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:evidence_vault/services/investigation/reconstruction_location_label_store.dart';
import 'package:evidence_vault/widgets/investigation/reconstruction_story_canvas.dart';
import 'package:evidence_vault/widgets/investigation/reconstruction_workspace.dart';
import 'package:evidence_vault/widgets/reconstruction/evidence_inspector_panel.dart';
import 'package:evidence_vault/widgets/reconstruction/narrative/narrative_event_card.dart';
import 'package:evidence_vault/widgets/reconstruction/reconstruction_narrative_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail('EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual');
  }
}

const _emptyValidation = NarrativeEventValidation(
  status: RelationshipGroupConfidence.low,
  typeCounts: [],
  recommendations: [],
);

WorkspaceEvidenceItem _item({required String id, required String incidentId}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 8, 14, 9, 13, 5),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
  );
}

TimelineAnchorNode _node({
  required WorkspaceEvidenceItem item,
  required int sequenceOrder,
}) {
  return TimelineAnchorNode(
    anchor: TimelineAnchor(
      id: 'anchor-${item.id}',
      incidentId: item.incidentId,
      capturedEvidenceId: item.id,
      anchoredAt: item.lastPreservedAt,
      sequenceOrder: sequenceOrder,
    ),
    capturedItem: item,
    supportingItems: const [],
  );
}

NarrativeEventViewModel _eventVm({
  required NarrativeEvent event,
  TimelineAnchorNode? anchor,
  List<WorkspaceEvidenceItem> display = const [],
}) {
  return NarrativeEventViewModel(
    event: event,
    anchorNode: anchor,
    relationshipGroups: const [],
    reconstructionNotes: const [],
    supportingEvidence: const [],
    displayEvidence: display,
    validation: _emptyValidation,
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

String _evidenceFingerprint(WorkspaceEvidenceController controller) {
  return controller.anchoredTimeline
      .map(
        (node) => [
          node.capturedItem.id,
          node.capturedItem.incidentId,
          node.anchor.sequenceOrder,
          node.anchor.anchoredAt.toIso8601String(),
          node.capturedItem.lastPreservedAt.toIso8601String(),
          node.capturedItem.title,
        ].join('|'),
      )
      .join(';');
}

Future<void> _pumpReconstruction(
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
        initialInvestigationTab: InvestigationWorkspaceTab.reconstruction,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReconstructionLocationLabelStore.instance.resetForTests();
    WorkspaceSession.instance.reset();
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('InvestigateIncidentScope reconstruction ownership', () {
    test('1–2 keeps bound events and excludes foreign incident events', () {
      final owned = _item(id: 'owned', incidentId: 'inc-A');
      final foreign = _item(id: 'foreign', incidentId: 'inc-B');
      final scoped = InvestigateIncidentScope.reconstruction([
        _eventVm(
          event: const NarrativeEvent(
            id: 'n-owned',
            incidentId: 'inc-A',
            sortOrder: 0,
            title: 'Owned event',
            timelineAnchorEvidenceId: 'owned',
          ),
          anchor: _node(item: owned, sequenceOrder: 0),
          display: [owned, foreign],
        ),
        _eventVm(
          event: const NarrativeEvent(
            id: 'n-foreign',
            incidentId: 'inc-B',
            sortOrder: 1,
            title: 'Foreign event',
            timelineAnchorEvidenceId: 'foreign',
          ),
          anchor: _node(item: foreign, sequenceOrder: 1),
          display: [foreign],
        ),
        _eventVm(
          event: const NarrativeEvent(
            id: 'n-foreign-added',
            incidentId: 'inc-B',
            sortOrder: 2,
            title: 'Other incident story',
            timelineAnchorEvidenceId: '',
          ),
        ),
      ], 'inc-A');

      expect(scoped, hasLength(1));
      expect(scoped.single.event.id, 'n-owned');
      expect(scoped.single.displayEvidence.map((item) => item.id), ['owned']);
      expect(scoped.any((event) => event.event.incidentId == 'inc-B'), isFalse);
    });

    test('9 keeps investigator-added events on the bound incident', () {
      final scoped = InvestigateIncidentScope.reconstruction([
        _eventVm(
          event: const NarrativeEvent(
            id: 'n-added',
            incidentId: 'inc-A',
            sortOrder: 0,
            title: 'Gap in the evening',
            timelineAnchorEvidenceId: '',
          ),
        ),
      ], 'inc-A');

      expect(scoped, hasLength(1));
      expect(scoped.single.isInvestigatorAdded, isTrue);
      expect(scoped.single.displayEvidence, isEmpty);
    });
  });

  group('Reconstruction chronology independence', () {
    test('3–5, 11–12 reorder and edit do not mutate evidence or incident', () {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      final incidentId = controller.currentIncident.id;
      final before = _evidenceFingerprint(controller);
      final evidenceIds = controller.journeyEvidenceItems
          .map((item) => item.id)
          .toList();
      final timelineOrder = controller.anchoredTimeline
          .map((node) => node.capturedItem.id)
          .toList();
      final firstEventId = controller.narrativeEvents.first.event.id;
      final secondEventId = controller.narrativeEvents.last.event.id;

      expect(controller.narrativeEvents.first.event.sortOrder, 0);
      expect(controller.anchoredTimeline.first.anchor.sequenceOrder, 0);

      controller.moveNarrativeEventDown(eventId: firstEventId);
      controller.updateNarrativeEventTitle(
        eventId: firstEventId,
        title: 'Arrival',
      );
      controller.updateNarrativeEventSummary(
        eventId: firstEventId,
        summary: 'The investigator’s explanation.',
      );

      expect(controller.narrativeEvents.first.event.id, secondEventId);
      expect(controller.narrativeEvents.last.event.title, 'Arrival');
      expect(
        controller.anchoredTimeline.map((node) => node.capturedItem.id),
        timelineOrder,
      );
      expect(_evidenceFingerprint(controller), before);
      expect(
        controller.journeyEvidenceItems.map((item) => item.id),
        evidenceIds,
      );
      expectIncident(incidentId, controller.currentIncident.id);
      expect(controller.currentIncident.title, 'Alpha Case');
    });
  });

  group('Reconstruction workspace', () {
    testWidgets('1–2 bound evidence only; foreign reconstruction is excluded', (
      tester,
    ) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      final incidentId = controller.currentIncident.id;
      final ownedIds = controller.journeyEvidenceItems
          .map((item) => item.id)
          .toList();
      final store = controller.aggregate.store;
      store.capturedEvidence.add(
        _captured(
          id: 'foreign',
          incidentId: 'inc-B',
          capturedAt: DateTime(2026, 8, 14, 10, 0, 0),
          timelineAnchorId: 'anchor-foreign',
        ),
      );
      store.timelineAnchors.add(
        TimelineAnchor(
          id: 'anchor-foreign',
          incidentId: 'inc-B',
          capturedEvidenceId: 'foreign',
          anchoredAt: DateTime(2026, 8, 14, 10, 0, 0),
          sequenceOrder: 99,
        ),
      );
      store.narrativeEvents.add(
        const NarrativeEvent(
          id: 'n-foreign',
          incidentId: 'inc-B',
          sortOrder: 99,
          title: 'Other incident story',
          timelineAnchorEvidenceId: '',
        ),
      );
      controller.refreshNarrativeProjection();

      await _pumpReconstruction(tester, controller: controller);

      expect(find.byType(ReconstructionWorkspace), findsOneWidget);
      expect(find.byType(ReconstructionStoryCanvas), findsOneWidget);
      expect(find.byKey(ReconstructionStoryCanvas.axesKey), findsOneWidget);
      expect(find.text('Reconstructed sequence'), findsNothing);
      expect(find.text('Based on captured evidence'), findsNothing);
      expect(find.text('Other incident story'), findsNothing);
      expect(find.byType(NarrativeEventCard), findsNothing);
      expect(
        find.byKey(ReconstructionWorkspace.nodeKey(ownedIds.first)),
        findsOneWidget,
      );
      expect(
        find.byKey(ReconstructionWorkspace.nodeKey('foreign')),
        findsNothing,
      );
      expect(find.byIcon(Icons.place_rounded), findsWidgets);
      expect(find.text('People'), findsNothing);
      expect(find.text('Participants'), findsNothing);
      expectIncident(incidentId, controller.currentIncident.id);
      expect(find.byType(ReconstructionNarrativePlaceholder), findsNothing);
      expect(find.byType(EvidenceInspectorPanel), findsNothing);
    });

    testWidgets(
      '4, 6–8, 11–12 chip opens Inspector, close returns, carousel stays bound',
      (tester) async {
        final controller = _controllerFor(
          id: 'inc-A',
          title: 'Alpha Case',
          photos: 2,
        );
        final incidentId = controller.currentIncident.id;
        final title = controller.currentIncident.title;
        final before = _evidenceFingerprint(controller);
        final firstEventId = controller.narrativeEvents.first.event.id;

        controller.aggregate.store.capturedEvidence.add(
          _captured(
            id: 'foreign',
            incidentId: 'inc-B',
            capturedAt: DateTime(2026, 8, 14, 11, 0, 0),
            timelineAnchorId: 'anchor-foreign',
          ),
        );

        await _pumpReconstruction(tester, controller: controller);

        expect(_evidenceFingerprint(controller), before);
        expect(controller.narrativeEvents.first.event.id, firstEventId);
        expect(find.byTooltip('Reorder narrative event'), findsNothing);

        final chip = find.byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('reconstruction_evidence_');
        }).first;
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(
          find.byType(InvestigationEvidenceInspectorModal),
          findsOneWidget,
        );
        expect(find.text('Evidence Inspector'), findsOneWidget);
        expect(find.byType(EvidenceInspectorPanel), findsNothing);

        final ordered = evidenceInspectorOrder(
          controller.journeyEvidenceItems,
          incidentId: incidentId,
        );
        expect(ordered.map((item) => item.incidentId).toSet(), {incidentId});

        final carousel = tester.widget<EvidenceSpatialCarousel>(
          find.byType(EvidenceSpatialCarousel),
        );
        if (ordered.length > 1) {
          carousel.onSelected(1);
          await tester.pumpAndSettle();
        }
        final preview = tester.widget<EvidenceInspectorPreview>(
          find.byType(EvidenceInspectorPreview),
        );
        expectIncident(incidentId, preview.record.evidence.incidentId);

        await tester.tap(find.byKey(const Key('evidence_inspector_close')));
        await tester.pumpAndSettle();

        expect(find.text('Evidence Inspector'), findsNothing);
        expect(find.byType(ReconstructionWorkspace), findsOneWidget);
        expect(
          WorkspaceSession.instance.activeInvestigationTab,
          InvestigationWorkspaceTab.reconstruction,
        );
        expectIncident(incidentId, controller.currentIncident.id);
        expect(controller.currentIncident.title, title);
        expect(_evidenceFingerprint(controller), before);

        final shell = tester.state<IncidentWorkspaceShellState>(
          find.byType(IncidentWorkspaceShell),
        );
        expectIncident(incidentId, shell.boundIncidentId);
      },
    );

    testWidgets('9 investigator-added is not presented as captured evidence', (
      tester,
    ) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
      );
      final store = controller.aggregate.store;
      final existing = List<NarrativeEvent>.from(store.narrativeEvents);
      store.narrativeEvents
        ..clear()
        ..add(
          NarrativeEvent(
            id: 'n-added',
            incidentId: controller.currentIncident.id,
            sortOrder: 0,
            title: 'Gap in the evening',
            timelineAnchorEvidenceId: '',
          ),
        )
        ..addAll(
          existing.map(
            (event) => event.copyWith(sortOrder: event.sortOrder + 1),
          ),
        );
      controller.refreshNarrativeProjection();

      await _pumpReconstruction(tester, controller: controller);

      final photoId = controller.journeyEvidenceItems.first.id;
      expect(find.text('Gap in the evening'), findsNothing);
      expect(find.text('Investigator-added'), findsNothing);
      expect(find.byType(NarrativeEventCard), findsNothing);
      expect(
        find.byKey(NarrativeEventCard.investigatorAddedKey('n-added')),
        findsNothing,
      );
      expect(
        find.byKey(ReconstructionWorkspace.nodeKey(photoId)),
        findsOneWidget,
      );
      expect(find.text('Referenced evidence removed.'), findsNothing);
    });

    testWidgets(
      '10–12 reconstruction persists after reopening the same incident',
      (tester) async {
        final controller = _controllerFor(
          id: 'inc-A',
          title: 'Alpha Case',
          photos: 2,
        );
        final incidentId = controller.currentIncident.id;
        final firstEventId = controller.narrativeEvents.first.event.id;
        controller.updateNarrativeEventTitle(
          eventId: firstEventId,
          title: 'Arrival',
        );
        controller.moveNarrativeEventDown(eventId: firstEventId);
        controller.moveNarrativeEventUp(eventId: firstEventId);
        final persistedOrder = controller.narrativeEvents
            .map((event) => event.event.id)
            .toList();
        expect(persistedOrder.first, firstEventId);

        final ownedIds = controller.journeyEvidenceItems
            .map((item) => item.id)
            .toList();

        await _pumpReconstruction(tester, controller: controller);
        expect(find.text('Arrival'), findsNothing);
        expect(
          find.byKey(ReconstructionWorkspace.nodeKey(ownedIds.first)),
          findsOneWidget,
        );
        expectIncident(incidentId, controller.currentIncident.id);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await _pumpReconstruction(tester, controller: controller);

        expect(find.text('Arrival'), findsNothing);
        expect(
          find.byKey(ReconstructionWorkspace.nodeKey(ownedIds.first)),
          findsOneWidget,
        );
        expect(
          controller.narrativeEvents.map((event) => event.event.id),
          persistedOrder,
        );
        expectIncident(incidentId, controller.currentIncident.id);
        expect(
          find.descendant(
            of: find.byType(InvestigationWorkspaceTabBar),
            matching: find.text('Reconstruct'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
