import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/participant/evidence_person_relationship.dart';
import 'package:evidence_vault/domain/participant/related_person_metadata.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/services/groups/group_intelligence_engine.dart';
import 'package:evidence_vault/widgets/investigation/add_related_person_sheet.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_groups_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-v3r-intel', title: 'Case'),
  );
}

Future<void> _pumpInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required String evidenceId,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(412, 915));
  final evidence = controller.currentIncident.evidence.firstWhere(
    (item) => item.id == evidenceId,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InvestigationEvidenceInspectorModal(
          evidence: evidence,
          orderedEvidence: controller.currentIncident.evidence,
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
  });

  test('adding a second person does not replace the first', () {
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Jacob',
      relationship: EvidencePersonRelationship.witness,
    );
    controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Sarah',
      relationship: EvidencePersonRelationship.personInvolved,
    );
    controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Daniel',
      relationship: EvidencePersonRelationship.other,
    );

    final item = controller.currentIncident.evidence.singleWhere(
      (evidence) => evidence.id == photo,
    );
    expect(item.relatedPeople.map((person) => person.displayName).toList(), [
      'Jacob',
      'Sarah',
      'Daniel',
    ]);
    final captured = controller.evidenceRepository.capturedById(photo)!;
    expect(
      RelatedPersonMetadata.peopleOf(
        captured.metadata,
      ).map((person) => person.displayName).toList(),
      ['Jacob', 'Sarah', 'Daniel'],
    );
  });

  test('recognized person reuses identity when selected', () {
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final video = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final jacob = controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Jacob',
      relationship: EvidencePersonRelationship.witness,
    );
    final reused = controller.addRelatedPersonToEvidence(
      evidenceId: video,
      displayName: 'Jacob',
      relationship: EvidencePersonRelationship.witness,
      existingParticipantId: jacob.id,
    );
    expect(reused.id, jacob.id);
    expect(controller.recognizedParticipants().length, 1);
  });

  test('groups people explanations stay grounded in stored evidence', () {
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final video = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final jacob = controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Jacob',
      relationship: EvidencePersonRelationship.witness,
    );
    controller.addRelatedPersonToEvidence(
      evidenceId: video,
      displayName: 'Jacob',
      relationship: EvidencePersonRelationship.witness,
      existingParticipantId: jacob.id,
    );
    controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Sarah',
      relationship: EvidencePersonRelationship.personInvolved,
    );

    final snapshot = GroupIntelligenceEngine.derive(
      evidence: controller.currentIncident.evidence,
      collections: controller.evidenceCollections,
    );
    expect(
      snapshot.people.map((person) => person.name),
      containsAll(['Jacob', 'Sarah']),
    );
    final jacobInsight = snapshot.people.singleWhere(
      (person) => person.name == 'Jacob',
    );
    expect(jacobInsight.momentCount, 2);
    expect(jacobInsight.explanation.contains('2 preserved moments'), isTrue);
    expect(
      snapshot.relationships.any((rel) => rel.title.contains('↔')),
      isTrue,
    );

    controller.renameParticipantIdentity(
      participantId: jacob.id,
      displayName: 'Jake',
    );
    final after = GroupIntelligenceEngine.derive(
      evidence: controller.currentIncident.evidence,
      collections: controller.evidenceCollections,
    );
    expect(after.people.any((person) => person.name == 'Jake'), isTrue);
    expect(after.people.any((person) => person.name == 'Jacob'), isFalse);
  });

  testWidgets('inspector keeps three people and offers Jacob later', (
    tester,
  ) async {
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final video = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Jacob',
      relationship: EvidencePersonRelationship.witness,
    );
    controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Sarah',
      relationship: EvidencePersonRelationship.personInvolved,
    );
    controller.addRelatedPersonToEvidence(
      evidenceId: photo,
      displayName: 'Daniel',
      relationship: EvidencePersonRelationship.other,
    );

    await _pumpInspector(tester, controller: controller, evidenceId: photo);
    expect(find.text('Jacob'), findsWidgets);
    expect(find.text('Sarah'), findsWidgets);
    expect(find.text('Daniel'), findsWidgets);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    await _pumpInspector(tester, controller: controller, evidenceId: photo);
    expect(find.text('Jacob'), findsWidgets);
    expect(find.text('Sarah'), findsWidgets);
    expect(find.text('Daniel'), findsWidgets);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    await _pumpInspector(tester, controller: controller, evidenceId: video);
    await tester.ensureVisible(find.text('Add Person'));
    await tester.tap(find.text('Add Person'));
    await tester.pumpAndSettle();
    expect(find.byType(AddRelatedPersonSheet), findsOneWidget);
    expect(find.text('Jacob'), findsWidgets);
  });

  testWidgets(
    'Groups modal is a 2x2 intelligence matrix without the old form',
    (tester) async {
      final controller = _controller();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeWorkspaceView(
              incident: controller.currentIncident,
              orderedCapturedEvidenceIds: controller.timelineRepository
                  .orderedCapturedEvidenceIds(),
              onEvidenceSelected: (_) {},
              onCreateCustomGroup: ({required name, evidenceIds = const []}) {
                return controller.createCustomGroup(
                  name: name,
                  evidenceIds: evidenceIds,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(OrganizeWorkspaceView.groupsBrowseKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(OrganizeGroupsModal.matrixKey), findsOneWidget);
      expect(
        find.byKey(
          OrganizeGroupsModal.lensKey(OrganizeGroupCategory.personParticipant),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeGroupsModal.lensKey(OrganizeGroupCategory.location)),
        findsOneWidget,
      );
      expect(
        find.byKey(
          OrganizeGroupsModal.lensKey(OrganizeGroupCategory.relationship),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeGroupsModal.lensKey(OrganizeGroupCategory.pattern)),
        findsOneWidget,
      );
      expect(find.byKey(OrganizeGroupsModal.customGroupBarKey), findsNothing);
      expect(find.byKey(OrganizeGroupsModal.nameFieldKey), findsNothing);
      expect(
        find.text('Optional interpretive layer. Chronology is unchanged.'),
        findsNothing,
      );
    },
  );
}
