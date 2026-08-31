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
  String? notePreview,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    incidentId: incidentId,
    kind: kind,
    title: '$kind $id',
    lastPreservedAt: DateTime(2026, 8, 14, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    notePreview: notePreview,
  );
}

RelationshipEvidenceSignal _signal({
  required String id,
  required DateTime capturedAt,
  String kindLabel = 'photo',
  double? latitude,
  double? longitude,
}) {
  return RelationshipEvidenceSignal(
    evidenceId: id,
    kindLabel: kindLabel,
    capturedAt: capturedAt,
    latitude: latitude,
    longitude: longitude,
  );
}

List<RelationshipSuggestion> _matterOnly({
  required List<MatterContentSignal> content,
  DateTime? capturedA,
  DateTime? capturedB,
  double? latA,
  double? lonA,
  double? latB,
  double? lonB,
}) {
  final now = DateTime(2026, 8, 14, 10, 2);
  return ComposedRelationshipProvider(
    matterProvider: ExplicitMatterRelationshipProvider(contentSignals: content),
  ).suggest(
    incidentId: 'inc',
    signals: [
      _signal(
        id: content[0].evidenceId,
        capturedAt: capturedA ?? now,
        latitude: latA,
        longitude: lonA,
      ),
      _signal(
        id: content[1].evidenceId,
        kindLabel: 'video',
        capturedAt: capturedB ?? now.add(const Duration(days: 2)),
        latitude: latB,
        longitude: lonB,
      ),
    ],
  ).where((s) => s.source == RelationshipSuggestionSource.ai).toList();
}

