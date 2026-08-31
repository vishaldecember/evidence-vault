import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/participant/evidence_person_relationship.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_groups_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-groups', title: 'Case'),
  );
}

Future<void> _pumpOrganize(
  WidgetTester tester,
  WorkspaceEvidenceController controller,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return OrganizeWorkspaceView(
              incident: controller.currentIncident,
              orderedCapturedEvidenceIds: controller.timelineRepository
                  .orderedCapturedEvidenceIds(),
              organizeCreatedIds: controller.organizeCreatedEvidenceIds,
              onEvidenceSelected: (_) {},
              onUpsertInterpretiveGroup:
                  ({required category, required name, collectionId}) {
                    return controller.upsertInterpretiveGroup(
                      category: category.name,
                      name: name,
                      collectionId: collectionId,
                    );
                  },
              onSetInterpretiveGroupMembership:
                  ({
                    required collectionId,
                    required evidenceId,
                    required associated,
                  }) {
                    controller.setInterpretiveGroupMembership(
                      collectionId: collectionId,
                      evidenceId: evidenceId,
                      associated: associated,
                    );
                  },
              onCreateCustomGroup: ({required name, evidenceIds = const []}) {
                return controller.createCustomGroup(
                  name: name,
                  evidenceIds: evidenceIds,
                );
              },
              onRenameGroupPerson: (participantId, displayName) {
                controller.renameParticipantIdentity(
                  participantId: participantId,
                  displayName: displayName,
                );
              },
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _dismissGroups(WidgetTester tester) async {
  final scrim = tester.getRect(find.byKey(OrganizeGroupsModal.scrimKey));
  await tester.tapAt(Offset(scrim.center.dx, scrim.top + 12));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
  });

  test(
    'interpretive group persists entity ↔ evidence in the incident store',
    () {
      final controller = _controller();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final video = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      final created = controller.upsertInterpretiveGroup(
        category: OrganizeGroupCategory.personParticipant.name,
        name: 'Jacob',
      );
      expect(created, isNotNull);
      expect(
        controller.setInterpretiveGroupMembership(
          collectionId: created!.id,
          evidenceId: photo,
          associated: true,
        ),
        isTrue,
      );
      expect(
        controller.setInterpretiveGroupMembership(
          collectionId: created.id,
          evidenceId: video,
          associated: true,
        ),
        isTrue,
      );

      final stored = controller.evidenceCollections.singleWhere(
        (collection) => collection.id == created.id,
      );
      expect(stored.name, 'Jacob');
      expect(stored.category, 'personParticipant');
      expect(stored.memberEvidenceIds.toSet(), {photo, video});

      final encoded = FirestoreSerializers.evidenceCollectionToMap(stored);
      final decoded = FirestoreSerializers.evidenceCollectionFromMap(
        encoded,
        stored.id,
      );
      expect(decoded.name, 'Jacob');
      expect(decoded.category, 'personParticipant');
      expect(decoded.memberEvidenceIds.toSet(), {photo, video});

      controller.ensureEvidenceCollections();
      expect(
        controller.evidenceCollections
            .singleWhere((collection) => collection.name == 'Jacob')
            .memberEvidenceIds
            .toSet(),
        {photo, video},
      );
    },
  );

  testWidgets(
    'Groups + shows people derived from evidence and keeps chronology',
    (tester) async {
      final controller = _controller();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final video = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      controller.ensureEvidenceCollections();
      final jacob = controller.addRelatedPersonToEvidence(
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
        evidenceId: video,
        displayName: 'Jacob',
        relationship: EvidencePersonRelationship.witness,
        existingParticipantId: jacob.id,
      );
      final idsBefore = [
        for (final item in controller.currentIncident.evidence) item.id,
      ];
      final hashesBefore = [
        for (final item in controller.currentIncident.evidence)
          item.contentHash,
      ];
      final sequenceBefore = controller.timelineRepository
          .orderedCapturedEvidenceIds();

      await _pumpOrganize(tester, controller);
      await tester.tap(find.byKey(OrganizeWorkspaceView.groupsBrowseKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(OrganizeGroupsModal.matrixKey), findsOneWidget);
      expect(find.byKey(OrganizeGroupsModal.nameFieldKey), findsNothing);
      expect(
        find.text('Optional interpretive layer. Chronology is unchanged.'),
        findsNothing,
      );

      await tester.tap(find.text('People / Participants'));
      await tester.pump();

      expect(find.text('Jacob'), findsWidgets);
      expect(find.text('Sarah'), findsWidgets);
      expect(find.textContaining('preserved moment'), findsWidgets);

      await _dismissGroups(tester);
      expect(find.byKey(OrganizeGroupsModal.modalKey), findsNothing);

      expect([
        for (final item in controller.currentIncident.evidence) item.id,
      ], idsBefore);
      expect([
        for (final item in controller.currentIncident.evidence)
          item.contentHash,
      ], hashesBefore);
      expect(
        controller.timelineRepository.orderedCapturedEvidenceIds(),
        sequenceBefore,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(video)),
        findsOneWidget,
      );
    },
  );
}
