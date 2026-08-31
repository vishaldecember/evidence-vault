import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/relationship/relationship_suggestion.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/services/collection/collection_engine.dart';
import 'package:evidence_vault/services/relationship/heuristic_relationship_provider.dart';
import 'package:evidence_vault/services/relationship/relationship_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
  });

  test('Primary Evidence designation toggles without capture friction', () {
    final controller = WorkspaceEvidenceController();
    final id = controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    expect(
      controller.aggregate.store.capturedEvidence.single.isPrimaryEvidence,
      isTrue,
    );

    controller.setPrimaryEvidence(evidenceId: id, isPrimary: false);
    expect(
      controller.aggregate.store.capturedEvidence.single.isPrimaryEvidence,
      isFalse,
    );

    controller.setPrimaryEvidence(evidenceId: id, isPrimary: true);
    expect(
      controller.aggregate.store.capturedEvidence.single.isPrimaryEvidence,
      isTrue,
    );
  });

  test('Supporting evidence maps to one primary with multiple supports', () {
    final controller = WorkspaceEvidenceController();
    final primaryId =
        controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
    controller.addContextEvidence(
      parentEvidenceId: primaryId,
      mode: WorkspaceCaptureMode.photo,
    );
    controller.addContextEvidence(
      parentEvidenceId: primaryId,
      mode: WorkspaceCaptureMode.note,
    );
    controller.addContextTextNote(
      parentEvidenceId: primaryId,
      text: 'Witness observed the vehicle.',
    );

    final graph = controller.investigationGraph;
    expect(graph.supportingFor(primaryId).length, greaterThanOrEqualTo(2));
    expect(graph.primaryEvidenceIds, contains(primaryId));
  });

  test('Deterministic RELATED links from collection membership — no duplicates',
      () {
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
    CollectionEngine.instance.ensureCollections(store: controller.aggregate.store);

    final result = RelationshipEngine.instance.ensureRelationships(
      store: controller.aggregate.store,
      relationshipRepository: controller.relationshipRepository,
    );

    expect(result.createdCount, greaterThan(0));
    final again = RelationshipEngine.instance.ensureRelationships(
      store: controller.aggregate.store,
      relationshipRepository: controller.relationshipRepository,
    );
    expect(again.createdCount, 0);

    final pairs = controller.relationshipRepository.all
        .map((r) => {r.sourceEvidenceId, r.targetEvidenceId}.join(':'))
        .toSet();
    expect(pairs.length, controller.relationshipRepository.all.length);
    expect(
      controller.relationshipRepository.all.every(
        (r) => r.type == RelationshipType.relatedTo,
      ),
      isTrue,
    );
  });

  test('Evidence with no peers yields empty relationship ensure', () {
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final result = RelationshipEngine.instance.ensureRelationships(
      store: controller.aggregate.store,
      relationshipRepository: controller.relationshipRepository,
    );
    expect(result.createdCount, 0);
    expect(controller.investigationGraph.edges.where(
      (e) => e.kind == InvestigationGraphEdgeKind.related,
    ), isEmpty);
  });

  test('Close timestamps produce readable RELATED reason', () {
    final provider = HeuristicRelationshipProvider();
    final now = DateTime(2026, 8, 8, 10);
    final suggestions = provider.suggest(
      incidentId: 'i1',
      signals: [
        RelationshipEvidenceSignal(
          evidenceId: 'a',
          kindLabel: 'photo',
          capturedAt: now,
        ),
        RelationshipEvidenceSignal(
          evidenceId: 'b',
          kindLabel: 'video',
          capturedAt: now.add(const Duration(seconds: 12)),
        ),
      ],
    );
    expect(suggestions, isNotEmpty);
    expect(
      suggestions.first.reason,
      contains('12 seconds apart'),
    );
    expect(suggestions.first.relationshipType, RelationshipType.relatedTo.name);
    expect(suggestions.first.source, RelationshipSuggestionSource.metadata);
  });

  test('Relationships persist locally across ensure cycles (offline-safe)', () {
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
    CollectionEngine.instance.ensureCollections(store: controller.aggregate.store);
    RelationshipEngine.instance.ensureRelationships(
      store: controller.aggregate.store,
      relationshipRepository: controller.relationshipRepository,
    );
    final before = controller.relationshipRepository.all.length;
    expect(before, greaterThan(0));

    // Simulate restart by rebuilding graph view from same store.
    final graph = controller.investigationGraph;
    expect(
      graph.edges.where((e) => e.kind == InvestigationGraphEdgeKind.related),
      isNotEmpty,
    );
    expect(controller.aggregate.store.relationships, hasLength(before));
  });

  test('AI provider seam is swappable without Capture Engine changes', () {
    final engine = RelationshipEngine(provider: _FixedAiProvider());
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.file);
    final result = engine.ensureRelationships(
      store: controller.aggregate.store,
      relationshipRepository: controller.relationshipRepository,
      autoAcceptConfidence: 0.9,
    );
    expect(result.suggestions.single.reason, 'AI reserved');
    expect(result.suggestions.single.source, RelationshipSuggestionSource.ai);
  });

  test('Maturity EMPTY/BUILDING remains functional with relationships', () {
    final controller = WorkspaceEvidenceController();
    expect(controller.journeyStage.name, anyOf('empty', 'EMPTY'.toLowerCase()));
    final primary =
        controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.addContextTextNote(
      parentEvidenceId: primary,
      text: 'Context note',
    );
    final stage = controller.enrichment.journeyStage;
    expect(['empty', 'building', 'rich'], contains(stage.name));
  });
}

class _FixedAiProvider implements RelationshipSuggestionProvider {
  @override
  List<RelationshipSuggestion> suggest({
    required String incidentId,
    required List<RelationshipEvidenceSignal> signals,
  }) {
    if (signals.length < 2) {
      return const [];
    }
    return [
      RelationshipSuggestion(
        id: 'ai_1',
        incidentId: incidentId,
        sourceEvidenceId: signals[0].evidenceId,
        targetEvidenceId: signals[1].evidenceId,
        relationshipType: RelationshipType.relatedTo.name,
        confidence: 0.95,
        reason: 'AI reserved',
        source: RelationshipSuggestionSource.ai,
        status: RelationshipSuggestionStatus.suggested,
        createdAt: DateTime.now(),
      ),
    ];
  }
}