void _assertHonestCopy(String text) {
  final lower = text.toLowerCase();
  expect(text, startsWith('Suggested relationship because'));
  expect(lower, isNot(contains('ai detected')));
  expect(lower, isNot(contains('ai believes')));
  expect(lower, isNot(contains('likely proves')));
  expect(lower, isNot(contains('proves')));
  expect(lower, isNot(contains('corroborat')));
  expect(lower, isNot(contains('same event')));
  expect(lower, isNot(contains('confirms')));
  expect(RegExp(r'\bsupports\b').hasMatch(lower), isFalse);
}

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
    InMemoryNarrativeEventRepository.resetForTests();
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
  });

  group('STEP 6B — Matter content intelligence contract', () {
    test('1. no Matter signals → zero Matter suggestions', () {
      final suggestions = ComposedRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: [
          _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10, 2)),
          _signal(
            id: 'b',
            capturedAt: DateTime(2026, 8, 14, 10, 2, 12),
          ),
        ],
      );
      expect(
        suggestions.where((s) => s.source == RelationshipSuggestionSource.ai),
        isEmpty,
      );
      expect(const DisabledMatterProvider().suggestRelated(
        incidentId: 'inc',
        captureSignals: const [],
      ), isEmpty);
    });

    test('2. explicit overlapping Matter signals → RELATED', () {
      final suggestions = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', placeMentions: ['Cafe X']),
          MatterContentSignal(evidenceId: 'b', placeMentions: ['Cafe X']),
        ],
      );
      expect(suggestions, hasLength(1));
      expect(suggestions.single.relationshipType, RelationshipType.relatedTo.name);
    });

    test('3. Matter suggestion source == ai', () {
      expect(
        _matterOnly(
          content: const [
            MatterContentSignal(evidenceId: 'a', namedEntities: ['Cafe X']),
            MatterContentSignal(evidenceId: 'b', namedEntities: ['Cafe X']),
          ],
        ).single.source,
        RelationshipSuggestionSource.ai,
      );
    });

    test('4. Matter suggestion is recognized as Suggested', () {
      final rel = EvidenceRelationship(
        id: 'rel',
        sourceEvidenceId: 'a',
        targetEvidenceId: 'b',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'ai',
        reason:
            'Suggested relationship because both items contain references to the same location.',
      );
      expect(EvidenceSemantics.isSuggestedRelated(rel), isTrue);
      expect(EvidenceSemantics.isExplicitUserRelationship(rel), isFalse);
    });

    test('5. Matter never emits SUPPORTS', () {
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
      expect(
        suggestions.every((s) => s.relationshipType == RelationshipType.relatedTo.name),
        isTrue,
      );
    });

    test('Matter never becomes Supporting evidence in Connections', () {
      final photo = _item(id: 'a', incidentId: 'inc');
      final video = _item(
        id: 'b',
        incidentId: 'inc',
        kind: WorkspaceEvidenceKind.video,
      );
      final suggestions = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
      );
      expect(suggestions, hasLength(1));
      expect(suggestions.single.relationshipType, RelationshipType.relatedTo.name);
      expect(suggestions.single.relationshipType, isNot(RelationshipType.supports.name));

      final persisted = EvidenceRelationship(
        id: 'rel-ai',
        sourceEvidenceId: 'a',
        targetEvidenceId: 'b',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'ai',
        reason: suggestions.single.reason,
      );
      expect(EvidenceSemantics.isSuggestedRelated(persisted), isTrue);
      expect(
        EvidenceSemantics.structurallySupports(
          child: video,
          parentId: photo.id,
          relationships: [persisted],
        ),
        isFalse,
      );
      expect(photo.parentEvidenceId, isNull);
      expect(video.parentEvidenceId, isNull);

      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc',
        items: [photo, video],
        relationships: [persisted],
        collections: const [],
        groupNodes: const [],
        suggestions: suggestions,
      );
      expect(presentation.suggested, isNotEmpty);
      expect(
        presentation.suggested.every(
          (pair) =>
              pair.kind == ConnectionsPairKind.suggested &&
              pair.label == 'Suggested relationship',
        ),
        isTrue,
      );
      expect(presentation.supporting, isEmpty);
      expect(
        presentation.suggested.any((pair) => pair.label == 'Supporting evidence'),
        isFalse,
      );
    });

    test('6. Matter never emits corroboration', () {
      expect(
        RelationshipType.values.map((t) => t.name),
        isNot(contains('corroborates')),
      );
      final reason = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', topics: ['lease agreement']),
          MatterContentSignal(evidenceId: 'b', topics: ['lease agreement']),
        ],
      ).single.reason;
      expect(reason.toLowerCase(), isNot(contains('corroborat')));
    });

    test('Matter overlap stays RELATED and is not corroboration', () {
      expect(
        RelationshipType.values.map((t) => t.name),
        isNot(contains('corroborates')),
      );
      final photo = _item(id: 'a', incidentId: 'inc');
      final video = _item(
        id: 'b',
        incidentId: 'inc',
        kind: WorkspaceEvidenceKind.video,
      );
      final suggestions = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
      );
      expect(suggestions, hasLength(1));
      expect(suggestions.single.relationshipType, RelationshipType.relatedTo.name);
      _assertHonestCopy(suggestions.single.reason);
      expect(suggestions.single.reason.toLowerCase(), isNot(contains('confirm')));
      expect(
        suggestions.single.reason.toLowerCase(),
        isNot(contains('independently')),
      );

      final persisted = EvidenceRelationship(
        id: 'rel-ai',
        sourceEvidenceId: 'a',
        targetEvidenceId: 'b',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'ai',
        reason: suggestions.single.reason,
      );
      expect(EvidenceSemantics.isSuggestedRelated(persisted), isTrue);
      expect(persisted.type, isNot(equals('corroborates')));

      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc',
        items: [photo, video],
        relationships: [persisted],
        collections: const [],
        groupNodes: const [],
        suggestions: suggestions,
      );
      expect(presentation.suggested.single.label, 'Suggested relationship');
      expect(presentation.supporting, isEmpty);
      expect(
        [
          ...presentation.suggested.map((pair) => pair.label),
          ...presentation.linked.map((pair) => pair.label),
        ].join(' ').toLowerCase(),
        isNot(contains('corroborat')),
      );
    });

    test('7. Matter never designates primary', () {
      final note = _item(
        id: 'note',
        incidentId: 'inc',
        kind: WorkspaceEvidenceKind.note,
      );
      final file = _item(
        id: 'file',
        incidentId: 'inc',
        kind: WorkspaceEvidenceKind.attachment,
      );
      final photo = _item(id: 'photo', incidentId: 'inc');
      final before = EvidenceSemantics.primaryChronologyCount([note, file, photo]);
      expect(EvidenceSemantics.isPrimaryChronologyEvidence(note), isFalse);
      expect(EvidenceSemantics.isPrimaryChronologyEvidence(file), isFalse);
      expect(EvidenceSemantics.isPrimaryChronologyEvidence(photo), isTrue);

      final suggestions = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'note', topics: ['lease agreement']),
          MatterContentSignal(evidenceId: 'file', topics: ['lease agreement']),
        ],
      );
      expect(suggestions, isNotEmpty);
      expect(suggestions.single.relationshipType, RelationshipType.relatedTo.name);
      expect(EvidenceSemantics.isPrimaryChronologyEvidence(note), isFalse);
      expect(EvidenceSemantics.isPrimaryChronologyEvidence(file), isFalse);
      expect(EvidenceSemantics.isPrimaryChronologyEvidence(photo), isTrue);
      expect(
        EvidenceSemantics.primaryChronologyCount([note, file, photo]),
        before,
      );
    });

    test('Matter facts do not become recorded context', () {
      final photo = _item(id: 'a', incidentId: 'inc');
      final video = _item(
        id: 'b',
        incidentId: 'inc',
        kind: WorkspaceEvidenceKind.video,
      );
      final suggestions = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
      );
      final matter = EvidenceRelationship(
        id: 'rel-ai',
        sourceEvidenceId: 'a',
        targetEvidenceId: 'b',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'ai',
        reason: suggestions.single.reason,
      );
      expect(suggestions, isNotEmpty);
      expect(photo.isContextual, isFalse);
      expect(EvidenceSemantics.hasLocation(photo), isFalse);
      expect(EvidenceSemantics.hasWrittenDescription(photo), isFalse);
      expect(EvidenceSemantics.hasRecordedContext(photo), isFalse);
      expect(
        EvidenceSemantics.hasRecordedContext(
          photo,
          incidentItems: [photo, video],
          relationships: [matter],
        ),
        isFalse,
      );
      expect(
        EnrichmentEngine.isEnriched(
          photo,
          EnrichmentContext(items: [photo, video], relationships: [matter]),
        ),
        isFalse,
      );

      final described = _item(
        id: 'a',
        incidentId: 'inc',
        notePreview: 'Red Honda Civic at the gate',
      );
      expect(
        EvidenceSemantics.hasRecordedContext(
          described,
          incidentItems: [described, video],
          relationships: [matter],
        ),
        isTrue,
      );
    });

    test('8. Matter never creates witness status', () {
      final photo = _item(id: 'photo', incidentId: 'inc');
      final video = _item(
        id: 'video',
        incidentId: 'inc',
        kind: WorkspaceEvidenceKind.video,
      );
      final items = [photo, video];
      final suggestions = _matterOnly(
        content: const [
          MatterContentSignal(
            evidenceId: 'photo',
            namedEntities: ['John Smith'],
          ),
          MatterContentSignal(
            evidenceId: 'video',
            namedEntities: ['John Smith'],
          ),
        ],
      );
      expect(suggestions, hasLength(1));
      expect(suggestions.single.relationshipType, RelationshipType.relatedTo.name);
      expect(suggestions.single.reason, contains('John Smith'));
      expect(suggestions.single.reason.toLowerCase(), isNot(contains('witness')));
      expect(photo.kind, isNot(WorkspaceEvidenceKind.witness));
      expect(video.kind, isNot(WorkspaceEvidenceKind.witness));
      expect(EvidenceSemantics.hasWitnessKind(items), isFalse);
      expect(photo.relatedPersonRole, isNull);
      expect(video.relatedPersonRole, isNull);

      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc',
        items: items,
        relationships: const [],
        collections: const [],
        groupNodes: const [],
        suggestions: suggestions,
      );
      expect(presentation.suggested.single.label, 'Suggested relationship');
      expect(
        presentation.suggested.single.detail?.toLowerCase() ?? '',
        isNot(contains('witness')),
      );
    });

    test('9. Matter does not enrich Journey', () {
      const incidentId = 'inc';
      final items = [
        _item(id: 'photo', incidentId: incidentId),
        _item(
          id: 'video',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.video,
        ),
      ];
      final before = EnrichmentEngine.compute(
        EnrichmentContext(items: items, relationships: const []),
      );
      expect(before.journeyStage, isNot(JourneyStage.rich));

      final suggestions = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'photo', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'video', objectLabels: ['Honda Civic']),
        ],
      );
      final matter = EvidenceRelationship(
        id: 'rel-ai',
        sourceEvidenceId: 'photo',
        targetEvidenceId: 'video',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 14),
        source: 'ai',
        reason: suggestions.single.reason,
      );
      final context = EnrichmentContext(items: items, relationships: [matter]);
      expect(context.signalsFor('photo').hasAiEnrichment, isFalse);
      expect(context.signalsFor('video').hasAiEnrichment, isFalse);
      expect(context.signalsFor('photo').hasAny, isFalse);

      final after = EnrichmentEngine.compute(context);
      expect(after.enrichedEvidenceCount, before.enrichedEvidenceCount);
      expect(after.enrichmentPercentage, before.enrichmentPercentage);
      expect(after.journeyStage, before.journeyStage);
      expect(after.journeyStage, isNot(JourneyStage.rich));
      expect(EnrichmentEngine.isEnriched(items.first, context), isFalse);
    });

    test('10. Matter does not trigger Adaptive Coaching defects', () {
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
      InvestigationCoachingContext ctx({
        List<EvidenceRelationship> relationships = const [],
      }) {
        return InvestigationCoachingContext(
          incidentId: incidentId,
          items: items,
          timelineNodes: const [],
          narrativeEvents: const [],
          relationships: relationships,
          groupMemberEvidenceIds: const {},
          primaryEvidenceCount: 3,
          enrichedEvidenceCount: 0,
          trustPackageQuality: quality,
        );
      }

      final before = InvestigationCoachingEngine.generate(ctx());
      final after = InvestigationCoachingEngine.generate(
        ctx(
          relationships: [
            EvidenceRelationship(
              id: 'rel-ai',
              sourceEvidenceId: 'photo',
              targetEvidenceId: 'video',
              type: RelationshipType.relatedTo,
              createdAt: DateTime(2026, 8, 14),
              source: 'ai',
              reason:
                  'Suggested relationship because both items contain references to the same location.',
            ),
          ],
        ),
      );
      expect(
        after.map((i) => i.fingerprint),
        before.map((i) => i.fingerprint),
      );
      expect(
        AdaptiveCoaching.normalize(
          input: AdaptiveCoachingInput(
            items: items,
            relationships: [
              EvidenceRelationship(
                id: 'rel-ai',
                sourceEvidenceId: 'photo',
                targetEvidenceId: 'video',
                type: RelationshipType.relatedTo,
                createdAt: DateTime(2026, 8, 14),
                source: 'ai',
                reason:
                    'Suggested relationship because both items contain references to the same location.',
              ),
            ],
            primaryEvidenceCount: 3,
          ),
          items: after,
        ).length,
        before.length,
      );
    });

    test('11. because-explanation is mandatory', () {
      final suggestion = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', placeMentions: ['Cafe X']),
          MatterContentSignal(evidenceId: 'b', placeMentions: ['Cafe X']),
        ],
      ).single;
      _assertHonestCopy(suggestion.reason);
      expect(suggestion.matterExplanation, isNotEmpty);
    });

    test('12. independent Matter clauses are preserved', () {
      final suggestion = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
      ).single;
      expect(suggestion.matterExplanation, isNotNull);
      expect(suggestion.timeExplanation, isNull);
      expect(suggestion.spaceExplanation, isNull);
    });

    test('13. TIME clause can coexist with Matter clause', () {
      final suggestion = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
        capturedA: DateTime(2026, 8, 14, 10, 2, 14),
        capturedB: DateTime(2026, 8, 14, 10, 2, 47),
      ).single;
      expect(suggestion.timeExplanation, isNotNull);
      expect(suggestion.matterExplanation, isNotNull);
      expect(suggestion.timeExplanation, contains('seconds apart'));
      expect(suggestion.reason, contains('seconds apart'));
      _assertHonestCopy(suggestion.reason);
    });

    test('14. SPACE clause can coexist with Matter clause', () {
      final suggestion = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', placeMentions: ['Cafe X']),
          MatterContentSignal(evidenceId: 'b', placeMentions: ['Cafe X']),
        ],
        capturedA: DateTime(2026, 8, 14, 10),
        capturedB: DateTime(2026, 8, 14, 12),
        latA: 27.7,
        lonA: 85.3,
        latB: 27.70015,
        lonB: 85.3,
      ).single;
      expect(suggestion.spaceExplanation, isNotNull);
      expect(suggestion.matterExplanation, isNotNull);
      expect(suggestion.spaceExplanation, contains('metres apart'));
      expect(suggestion.reason, contains('metres apart'));
      _assertHonestCopy(suggestion.reason);
    });

    test('independent TIME SPACE MATTER explanations stay separate', () {
      final suggestion = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
        capturedA: DateTime(2026, 8, 14, 10, 2),
        capturedB: DateTime(2026, 8, 14, 10, 2, 30),
        latA: 27.7,
        lonA: 85.3,
        latB: 27.700359,
        lonB: 85.3,
      ).single;

      expect(suggestion.matterExplanation, 'both records reference Honda Civic');
      expect(suggestion.timeExplanation, 'Captured 30 seconds apart');
      expect(suggestion.spaceExplanation, contains('metres apart'));
      expect(suggestion.spaceExplanation, isNot(equals(suggestion.timeExplanation)));
      expect(suggestion.spaceExplanation, isNot(equals(suggestion.matterExplanation)));
      expect(suggestion.reason, startsWith('Suggested relationship because'));
      expect(suggestion.reason, contains('Honda Civic'));
      expect(suggestion.reason, contains('30 seconds'));
      expect(suggestion.reason, contains('metres'));
      _assertHonestCopy(suggestion.reason);
    });

    test('15. TIME + SPACE + MATTER remains RELATED only', () {
      final suggestions = ComposedRelationshipProvider(
        matterProvider: const ExplicitMatterRelationshipProvider(
          contentSignals: [
            MatterContentSignal(evidenceId: 'a', placeMentions: ['Cafe X']),
            MatterContentSignal(evidenceId: 'b', placeMentions: ['Cafe X']),
          ],
        ),
      ).suggest(
        incidentId: 'inc',
        signals: [
          _signal(
            id: 'a',
            capturedAt: DateTime(2026, 8, 14, 10, 2, 14),
            latitude: 27.7,
            longitude: 85.3,
          ),
          _signal(
            id: 'b',
            kindLabel: 'video',
            capturedAt: DateTime(2026, 8, 14, 10, 2, 44),
            latitude: 27.70015,
            longitude: 85.3,
          ),
        ],
      );
      final matter = suggestions.where(
        (s) => s.source == RelationshipSuggestionSource.ai,
      );
      expect(matter, hasLength(1));
      expect(matter.single.relationshipType, RelationshipType.relatedTo.name);
      expect(matter.single.timeExplanation, isNotNull);
      expect(matter.single.spaceExplanation, isNotNull);
      expect(matter.single.matterExplanation, isNotNull);
      expect(
        suggestions.any((s) => s.relationshipType == RelationshipType.supports.name),
        isFalse,
      );
    });

    test('16. Matter confidence remains below metadata auto-accept', () {
      expect(ComposedRelationshipProvider.suggestionOnlyConfidenceCap, 0.69);
      expect(ExplicitMatterRelationshipProvider.matterOnlyConfidence, 0.55);
      expect(
        ComposedRelationshipProvider.suggestionOnlyConfidenceCap,
        lessThan(0.7),
      );

      final matterOnly = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
      ).single;
      expect(matterOnly.confidence, 0.55);
      expect(matterOnly.status, RelationshipSuggestionStatus.suggested);

      final strongest = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
        capturedA: DateTime(2026, 8, 14, 10, 2, 14),
        capturedB: DateTime(2026, 8, 14, 10, 2, 44),
        latA: 27.7,
        lonA: 85.3,
        latB: 27.70015,
        lonB: 85.3,
      ).single;
      expect(strongest.confidence, lessThanOrEqualTo(0.69));
      expect(strongest.confidence, lessThan(0.7));
      expect(strongest.status, RelationshipSuggestionStatus.suggested);
    });

    test('17. existing TIME/SPACE metadata suggestions remain unchanged', () {
      final signals = [
        _signal(
          id: 'a',
          capturedAt: DateTime(2026, 8, 14, 10, 2),
          latitude: 27.7,
          longitude: 85.3,
        ),
        _signal(
          id: 'b',
          kindLabel: 'video',
          capturedAt: DateTime(2026, 8, 14, 10, 2, 12),
          latitude: 27.70015,
          longitude: 85.3,
        ),
      ];
      final heuristic = HeuristicRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: signals,
      );
      final composed = ComposedRelationshipProvider(
        matterProvider: const ExplicitMatterRelationshipProvider(
          contentSignals: [
            MatterContentSignal(evidenceId: 'a', placeMentions: ['Cafe X']),
            MatterContentSignal(evidenceId: 'b', placeMentions: ['Cafe X']),
          ],
        ),
      ).suggest(incidentId: 'inc', signals: signals);
      final metadata = composed
          .where((s) => s.source == RelationshipSuggestionSource.metadata)
          .toList();
      expect(metadata.length, heuristic.length);
      for (var i = 0; i < heuristic.length; i++) {
        expect(metadata[i].id, heuristic[i].id);
        expect(metadata[i].confidence, heuristic[i].confidence);
        expect(metadata[i].reason, heuristic[i].reason);
      }
    });

    test('18. existing user SUPPORTS relationships remain unchanged', () {
      final photo = _item(id: 'photo', incidentId: 'inc');
      final note = _item(
        id: 'note',
        incidentId: 'inc',
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
    });

    test('19. empty Matter signals never produce invented suggestions', () {
      expect(
        ExplicitMatterRelationshipProvider(
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
        ),
        isEmpty,
      );
    });

    test('20. Matter stays suggestion-first without auto-accept', () {
      final controller = WorkspaceEvidenceController();
      final a = controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      final b = controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
      final result = RelationshipEngine(
        provider: ComposedRelationshipProvider(
          matterProvider: ExplicitMatterRelationshipProvider(
            contentSignals: [
              MatterContentSignal(evidenceId: a, placeMentions: const ['Cafe X']),
              MatterContentSignal(evidenceId: b, placeMentions: const ['Cafe X']),
            ],
          ),
        ),
      ).ensureRelationships(
        store: controller.aggregate.store,
        relationshipRepository: controller.relationshipRepository,
      );
      expect(
        result.suggestions
            .where((s) => s.source == RelationshipSuggestionSource.ai)
            .every((s) => s.status == RelationshipSuggestionStatus.suggested),
        isTrue,
      );
      expect(
        controller.relationshipRepository.all.every((rel) => rel.source != 'ai'),
        isTrue,
      );
    });

    test('TIME alone remains TIME metadata, not Matter', () {
      final now = DateTime(2026, 8, 14, 10, 2);
      List<RelationshipEvidenceSignal> pair(Duration delta) => [
            _signal(id: 'a', capturedAt: now),
            _signal(
              id: 'b',
              kindLabel: 'video',
              capturedAt: now.add(delta),
            ),
          ];

      final thirtySeconds = pair(const Duration(seconds: 30));
      final heuristic = HeuristicRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: thirtySeconds,
      );
      final composed = ComposedRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: thirtySeconds,
      );

      expect(composed.length, heuristic.length);
      expect(
        composed.where((s) => s.source == RelationshipSuggestionSource.ai),
        isEmpty,
      );
      expect(composed, isNotEmpty);
      expect(
        composed.every((s) => s.source == RelationshipSuggestionSource.metadata),
        isTrue,
      );
      expect(
        composed.every((s) => s.status == RelationshipSuggestionStatus.suggested),
        isTrue,
      );
      expect(
        composed.single.reason,
        'Related because these were captured 30 seconds apart.',
      );
      expect(composed.single.reason.toLowerCase(), isNot(contains('same object')));
      expect(composed.single.reason.toLowerCase(), isNot(contains('same thing')));
      expect(composed.single.confidence, heuristic.single.confidence);

      final atThreshold = ComposedRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: pair(const Duration(seconds: 90)),
      );
      expect(
        atThreshold.where((s) => s.source == RelationshipSuggestionSource.metadata),
        isNotEmpty,
      );
      expect(
        atThreshold.single.reason,
        contains('90 seconds apart'),
      );

      final beyondThreshold = ComposedRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: pair(const Duration(seconds: 91)),
      );
      expect(beyondThreshold, isEmpty);
    });

    test('GPS alone is SPACE metadata, not Matter', () {
      final signals = [
        _signal(
          id: 'a',
          capturedAt: DateTime(2026, 8, 12, 10),
          latitude: 27.7,
          longitude: 85.3,
        ),
        _signal(
          id: 'b',
          kindLabel: 'video',
          capturedAt: DateTime(2026, 8, 14, 10),
          latitude: 27.7,
          longitude: 85.3,
        ),
      ];
      final composed = ComposedRelationshipProvider().suggest(
        incidentId: 'inc',
        signals: signals,
      );
      final matter = composed.where(
        (s) => s.source == RelationshipSuggestionSource.ai,
      );
      final space = composed.where(
        (s) => s.source == RelationshipSuggestionSource.metadata,
      );
      expect(matter, isEmpty);
      expect(space, isNotEmpty);
      expect(
        space.every((s) => s.status == RelationshipSuggestionStatus.suggested),
        isTrue,
      );
      expect(
        space.any((s) => s.reason.contains('near the same location')),
        isTrue,
      );
      for (final suggestion in composed) {
        final lower = suggestion.reason.toLowerCase();
        expect(lower, isNot(contains('same object')));
        expect(lower, isNot(contains('same thing')));
        expect(lower, isNot(contains('contain the same')));
      }
      expect(
        ExplicitMatterRelationshipProvider(
          contentSignals: const [
            MatterContentSignal(evidenceId: 'a', placeMentions: ['27.7, 85.3']),
            MatterContentSignal(evidenceId: 'b', placeMentions: ['27.7, 85.3']),
          ],
        ).suggestRelated(incidentId: 'inc', captureSignals: signals),
        isEmpty,
        reason: 'GPS coordinates must not become Matter place mentions',
      );
    });

    test('filename alone does not become Matter', () {
      const hondaFile = 'IMG_20260815_Honda.jpg';
      expect(
        ExplicitMatterRelationshipProvider().suggestRelated(
          incidentId: 'inc',
          captureSignals: [
            _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10)),
            _signal(id: 'b', capturedAt: DateTime(2026, 8, 14, 10, 1)),
          ],
        ),
        isEmpty,
      );
      expect(
        ExplicitMatterRelationshipProvider(
          contentSignals: const [
            MatterContentSignal(evidenceId: 'a', objectLabels: [hondaFile]),
            MatterContentSignal(evidenceId: 'b', objectLabels: [hondaFile]),
          ],
        ).suggestRelated(
          incidentId: 'inc',
          captureSignals: [
            _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10)),
            _signal(id: 'b', capturedAt: DateTime(2026, 8, 14, 10, 1)),
          ],
        ),
        isEmpty,
        reason: 'filename must not become Matter object Honda',
      );
      expect(
        _matterOnly(
          content: const [
            MatterContentSignal(evidenceId: 'a'),
            MatterContentSignal(evidenceId: 'b'),
          ],
        ),
        isEmpty,
      );
    });

    test('generic tokens such as car or incident do not create Matter RELATED', () {
      const genericFacts = [
        'car',
        'incident',
        'vehicle',
        'person',
        'photo',
        'document',
        'event',
      ];
      for (final token in genericFacts) {
        expect(
          ExplicitMatterRelationshipProvider(
            contentSignals: [
              MatterContentSignal(evidenceId: 'a', objectLabels: [token]),
              MatterContentSignal(evidenceId: 'b', objectLabels: [token]),
            ],
          ).suggestRelated(
            incidentId: 'inc',
            captureSignals: [
              _signal(id: 'a', capturedAt: DateTime(2026, 8, 14, 10)),
              _signal(id: 'b', capturedAt: DateTime(2026, 8, 14, 10, 1)),
            ],
          ),
          isEmpty,
          reason: 'generic object "$token" must not create Matter RELATED',
        );
        expect(
          _matterOnly(
            content: [
              MatterContentSignal(evidenceId: 'a', topics: [token]),
              MatterContentSignal(evidenceId: 'b', topics: [token]),
            ],
          ),
          isEmpty,
          reason: 'generic topic "$token" must not create Matter RELATED',
        );
      }
    });

    test('Cafe X two days apart is RELATED, not same event', () {
      final suggestion = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', placeMentions: ['Cafe X']),
          MatterContentSignal(evidenceId: 'b', placeMentions: ['Cafe X']),
        ],
        capturedA: DateTime(2026, 8, 12, 10),
        capturedB: DateTime(2026, 8, 14, 10),
      ).single;
      _assertHonestCopy(suggestion.reason);
      expect(suggestion.timeExplanation, isNull);
    });

    test('Matter explanations forbid proof and corroboration language', () {
      final honest = _matterOnly(
        content: const [
          MatterContentSignal(evidenceId: 'a', objectLabels: ['Honda Civic']),
          MatterContentSignal(evidenceId: 'b', objectLabels: ['Honda Civic']),
        ],
      ).single;
      expect(
        honest.reason,
        'Suggested relationship because both records reference Honda Civic.',
      );
      _assertHonestCopy(honest.reason);

      const forbidden = [
        'corroborates',
        'proves',
        'same event',
        'AI detected',
        'supports',
        'confirms',
      ];
      for (final phrase in forbidden) {
        final suggestions = ComposedRelationshipProvider(
          matterProvider: _PhraseMatterProvider(phrase),
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
          reason: 'Matter must drop copy that claims "$phrase"',
        );
      }
    });

    test('composer drops Matter copy that claims proof or corroboration', () {
      final suggestions = ComposedRelationshipProvider(
        matterProvider: _ForbiddenCopyMatterProvider(),
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

    test('Photo + Video + Voice with Matter remains three primaries', () {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.preserveEvidence(WorkspaceCaptureMode.voice);
      expect(
        EvidenceSemantics.primaryChronologyCount(
          controller.currentIncident.evidence,
        ),
        3,
      );
    });
  });
}

