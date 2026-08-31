import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/workspace/relationship_group_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

void main() {
  group('RelationshipGroupSummary', () {
    test('groupCountLabel pluralizes correctly', () {
      expect(RelationshipGroupSummary.groupCountLabel(1), '1 Group Created');
      expect(RelationshipGroupSummary.groupCountLabel(3), '3 Groups Created');
      expect(RelationshipGroupSummary.groupCountLabel(5), '5 Groups Created');
    });

    testWidgets('hidden when no relationship groups exist', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationshipGroupSummary(relationshipGroups: const []),
          ),
        ),
      );

      expect(find.text('Relationship Groups'), findsNothing);
    });

    testWidgets('shows count, chips, and View Connections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationshipGroupSummary(
              relationshipGroups: controller.state.relationshipGroups,
            ),
          ),
        ),
      );

      expect(find.text('Relationship Groups'), findsOneWidget);
      expect(find.text('2 Groups Created'), findsOneWidget);
      expect(find.text('Connections →'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('View Connections invokes placeholder action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var viewConnectionsTapped = false;
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );
      controller.commitRelationshipGroup(evidenceIds: ['photo', 'video']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationshipGroupSummary(
              relationshipGroups: controller.state.relationshipGroups,
              onViewConnections: () => viewConnectionsTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Connections →'));
      await tester.pump();

      expect(viewConnectionsTapped, isTrue);
    });
  });

  group('Workspace integration (8.5.20.3)', () {
    testWidgets('summary appears below Incident Status label', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );
      controller.commitRelationshipGroup(evidenceIds: ['photo', 'video']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Incident Status'),
                RelationshipGroupSummary(
                  relationshipGroups: controller.state.relationshipGroups,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Incident Status'), findsOneWidget);
      expect(find.text('Relationship Groups'), findsOneWidget);
      expect(find.text('1 Group Created'), findsOneWidget);

      final statusY = tester.getTopLeft(find.text('Incident Status')).dy;
      final summaryY = tester.getTopLeft(find.text('Relationship Groups')).dy;
      expect(summaryY, greaterThan(statusY));
    });

    testWidgets('summary updates when additional groups are committed',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationshipGroupSummary(
              relationshipGroups: controller.state.relationshipGroups,
            ),
          ),
        ),
      );
      expect(find.text('1 Group Created'), findsOneWidget);

      controller.commitRelationshipGroup(evidenceIds: ['c', 'd']);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationshipGroupSummary(
              relationshipGroups: controller.state.relationshipGroups,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 Groups Created'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byType(RelationshipGroupSummary),
          matching: find.bySemanticsLabel('Group 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(RelationshipGroupSummary),
          matching: find.bySemanticsLabel('Group 2'),
        ),
        findsOneWidget,
      );
    });
  });
}
