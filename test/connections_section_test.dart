import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_group.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/evidence_workspace_screen.dart';
import 'package:evidence_vault/services/relationship_group_color_service.dart';
import 'package:evidence_vault/widgets/connections/connections_section.dart';
import 'package:evidence_vault/widgets/connections/relationship_group_card.dart';
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

RelationshipGroup _group({
  required String id,
  required List<String> evidenceIds,
  int colorIndex = 0,
  DateTime? createdAt,
}) {
  return RelationshipGroup(
    id: id,
    evidenceIds: evidenceIds,
    type: RelationshipType.relatedTo,
    createdAt: createdAt ?? DateTime(2026, 7, 28, 12),
    colorIndex: colorIndex,
  );
}

void main() {
  testWidgets('Connections section shows empty state without groups',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionsSection(
            relationshipGroups: const [],
            evidence: [_item(id: 'photo')],
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Connections'), findsOneWidget);
    expect(find.textContaining('Connections Workspace'), findsOneWidget);
    expect(find.byType(RelationshipGroupCard), findsNothing);
  });

  testWidgets('Connections section renders one card per relationship group',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionsSection(
            relationshipGroups: [
              _group(id: 'g1', evidenceIds: ['photo', 'video'], colorIndex: 0),
              _group(
                id: 'g2',
                evidenceIds: ['note', 'voice'],
                colorIndex: 1,
                createdAt: DateTime(2026, 7, 29),
              ),
            ],
            evidence: [
              _item(id: 'photo'),
              _item(id: 'video', kind: WorkspaceEvidenceKind.video),
              _item(id: 'note', kind: WorkspaceEvidenceKind.note),
              _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
            ],
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(RelationshipGroupCard), findsNWidgets(2));
    expect(find.text('Group 1'), findsOneWidget);
    expect(find.text('Group 2'), findsOneWidget);
    expect(find.text('Photo'), findsWidgets);
    expect(find.text('Video'), findsWidgets);
  });

  testWidgets('group header expands and collapses', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionsSection(
            relationshipGroups: [
              _group(id: 'g1', evidenceIds: ['photo', 'video']),
            ],
            evidence: [
              _item(id: 'photo'),
              _item(id: 'video', kind: WorkspaceEvidenceKind.video),
            ],
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Video'), findsOneWidget);

    await tester.tap(find.text('Group 1'));
    await tester.pumpAndSettle();

    expect(find.text('Video'), findsNothing);

    await tester.tap(find.text('Group 1'));
    await tester.pumpAndSettle();

    expect(find.text('Video'), findsOneWidget);
  });

  testWidgets('future edit actions menu is scaffolded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionsSection(
            relationshipGroups: [
              _group(id: 'g1', evidenceIds: ['photo', 'video']),
            ],
            evidence: [
              _item(id: 'photo'),
              _item(id: 'video', kind: WorkspaceEvidenceKind.video),
            ],
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Rename Group'), findsOneWidget);
    expect(find.text('Delete Group'), findsOneWidget);
    expect(find.text('Edit Group'), findsOneWidget);
  });

  testWidgets('committed groups persist in controller but not workspace UI',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(
        items: [_item(id: 'photo'), _item(id: 'video')],
      ),
    );

    controller.commitRelationshipGroup(
      evidenceIds: ['photo', 'video'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceWorkspaceScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.state.relationshipGroups, hasLength(1));
    expect(find.text('Connections'), findsNothing);
    expect(find.byType(RelationshipGroupCard), findsNothing);
  });

  test('RelationshipGroupColorService uses persisted colorIndex', () {
    final groups = [
      _group(id: 'a', evidenceIds: ['1', '2'], colorIndex: 0),
      _group(
        id: 'b',
        evidenceIds: ['3', '4'],
        colorIndex: 1,
        createdAt: DateTime(2026, 8, 1),
      ),
    ];

    expect(
      RelationshipGroupColorService.colorForGroup(groups[0]),
      RelationshipGroupColorService.colorForIndex(0),
    );
    expect(
      RelationshipGroupColorService.colorForGroup(groups[1]),
      RelationshipGroupColorService.colorForIndex(1),
    );
  });
}
