import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/investigation/investigation_header.dart';
import 'package:evidence_vault/widgets/workspace/incident_identity_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({required String id}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

void main() {
  setUp(() => WorkspaceSession.instance.reset());

  group('CurrentIncident single source of truth', () {
    test('controller projects shared CurrentIncident from repository', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Original',
          items: [_item(id: 'photo')],
        ),
      );

      expect(controller.currentIncident.title, 'Original');
      expect(
        identical(
          controller.currentIncident.id,
          controller.incidentRepository.currentIncident.id,
        ),
        isTrue,
      );

      controller.updateIncidentName('Renamed Case');

      expect(controller.currentIncident.title, 'Renamed Case');
      expect(
        controller.incidentRepository.currentIncident.title,
        'Renamed Case',
      );
      expect(controller.aggregate.sharedIncident.title, 'Renamed Case');
    });

    testWidgets('rename in Investigation updates Capture immediately',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: '',
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );
      WorkspaceSession.instance.controller = controller;

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            controller: controller,
            initialStage: InvestigationMethodologyStage.investigation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationHeader), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(InvestigationHeader),
          matching: find.text('Untitled Incident'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final investigationField = find.descendant(
        of: find.byType(InvestigationHeader),
        matching: find.byType(TextField),
      );
      await tester.enterText(investigationField, 'Synced Incident');
      await tester.pumpAndSettle();

      expect(controller.currentIncident.title, 'Synced Incident');

      await tester.tap(find.text('Capture'));
      await tester.pumpAndSettle();

      expect(find.text('Capture what happened clearly'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(IncidentIdentityDrawer),
          matching: find.text('Synced Incident'),
        ),
        findsWidgets,
      );

      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      expect(controller.currentIncident.title, 'Synced Incident');

      await tester.tap(find.text('Trust Package'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Synced Incident'), findsWidgets);
    });
  });
}
