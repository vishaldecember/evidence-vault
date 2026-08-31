import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/matter/matter_content_signal.dart';
import 'package:evidence_vault/domain/matter/matter_relationship_provider.dart';
import 'package:evidence_vault/domain/relationship/relationship_suggestion.dart';
import 'package:evidence_vault/engines/adaptive_coaching.dart';
import 'package:evidence_vault/engines/enrichment_engine.dart';
import 'package:evidence_vault/engines/evidence_semantics.dart';
import 'package:evidence_vault/engines/investigation_coaching_engine.dart';
import 'package:evidence_vault/mappers/connections_presentation_mapper.dart';
import 'package:evidence_vault/models/connections_presentation.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:evidence_vault/services/relationship/composed_relationship_provider.dart';
import 'package:evidence_vault/services/relationship/explicit_matter_relationship_provider.dart';
import 'package:evidence_vault/services/relationship/heuristic_relationship_provider.dart';
import 'package:evidence_vault/services/relationship/relationship_engine.dart';
import 'package:evidence_vault/services/trust_package_scorecard_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required String incidentId,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? parentEvidenceId,
  String? notePreview,
  double? latitude,
  double? longitude,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    incidentId: incidentId,
    kind: kind,
    title: '$kind $id',
    lastPreservedAt: DateTime(2026, 8, 14, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
    notePreview: notePreview,
    latitude: latitude,
    longitude: longitude,
  );
}

RelationshipEvidenceSignal _signal({
  required String id,
  required DateTime capturedAt,
  String kindLabel = 'photo',
  double? latitude,
  double? longitude,
  String? parentEvidenceId,
}) {
  return RelationshipEvidenceSignal(
    evidenceId: id,
    kindLabel: kindLabel,
    capturedAt: capturedAt,
    latitude: latitude,
    longitude: longitude,
    parentEvidenceId: parentEvidenceId,
  );
}

