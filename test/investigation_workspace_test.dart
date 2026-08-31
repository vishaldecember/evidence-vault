import 'package:evidence_vault/controllers/reconstruction_canvas_controller.dart';
import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/relationship_group_confidence.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:evidence_vault/screens/investigation_workspace_screen.dart';
import 'package:evidence_vault/services/investigation_canvas_sync_engine.dart';
import 'package:evidence_vault/services/investigation/reconstruction_location_label_store.dart';
import 'package:evidence_vault/widgets/investigation/investigation_header.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:evidence_vault/widgets/investigation/reconstruction_story_canvas.dart';
import 'package:evidence_vault/widgets/investigation/reconstruction_workspace.dart';
import 'package:evidence_vault/widgets/reconstruction/narrative/structured_narrative_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  bool isContextual = false,
  Set<String> relatedEvidenceIds = const {},
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    isContextual: isContextual,
    relatedEvidenceIds: relatedEvidenceIds,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReconstructionLocationLabelStore.instance.resetForTests();
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('NarrativeBuilder', () {
    test('generates one event per timeline anchor on first open', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
        ),
      );

      final events = controller.narrativeEvents;

      expect(events, hasLength(2));
      expect(events[0].event.title, 'Event 1');
      expect(events[1].event.title, 'Event 2');
    });

    test(
      'displays validation summary inherited from evidence completeness',
      () {
        final controller = WorkspaceEvidenceController(
          initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
        );

        final validation = controller.narrativeEvents.single.validation;
        expect(validation.statusEmoji, '🔴');
        expect(validation.status, RelationshipGroupConfidence.low);
      },
    );

    test('selecting narrative event highlights referenced anchor', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video'),
          ],
        ),
      );
      final events = controller.narrativeEvents;
      final canvas = InvestigationCanvasController();

      canvas.selectNarrativeSection(
        sectionId: events.first.event.id,
        notes: controller.sortedReflections,
        items: controller.state.items,
        groups: controller.state.relationshipGroups,
        timelineNodes: controller.anchoredTimeline,
        narrativeEvents: events,
      );

      final highlightedAnchors =
          InvestigationCanvasSyncEngine.highlightedTimelineAnchorIds(
            state: canvas.state,
            groupNodes: controller.connectionGroupNodes,
            notes: controller.sortedReflections,
            items: controller.state.items,
            groups: controller.state.relationshipGroups,
            timelineNodes: controller.anchoredTimeline,
            narrativeEvents: events,
          );

      expect(
        highlightedAnchors,
        contains(events.first.event.timelineAnchorEvidenceId),
      );
    });
  });

  group('InvestigationCanvasSyncEngine', () {
    test('selecting timeline anchor highlights its relationship group', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
        ),
      );
      controller.commitRelationshipGroup(evidenceIds: ['photo', 'video']);

      final canvas = InvestigationCanvasController();
      final narrativeEvents = controller.narrativeEvents;
      canvas.selectTimelineAnchor(
        anchorId: 'photo',
        groups: controller.state.relationshipGroups,
        notes: controller.sortedReflections,
        items: controller.state.items,
        timelineNodes: controller.anchoredTimeline,
        narrativeEvents: narrativeEvents,
      );

      final highlightedGroups =
          InvestigationCanvasSyncEngine.highlightedRelationshipGroupIds(
            state: canvas.state,
            groups: controller.state.relationshipGroups,
            groupNodes: controller.connectionGroupNodes,
            notes: controller.sortedReflections,
            items: controller.state.items,
            timelineNodes: controller.anchoredTimeline,
            narrativeEvents: narrativeEvents,
          );

      expect(highlightedGroups, hasLength(1));
    });
  });

  group('InvestigationWorkspaceScreen', () {
    testWidgets(
      'renders shared investigation header and reconstruction workspace',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final controller = WorkspaceEvidenceController(
          initialState: WorkspaceEvidenceState(
            items: [
              _item(id: 'photo'),
              _item(id: 'video'),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: InvestigationWorkspaceScreen(
              controller: controller,
              onOpenFullEvidenceRecord: (_) async {},
              initialTab: InvestigationWorkspaceTab.reconstruction,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InvestigationHeader), findsOneWidget);
        expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
        expect(find.byType(ReconstructionWorkspace), findsOneWidget);
        expect(find.byType(ReconstructionStoryCanvas), findsOneWidget);
        expect(find.byType(StructuredNarrativeBuilder), findsNothing);
        expect(find.text('Event 1'), findsNothing);
        expect(controller.narrativeEvents, hasLength(2));
        expect(
          find.byKey(ReconstructionWorkspace.nodeKey('photo')),
          findsOneWidget,
        );
        expect(
          find.byKey(ReconstructionWorkspace.nodeKey('video')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.place_rounded), findsWidgets);
        expect(find.text('People'), findsNothing);
        expect(find.text('Participants'), findsNothing);
        expect(find.text('Incident Status'), findsOneWidget);
        expect(find.text('Untitled Incident'), findsOneWidget);
        expect(find.text('Tap to rename incident'), findsOneWidget);
        expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
        expect(find.textContaining('Reconstruction Health'), findsOneWidget);
      },
    );

    testWidgets('tab switch preserves shared canvas state', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final canvasController = InvestigationCanvasController();
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InvestigationWorkspaceScreen(
            controller: controller,
            canvasController: canvasController,
            onOpenFullEvidenceRecord: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      canvasController.selectTimelineAnchor(
        anchorId: 'photo',
        groups: controller.state.relationshipGroups,
        notes: controller.sortedReflections,
        items: controller.state.items,
        timelineNodes: controller.anchoredTimeline,
        narrativeEvents: controller.narrativeEvents,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connections'));
      await tester.pumpAndSettle();

      expect(
        canvasController.state.activeTab,
        InvestigationWorkspaceTab.connections,
      );
      expect(canvasController.state.selectedTimelineAnchorId, 'photo');
    });

    testWidgets('opens on requested initial tab from navigation', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InvestigationWorkspaceScreen(
            controller: controller,
            onOpenFullEvidenceRecord: (_) async {},
            initialTab: InvestigationWorkspaceTab.connections,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Investigation Workspace'), findsOneWidget);
      expect(find.byType(StructuredNarrativeBuilder), findsNothing);
    });
  });
}
