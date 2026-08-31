import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/investigation_health/health_finding_category.dart';
import 'package:evidence_vault/domain/investigation_health/health_finding_type.dart';
import 'package:evidence_vault/domain/investigation_health/health_message_keys.dart';
import 'package:evidence_vault/domain/investigation_health/health_recommendation_keys.dart';
import 'package:evidence_vault/domain/investigation_health/investigation_health_scoring.dart';
import 'package:evidence_vault/domain/investigation_health/investigation_health_weights.dart';
import 'package:evidence_vault/engines/investigation_health_engine.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  bool isContextual = false,
  Set<String> relatedEvidenceIds = const {},
  String? notePreview,
  DateTime? lastPreservedAt,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: lastPreservedAt ?? DateTime(2026, 7, 28, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    isContextual: isContextual,
    relatedEvidenceIds: relatedEvidenceIds,
    notePreview: notePreview,
  );
}

void main() {
  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('InvestigationHealthScoring', () {
    test('overall score applies configurable weights', () {
      const weights = InvestigationHealthWeights(
        evidenceCompleteness: 0.5,
        relationshipCoverage: 0.1,
        timelineIntegrity: 0.1,
        narrativeSupport: 0.2,
        trustReadiness: 0.1,
      );

      final overall = InvestigationHealthScoring.overallScore(
        evidenceCompletenessScore: 100,
        relationshipCoverageScore: 50,
        timelineIntegrityScore: 50,
        narrativeSupportScore: 80,
        trustReadinessScore: 60,
        weights: weights,
      );

      expect(overall, 82);
    });

    test('category score deducts penalties by priority', () {
      final score = InvestigationHealthScoring.categoryScore(
        HealthFindingCategory.timelineIntegrity,
        const [],
      );

      expect(score, 100);
    });
  });

  group('InvestigationHealthEngine', () {
    test('returns zero scores when no primary evidence exists', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: const []),
      );

      final health = InvestigationHealthEngine.evaluate(
        controller.aggregate,
        generatedAt: DateTime(2026, 8, 3, 12),
      );

      expect(health.overallScore, 0);
      expect(health.findings, isEmpty);
      expect(health.generatedAt, DateTime(2026, 8, 3, 12));
    });

    test('complete investigation produces high scores and fewer findings', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Complete Incident',
          items: [
            _item(id: 'photo-1'),
            _item(id: 'photo-2'),
            _item(
              id: 'context-note',
              kind: WorkspaceEvidenceKind.note,
              isContextual: true,
              relatedEvidenceIds: {'photo-1'},
              notePreview: 'Front door visible.',
            ),
            _item(
              id: 'context-note-2',
              kind: WorkspaceEvidenceKind.note,
              isContextual: true,
              relatedEvidenceIds: {'photo-2'},
              notePreview: 'Lobby area.',
            ),
            _item(id: 'witness', kind: WorkspaceEvidenceKind.witness),
            _item(
              id: 'support-doc',
              kind: WorkspaceEvidenceKind.attachment,
              isContextual: true,
              relatedEvidenceIds: {'photo-1'},
            ),
          ],
        ),
      );
      controller.commitRelationshipGroup(evidenceIds: ['photo-1', 'photo-2']);

      final health = InvestigationHealthEngine.evaluate(controller.aggregate);

      expect(health.overallScore, greaterThan(60));
      expect(health.evidenceCompletenessScore, greaterThan(50));
      expect(
        health.findings.where(
          (finding) =>
              finding.type == HealthFindingType.missingObservation,
        ),
        isEmpty,
      );
      expect(health.findings.every((finding) => finding.messageKey.isNotEmpty),
          isTrue);
      expect(
        health.findings.every((finding) => finding.recommendationKey.isNotEmpty),
        isTrue,
      );
    });

    test('sparse investigation produces lower scores and completeness findings',
        () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo-1'),
            _item(id: 'photo-2'),
          ],
        ),
      );

      final health = InvestigationHealthEngine.evaluate(controller.aggregate);

      expect(health.overallScore, lessThan(80));
      expect(health.evidenceCompletenessScore, lessThan(100));
      expect(
        health.findings.any(
          (finding) =>
              finding.category ==
                  HealthFindingCategory.evidenceCompleteness &&
              finding.type == HealthFindingType.missingObservation,
        ),
        isTrue,
      );
      expect(
        health.findings.any(
          (finding) =>
              finding.type == HealthFindingType.notLinkedToRelationship,
        ),
        isTrue,
      );
    });

    test('isolated evidence generates relationship coverage finding', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo-1'),
            _item(
              id: 'isolated-doc',
              kind: WorkspaceEvidenceKind.note,
              notePreview: 'Standalone memo.',
            ),
          ],
        ),
      );

      final health = InvestigationHealthEngine.evaluate(controller.aggregate);
      final isolated = health.findings.where(
        (finding) => finding.type == HealthFindingType.isolatedEvidence,
      );

      expect(isolated, hasLength(1));
      expect(isolated.first.affectedObjectId, 'isolated-doc');
      expect(isolated.first.messageKey,
          HealthMessageKeys.relationshipIsolatedEvidence);
      expect(isolated.first.recommendationKey,
          HealthRecommendationKeys.connectEvidence);
    });

    test('unsupported narrative generates narrative support finding', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo-1')],
        ),
      );

      final health = InvestigationHealthEngine.evaluate(controller.aggregate);
      final unsupported = health.findings.where(
        (finding) =>
            finding.type == HealthFindingType.unsupportedNarrativeStatement,
      );

      expect(unsupported, isNotEmpty);
      expect(unsupported.first.category, HealthFindingCategory.narrativeSupport);
      expect(unsupported.first.recommendationKey,
          HealthRecommendationKeys.strengthenNarrativeSupport);
      expect(health.narrativeSupportScore, lessThan(100));
    });

    test('timeline integrity findings include unsupported anchors', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo-1')],
        ),
      );

      final health = InvestigationHealthEngine.evaluate(controller.aggregate);

      expect(
        health.findings.any(
          (finding) =>
              finding.type ==
              HealthFindingType.anchorWithoutSupportingEvidence,
        ),
        isTrue,
      );
      expect(health.timelineIntegrityScore, lessThan(100));
    });

    test('findings contain structured keys only — no presentation copy', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo-1'),
            _item(id: 'photo-2'),
          ],
        ),
      );

      final health = InvestigationHealthEngine.evaluate(controller.aggregate);

      for (final finding in health.findings) {
        expect(finding.messageKey.startsWith('health.'), isTrue);
        expect(finding.recommendationKey, matches(RegExp(r'^[A-Z_]+$')));
        expect(finding.id, isNotEmpty);
      }
    });

    test('chronological gap finding appears for distant timeline anchors', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo-1',
              lastPreservedAt: DateTime(2026, 7, 28, 8),
            ),
            _item(
              id: 'photo-2',
              lastPreservedAt: DateTime(2026, 7, 28, 16),
            ),
          ],
        ),
      );

      final health = InvestigationHealthEngine.evaluate(
        controller.aggregate,
        rules: const InvestigationHealthRules(
          significantTimeGap: Duration(hours: 2),
        ),
      );

      expect(
        health.findings.any(
          (finding) => finding.type == HealthFindingType.chronologicalGap,
        ),
        isTrue,
      );
    });
  });
}