class _PhraseMatterProvider implements MatterRelationshipProvider {
  const _PhraseMatterProvider(this.phrase);

  final String phrase;

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
        id: 'bad-copy-$phrase',
        incidentId: incidentId,
        sourceEvidenceId: captureSignals[0].evidenceId,
        targetEvidenceId: captureSignals[1].evidenceId,
        relationshipType: RelationshipType.relatedTo.name,
        confidence: 0.55,
        reason: 'Suggested relationship because this $phrase the record.',
        source: RelationshipSuggestionSource.ai,
        status: RelationshipSuggestionStatus.suggested,
        createdAt: DateTime(2026, 8, 14),
        matterExplanation: 'this $phrase the record',
      ),
    ];
  }
}

class _ForbiddenCopyMatterProvider implements MatterRelationshipProvider {
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
        id: 'bad-copy',
        incidentId: incidentId,
        sourceEvidenceId: captureSignals[0].evidenceId,
        targetEvidenceId: captureSignals[1].evidenceId,
        relationshipType: RelationshipType.relatedTo.name,
        confidence: 0.55,
        reason: 'Suggested relationship because these photos corroborate the same event.',
        source: RelationshipSuggestionSource.ai,
        status: RelationshipSuggestionStatus.suggested,
        createdAt: DateTime(2026, 8, 14),
        matterExplanation: 'these photos corroborate the same event',
      ),
    ];
  }
}
