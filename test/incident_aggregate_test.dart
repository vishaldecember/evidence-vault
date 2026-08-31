import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/evidence/supporting_evidence_type.dart';
import 'package:evidence_vault/domain/reconstruction/reconstruction_note.dart';
import 'package:evidence_vault/migration/workspace_state_migration.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/reflection_model.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
  });

  group('WorkspaceStateMigration', () {
    test('migrates legacy workspace state without data loss', () {
      final legacy = WorkspaceEvidenceState(
        items: [
          WorkspaceEvidenceItem(
            id: 'photo-1',
            kind: WorkspaceEvidenceKind.image,
            title: 'Photo Evidence',
            lastPreservedAt: DateTime(2026, 7, 28, 9),
            integrityVerified: true,
            verification: VerificationFactory.initial(),
          ),
          WorkspaceEvidenceItem(
            id: 'note-1',
            kind: WorkspaceEvidenceKind.note,
            title: 'Context — Written Note',
            lastPreservedAt: DateTime(2026, 7, 28, 10),
            integrityVerified: true,
            verification: VerificationFactory.initial(),
            isContextual: true,
            relatedEvidenceIds: {'photo-1'},
          ),
        ],
        reflections: [
          ReconstructionNote(
            id: 'note-a',
            body: 'Initial observation',
            createdAt: DateTime(2026, 7, 28, 11),
            updatedAt: DateTime(2026, 7, 28, 11),
          ),
        ],
        incidentName: 'Workplace Concern',
      );

      final store = WorkspaceStateMigration.migrate(legacy);

      expect(store.incident.title, 'Workplace Concern');
      expect(store.capturedEvidence, hasLength(1));
      expect(store.capturedEvidence.first.type, CapturedEvidenceType.photo);
      expect(store.supportingEvidence, hasLength(1));
      expect(store.supportingEvidence.first.type, SupportingEvidenceType.note);
      expect(store.timelineAnchors, hasLength(1));
      expect(store.reconstructionNotes, hasLength(1));
    });
  });

  group('IncidentAggregate pipeline', () {
    test('capture persists captured evidence and timeline anchor', () {
      final controller = WorkspaceEvidenceController();

      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);

      expect(controller.aggregate.store.capturedEvidence, hasLength(2));
      expect(controller.aggregate.store.timelineAnchors, hasLength(2));
      expect(
        controller.timelineRepository.orderedCapturedEvidenceIds(),
        hasLength(2),
      );
      expect(controller.journeyEvidenceItems, hasLength(2));
    });

    test('reconstruction notes use domain model with UI alias', () {
      final controller = WorkspaceEvidenceController();

      final note = controller.addReflection(body: 'Hypothesis recorded.');
      expect(note, isA<ReconstructionNote>());
      expect(controller.sortedReflections, hasLength(1));
      expect(controller.state.reflections.first.body, 'Hypothesis recorded.');
    });
  });
}
