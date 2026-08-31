import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/trust_package/trust_package.dart';
import 'package:evidence_vault/domain/trust_package/trust_package_assembler.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  bool isContextual = false,
  String? notePreview,
  Set<String> relatedEvidenceIds = const {},
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28, 12),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    isContextual: isContextual,
    notePreview: notePreview,
    relatedEvidenceIds: relatedEvidenceIds,
  );
}

void main() {
  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('DefaultTrustPackageAssembler', () {
    const assembler = DefaultTrustPackageAssembler();

    test('assembles all trust package sections from incident aggregate', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Workplace Incident',
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
            _item(
              id: 'context-note',
              kind: WorkspaceEvidenceKind.note,
              isContextual: true,
              relatedEvidenceIds: {'photo'},
              notePreview: 'Door was unlocked.',
            ),
            _item(id: 'witness', kind: WorkspaceEvidenceKind.witness),
          ],
        ),
      );
      controller.commitRelationshipGroup(evidenceIds: ['photo', 'video']);
      controller.aggregate.narrativeEventRepository.ensureInitialStructure(
        orderedAnchorEvidenceIds:
            controller.aggregate.timelineRepository.orderedCapturedEvidenceIds(),
      );

      final package = assembler.assemble(controller.aggregate);

      expect(package.incidentSummary.incidentName, 'Workplace Incident');
      expect(package.incidentSummary.incidentType, 'General Incident');
      expect(package.incidentSummary.reconstructionHealth, isNotEmpty);
      expect(package.investigationSummary.timelineAnchorCount, 2);
      expect(package.investigationSummary.relationshipGroupCount, 1);
      expect(package.investigationSummary.narrativeEventCount, 2);
      expect(package.investigationSummary.witnessCount, 1);
      expect(package.timelineSection.entries, hasLength(2));
      expect(package.relationshipGroupsSection.groups, hasLength(1));
      expect(package.relationshipGroupsSection.groups.single.groupName,
          isNotEmpty);
      expect(package.reconstructionSection.events, hasLength(2));
      expect(package.evidenceAppendix.entries, hasLength(4));
      expect(package.integritySummary.evidenceCount, 4);
      expect(package.metadata.packageVersion, DefaultTrustPackageAssembler.packageVersion);
      expect(package.metadata.generatedBy, DefaultTrustPackageAssembler.generatedBy);
      expect(
        package.metadata.trustPackageId,
        '${controller.aggregate.store.incident.id}@trust-package/v1',
      );
    });

    test('timeline entries preserve anchor chronology and evidence references', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo',
              notePreview: 'Entrance photo',
            ),
            _item(
              id: 'note',
              kind: WorkspaceEvidenceKind.note,
              isContextual: true,
              relatedEvidenceIds: {'photo'},
              notePreview: 'Supporting note',
            ),
          ],
        ),
      );

      final package = assembler.assemble(controller.aggregate);
      final entry = package.timelineSection.entries.single;

      expect(entry.capturedEvidenceId, 'photo');
      expect(entry.relatedEvidenceIds, contains('photo'));
      expect(entry.relatedEvidenceIds, contains('note'));
      expect(entry.title, 'Evidence photo');
    });

    test('evidence appendix references evidence without duplicating media fields', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );
      controller.commitRelationshipGroup(evidenceIds: ['photo', 'video']);

      final package = assembler.assemble(controller.aggregate);
      final appendixEntry = package.evidenceAppendix.entries.firstWhere(
        (entry) => entry.evidenceId == 'photo',
      );

      expect(appendixEntry.evidenceType, isNotEmpty);
      expect(appendixEntry.device, isNotNull);
      expect(appendixEntry.relationshipGroupIds, hasLength(1));
    });

    test('integrity summary reports missing narrative anchor references', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
      );
      controller.aggregate.narrativeEventRepository.ensureInitialStructure(
        orderedAnchorEvidenceIds: ['photo'],
      );
      final event = controller.aggregate.store.narrativeEvents.single;
      controller.aggregate.store.narrativeEvents[0] = event.copyWith(
        timelineAnchorEvidenceId: 'removed-photo',
      );

      final package = assembler.assemble(controller.aggregate);

      expect(
        package.integritySummary.missingReferences,
        contains(
          contains('Narrative event ${event.id} references removed anchor'),
        ),
      );
      expect(package.integritySummary.validationStatus, isNotEmpty);
    });

    test('assembly is deterministic for the same incident aggregate', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Deterministic Incident',
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
        ),
      );
      controller.commitRelationshipGroup(evidenceIds: ['photo', 'video']);
      controller.aggregate.narrativeEventRepository.ensureInitialStructure(
        orderedAnchorEvidenceIds:
            controller.aggregate.timelineRepository.orderedCapturedEvidenceIds(),
      );

      final first = assembler.assemble(controller.aggregate);
      final second = assembler.assemble(controller.aggregate);

      expect(first.metadata.trustPackageId, second.metadata.trustPackageId);
      expect(first.metadata.packageVersion, second.metadata.packageVersion);
      expect(first.metadata.generatedAt, second.metadata.generatedAt);
      expect(first.metadata.incidentVersion, second.metadata.incidentVersion);
      expect(first.investigationSummary.timelineAnchorCount,
          second.investigationSummary.timelineAnchorCount);
      expect(first.investigationSummary.narrativeEventCount,
          second.investigationSummary.narrativeEventCount);
      expect(
        first.timelineSection.entries.map((entry) => entry.capturedEvidenceId),
        second.timelineSection.entries.map((entry) => entry.capturedEvidenceId),
      );
      expect(
        first.reconstructionSection.events.map((entry) => entry.eventId),
        second.reconstructionSection.events.map((entry) => entry.eventId),
      );
      expect(
        first.evidenceAppendix.entries.map((entry) => entry.evidenceId),
        second.evidenceAppendix.entries.map((entry) => entry.evidenceId),
      );
    });

    test('does not mutate incident aggregate during assembly', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
      );
      final capturedBefore =
          controller.aggregate.store.capturedEvidence.length;
      final narrativeBefore =
          List<TrustPackageReconstructionEventEntry>.from(
            assembler
                .assemble(controller.aggregate)
                .reconstructionSection
                .events,
          );

      assembler.assemble(controller.aggregate);

      expect(controller.aggregate.store.capturedEvidence.length, capturedBefore);
      expect(
        assembler.assemble(controller.aggregate).reconstructionSection.events,
        narrativeBefore,
      );
    });
  });
}