void _forbidContractViolations(Iterable<String> messages) {
  for (final message in messages) {
    final lower = message.toLowerCase();
    expect(lower, isNot(contains('missing evidence')));
    expect(lower, isNot(contains('capture additional')));
    expect(lower, isNot(contains('uncorroborated')));
    expect(lower, isNot(contains('corroborat')));
    expect(lower, isNot(contains('missing witness')));
  }
}

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
    InMemoryNarrativeEventRepository.resetForTests();
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
  });

  group('STEP 6A — Matter contract', () {
    test('1. disabled Matter provider produces zero Matter suggestions', () {
      final now = DateTime(2026, 8, 14, 10, 2);
      final signals = [
        _signal(id: 'a', capturedAt: now),
        _signal(id: 'b', capturedAt: now.add(const Duration(seconds: 12))),
      ];
      final disabled = const DisabledMatterProvider().suggestRelated(
        incidentId: 'inc',
        captureSignals: signals,
      );
      expect(disabled, isEmpty);

      final composed = ComposedRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: signals,
      );
      expect(
        composed.where((s) => s.source == RelationshipSuggestionSource.ai),
        isEmpty,
      );
    });

    test('2. Matter signal produces RELATED, never SUPPORTS', () {
      final suggestions = ExplicitMatterRelationshipProvider(
        contentSignals: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
      ).suggestRelated(
        incidentId: 'inc',
        captureSignals: [
          _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10)),
          _signal(id: 'b', capturedAt: DateTime(2026, 8, 14, 11)),
        ],
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.relationshipType, RelationshipType.relatedTo.name);
      expect(
        suggestions.every((s) => s.relationshipType != RelationshipType.supports.name),
        isTrue,
      );
    });

    test('3. Matter source is distinguishable as AI / suggested', () {
      final suggestions = ExplicitMatterRelationshipProvider(
        contentSignals: const [
          MatterContentSignal(evidenceId: 'a', namedEntities: ['Alex']),
          MatterContentSignal(evidenceId: 'b', namedEntities: ['Alex']),
        ],
      ).suggestRelated(
        incidentId: 'inc',
        captureSignals: [
          _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10)),
          _signal(id: 'b', capturedAt: DateTime(2026, 8, 14, 11)),
        ],
      );

      expect(suggestions.single.source, RelationshipSuggestionSource.ai);
      expect(
        suggestions.single.status,
        RelationshipSuggestionStatus.suggested,
      );

      final persisted = EvidenceRelationship(
        id: 'rel',
        sourceEvidenceId: 'a',
        targetEvidenceId: 'b',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'ai',
        reason: suggestions.single.reason,
      );
      expect(EvidenceSemantics.isSuggestedRelated(persisted), isTrue);
      expect(EvidenceSemantics.isExplicitUserRelationship(persisted), isFalse);
    });

    test('4. Matter suggestion contains a because-explanation', () {
      final suggestions = ExplicitMatterRelationshipProvider(
        contentSignals: const [
          MatterContentSignal(
            evidenceId: 'a',
            placeMentions: ['Cafe Central'],
          ),
          MatterContentSignal(
            evidenceId: 'b',
            placeMentions: ['Cafe Central'],
          ),
        ],
      ).suggestRelated(
        incidentId: 'inc',
        captureSignals: [
          _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10)),
          _signal(id: 'b', capturedAt: DateTime(2026, 8, 14, 11)),
        ],
      );

      expect(suggestions.single.reason, contains('Suggested relationship because'));
      expect(suggestions.single.reason, contains('Cafe Central'));
      expect(suggestions.single.matterExplanation, isNotNull);
      expect(suggestions.single.reason.toLowerCase(), isNot(contains('ai detected')));
    });

    test('5. Matter alone does not satisfy hasRecordedContext', () {
      const incidentId = 'inc';
      final photo = _item(id: 'photo', incidentId: incidentId);
      expect(EvidenceSemantics.hasRecordedContext(photo), isFalse);
      expect(
        EvidenceSemantics.hasRecordedContext(
          photo,
          relationships: [
            EvidenceRelationship(
              id: 'rel',
              sourceEvidenceId: 'photo',
              targetEvidenceId: 'video',
              type: RelationshipType.relatedTo,
              createdAt: DateTime(2026, 8, 14),
              source: 'ai',
              reason:
                  'Suggested relationship because both items contain similar content.',
            ),
          ],
        ),
        isFalse,
      );
    });

    test('6. Matter alone does not make Journey RICH', () {
      const incidentId = 'inc';
      final items = [
        _item(id: 'photo', incidentId: incidentId),
        _item(
          id: 'video',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.video,
        ),
      ];
      final relationships = [
        EvidenceRelationship(
          id: 'rel',
          sourceEvidenceId: 'photo',
          targetEvidenceId: 'video',
          type: RelationshipType.relatedTo,
          createdAt: DateTime(2026, 8, 14),
          source: 'ai',
          reason:
              'Suggested relationship because both items appear to contain the same object.',
        ),
      ];
      final snapshot = EnrichmentEngine.compute(
        EnrichmentContext(items: items, relationships: relationships),
      );
      expect(snapshot.enrichedEvidenceCount, 0);
      expect(snapshot.journeyStage, isNot(JourneyStage.rich));
    });

    test('7. Matter alone does not create witness', () {
      const incidentId = 'inc';
      final items = [
        _item(id: 'photo', incidentId: incidentId),
        _item(
          id: 'video',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.video,
        ),
      ];
      expect(EvidenceSemantics.hasWitnessKind(items), isFalse);

      final suggestions = ExplicitMatterRelationshipProvider(
        contentSignals: const [
          MatterContentSignal(evidenceId: 'photo', namedEntities: ['Alex']),
          MatterContentSignal(evidenceId: 'video', namedEntities: ['Alex']),
        ],
      ).suggestRelated(
        incidentId: incidentId,
        captureSignals: [
          _signal(id: 'photo', capturedAt: DateTime(2026, 8, 14, 10)),
          _signal(
            id: 'video',
            kindLabel: 'video',
            capturedAt: DateTime(2026, 8, 14, 10, 1),
          ),
        ],
      );
      expect(suggestions, isNotEmpty);
      expect(EvidenceSemantics.hasWitnessKind(items), isFalse);
    });

    test('8. Matter alone does not create primary evidence', () {
      const incidentId = 'inc';
      final note = _item(
        id: 'note',
        incidentId: incidentId,
        kind: WorkspaceEvidenceKind.note,
      );
      expect(EvidenceSemantics.isPrimaryChronologyEvidence(note), isFalse);

      ExplicitMatterRelationshipProvider(
        contentSignals: const [
          MatterContentSignal(evidenceId: 'note', topics: ['lease']),
          MatterContentSignal(evidenceId: 'file', topics: ['lease']),
        ],
      ).suggestRelated(
        incidentId: incidentId,
        captureSignals: [
          _signal(id: 'note', kindLabel: 'note', capturedAt: DateTime(2026, 8, 14)),
          _signal(id: 'file', kindLabel: 'file', capturedAt: DateTime(2026, 8, 14)),
        ],
      );
      expect(EvidenceSemantics.isPrimaryChronologyEvidence(note), isFalse);
    });

    test('9. Matter alone does not create corroboration', () {
      expect(
        EvidenceRelationship(
          id: 'rel',
          sourceEvidenceId: 'a',
          targetEvidenceId: 'b',
          type: RelationshipType.relatedTo,
          createdAt: DateTime(2026, 8, 14),
          source: 'ai',
        ).type,
        isNot(equals('corroborates')),
      );
      expect(
        RelationshipType.values.map((t) => t.name),
        isNot(contains('corroborates')),
      );
    });

    test('10. TIME + SPACE + MATTER strengthens a RELATED suggestion', () {
      final now = DateTime(2026, 8, 14, 10, 2, 14);
      final matter = ExplicitMatterRelationshipProvider(
        contentSignals: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
      );
      final composed = ComposedRelationshipProvider(matterProvider: matter);

      final matterOnly = composed.suggest(
        incidentId: 'inc',
        signals: [
          _signal(id: 'a', capturedAt: now),
          _signal(id: 'b', capturedAt: now.add(const Duration(days: 3))),
        ],
      ).where((s) => s.source == RelationshipSuggestionSource.ai).single;

      final combined = composed.suggest(
        incidentId: 'inc',
        signals: [
          _signal(
            id: 'a',
            capturedAt: now,
            latitude: 27.7,
            longitude: 85.3,
          ),
          _signal(
            id: 'b',
            kindLabel: 'video',
            capturedAt: now.add(const Duration(seconds: 33)),
            latitude: 27.70015,
            longitude: 85.3,
          ),
        ],
      ).where((s) => s.source == RelationshipSuggestionSource.ai).single;

      expect(combined.confidence, greaterThan(matterOnly.confidence));
      expect(combined.timeExplanation, isNotNull);
      expect(combined.spaceExplanation, isNotNull);
      expect(combined.matterExplanation, isNotNull);
    });

    test('11. TIME + SPACE + MATTER still produces RELATED only', () {
      final now = DateTime(2026, 8, 14, 10, 2);
      final suggestions = ComposedRelationshipProvider(
        matterProvider: const ExplicitMatterRelationshipProvider(
          contentSignals: [
            MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
            MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
          ],
        ),
      ).suggest(
        incidentId: 'inc',
        signals: [
          _signal(
            id: 'a',
            capturedAt: now,
            latitude: 27.7,
            longitude: 85.3,
          ),
          _signal(
            id: 'b',
            kindLabel: 'video',
            capturedAt: now.add(const Duration(seconds: 33)),
            latitude: 27.70015,
            longitude: 85.3,
          ),
        ],
      );

      expect(
        suggestions.every((s) => s.relationshipType == RelationshipType.relatedTo.name),
        isTrue,
      );
      expect(
        suggestions.any((s) => s.relationshipType == RelationshipType.supports.name),
        isFalse,
      );
    });

    test('12. Matter does not generate Adaptive Coaching warnings', () {
      const incidentId = 'inc-A';
      const quality = TrustPackageInvestigationQuality(
        overallRating: TrustPackageQualityRating.incomplete,
        indicators: [],
      );
      final items = [
        _item(id: 'photo', incidentId: incidentId),
        _item(
          id: 'video',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.video,
        ),
        _item(
          id: 'voice',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.voice,
        ),
      ];
      final withoutMatter = InvestigationCoachingContext(
        incidentId: incidentId,
        items: items,
        timelineNodes: const [],
        narrativeEvents: const [],
        relationships: const [],
        groupMemberEvidenceIds: const {},
        primaryEvidenceCount: 3,
        enrichedEvidenceCount: 0,
        trustPackageQuality: quality,
      );
      final withMatter = InvestigationCoachingContext(
        incidentId: incidentId,
        items: items,
        timelineNodes: const [],
        narrativeEvents: const [],
        relationships: [
          EvidenceRelationship(
            id: 'rel-ai',
            sourceEvidenceId: 'photo',
            targetEvidenceId: 'video',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 14),
            source: 'ai',
            reason:
                'Suggested relationship because both items appear to contain the same object.',
          ),
        ],
        groupMemberEvidenceIds: const {},
        primaryEvidenceCount: 3,
        enrichedEvidenceCount: 0,
        trustPackageQuality: quality,
      );

      final before = InvestigationCoachingEngine.generate(withoutMatter);
      final after = InvestigationCoachingEngine.generate(withMatter);
      expect(
        after.map((item) => item.fingerprint).toList(),
        before.map((item) => item.fingerprint).toList(),
      );
      expect(
        AdaptiveCoaching.normalize(
          input: AdaptiveCoachingInput(
            items: withMatter.items,
            relationships: withMatter.relationships,
            primaryEvidenceCount: 3,
          ),
          items: after,
        ).length,
        before.length,
      );
    });

    test('13. existing metadata TIME/SPACE behavior remains unchanged', () {
      final now = DateTime(2026, 8, 14, 10, 2);
      final signals = [
        _signal(
          id: 'a',
          capturedAt: now,
          latitude: 27.7,
          longitude: 85.3,
        ),
        _signal(
          id: 'b',
          kindLabel: 'video',
          capturedAt: now.add(const Duration(seconds: 12)),
          latitude: 27.70015,
          longitude: 85.3,
        ),
      ];
      final heuristic = HeuristicRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: signals,
      );
      final composed = ComposedRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: signals,
      );

      expect(composed.length, heuristic.length);
      for (var i = 0; i < heuristic.length; i++) {
        expect(composed[i].id, heuristic[i].id);
        expect(composed[i].source, RelationshipSuggestionSource.metadata);
        expect(composed[i].relationshipType, heuristic[i].relationshipType);
        expect(composed[i].confidence, heuristic[i].confidence);
        expect(composed[i].reason, heuristic[i].reason);
      }
    });

    test('14. user-created SUPPORTS remains structural', () {
      const incidentId = 'inc';
      final photo = _item(id: 'photo', incidentId: incidentId);
      final note = _item(
        id: 'note',
        incidentId: incidentId,
        kind: WorkspaceEvidenceKind.note,
      );
      final supports = EvidenceRelationship(
        id: 'user-supports',
        sourceEvidenceId: 'note',
        targetEvidenceId: 'photo',
        type: RelationshipType.supports,
        createdAt: DateTime(2026, 8, 14),
        source: 'user',
      );
      expect(
        EvidenceSemantics.structurallySupports(
          child: note,
          parentId: photo.id,
          relationships: [supports],
        ),
        isTrue,
      );
      expect(EvidenceSemantics.isSuggestedRelated(supports), isFalse);
    });

    test('15. suggested RELATED remains distinguishable from user RELATED', () {
      final metadata = EvidenceRelationship(
        id: 'meta',
        sourceEvidenceId: 'a',
        targetEvidenceId: 'b',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'metadata',
        reason: 'Related because these were captured 12 seconds apart.',
      );
      final matter = EvidenceRelationship(
        id: 'ai',
        sourceEvidenceId: 'a',
        targetEvidenceId: 'c',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'ai',
        reason:
            'Suggested relationship because both items contain similar content.',
      );
      final user = EvidenceRelationship(
        id: 'user',
        sourceEvidenceId: 'a',
        targetEvidenceId: 'd',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'user',
      );
      expect(EvidenceSemantics.isSuggestedRelated(metadata), isTrue);
      expect(EvidenceSemantics.isSuggestedRelated(matter), isTrue);
      expect(EvidenceSemantics.isSuggestedRelated(user), isFalse);
      expect(EvidenceSemantics.isExplicitUserRelationship(user), isTrue);
    });

    test('16. Photo + Video + Voice with Matter does not claim defects', () {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final video = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.voice);
      controller.relationshipRepository.linkEvidence(
        sourceEvidenceId: photo,
        targetEvidenceId: video,
        type: RelationshipType.relatedTo,
        source: 'ai',
        reason:
            'Suggested relationship because both items appear to contain the same object.',
      );

      final coaching = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      _forbidContractViolations([
        for (final item in coaching) ...[item.observation, item.suggestedAction],
      ]);
      expect(EvidenceSemantics.primaryChronologyCount(
        controller.currentIncident.evidence,
      ), 3);
    });

    test('composer drops SUPPORTS if a Matter provider emits it', () {
      final suggestions = ComposedRelationshipProvider(
        matterProvider: _SupportsMatterProvider(),
      ).suggest(
        incidentId: 'inc',
        signals: [
          _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10)),
          _signal(id: 'b', capturedAt: DateTime(2026, 8, 14, 11)),
        ],
      );
      expect(
        suggestions.where((s) => s.source == RelationshipSuggestionSource.ai),
        isEmpty,
      );
    });

    test('Matter stays suggestion-first under RelationshipEngine auto-accept', () {
      final controller = WorkspaceEvidenceController();
      final a = controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      final b = controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
      final engine = RelationshipEngine(
        provider: ComposedRelationshipProvider(
          matterProvider: ExplicitMatterRelationshipProvider(
            contentSignals: [
              MatterContentSignal(evidenceId: a, objectLabels: const ['Honda Civic']),
              MatterContentSignal(evidenceId: b, objectLabels: const ['Honda Civic']),
            ],
          ),
        ),
      );
      final result = engine.ensureRelationships(
        store: controller.aggregate.store,
        relationshipRepository: controller.relationshipRepository,
      );

      final matter = result.suggestions.where(
        (s) => s.source == RelationshipSuggestionSource.ai,
      );
      expect(matter, isNotEmpty);
      expect(
        matter.every((s) => s.status == RelationshipSuggestionStatus.suggested),
        isTrue,
      );
      expect(matter.every((s) => s.confidence < 0.7), isTrue);
      expect(
        controller.relationshipRepository.all.every((rel) => rel.source != 'ai'),
        isTrue,
      );

      final presentation = ConnectionsPresentationMapper.build(
        incidentId: controller.currentIncident.id,
        items: controller.currentIncident.evidence,
        relationships: controller.relationshipRepository.all,
        collections: const [],
        groupNodes: const [],
        suggestions: result.suggestions,
      );
      expect(
        presentation.suggested.any(
          (pair) => pair.kind == ConnectionsPairKind.suggested,
        ),
        isTrue,
      );
      expect(
        presentation.suggested.any(
          (pair) => (pair.detail ?? '').toLowerCase().contains('honda civic'),
        ),
        isTrue,
      );
    });

    test('empty content signals do not invent Matter intelligence', () {
      final suggestions = ExplicitMatterRelationshipProvider(
        contentSignals: const [
          MatterContentSignal(evidenceId: 'a'),
          MatterContentSignal(evidenceId: 'b'),
        ],
      ).suggestRelated(
        incidentId: 'inc',
        captureSignals: [
          _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10)),
          _signal(id: 'b', capturedAt: DateTime(2026, 8, 14, 10, 1)),
        ],
      );
      expect(suggestions, isEmpty);
    });
  });
}

class _SupportsMatterProvider implements MatterRelationshipProvider {
  @override
  List<RelationshipSuggestion> suggestRelated({
    required String incidentId,
    required List<RelationshipEvidenceSignal> captureSignals,
  }) {
    if (captureSignals.length < 2) {
      return const [];
    }
    return [
      RelationshipSuggestion(
        id: 'bad',
        incidentId: incidentId,
        sourceEvidenceId: captureSignals[0].evidenceId,
        targetEvidenceId: captureSignals[1].evidenceId,
        relationshipType: RelationshipType.supports.name,
        confidence: 0.99,
        reason: 'Suggested relationship because both items contain similar content.',
        source: RelationshipSuggestionSource.ai,
        status: RelationshipSuggestionStatus.suggested,
        createdAt: DateTime(2026, 8, 14),
      ),
    ];
  }
}
