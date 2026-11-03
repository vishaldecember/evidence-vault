import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/investigation/connection_trace.dart';
import 'package:evidence_vault/domain/participant/evidence_person_relationship.dart';
import 'package:evidence_vault/domain/participant/related_person_link.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/timeline_workspace_filter.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/services/investigation/connection_trace_engine.dart';
import 'package:evidence_vault/services/investigation/spatial_graph_layout.dart';
import 'package:evidence_vault/services/investigation/user_connection_overlay_store.dart';
import 'package:evidence_vault/services/relationship/relationship_engine.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:evidence_vault/widgets/investigation/connections_workspace.dart';
import 'package:evidence_vault/widgets/investigation/investigation_graph_workspace.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:evidence_vault/widgets/timeline/timeline_anchor_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  DateTime? lastPreservedAt,
  String incidentId = 'inc-A',
  String title = '',
  String? parentEvidenceId,
  String? relatedPersonName,
  String? relatedPersonRole,
  List<RelatedPersonLink> relatedPeople = const [],
  bool isContextual = false,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: title.isEmpty ? 'Evidence $id' : title,
    lastPreservedAt: lastPreservedAt ?? DateTime(2026, 8, 14, 10, 42),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
    parentEvidenceId: parentEvidenceId,
    relatedPersonName: relatedPersonName,
    relatedPersonRole: relatedPersonRole,
    relatedPeople: relatedPeople,
    isContextual: isContextual,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserConnectionOverlayStore.instance.resetForTests();
    WorkspaceSession.instance.reset();
  });

  group('Investigate timeline filters', () {
    test('exposes file, note, voice, and witness-related evidence', () {
      final controller = WorkspaceEvidenceController();
      final photoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final videoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      final voiceId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.voice,
      );
      final fileId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.file,
      );
      final noteId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.note,
      );
      controller.addRelatedPersonToEvidence(
        evidenceId: photoId,
        displayName: 'Jacob',
        relationship: EvidencePersonRelationship.witness,
      );

      final tree = controller.anchoredTimeline;
      expect(
        tree.map((node) => node.capturedItem.id),
        containsAll([photoId, videoId, voiceId, fileId, noteId]),
      );

      final documents = TimelineWorkspaceFilter.apply(
        filter: TimelineWorkspaceFilter.documents,
        nodes: tree,
      );
      expect(documents.any((node) => node.capturedItem.id == fileId), isTrue);

      final notes = TimelineWorkspaceFilter.apply(
        filter: TimelineWorkspaceFilter.notes,
        nodes: tree,
      );
      expect(notes.any((node) => node.capturedItem.id == noteId), isTrue);

      final witness = TimelineWorkspaceFilter.apply(
        filter: TimelineWorkspaceFilter.witness,
        nodes: tree,
      );
      expect(witness.any((node) => node.capturedItem.id == photoId), isTrue);
    });

    testWidgets(
      'Investigate Documents, Notes, and Witness chips show matches',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final controller = WorkspaceEvidenceController();
        controller.preserveEvidence(WorkspaceCaptureMode.photo);
        controller.preserveEvidence(WorkspaceCaptureMode.file);
        controller.preserveEvidence(WorkspaceCaptureMode.note);
        controller.addRelatedPersonToEvidence(
          evidenceId: controller.journeyEvidenceItems
              .firstWhere((item) => item.kind == WorkspaceEvidenceKind.image)
              .id,
          displayName: 'Jacob',
          relationship: EvidencePersonRelationship.witness,
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

        expect(find.text('Investigation Workspace'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(InvestigationWorkspaceTabBar),
            matching: find.text('Timeline'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Documents'));
        await tester.tap(find.text('Documents'));
        await tester.pumpAndSettle();
        expect(find.byType(TimelineAnchorEntry), findsOneWidget);

        await tester.tap(find.text('Notes'));
        await tester.pumpAndSettle();
        expect(find.byType(TimelineAnchorEntry), findsOneWidget);

        await tester.tap(find.text('Witness'));
        await tester.pumpAndSettle();
        expect(find.byType(TimelineAnchorEntry), findsOneWidget);
      },
    );
  });

  group('Spatial graph', () {
    test(
      'lays out a fixed vertical spine with left location and right people',
      () {
        final photo = _item(
          id: 'moment-a',
          lastPreservedAt: DateTime(2026, 8, 14, 10),
          relatedPeople: const [
            RelatedPersonLink(
              participantId: 'p-jacob',
              displayName: 'Jacob',
              roleName: 'witness',
            ),
          ],
        );
        final video = _item(
          id: 'moment-b',
          kind: WorkspaceEvidenceKind.video,
          lastPreservedAt: DateTime(2026, 8, 14, 10, 20),
        );
        final note = _item(
          id: 'ctx-note',
          kind: WorkspaceEvidenceKind.note,
          parentEvidenceId: 'moment-a',
          isContextual: true,
          lastPreservedAt: DateTime(2026, 8, 14, 10, 5),
        );
        final graph = InvestigationGraphView(
          primaryEvidenceIds: const ['moment-a', 'moment-b'],
          supportingByPrimaryId: const {
            'moment-a': ['ctx-note'],
          },
          edges: const [
            InvestigationGraphEdge(
              id: 'e1',
              sourceEvidenceId: 'moment-a',
              targetEvidenceId: 'moment-b',
              kind: InvestigationGraphEdgeKind.related,
            ),
          ],
          collections: [
            EvidenceCollection(
              id: 'loc-1',
              incidentId: 'inc-A',
              name: 'Lobby',
              category: 'location',
              systemGenerated: true,
              displayOrder: 0,
              createdAt: DateTime(2026, 8, 14),
              updatedAt: DateTime(2026, 8, 14),
              memberEvidenceIds: const ['moment-b'],
            ),
          ],
          evidenceById: {photo.id: photo, video.id: video, note.id: note},
        );

        final layout = SpatialGraphLayout.fromGraph(graph);
        final momentA = layout.nodeById('moment-a')!;
        final momentB = layout.nodeById('moment-b')!;
        expect(momentA.kind, SpatialGraphNodeKind.moment);
        expect(momentB.kind, SpatialGraphNodeKind.moment);
        expect(momentA.position.dx, layout.axisX);
        expect(momentB.position.dx, layout.axisX);
        expect(momentB.position.dy, greaterThan(momentA.position.dy));
        expect(layout.axisX, greaterThan(40));

        final people = layout.nodes
            .where((node) => node.kind == SpatialGraphNodeKind.person)
            .toList();
        expect(people, isNotEmpty);
        expect(people.first.position.dx, greaterThan(layout.axisX));

        final locations = layout.nodes
            .where((node) => node.kind == SpatialGraphNodeKind.location)
            .toList();
        expect(locations, isNotEmpty);
        expect(locations.first.position.dx, lessThan(layout.axisX));
        expect(
          layout.axisX - locations.first.position.dx,
          SpatialGraphLayout.locationInset,
        );
        expect(
          layout.nodes.where(
            (node) => node.kind == SpatialGraphNodeKind.context,
          ),
          isNotEmpty,
        );
        expect(layout.gaps, isEmpty);
        expect(layout.edges, isNotEmpty);
      },
    );

    testWidgets('renders nodes and edges without an evidence card gallery', (
      tester,
    ) async {
      final photo = _item(id: 'moment-a');
      final graph = InvestigationGraphView(
        primaryEvidenceIds: const ['moment-a'],
        supportingByPrimaryId: const {},
        edges: const [],
        collections: const [],
        evidenceById: {photo.id: photo},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationGraphWorkspace(
              graph: graph,
              onEvidenceTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(InvestigationGraphWorkspace.nodeKey('moment-a')),
        findsOneWidget,
      );
      expect(find.byKey(InvestigationGraphWorkspace.spineKey), findsOneWidget);
      expect(find.byKey(InvestigationGraphWorkspace.edgesKey), findsOneWidget);
      expect(find.byType(JourneyEvidenceThumbnail), findsNothing);
      expect(find.text('Make Primary'), findsNothing);
    });

    testWidgets('Connections uses evidence icons, not thumbnails or a spine', (
      tester,
    ) async {
      final photo = _item(id: 'photo');
      final clip = _item(
        id: 'clip',
        kind: WorkspaceEvidenceKind.video,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 50),
      );
      final photoNote = _item(
        id: 'photo-note',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
        isContextual: true,
      );
      final clipNote = _item(
        id: 'clip-note',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'clip',
        isContextual: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionsWorkspace(
              incidentId: 'inc-A',
              evidence: [photo, clip, photoNote, clipNote],
              collections: const [],
              relationships: [
                EvidenceRelationship(
                  id: 'rel-1',
                  sourceEvidenceId: 'photo',
                  targetEvidenceId: 'clip',
                  type: RelationshipType.relatedTo,
                  createdAt: DateTime(2026, 8, 14),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JourneyEvidenceThumbnail), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byType(ConnectionsWorkspace), findsOneWidget);
      expect(find.byKey(InvestigationGraphWorkspace.spineKey), findsNothing);
    });
  });

  group('Connections overlay', () {
    test('system snapshot uses real people and relationships only', () {
      final photo = _item(id: 'photo');
      final note = _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
        isContextual: true,
      );
      final witnessed = _item(
        id: 'clip',
        kind: WorkspaceEvidenceKind.video,
        relatedPeople: const [
          RelatedPersonLink(
            participantId: 'p-jacob',
            displayName: 'Jacob',
            roleName: 'witness',
          ),
        ],
      );
      final snapshot = ConnectionTraceEngine.systemSnapshot(
        evidence: [photo, note, witnessed],
        relationships: [
          EvidenceRelationship(
            id: 'rel-1',
            sourceEvidenceId: 'photo',
            targetEvidenceId: 'clip',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
          ),
        ],
        collections: [
          EvidenceCollection(
            id: 'loc-1',
            incidentId: 'inc-A',
            name: 'Lobby',
            category: 'location',
            systemGenerated: true,
            displayOrder: 0,
            createdAt: DateTime(2026, 8, 14),
            updatedAt: DateTime(2026, 8, 14),
            memberEvidenceIds: const ['photo'],
          ),
        ],
      );

      expect(snapshot.nodes.where((node) => node.id == 'photo'), isNotEmpty);
      expect(
        snapshot.nodes.where((node) => node.kind == ConnectionTraceKind.person),
        isNotEmpty,
      );
      expect(
        snapshot.links.any(
          (link) => link.fromId == 'photo' && link.toId == 'note',
        ),
        isTrue,
      );
      expect(
        snapshot.links.any(
          (link) => link.fromId == 'photo' && link.toId == 'clip',
        ),
        isTrue,
      );
      expect(
        snapshot.links.any(
          (link) => link.fromId == 'photo' && link.toId == 'loc-1',
        ),
        isTrue,
      );
      final evidenceNodes = [
        for (final node in snapshot.nodes)
          if (node.evidenceId != null) node,
      ];
      expect(evidenceNodes, hasLength(3));
      expect(
        evidenceNodes.map((node) => node.position.dy).toSet().length,
        greaterThan(1),
      );
    });

    test(
      'My Connections persist independently of evidence and groups',
      () async {
        final controller = WorkspaceEvidenceController();
        final photoId = controller.preserveEvidenceAndReturnId(
          WorkspaceCaptureMode.photo,
        );
        final videoId = controller.preserveEvidenceAndReturnId(
          WorkspaceCaptureMode.video,
        );
        controller.commitRelationshipGroup(evidenceIds: [photoId, videoId]);
        final groupBefore = controller.state.relationshipGroups.single;
        final idsBefore = controller.journeyEvidenceItems
            .map((item) => item.id)
            .toList();
        final timesBefore = controller.journeyEvidenceItems
            .map((item) => item.lastPreservedAt)
            .toList();

        final system = ConnectionTraceEngine.systemSnapshot(
          evidence: controller.state.items
              .where(
                (item) => item.belongsToIncident(controller.currentIncident.id),
              )
              .toList(),
          relationships: controller.state.relationships,
        );
        final mine = UserConnectionOverlayStore.instance
            .cloneSystem(system)
            .copyWith(
              links: [
                const ConnectionTraceLink(
                  fromId: 'moved-from',
                  toId: 'moved-to',
                ),
              ],
            );
        await UserConnectionOverlayStore.instance.save(
          incidentId: controller.currentIncident.id,
          snapshot: mine,
        );

        expect(
          UserConnectionOverlayStore.instance
              .snapshotFor(controller.currentIncident.id)!
              .links
              .single
              .fromId,
          'moved-from',
        );
        expect(
          ConnectionTraceEngine.systemSnapshot(
            evidence: controller.state.items
                .where(
                  (item) =>
                      item.belongsToIncident(controller.currentIncident.id),
                )
                .toList(),
            relationships: controller.state.relationships,
          ).links.any((link) => link.fromId == 'moved-from'),
          isFalse,
        );
        expect(controller.state.relationshipGroups.single.id, groupBefore.id);
        expect(
          controller.state.relationshipGroups.single.memberEvidenceIds,
          groupBefore.memberEvidenceIds,
        );
        expect(
          controller.journeyEvidenceItems.map((item) => item.id),
          idsBefore,
        );
        expect(
          controller.journeyEvidenceItems.map((item) => item.lastPreservedAt),
          timesBefore,
        );
      },
    );

    test('spatial layout keeps nodes and edges clear of each other', () {
      final photo = _item(id: 'photo');
      final note = _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
        isContextual: true,
      );
      final clip = _item(
        id: 'clip',
        kind: WorkspaceEvidenceKind.video,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 50),
      );
      final extra = _item(
        id: 'extra',
        kind: WorkspaceEvidenceKind.voice,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 55),
      );
      final snapshot = ConnectionTraceEngine.systemSnapshot(
        evidence: [photo, note, clip, extra],
        relationships: [
          EvidenceRelationship(
            id: 'rel-1',
            sourceEvidenceId: 'photo',
            targetEvidenceId: 'clip',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
          ),
          EvidenceRelationship(
            id: 'rel-2',
            sourceEvidenceId: 'clip',
            targetEvidenceId: 'extra',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
          ),
        ],
      );

      expect(ConnectionTraceEngine.markSize, closeTo(28 * 1.1, 0.6));
      ConnectionTraceNode byId(String id) =>
          snapshot.nodes.firstWhere((node) => node.id == id);

      for (var i = 0; i < snapshot.nodes.length; i++) {
        for (var j = i + 1; j < snapshot.nodes.length; j++) {
          expect(
            ConnectionTraceEngine.nodesOverlap(
              snapshot.nodes[i].position,
              snapshot.nodes[j].position,
            ),
            isFalse,
          );
        }
      }

      for (final link in snapshot.links) {
        final from = byId(link.fromId);
        final to = byId(link.toId);
        final start = ConnectionTraceEngine.pointOnCircumference(
          from.position,
          to.position,
        );
        final end = ConnectionTraceEngine.pointOnCircumference(
          to.position,
          from.position,
        );
        expect(
          (start - from.position).distance,
          closeTo(ConnectionTraceEngine.visualRadius, 0.01),
        );
        expect(
          (end - to.position).distance,
          closeTo(ConnectionTraceEngine.visualRadius, 0.01),
        );
        for (final node in snapshot.nodes) {
          if (node.id == from.id || node.id == to.id) {
            continue;
          }
          expect(
            ConnectionTraceEngine.edgeHitsNode(
              from: from.position,
              to: to.position,
              other: node.position,
            ),
            isFalse,
          );
        }
      }
    });

    testWidgets('Connections is a single system map without My Connections', (
      tester,
    ) async {
      final photo = _item(id: 'photo');
      final clip = _item(
        id: 'clip',
        kind: WorkspaceEvidenceKind.video,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 50),
      );
      final photoNote = _item(
        id: 'photo-note',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
        isContextual: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionsWorkspace(
              incidentId: 'inc-A',
              evidence: [photo, clip, photoNote],
              collections: const [],
              relationships: [
                EvidenceRelationship(
                  id: 'rel-1',
                  sourceEvidenceId: 'photo',
                  targetEvidenceId: 'clip',
                  type: RelationshipType.relatedTo,
                  createdAt: DateTime(2026, 8, 14),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Connections'), findsNothing);
      expect(find.text('System Generated'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
      expect(find.byType(JourneyEvidenceThumbnail), findsNothing);
    });

    test('system and investigator traces keep distinct connection colors', () {

      final photo = _item(id: 'photo');
      final note = _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
        isContextual: true,
      );
      final clip = _item(
        id: 'clip',
        kind: WorkspaceEvidenceKind.video,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 50),
      );
      final snapshot = ConnectionTraceEngine.systemSnapshot(
        evidence: [photo, note, clip],
        relationships: [
          EvidenceRelationship(
            id: 'rel-user',
            sourceEvidenceId: 'photo',
            targetEvidenceId: 'clip',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
            source: 'user',
          ),
          EvidenceRelationship(
            id: 'rel-meta',
            sourceEvidenceId: 'note',
            targetEvidenceId: 'clip',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
            source: 'metadata',
            reason: 'Related because capture times are close.',
          ),
        ],
      );
      expect(
        snapshot.links.any(
          (link) =>
              link.fromId == 'photo' &&
              link.toId == 'note' &&
              link.origin == ConnectionTraceOrigin.systemGenerated,
        ),
        isTrue,
      );
      expect(
        snapshot.links.any(
          (link) =>
              ((link.fromId == 'photo' && link.toId == 'clip') ||
                  (link.fromId == 'clip' && link.toId == 'photo')) &&
              link.origin == ConnectionTraceOrigin.user,
        ),
        isTrue,
      );
      expect(
        snapshot.links.any(
          (link) =>
              ((link.fromId == 'note' && link.toId == 'clip') ||
                  (link.fromId == 'clip' && link.toId == 'note')) &&
              link.origin == ConnectionTraceOrigin.systemGenerated,
        ),
        isTrue,
      );

      final merged = ConnectionTraceEngine.mergeUserOverlay(
        system: snapshot,
        mine: ConnectionTraceSnapshot(
          nodes: snapshot.nodes,
          links: const [
            ConnectionTraceLink(fromId: 'note', toId: 'photo'),
          ],
        ),
      );
      expect(
        merged.links.any((link) => link.origin == ConnectionTraceOrigin.user),
        isTrue,
      );
    });
  });
}




