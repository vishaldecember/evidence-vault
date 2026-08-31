import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/workspace/incident_journey_card.dart';
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

void main() {
  setUp(() => WorkspaceSession.instance.reset());

  group('Organize Records card', () {
    testWidgets('shows structure view instead of Capture maturity or Connect',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Street Fight',
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.voice),
          ],
        ),
      );
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

      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(find.text('Street Fight'), findsOneWidget);
      expect(find.byKey(OrganizeWorkspaceView.structureKey), findsOneWidget);
      expect(find.text('Evidence structure'), findsNothing);
      expect(find.text('Evidence Maturity'), findsNothing);
      expect(find.text('Organize Records'), findsNothing);
      expect(find.text('Connect'), findsNothing);
      expect(find.byType(IncidentJourneyCard), findsNothing);
    });

    testWidgets('capture stage keeps Evidence Maturity title', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );
      WorkspaceSession.instance.controller = controller;

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            controller: controller,
            initialStage: InvestigationMethodologyStage.capture,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Evidence Maturity'), findsOneWidget);
      expect(find.text('Captured'), findsOneWidget);
      expect(find.text('Strengthening'), findsNothing);
      expect(find.text('Investigation Ready'), findsOneWidget);
      expect(find.text('Organize Records'), findsNothing);
      expect(find.text('Suggested Collections'), findsNothing);
    });
  });
}
