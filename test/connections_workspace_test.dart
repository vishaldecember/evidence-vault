import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/screens/investigation_workspace_screen.dart';
import 'package:evidence_vault/services/investigation/user_connection_overlay_store.dart';
import 'package:evidence_vault/services/relationship_group_color_service.dart';
import 'package:evidence_vault/widgets/connections/connection_group_panel.dart';
import 'package:evidence_vault/widgets/investigation/connections_tree_view.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
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
  group('RelationshipRepository organize actions', () {
    test('moveSupportingToGroup moves note between groups', () {
      final controller = WorkspaceEvidenceController();
      final photoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final videoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      controller.addContextTextNote(
        parentEvidenceId: photoId,
        text: 'Photo context',
      );
      controller.addContextTextNote(
        parentEvidenceId: videoId,
        text: 'Video context',
      );

      final photoNoteId = controller.state.items
          .firstWhere(
            (item) =>
                item.kind == WorkspaceEvidenceKind.note &&
                item.relatedEvidenceIds.contains(photoId),
          )
          .id;
      final videoNoteId = controller.state.items
          .firstWhere(
            (item) =>
                item.kind == WorkspaceEvidenceKind.note &&
                item.relatedEvidenceIds.contains(videoId),
          )
          .id;

      controller.commitRelationshipGroup(evidenceIds: [photoId, photoNoteId]);
      controller.commitRelationshipGroup(evidenceIds: [videoId, videoNoteId]);

      final sourceGroup = controller.state.relationshipGroups.first;
      final targetGroup = controller.state.relationshipGroups.last;

      controller.moveSupportingToGroup(
        supportingEvidenceId: photoNoteId,
        targetGroupId: targetGroup.id,
      );

      final updatedTarget = controller.state.relationshipGroups.firstWhere(
        (group) => group.id == targetGroup.id,
      );
      final updatedSource = controller.state.relationshipGroups.firstWhere(
        (group) => group.id == sourceGroup.id,
      );

      expect(updatedTarget.memberEvidenceIds, contains(photoNoteId));
      expect(updatedSource.memberEvidenceIds, isNot(contains(photoNoteId)));
    });

    test('mergeGroups combines members and preserves target colour', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'a'),
            _item(id: 'b'),
            _item(id: 'c'),
            _item(id: 'd'),
          ],
        ),
      );

      controller.commitRelationshipGroup(evidenceIds: ['a', 'b']);
      controller.commitRelationshipGroup(evidenceIds: ['c', 'd']);

      final target = controller.state.relationshipGroups.first;
      final source = controller.state.relationshipGroups.last;
      final targetColor = target.colorIndex;

      controller.mergeRelationshipGroups(
        sourceGroupId: source.id,
        targetGroupId: target.id,
      );

      expect(controller.state.relationshipGroups, hasLength(1));
      expect(controller.state.relationshipGroups.first.colorIndex, targetColor);
      expect(
        controller.state.relationshipGroups.first.memberEvidenceIds,
        hasLength(4),
      );
    });

    test('updateGroupInvestigation persists name and description', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'a'),
            _item(id: 'b'),
          ],
        ),
      );

      controller.commitRelationshipGroup(evidenceIds: ['a', 'b']);
      final group = controller.state.relationshipGroups.single;

      controller.updateRelationshipGroupInvestigation(
        groupId: group.id,
        displayName: '  Entrance Sequence  ',
        description:
            '  Evidence collected between arrival at the premises and entry into the building.  ',
      );

      final updated = controller.state.relationshipGroups.single;
      expect(updated.displayName, 'Entrance Sequence');
      expect(
        updated.description,
        'Evidence collected between arrival at the premises and entry into the building.',
      );
      expect(
        RelationshipGroupColorService.displayName(
          updated,
          controller.state.relationshipGroups,
        ),
        'Entrance Sequence',
      );

      controller.updateRelationshipGroupInvestigation(
        groupId: group.id,
        displayName: '   ',
        description: '   ',
      );

      expect(controller.state.relationshipGroups.single.displayName, isNull);
      expect(controller.state.relationshipGroups.single.description, isNull);
      expect(
        RelationshipGroupColorService.displayName(
          controller.state.relationshipGroups.single,
          controller.state.relationshipGroups,
        ),
        'Group 1',
      );
    });
  });

  group('Investigation Connections workspace', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      UserConnectionOverlayStore.instance.resetForTests();
      WorkspaceSession.instance.reset();
    });

    testWidgets('opens Connections from Investigation tab', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.commitRelationshipGroup(
        evidenceIds: controller.journeyEvidenceItems.map((e) => e.id).toList(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            controller: controller,
            initialStage: InvestigationMethodologyStage.investigation,
            initialInvestigationTab: InvestigationWorkspaceTab.connections,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationWorkspaceScreen), findsOneWidget);
      expect(find.text('Investigation Workspace'), findsOneWidget);
      expect(find.byType(ConnectionsTreeView), findsOneWidget);
      expect(find.text('My Connections'), findsNothing);
      expect(find.byType(ConnectionGroupPanel), findsNothing);
    });

    testWidgets('Organize mode exposes Groups+ without Create Group text', (
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
      controller.commitRelationshipGroup(evidenceIds: ['photo', 'video']);

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            controller: controller,
            initialStage: InvestigationMethodologyStage.evidence,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
      expect(find.text('Create Group'), findsNothing);
      expect(find.byKey(const Key('organize_create_group')), findsNothing);
    });

    testWidgets('Connections map stays independent of Groups', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.commitRelationshipGroup(
        evidenceIds: controller.journeyEvidenceItems.map((e) => e.id).toList(),
      );
      final groupId = controller.state.relationshipGroups.single.id;
      final groupMembers = [
        ...controller.state.relationshipGroups.single.memberEvidenceIds,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            controller: controller,
            initialStage: InvestigationMethodologyStage.investigation,
            initialInvestigationTab: InvestigationWorkspaceTab.connections,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionsTreeView), findsOneWidget);
      expect(find.text('My Connections'), findsNothing);
      expect(controller.state.relationshipGroups.single.id, groupId);
      expect(
        controller.state.relationshipGroups.single.memberEvidenceIds,
        groupMembers,
      );
    });
  });
}
