import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/investigation/investigation_graph.dart';
import 'package:evidence_vault/domain/investigation/investigation_graph_node.dart';
import 'package:evidence_vault/domain/participant/evidence_person_relationship.dart';
import 'package:evidence_vault/domain/participant/participant_role.dart';
import 'package:evidence_vault/migration/workspace_state_migration.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
  });

  group('ParticipantRepository', () {
    test('creates participant attached to incident', () {
      final controller = WorkspaceEvidenceController();
      final repository = controller.participantRepository;

      final participant = repository.create(
        displayName: 'Alex Morgan',
        role: ParticipantRole.reporter,
        contactInformation: 'alex@example.com',
        organisation: 'Internal Audit',
        notes: 'Initial reporter contact.',
      );

      expect(participant.displayName, 'Alex Morgan');
      expect(participant.role, ParticipantRole.reporter);
      expect(participant.incidentId, controller.aggregate.incident.id);
      expect(repository.getByIncident(), hasLength(1));
      expect(repository.getById(participant.id), participant);
    });

    test('updates and deletes participant when no evidence references them', () {
      final controller = WorkspaceEvidenceController();
      final repository = controller.participantRepository;
      final created = repository.create(
        displayName: 'Jordan Lee',
        role: ParticipantRole.witness,
      );

      final updated = repository.update(
        participantId: created.id,
        displayName: 'Jordan Lee (Witness)',
        role: ParticipantRole.witness,
        notes: 'Available for follow-up.',
      );

      expect(updated?.displayName, 'Jordan Lee (Witness)');
      expect(updated?.notes, 'Available for follow-up.');
      expect(repository.delete(created.id), isTrue);
      expect(repository.getById(created.id), isNull);
    });

    test('delete fails when evidence references participant', () {
      final controller = WorkspaceEvidenceController();
      final repository = controller.participantRepository;
      final participant = repository.create(
        displayName: 'Sam Rivera',
        role: ParticipantRole.subject,
      );

      controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
        participantId: participant.id,
      );

      expect(repository.delete(participant.id), isFalse);
      expect(repository.getById(participant.id), isNotNull);
    });

    test('findOrCreateByDisplayName reuses matching participant', () {
      final controller = WorkspaceEvidenceController();
      final repository = controller.participantRepository;

      final first = repository.create(
        displayName: 'Sarah Johnson',
        role: ParticipantRole.witness,
      );
      final reused = repository.findOrCreateByDisplayName(
        displayName: 'sarah johnson',
        role: ParticipantRole.friend,
      );

      expect(reused.id, first.id);
      expect(repository.getByIncident(), hasLength(1));
    });
  });

  group('Evidence participant ownership', () {
    test('captured evidence optionally references participant', () {
      final controller = WorkspaceEvidenceController();
      final participant = controller.participantRepository.create(
        displayName: 'Reporter One',
        role: ParticipantRole.reporter,
      );

      final captured = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
        participantId: participant.id,
      );

      expect(captured.participantId, participant.id);
      expect(
        controller.state.items.singleWhere((item) => item.id == captured.id)
            .participantId,
        participant.id,
      );
    });

    test('supporting evidence optionally references participant', () {
      final controller = WorkspaceEvidenceController();
      final witness = controller.participantRepository.create(
        displayName: 'Witness One',
        role: ParticipantRole.witness,
      );
      final captured = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );

      final statement = controller.evidenceRepository.addSupportingFromCaptureMode(
        WorkspaceCaptureMode.note,
        parentCapturedEvidenceId: captured.id,
        participantId: witness.id,
      );

      expect(statement.participantId, witness.id);
    });

    test('assignParticipantToCaptured updates existing evidence', () {
      final controller = WorkspaceEvidenceController();
      final participant = controller.participantRepository.create(
        displayName: 'Investigator',
        role: ParticipantRole.investigator,
      );
      final captured = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.video,
      );

      final updated = controller.evidenceRepository.assignParticipantToCaptured(
        evidenceId: captured.id,
        participantId: participant.id,
      );

      expect(updated?.participantId, participant.id);
    });

    test('assignRelatedPersonToEvidence creates and links participant', () {
      final controller = WorkspaceEvidenceController();
      final captured = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );

      final participant = controller.assignRelatedPersonToEvidence(
        evidenceId: captured.id,
        displayName: 'Sarah Johnson',
        relationship: EvidencePersonRelationship.witness,
      );

      expect(participant.displayName, 'Sarah Johnson');
      expect(
        controller.state.items.singleWhere((item) => item.id == captured.id)
            .participantId,
        participant.id,
      );
    });
  });

  group('WorkspaceStateMigration', () {
    test('preserves participantId on migrated evidence', () {
      final legacy = WorkspaceEvidenceState(
        items: [
          WorkspaceEvidenceItem(
            id: 'photo-1',
            kind: WorkspaceEvidenceKind.image,
            title: 'Photo Evidence',
            lastPreservedAt: DateTime(2026, 7, 28, 9),
            integrityVerified: true,
            verification: VerificationFactory.initial(),
            participantId: 'participant-legacy',
          ),
        ],
      );

      final store = WorkspaceStateMigration.migrate(legacy);

      expect(store.capturedEvidence.single.participantId, 'participant-legacy');
    });
  });

  group('InvestigationGraph', () {
    test('includes participants as first-class graph nodes', () {
      final controller = WorkspaceEvidenceController();
      final reporter = controller.participantRepository.create(
        displayName: 'Reporter',
        role: ParticipantRole.reporter,
      );
      final captured = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
        participantId: reporter.id,
      );

      final nodes = InvestigationGraph.nodesFromStore(controller.aggregate.store);
      final participantNodes = nodes.where(
        (node) => node.kind == InvestigationGraphNodeKind.participant,
      );
      final evidenceNode = nodes.firstWhere(
        (node) => node.id == captured.id,
      );

      expect(participantNodes, hasLength(1));
      expect(participantNodes.first.id, reporter.id);
      expect(evidenceNode.participantId, reporter.id);
    });

    test('participants may exist without evidence', () {
      final controller = WorkspaceEvidenceController();
      controller.participantRepository.create(
        displayName: 'Unlinked Witness',
        role: ParticipantRole.witness,
      );

      final nodes = InvestigationGraph.nodesFromStore(controller.aggregate.store);

      expect(
        nodes.any(
          (node) => node.kind == InvestigationGraphNodeKind.participant,
        ),
        isTrue,
      );
      expect(controller.aggregate.store.capturedEvidence, isEmpty);
    });
  });
}
