import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/workspace/continue_capturing_section.dart';
import 'package:evidence_vault/widgets/workspace/connect_evidence_action.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
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

Future<void> _pumpEvidenceStage(
  WidgetTester tester,
  WorkspaceEvidenceController controller,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(412, 915));
  WorkspaceSession.instance.controller = controller;
  await tester.pumpWidget(
    MaterialApp(
      home: IncidentWorkspaceShell(
        controller: controller,
        initialStage: InvestigationMethodologyStage.evidence,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => WorkspaceSession.instance.reset());

  group('ConnectEvidencesPill visibility', () {
    testWidgets('hidden when fewer than two journey evidence items', (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo')],
        ),
      );

      await _pumpEvidenceStage(tester, controller);

      expect(find.byType(ConnectEvidencesPill), findsNothing);
      expect(find.text('Connect'), findsNothing);
    });

    testWidgets('visible when at least two journey evidence items', (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );

      await _pumpEvidenceStage(tester, controller);

      // Organize uses Groups+, not the leftover Connect pill.
      expect(find.byType(ConnectEvidencesPill), findsNothing);
      expect(find.text('Connect'), findsNothing);
      expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
    });
  });

  group('Connect Mode interaction', () {
    testWidgets('activates Connect Mode and shows Done label', (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );

      await _pumpEvidenceStage(tester, controller);

      expect(find.byType(ConnectEvidencesPill), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
    });

    testWidgets('selects multiple evidence before commit', (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
            _item(id: 'note', kind: WorkspaceEvidenceKind.note),
          ],
        ),
      );

      await _pumpEvidenceStage(tester, controller);

      expect(find.byType(ConnectEvidencesPill), findsNothing);
      expect(controller.state.relationshipGroups, isEmpty);
    });

    testWidgets('Done commits one relationship group', (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );

      await _pumpEvidenceStage(tester, controller);
      expect(find.byType(ConnectEvidencesPill), findsNothing);

      final group = controller.commitRelationshipGroup(
        evidenceIds: ['photo', 'video'],
      );
      expect(group, isNotNull);
      expect(controller.state.relationshipGroups, hasLength(1));
    });

    testWidgets('Cancel exits Connect Mode without commit', (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );

      await _pumpEvidenceStage(tester, controller);

      expect(find.byType(ConnectEvidencesPill), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(controller.state.relationshipGroups, isEmpty);
    });

    testWidgets('capture stage does not expose Connect action', (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            controller: controller,
            initialStage: InvestigationMethodologyStage.capture,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Capture what happened clearly'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ContinueCapturingSection),
          matching: find.byType(ConnectEvidencesPill),
        ),
        findsNothing,
      );
    });

    testWidgets('second Connect session uses next colour index', (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video'),
            _item(id: 'note', kind: WorkspaceEvidenceKind.note),
          ],
        ),
      );

      await _pumpEvidenceStage(tester, controller);
      expect(find.byType(ConnectEvidencesPill), findsNothing);

      final first = controller.commitRelationshipGroup(
        evidenceIds: ['photo', 'video'],
      );
      final second = controller.commitRelationshipGroup(
        evidenceIds: ['photo', 'note'],
      );

      expect(controller.state.relationshipGroups, hasLength(2));
      expect(first?.colorIndex, 0);
      expect(second?.colorIndex, 1);
      expect(controller.state.relationshipGroups.first.colorIndex, 0);
      expect(controller.state.relationshipGroups.last.colorIndex, 1);
    });
  });
}
