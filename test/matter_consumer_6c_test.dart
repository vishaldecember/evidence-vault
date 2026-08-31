import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/relationship/relationship_suggestion.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/domain/risk/incident_risk_assessment.dart';
import 'package:evidence_vault/engines/adaptive_coaching.dart';
import 'package:evidence_vault/engines/enrichment_engine.dart';
import 'package:evidence_vault/engines/evidence_semantics.dart';
import 'package:evidence_vault/engines/investigation_coaching_engine.dart';
import 'package:evidence_vault/mappers/connections_presentation_mapper.dart';
import 'package:evidence_vault/models/connections_presentation.dart';
import 'package:evidence_vault/models/evidence_record_model.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/relationship/composed_relationship_provider.dart';
import 'package:evidence_vault/services/relationship/explicit_matter_relationship_provider.dart';
import 'package:evidence_vault/services/relationship/relationship_engine.dart';
import 'package:evidence_vault/services/risk/deterministic_risk_assessment_provider.dart';
import 'package:evidence_vault/services/risk/risk_assessment_provider.dart';
import 'package:evidence_vault/services/risk/risk_coach_preferences.dart';
import 'package:evidence_vault/services/trust_package_scorecard_service.dart';
import 'package:evidence_vault/story/story_builder.dart';
import 'package:evidence_vault/domain/matter/matter_content_signal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? parentEvidenceId,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    incidentId: 'inc-1',
    kind: kind,
    title: '$kind $id',
    lastPreservedAt: DateTime(2026, 8, 14, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
  );
}

EvidenceRelationship _rel({
  required String id,
  required String from,
  required String to,
  RelationshipType type = RelationshipType.relatedTo,
  String? source,
  String? reason,
}) {
  return EvidenceRelationship(
    id: id,
    sourceEvidenceId: from,
    targetEvidenceId: to,
    type: type,
    createdAt: DateTime(2026, 8, 14),
    source: source,
    reason: reason,
  );
}

RelationshipSuggestion _aiSuggested({
  required String from,
  required String to,
}) {
  return RelationshipSuggestion(
    id: 'sug-ai',
    incidentId: 'inc-1',
    sourceEvidenceId: from,
    targetEvidenceId: to,
    relationshipType: RelationshipType.relatedTo.name,
    confidence: 0.55,
    reason:
        'Suggested relationship because both items contain references to the same location.',
    source: RelationshipSuggestionSource.ai,
    status: RelationshipSuggestionStatus.suggested,
    createdAt: DateTime(2026, 8, 14),
    matterExplanation: 'both items contain references to the same location',
  );
}

