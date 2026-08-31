import 'package:evidence_vault/engines/enrichment_engine.dart';
import 'package:evidence_vault/models/relationship_group_confidence.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/narrative_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? notePreview,
  bool isContextual = false,
  double? latitude,
  double? longitude,
  String? parentEvidenceId,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    notePreview: notePreview,
    isContextual: isContextual,
    latitude: latitude,
    longitude: longitude,
    parentEvidenceId: parentEvidenceId,
  );
}

void main() {
  group('NarrativeValidationService', () {
    test('single primary evidence is low with coaching recommendations', () {
      final validation = NarrativeValidationService.validateEvent(
        displayEvidence: [_item(id: 'photo')],
        supportingEvidence: const [],
        reconstructionNotes: const [],
        hasMissingReferencedEvidence: false,
        enrichmentContext: const EnrichmentContext(items: [], relationships: []),
      );

      expect(validation.status, RelationshipGroupConfidence.low);
      expect(validation.recommendations, contains(NarrativeValidationService.recEventSingleEvidence));
      expect(validation.recommendations, contains(NarrativeValidationService.recWitnessOptional));
      expect(validation.recommendations, isNot(contains('Only one primary evidence captured.')));
      expect(validation.recommendations, isNot(contains('Capture additional evidence.')));
      expect(validation.recommendations, isNot(contains('Missing witness statement.')));
      expect(validation.supportedByLines, contains('• 📷 1 Photo'));
    });

    test('multiple evidence types with context and witness is high', () {
      final validation = NarrativeValidationService.validateEvent(
        displayEvidence: [
          _item(id: 'photo'),
          _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          _item(id: 'witness', kind: WorkspaceEvidenceKind.witness),
        ],
        supportingEvidence: [
          _item(
            id: 'doc',
            kind: WorkspaceEvidenceKind.attachment,
            parentEvidenceId: 'photo',
          ),
        ],
        reconstructionNotes: const [],
        hasMissingReferencedEvidence: false,
        enrichmentContext: const EnrichmentContext(items: [], relationships: []),
        eventSummary: 'The suspect arrived at the entrance.',
      );

      expect(validation.status, RelationshipGroupConfidence.high);
      expect(validation.recommendations, isEmpty);
    });

    test('two evidence items with partial context is medium', () {
      final validation = NarrativeValidationService.validateEvent(
        displayEvidence: [
          _item(id: 'photo'),
          _item(id: 'video', kind: WorkspaceEvidenceKind.video),
        ],
        supportingEvidence: const [],
        reconstructionNotes: const [],
        hasMissingReferencedEvidence: false,
        enrichmentContext: const EnrichmentContext(items: [], relationships: []),
        eventSummary: 'Entry captured on camera.',
      );

      expect(validation.status, RelationshipGroupConfidence.medium);
      expect(validation.recommendations, contains(NarrativeValidationService.recWitnessOptional));
    });

    test('missing anchor evidence is low with removal coaching', () {
      final validation = NarrativeValidationService.validateEvent(
        displayEvidence: const [],
        supportingEvidence: const [],
        reconstructionNotes: const [],
        hasMissingReferencedEvidence: true,
        enrichmentContext: const EnrichmentContext(items: [], relationships: []),
      );

      expect(validation.status, RelationshipGroupConfidence.low);
      expect(validation.recommendations, contains(NarrativeValidationService.recReferencedRemoved));
    });

    test('voice note without context recommends contextual coaching', () {
      final validation = NarrativeValidationService.validateEvent(
        displayEvidence: [
          _item(id: 'photo'),
          _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
        ],
        supportingEvidence: const [],
        reconstructionNotes: const [],
        hasMissingReferencedEvidence: false,
        enrichmentContext: const EnrichmentContext(items: [], relationships: []),
        eventSummary: 'Officer notes from the scene.',
      );

      expect(
        validation.recommendations,
        contains(NarrativeValidationService.recVoiceNoWrittenExplanation),
      );
    });

    test('location recorded does not emit missing-location warning', () {
      final validation = NarrativeValidationService.validateEvent(
        displayEvidence: [
          _item(id: 'photo', latitude: 28.2, longitude: 83.9),
        ],
        supportingEvidence: const [],
        reconstructionNotes: const [],
        hasMissingReferencedEvidence: false,
        enrichmentContext: const EnrichmentContext(items: [], relationships: []),
      );

      expect(
        validation.recommendations,
        isNot(contains(NarrativeValidationService.recLocationMissing)),
      );
      expect(
        validation.recommendations,
        contains(NarrativeValidationService.recNoWrittenExplanation),
      );
    });
  });

  group('NarrativeReconstructionHealth', () {
    test('all high events produce excellent health', () {
      final health = NarrativeValidationService.computeReconstructionHealth([
        const NarrativeEventValidation(
          status: RelationshipGroupConfidence.high,
          typeCounts: [],
          recommendations: [],
        ),
        const NarrativeEventValidation(
          status: RelationshipGroupConfidence.high,
          typeCounts: [],
          recommendations: [],
        ),
      ]);

      expect(health.status, ReconstructionHealthStatus.excellent);
      expect(health.label, 'Excellent');
      expect(health.coverageLabel,
          '2 of 2 Narrative Events sufficiently supported.');
    });

    test('mixed medium events produce needs review health', () {
      final health = NarrativeValidationService.computeReconstructionHealth([
        const NarrativeEventValidation(
          status: RelationshipGroupConfidence.high,
          typeCounts: [],
          recommendations: [],
        ),
        const NarrativeEventValidation(
          status: RelationshipGroupConfidence.medium,
          typeCounts: [],
          recommendations: [NarrativeValidationService.recWitnessOptional],
        ),
      ]);

      expect(health.status, ReconstructionHealthStatus.needsReview);
      expect(health.supportedEventCount, 2);
    });

    test('majority low events produce incomplete health', () {
      final health = NarrativeValidationService.computeReconstructionHealth([
        const NarrativeEventValidation(
          status: RelationshipGroupConfidence.low,
          typeCounts: [],
          recommendations: [NarrativeValidationService.recEventSingleEvidence],
        ),
        const NarrativeEventValidation(
          status: RelationshipGroupConfidence.low,
          typeCounts: [],
          recommendations: [NarrativeValidationService.recEventSingleEvidence],
        ),
        const NarrativeEventValidation(
          status: RelationshipGroupConfidence.medium,
          typeCounts: [],
          recommendations: [],
        ),
      ]);

      expect(health.status, ReconstructionHealthStatus.incomplete);
      expect(health.supportedEventCount, 1);
    });
  });
}