RiskAssessmentContext _riskContext({
  required List<WorkspaceEvidenceItem> evidence,
  List<EvidenceRelationship> relationships = const [],
  List<RelationshipSuggestion> suggestions = const [],
}) {
  final byId = {for (final item in evidence) item.id: item};
  return RiskAssessmentContext(
    incidentId: 'inc-1',
    incidentTitle: 'Incident',
    journeyStage: JourneyStage.building,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
    now: DateTime(2026, 8, 8),
    evidence: evidence,
    capturedEvidence: const [],
    relationships: relationships,
    collections: const [],
    graph: InvestigationGraphView(
      primaryEvidenceIds: [
        for (final item in evidence)
          if (EvidenceSemantics.isPrimaryChronologyEvidence(item)) item.id,
      ],
      supportingByPrimaryId: const {},
      edges: const [],
      collections: const [],
      evidenceById: byId,
    ),
    relationshipSuggestions: suggestions,
    narrativeEventCount: 0,
    dismissedIds: const {},
    reviewedIds: const {},
    librarySummaries: const [],
    memoryRecallHints: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RiskCoachPreferences.instance.resetForTests();
  });

  final photo = _item(id: 'photo');
  final video = _item(id: 'video', kind: WorkspaceEvidenceKind.video);
  final voice = _item(id: 'voice', kind: WorkspaceEvidenceKind.voice);
  final note = _item(id: 'note', kind: WorkspaceEvidenceKind.note);

  test('1. pending ai RELATED does not create Risk Coach documentation gap',
      () async {
    final items = await const DeterministicRiskAssessmentProvider().assess(
      _riskContext(
        evidence: [photo, video],
        suggestions: [_aiSuggested(from: 'photo', to: 'video')],
      ),
    );
    expect(
      items.any((item) => item.riskType == RiskType.relationshipGap),
      isFalse,
    );
    expect(
      items.any((item) => item.riskType == RiskType.missingEvidence),
      isFalse,
    );
    expect(
      items.any(
        (item) => item.reason.contains(
          'suggested between evidence items but has not been reviewed',
        ),
      ),
      isFalse,
    );
  });

  test('2. pending ai RELATED does not create missing-support warning',
      () async {
    final items = await const DeterministicRiskAssessmentProvider().assess(
      _riskContext(
        evidence: [photo, video],
        relationships: [
          _rel(
            id: 'ai',
            from: 'photo',
            to: 'video',
            source: 'ai',
            reason:
                'Suggested relationship because both items contain references to the same location.',
          ),
        ],
        suggestions: [_aiSuggested(from: 'photo', to: 'video')],
      ),
    );
    expect(
      items.any(
        (item) =>
            item.reason.toLowerCase().contains('supporting') &&
            item.riskType == RiskType.missingEvidence,
      ),
      isFalse,
    );
    expect(
      EvidenceSemantics.hasStructuralSupport(
        evidenceId: 'photo',
        items: [photo, video],
        relationships: [
          _rel(id: 'ai', from: 'photo', to: 'video', source: 'ai'),
        ],
      ),
      isFalse,
    );
  });

  test('6C-2 Risk Coach ignores unreviewed Matter suggestions', () async {
    final withoutMatter = await const DeterministicRiskAssessmentProvider()
        .assess(_riskContext(evidence: [photo, video]));
    final withMatter = await const DeterministicRiskAssessmentProvider().assess(
      _riskContext(
        evidence: [photo, video],
        relationships: [
          _rel(
            id: 'ai',
            from: 'photo',
            to: 'video',
            source: 'ai',
            reason:
                'Suggested relationship because both records reference Honda Civic.',
          ),
        ],
        suggestions: [_aiSuggested(from: 'photo', to: 'video')],
      ),
    );

    expect(
      withMatter.map((item) => item.riskType).toSet(),
      withoutMatter.map((item) => item.riskType).toSet(),
    );
    expect(
      withMatter.any((item) => item.riskType == RiskType.relationshipGap),
      isFalse,
    );
    for (final item in withMatter) {
      final lower = item.reason.toLowerCase();
      expect(lower, isNot(contains('this evidence is connected')));
      expect(lower, isNot(contains('is connected')));
      expect(
        lower,
        isNot(contains('suggested between evidence items but has not been reviewed')),
      );
    }
    expect(
      EvidenceSemantics.hasStructuralSupport(
        evidenceId: 'photo',
        items: [photo, video],
        relationships: [
          _rel(id: 'ai', from: 'photo', to: 'video', source: 'ai'),
        ],
      ),
      isFalse,
    );
  });

  test('6C-1 Connections mapping isolates Matter as Suggested', () {
    ConnectionsPresentation present({
      List<EvidenceRelationship> relationships = const [],
      List<RelationshipSuggestion> suggestions = const [],
      List<WorkspaceEvidenceItem>? items,
    }) {
      return ConnectionsPresentationMapper.build(
        incidentId: 'inc-1',
        items: items ?? [photo, video],
        relationships: relationships,
        collections: const [],
        groupNodes: const [],
        suggestions: suggestions,
      );
    }

    void expectNoCorroboration(ConnectionsPresentation presentation) {
      final labels = [
        ...presentation.suggested.map((pair) => pair.label),
        ...presentation.linked.map((pair) => pair.label),
        ...presentation.supporting.map((pair) => pair.label),
      ].join(' ').toLowerCase();
      expect(labels, isNot(contains('corroborat')));
    }

    final pendingMatter = present(suggestions: [_aiSuggested(from: 'photo', to: 'video')]);
    expect(pendingMatter.suggested, hasLength(1));
    expect(pendingMatter.suggested.single.kind, ConnectionsPairKind.suggested);
    expect(pendingMatter.suggested.single.label, 'Suggested relationship');
    expect(pendingMatter.supporting, isEmpty);
    expect(pendingMatter.linked, isEmpty);
    expectNoCorroboration(pendingMatter);

    final persistedMatter = present(
      relationships: [
        _rel(
          id: 'ai',
          from: 'photo',
          to: 'video',
          source: 'ai',
          reason:
              'Suggested relationship because both records reference Honda Civic.',
        ),
      ],
      suggestions: [_aiSuggested(from: 'photo', to: 'video')],
    );
    expect(persistedMatter.suggested.single.label, 'Suggested relationship');
    expect(persistedMatter.supporting, isEmpty);
    expect(persistedMatter.linked, isEmpty);
    expectNoCorroboration(persistedMatter);

    final metadata = present(
      relationships: [
        _rel(
          id: 'meta',
          from: 'photo',
          to: 'video',
          source: 'metadata',
          reason: 'Related because these were captured 12 seconds apart.',
        ),
      ],
    );
    expect(metadata.suggested.single.label, 'Suggested relationship');
    expect(metadata.linked, isEmpty);

    final userRelated = present(
      relationships: [
        _rel(id: 'user', from: 'photo', to: 'video', source: 'user'),
      ],
    );
    expect(userRelated.linked.single.label, 'Linked evidence');
    expect(userRelated.suggested, isEmpty);

    final child = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      parentEvidenceId: 'photo',
    );
    final supports = present(
      items: [photo, child],
      relationships: [
        _rel(
          id: 'sup',
          from: 'note',
          to: 'photo',
          type: RelationshipType.supports,
          source: 'user',
        ),
      ],
    );
    expect(supports.supporting.single.label, 'Supporting evidence');
    expect(supports.suggested, isEmpty);
  });

  test('3. ai RELATED remains Suggested Relationship', () {
    final presentation = ConnectionsPresentationMapper.build(
      incidentId: 'inc-1',
      items: [photo, video],
      relationships: [
        _rel(
          id: 'ai',
          from: 'photo',
          to: 'video',
          source: 'ai',
          reason:
              'Suggested relationship because both items contain references to the same location.',
        ),
      ],
      collections: const [],
      groupNodes: const [],
      suggestions: const [],
    );
    expect(presentation.suggested, hasLength(1));
    expect(presentation.suggested.single.kind, ConnectionsPairKind.suggested);
    expect(presentation.supporting, isEmpty);
    expect(presentation.linked, isEmpty);
  });

  test('4. metadata RELATED remains Suggested Relationship', () {
    final presentation = ConnectionsPresentationMapper.build(
      incidentId: 'inc-1',
      items: [photo, video],
      relationships: [
        _rel(
          id: 'meta',
          from: 'photo',
          to: 'video',
          source: 'metadata',
          reason: 'Related because these were captured 12 seconds apart.',
        ),
      ],
      collections: const [],
      groupNodes: const [],
      suggestions: const [],
    );
    expect(presentation.suggested.single.kind, ConnectionsPairKind.suggested);
    expect(presentation.linked, isEmpty);
  });

  test('5. user SUPPORTS remains Supporting', () {
    final child = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      parentEvidenceId: 'photo',
    );
    final presentation = ConnectionsPresentationMapper.build(
      incidentId: 'inc-1',
      items: [photo, child],
      relationships: [
        _rel(
          id: 'sup',
          from: 'note',
          to: 'photo',
          type: RelationshipType.supports,
          source: 'user',
        ),
      ],
      collections: const [],
      groupNodes: const [],
      suggestions: const [],
    );
    expect(presentation.supporting, isNotEmpty);
    expect(
      EvidenceSemantics.structurallySupports(
        child: child,
        parentId: 'photo',
        relationships: [
          _rel(
            id: 'sup',
            from: 'note',
            to: 'photo',
            type: RelationshipType.supports,
            source: 'user',
          ),
        ],
      ),
      isTrue,
    );
  });

  test('6. user explicit RELATED remains Linked', () {
    final presentation = ConnectionsPresentationMapper.build(
      incidentId: 'inc-1',
      items: [photo, video],
      relationships: [
        _rel(id: 'user', from: 'photo', to: 'video', source: 'user'),
      ],
      collections: const [],
      groupNodes: const [],
      suggestions: const [],
    );
    expect(presentation.linked, hasLength(1));
    expect(presentation.suggested, isEmpty);
    expect(
      EvidenceSemantics.isExplicitUserRelationship(
        _rel(id: 'user', from: 'photo', to: 'video', source: 'user'),
      ),
      isTrue,
    );
  });

  test('6C-7 user RELATED and Matter RELATED are not treated identically', () {
    final userCreated = _rel(
      id: 'user',
      from: 'photo',
      to: 'video',
      source: 'user',
    );
    final userUnsourced = _rel(
      id: 'user-null',
      from: 'photo',
      to: 'note',
    );
    final matter = _rel(
      id: 'ai',
      from: 'photo',
      to: 'voice',
      source: 'ai',
      reason:
          'Suggested relationship because both records reference Honda Civic.',
    );
    expect(EvidenceSemantics.isExplicitUserRelationship(userCreated), isTrue);
    expect(EvidenceSemantics.isSuggestedRelated(userCreated), isFalse);
    expect(EvidenceSemantics.isExplicitUserRelationship(userUnsourced), isTrue);
    expect(EvidenceSemantics.isSuggestedRelated(matter), isTrue);
    expect(EvidenceSemantics.isExplicitUserRelationship(matter), isFalse);

    final presentation = ConnectionsPresentationMapper.build(
      incidentId: 'inc-1',
      items: [photo, video, voice, note],
      relationships: [userCreated, userUnsourced, matter],
      collections: const [],
      groupNodes: const [],
      suggestions: [
        RelationshipSuggestion(
          id: 'sug-ai',
          incidentId: 'inc-1',
          sourceEvidenceId: 'photo',
          targetEvidenceId: 'voice',
          relationshipType: RelationshipType.relatedTo.name,
          confidence: 0.55,
          reason: matter.reason!,
          source: RelationshipSuggestionSource.ai,
          status: RelationshipSuggestionStatus.suggested,
          createdAt: DateTime(2026, 8, 14),
        ),
      ],
    );

    expect(
      presentation.linked.map((pair) => pair.pairId),
      containsAll(['photo__video', 'note__photo']),
    );
    expect(
      presentation.linked.every((pair) => pair.label == 'Linked evidence'),
      isTrue,
    );
    expect(presentation.suggested, hasLength(1));
    expect(presentation.suggested.single.label, 'Suggested relationship');
    expect(presentation.suggested.single.kind, ConnectionsPairKind.suggested);
    expect(
      presentation.suggested.single.pairId,
      'photo__voice',
    );
    expect(
      presentation.linked.any((pair) => pair.pairId == 'photo__voice'),
      isFalse,
    );
  });

  test('7. ai RELATED does not become corroboration', () {
    expect(
      RelationshipType.values.map((t) => t.name),
      isNot(contains('corroborates')),
    );
    expect(
      EvidenceSemantics.isSuggestedRelated(
        _rel(id: 'ai', from: 'photo', to: 'video', source: 'ai'),
      ),
      isTrue,
    );
  });

  test('6C-4 Journey state is unchanged by Matter RELATED', () {
    void expectSameJourney(
      List<WorkspaceEvidenceItem> items, {
      required JourneyStage expectedStage,
    }) {
      final before = EnrichmentEngine.compute(
        EnrichmentContext(items: items, relationships: const []),
      );
      final after = EnrichmentEngine.compute(
        EnrichmentContext(
          items: items,
          relationships: [
            _rel(
              id: 'ai',
              from: items.first.id,
              to: items.last.id,
              source: 'ai',
              reason:
                  'Suggested relationship because both records reference Honda Civic.',
            ),
          ],
        ),
      );
      expect(before.journeyStage, expectedStage);
      expect(after.journeyStage, before.journeyStage);
      expect(after.enrichedEvidenceCount, before.enrichedEvidenceCount);
      expect(after.enrichmentPercentage, before.enrichmentPercentage);
      final afterContext = EnrichmentContext(
        items: items,
        relationships: [
          _rel(id: 'ai', from: items.first.id, to: items.last.id, source: 'ai'),
        ],
      );
      expect(afterContext.signalsFor(items.first.id).hasAiEnrichment, isFalse);
      for (final item in items) {
        expect(
          EvidenceSemantics.hasRecordedContext(
            item,
            incidentItems: items,
            relationships: afterContext.relationships,
          ),
          EvidenceSemantics.hasRecordedContext(item, incidentItems: items),
        );
        expect(
          EnrichmentEngine.isEnriched(item, afterContext),
          EnrichmentEngine.isEnriched(
            item,
            EnrichmentContext(items: items, relationships: const []),
          ),
        );
      }
    }

    expectSameJourney([photo, video], expectedStage: JourneyStage.empty);

    final describedPhoto = WorkspaceEvidenceItem(
      id: 'photo',
      incidentId: 'inc-1',
      kind: WorkspaceEvidenceKind.image,
      title: 'Photo',
      lastPreservedAt: DateTime(2026, 8, 14, 10),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      notePreview: 'Red Honda Civic at the gate',
    );
    final locatedVideo = WorkspaceEvidenceItem(
      id: 'video',
      incidentId: 'inc-1',
      kind: WorkspaceEvidenceKind.video,
      title: 'Video',
      lastPreservedAt: DateTime(2026, 8, 14, 10),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      latitude: 27.7,
      longitude: 85.3,
    );
    expectSameJourney(
      [describedPhoto, locatedVideo],
      expectedStage: JourneyStage.rich,
    );
  });

  test('8. ai RELATED does not enrich Journey', () {
    final snapshot = EnrichmentEngine.compute(
      EnrichmentContext(
        items: [photo, video],
        relationships: [
          _rel(
            id: 'ai',
            from: 'photo',
            to: 'video',
            source: 'ai',
            reason:
                'Suggested relationship because both items contain references to the same location.',
          ),
        ],
      ),
    );
    expect(snapshot.enrichedEvidenceCount, 0);
    expect(snapshot.journeyStage, isNot(JourneyStage.rich));
  });

  test('6C-3 Adaptive Coaching ignores Day 3 Matter intelligence', () {
    const quality = TrustPackageInvestigationQuality(
      overallRating: TrustPackageQualityRating.incomplete,
      indicators: [],
    );
    final day1 = DateTime(2026, 8, 1, 10);
    final day1Photo = WorkspaceEvidenceItem(
      id: 'photo',
      incidentId: 'inc-1',
      kind: WorkspaceEvidenceKind.image,
      title: 'Day 1 photo',
      lastPreservedAt: day1,
      integrityVerified: true,
      verification: VerificationFactory.initial(),
    );
    final day1Video = WorkspaceEvidenceItem(
      id: 'video',
      incidentId: 'inc-1',
      kind: WorkspaceEvidenceKind.video,
      title: 'Day 1 video',
      lastPreservedAt: day1,
      integrityVerified: true,
      verification: VerificationFactory.initial(),
    );
    InvestigationCoachingContext onDay({
      List<EvidenceRelationship> relationships = const [],
    }) {
      return InvestigationCoachingContext(
        incidentId: 'inc-1',
        items: [day1Photo, day1Video],
        timelineNodes: const [],
        narrativeEvents: const [],
        relationships: relationships,
        groupMemberEvidenceIds: const {},
        primaryEvidenceCount: 2,
        enrichedEvidenceCount: 0,
        trustPackageQuality: quality,
        previouslySeenEvidenceIds: {'photo', 'video'},
      );
    }

    final beforeMatter = InvestigationCoachingEngine.generate(onDay());
    final day3Matter = InvestigationCoachingEngine.generate(
      onDay(
        relationships: [
          _rel(
            id: 'ai',
            from: 'photo',
            to: 'video',
            source: 'ai',
            reason:
                'Suggested relationship because both records reference Honda Civic.',
          ),
        ],
      ),
    );
    expect(
      day3Matter.map((item) => item.fingerprint),
      beforeMatter.map((item) => item.fingerprint),
    );
    expect(
      day3Matter.any((item) => item.fingerprint.startsWith('incident:development')),
      isFalse,
    );
    expect(
      AdaptiveCoaching.normalize(
        input: AdaptiveCoachingInput(
          items: [day1Photo, day1Video],
          relationships: [
            _rel(id: 'ai', from: 'photo', to: 'video', source: 'ai'),
          ],
          primaryEvidenceCount: 2,
          previouslySeenEvidenceIds: {'photo', 'video'},
        ),
        items: day3Matter,
      ).any((item) => item.fingerprint.startsWith('incident:development')),
      isFalse,
    );
  });

  test('9. ai RELATED does not affect Adaptive Coaching development', () {
    const quality = TrustPackageInvestigationQuality(
      overallRating: TrustPackageQualityRating.incomplete,
      indicators: [],
    );
    InvestigationCoachingContext ctx({
      List<EvidenceRelationship> relationships = const [],
    }) {
      return InvestigationCoachingContext(
        incidentId: 'inc-1',
        items: [photo, video, voice],
        timelineNodes: const [],
        narrativeEvents: const [],
        relationships: relationships,
        groupMemberEvidenceIds: const {},
        primaryEvidenceCount: 3,
        enrichedEvidenceCount: 0,
        trustPackageQuality: quality,
        previouslySeenEvidenceIds: {'photo', 'video', 'voice'},
      );
    }

    final before = InvestigationCoachingEngine.generate(ctx());
    final after = InvestigationCoachingEngine.generate(
      ctx(
        relationships: [
          _rel(id: 'ai', from: 'photo', to: 'video', source: 'ai'),
        ],
      ),
    );
    expect(
      after.map((item) => item.fingerprint),
      before.map((item) => item.fingerprint),
    );
    expect(
      after.any((item) => item.fingerprint.startsWith('incident:development')),
      isFalse,
    );
    expect(
      AdaptiveCoaching.normalize(
        input: AdaptiveCoachingInput(
          items: [photo, video, voice],
          relationships: [
            _rel(id: 'ai', from: 'photo', to: 'video', source: 'ai'),
          ],
          primaryEvidenceCount: 3,
          previouslySeenEvidenceIds: {'photo', 'video', 'voice'},
        ),
        items: after,
      ).any((item) => item.fingerprint.startsWith('incident:development')),
      isFalse,
    );
  });

  test('10. missing source fails closed and does not become stronger evidence',
      () {
    final orphanMatter = _rel(
      id: 'legacy',
      from: 'photo',
      to: 'video',
      reason:
          'Suggested relationship because both items contain references to the same location.',
    );
    expect(EvidenceSemantics.isSuggestedRelated(orphanMatter), isTrue);
    expect(EvidenceSemantics.isExplicitUserRelationship(orphanMatter), isFalse);
    expect(
      EvidenceSemantics.hasStructuralSupport(
        evidenceId: 'photo',
        items: [photo, video],
        relationships: [orphanMatter],
      ),
      isFalse,
    );
    expect(
      EvidenceSemantics.structurallySupports(
        child: note,
        parentId: 'photo',
        relationships: [orphanMatter],
      ),
      isFalse,
    );
    final snapshot = EnrichmentEngine.compute(
      EnrichmentContext(items: [photo, video], relationships: [orphanMatter]),
    );
    expect(snapshot.enrichedEvidenceCount, 0);

    final presentation = ConnectionsPresentationMapper.build(
      incidentId: 'inc-1',
      items: [photo, video],
      relationships: [orphanMatter],
      collections: const [],
      groupNodes: const [],
      suggestions: const [],
    );
    expect(presentation.suggested, isNotEmpty);
    expect(presentation.linked, isEmpty);
    expect(presentation.supporting, isEmpty);
  });

  test('11. Matter explanation survives consumer projection', () {
    final suggestion = _aiSuggested(from: 'photo', to: 'video');
    final presentation = ConnectionsPresentationMapper.build(
      incidentId: 'inc-1',
      items: [photo, video],
      relationships: const [],
      collections: const [],
      groupNodes: const [],
      suggestions: [suggestion],
    );
    expect(presentation.suggested, hasLength(1));
    expect(
      presentation.suggested.single.detail,
      contains('same location'),
    );
    expect(
      presentation.suggested.single.label,
      'Suggested relationship',
    );
  });

  test('12. TIME + SPACE + MATTER remains RELATED only', () {
    final now = DateTime(2026, 8, 14, 10, 2, 14);
    final suggestions = ComposedRelationshipProvider(
      matterProvider: const ExplicitMatterRelationshipProvider(
        contentSignals: [
          MatterContentSignal(evidenceId: 'a', placeMentions: ['Cafe X']),
          MatterContentSignal(evidenceId: 'b', placeMentions: ['Cafe X']),
        ],
      ),
    ).suggest(
      incidentId: 'inc-1',
      signals: [
        RelationshipEvidenceSignal(
          evidenceId: 'a',
          kindLabel: 'photo',
          capturedAt: now,
          latitude: 27.7,
          longitude: 85.3,
        ),
        RelationshipEvidenceSignal(
          evidenceId: 'b',
          kindLabel: 'video',
          capturedAt: now.add(const Duration(seconds: 30)),
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
    expect(matter.single.confidence, lessThan(0.7));
  });

  test('6C-6 Graph does not promote Matter RELATED to SUPPORTS or primary', () {
    final items = [photo, video, note];
    final matter = _rel(
      id: 'ai',
      from: 'photo',
      to: 'note',
      source: 'ai',
      reason:
          'Suggested relationship because both records reference Honda Civic.',
    );
    final view = RelationshipEngine().buildGraphView(
      store: IncidentStore(
        incident: Incident(
          id: 'inc-1',
          title: 'Incident',
          status: IncidentStatus.draft,
          createdAt: DateTime(2026, 8, 14),
          updatedAt: DateTime(2026, 8, 14),
        ),
      ),
      evidence: items,
      relationships: [matter],
    );

    final matterEdges = view.edges.where(
      (edge) =>
          (edge.sourceEvidenceId == 'photo' && edge.targetEvidenceId == 'note') ||
          (edge.sourceEvidenceId == 'note' && edge.targetEvidenceId == 'photo'),
    );
    expect(matterEdges, isNotEmpty);
    expect(
      matterEdges.every((edge) => edge.kind == InvestigationGraphEdgeKind.related),
      isTrue,
    );
    expect(
      matterEdges.any((edge) => edge.kind == InvestigationGraphEdgeKind.supports),
      isFalse,
    );
    expect(matterEdges.every((edge) => edge.source == 'ai'), isTrue);
    expect(view.primaryEvidenceIds, containsAll(['photo', 'video']));
    expect(view.primaryEvidenceIds, isNot(contains('note')));
    expect(view.supportingByPrimaryId['photo'] ?? const <String>[], isEmpty);
    expect(EvidenceSemantics.isPrimaryChronologyEvidence(note), isFalse);
  });

  test('Graph does not promote ai RELATED to SUPPORTS', () {
    final edge = InvestigationGraphEdge(
      id: 'e1',
      sourceEvidenceId: 'photo',
      targetEvidenceId: 'video',
      kind: InvestigationGraphEdgeKind.related,
      reason:
          'Suggested relationship because both items contain references to the same location.',
      source: 'ai',
    );
    expect(edge.kind, isNot(InvestigationGraphEdgeKind.supports));
    expect(edge.source, 'ai');
  });

  test('6C-5 Inspector and Story do not promote Matter RELATED', () {
    final items = [photo, video];
    final matter = _rel(
      id: 'ai',
      from: 'photo',
      to: 'video',
      source: 'ai',
      reason:
          'Suggested relationship because both records reference Honda Civic.',
    );
    final inspector = EvidenceRecordModel.fromWorkspace(
      evidence: photo,
      allItems: items,
      relationships: [matter],
    );
    expect(inspector.linkedEvidence, isEmpty);
    expect(inspector.contextItems, isEmpty);
    expect(inspector.hasLinkedEvidence, isFalse);

    final story = const DefaultStoryBuilder().build(
      StoryBuildContext(
        items: items,
        relationships: [matter],
        reflections: const [],
      ),
    );
    expect(story.linkedEvidence, isEmpty);
    expect(story.supportingContext, isEmpty);
    expect(EvidenceSemantics.isPrimaryChronologyEvidence(photo), isTrue);
    expect(EvidenceSemantics.hasWitnessKind(items), isFalse);
    expect(
      EvidenceSemantics.primaryChronologyCount(story.evidenceHighlights),
      EvidenceSemantics.primaryChronologyCount(items),
    );

    final copy = [
      story.summary ?? '',
      ...story.linkedEvidence.map((entry) => entry.link.title ?? ''),
      ...story.linkedEvidence.map((entry) => entry.link.type.name),
      ...inspector.linkedEvidence.map((item) => item.title ?? ''),
      ...inspector.linkedEvidence.map((item) => item.type.name),
    ].join(' ').toLowerCase();
    expect(copy, isNot(contains('corroborat')));
    expect(copy, isNot(contains('same event')));
    expect(RegExp(r'\bsupports\b').hasMatch(copy), isFalse);
    expect(copy, isNot(contains('witness')));
    expect(copy, isNot(contains('primary chronology')));
  });

  test('Inspector and Story omit suggested RELATED from linked lists', () {
    final items = [photo, video];
    final suggested = _rel(
      id: 'ai',
      from: 'photo',
      to: 'video',
      source: 'ai',
      reason:
          'Suggested relationship because both items contain references to the same location.',
    );
    final user = _rel(id: 'user', from: 'photo', to: 'video', source: 'user');

    final recordSuggested = EvidenceRecordModel.fromWorkspace(
      evidence: photo,
      allItems: items,
      relationships: [suggested],
    );
    expect(recordSuggested.linkedEvidence, isEmpty);

    final recordUser = EvidenceRecordModel.fromWorkspace(
      evidence: photo,
      allItems: items,
      relationships: [user],
    );
    expect(recordUser.linkedEvidence, hasLength(1));

    final storySuggested = const DefaultStoryBuilder().build(
      StoryBuildContext(
        items: items,
        relationships: [suggested],
        reflections: const [],
      ),
    );
    expect(storySuggested.linkedEvidence, isEmpty);

    final storyUser = const DefaultStoryBuilder().build(
      StoryBuildContext(
        items: items,
        relationships: [user],
        reflections: const [],
      ),
    );
    expect(storyUser.linkedEvidence, hasLength(1));
  });
}
