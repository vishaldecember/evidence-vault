import '../domain/incident/incident_aggregate.dart';
import '../domain/investigation_health/health_finding.dart';
import '../domain/investigation_health/health_finding_category.dart';
import '../domain/investigation_health/health_finding_priority.dart';
import '../domain/investigation_health/health_finding_type.dart';
import '../domain/investigation_health/health_message_keys.dart';
import '../domain/investigation_health/health_recommendation_keys.dart';
import '../domain/investigation_health/investigation_health.dart';
import '../domain/investigation_health/investigation_health_scoring.dart';
import '../domain/investigation_health/investigation_health_weights.dart';
import '../domain/trust_package/trust_package_assembler.dart';
import '../engines/enrichment_engine.dart';
import '../engines/evidence_semantics.dart';
import '../engines/narrative_builder.dart';
import '../mappers/evidence_projection.dart';
import '../models/connection_group_node.dart';
import '../models/reflection_model.dart';
import '../models/relationship_group.dart';
import '../models/relationship_group_confidence.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';
import '../repositories/incident_store.dart';
import '../repositories/workspace_evidence_repository.dart';
import '../services/relationship_group_color_service.dart';
import '../services/trust_package_scorecard_service.dart';

/// Tunable thresholds for deterministic health evaluation.
class InvestigationHealthRules {
  const InvestigationHealthRules({
    this.significantTimeGap = const Duration(hours: 2),
    this.largeTimeGap = const Duration(hours: 6),
  });

  final Duration significantTimeGap;
  final Duration largeTimeGap;
}

/// Snapshot of investigation state used by [InvestigationHealthEngine].
///
/// Findings use structured keys only. Step 4C does not expose Health copy to
/// users. Isolated / supporting-gap / former corroboration keys are internal
/// scoring signals, not product claims of corroboration.
class InvestigationHealthContext {
  const InvestigationHealthContext({
    required this.incidentId,
    required this.items,
    required this.timelineNodes,
    required this.groupNodes,
    required this.groups,
    required this.narrativeEvents,
    required this.enrichmentContext,
    required this.groupMemberEvidenceIds,
    required this.narrativeReferencedEvidenceIds,
    required this.trustPackageQuality,
    required this.primaryEvidenceCount,
  });

  final String incidentId;
  final List<WorkspaceEvidenceItem> items;
  final List<TimelineAnchorNode> timelineNodes;
  final List<ConnectionGroupNode> groupNodes;
  final List<RelationshipGroup> groups;
  final List<NarrativeEventViewModel> narrativeEvents;
  final EnrichmentContext enrichmentContext;
  final Set<String> groupMemberEvidenceIds;
  final Set<String> narrativeReferencedEvidenceIds;
  final TrustPackageInvestigationQuality trustPackageQuality;
  final int primaryEvidenceCount;

  factory InvestigationHealthContext.fromAggregate(IncidentAggregate aggregate) {
    final store = aggregate.store;
    final incidentId = store.incident.id;
    final items = EvidenceSemantics.incidentScopedItems(
      EvidenceProjection.toWorkspaceItems(store),
      incidentId,
    );
    final timelineNodes = EvidenceSemantics.incidentScopedTimeline(
      WorkspaceEvidenceRepository.anchoredTree(
        store,
        aggregate.timelineRepository,
      ),
      incidentId,
    );
    final groupNodes = WorkspaceEvidenceRepository.connectionGroupNodes(
      store,
      aggregate.timelineRepository,
    );
    final groups = RelationshipGroupColorService.orderedGroups(
      store.relationshipGroups,
    );
    final scopedRelationships = EvidenceSemantics.incidentScopedRelationships(
      relationships: store.relationships,
      scopedItems: items,
    );
    final enrichmentContext = EnrichmentContext(
      items: items,
      relationships: scopedRelationships,
    );
    final reflections = _reflectionsFromStore(store);

    aggregate.narrativeEventRepository.ensureInitialStructure(
      orderedAnchorEvidenceIds:
          aggregate.timelineRepository.orderedCapturedEvidenceIds(),
    );

    final narrativeEvents = [
      for (final event in const DefaultNarrativeBuilder().build(
        NarrativeBuildContext(
          store: store,
          timelineNodes: timelineNodes,
          groupNodes: groupNodes,
          notes: reflections,
          items: items,
          groups: groups,
          enrichmentContext: enrichmentContext,
        ),
      ))
        if (event.event.incidentId.isNotEmpty &&
            event.event.incidentId == incidentId)
          event,
    ];

    final groupMemberIds = <String>{
      for (final group in groups) ...group.memberEvidenceIds,
    };
    final narrativeReferencedIds = <String>{};
    for (final event in narrativeEvents) {
      for (final item in event.displayEvidence) {
        narrativeReferencedIds.add(item.id);
      }
      for (final item in event.supportingEvidence) {
        narrativeReferencedIds.add(item.id);
      }
    }

    final trustPackage =
        const DefaultTrustPackageAssembler().assemble(aggregate);

    return InvestigationHealthContext(
      incidentId: incidentId,
      items: items,
      timelineNodes: timelineNodes,
      groupNodes: groupNodes,
      groups: groups,
      narrativeEvents: narrativeEvents,
      enrichmentContext: enrichmentContext,
      groupMemberEvidenceIds: groupMemberIds,
      narrativeReferencedEvidenceIds: narrativeReferencedIds,
      trustPackageQuality: TrustPackageScorecardService.evaluate(trustPackage),
      primaryEvidenceCount: EvidenceSemantics.primaryChronologyCount(items),
    );
  }

  static List<ReflectionModel> _reflectionsFromStore(IncidentStore store) {
    final notes = List<ReflectionModel>.from(store.reconstructionNotes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }
}

/// Evaluates investigation structure — never truth, intent, or legal conclusions.
abstract final class InvestigationHealthEngine {
  InvestigationHealthEngine._();

  static InvestigationHealth evaluate(
    IncidentAggregate aggregate, {
    InvestigationHealthWeights weights = InvestigationHealthWeights.defaults,
    InvestigationHealthRules rules = const InvestigationHealthRules(),
    DateTime? generatedAt,
  }) {
    final context = InvestigationHealthContext.fromAggregate(aggregate);
    if (context.primaryEvidenceCount == 0) {
      return InvestigationHealth(
        overallScore: 0,
        evidenceCompletenessScore: 0,
        relationshipCoverageScore: 0,
        timelineIntegrityScore: 0,
        narrativeSupportScore: 0,
        trustReadinessScore: 0,
        generatedAt: generatedAt ?? DateTime.now(),
        findings: const [],
      );
    }

    final findings = <HealthFinding>[
      ..._evidenceCompletenessFindings(context),
      ..._relationshipCoverageFindings(context),
      ..._timelineIntegrityFindings(context, rules),
      ..._narrativeSupportFindings(context),
      ..._trustReadinessFindings(context),
    ];

    final evidenceCompletenessScore = InvestigationHealthScoring.categoryScore(
      HealthFindingCategory.evidenceCompleteness,
      findings,
    );
    final relationshipCoverageScore = InvestigationHealthScoring.categoryScore(
      HealthFindingCategory.relationshipCoverage,
      findings,
    );
    final timelineIntegrityScore = InvestigationHealthScoring.categoryScore(
      HealthFindingCategory.timelineIntegrity,
      findings,
    );
    final narrativeSupportScore = InvestigationHealthScoring.categoryScore(
      HealthFindingCategory.narrativeSupport,
      findings,
    );
    final trustReadinessScore = InvestigationHealthScoring.categoryScore(
      HealthFindingCategory.trustReadiness,
      findings,
    );

    return InvestigationHealth(
      overallScore: InvestigationHealthScoring.overallScore(
        evidenceCompletenessScore: evidenceCompletenessScore,
        relationshipCoverageScore: relationshipCoverageScore,
        timelineIntegrityScore: timelineIntegrityScore,
        narrativeSupportScore: narrativeSupportScore,
        trustReadinessScore: trustReadinessScore,
        weights: weights,
      ),
      evidenceCompletenessScore: evidenceCompletenessScore,
      relationshipCoverageScore: relationshipCoverageScore,
      timelineIntegrityScore: timelineIntegrityScore,
      narrativeSupportScore: narrativeSupportScore,
      trustReadinessScore: trustReadinessScore,
      generatedAt: generatedAt ?? DateTime.now(),
      findings: findings,
    );
  }

  static List<HealthFinding> _evidenceCompletenessFindings(
    InvestigationHealthContext context,
  ) {
    final findings = <HealthFinding>[];
    final linkedEvidenceIds = _linkedEvidenceIds(context);

    for (final item in EvidenceSemantics.primaryChronology(context.items)) {
      if (!EvidenceSemantics.hasRecordedContext(
        item,
        incidentItems: context.items,
        relationships: context.enrichmentContext.relationships,
      )) {
        findings.add(
          HealthFinding(
            id: _findingId(
              HealthFindingCategory.evidenceCompleteness,
              HealthFindingType.missingObservation,
              item.id,
            ),
            category: HealthFindingCategory.evidenceCompleteness,
            priority: HealthFindingPriority.medium,
            type: HealthFindingType.missingObservation,
            messageKey: HealthMessageKeys.evidenceMissingObservation,
            affectedObjectId: item.id,
            recommendationKey: HealthRecommendationKeys.addObservation,
          ),
        );
      }

      if (!context.groupMemberEvidenceIds.contains(item.id) &&
          !linkedEvidenceIds.contains(item.id)) {
        findings.add(
          HealthFinding(
            id: _findingId(
              HealthFindingCategory.evidenceCompleteness,
              HealthFindingType.notLinkedToRelationship,
              item.id,
            ),
            category: HealthFindingCategory.evidenceCompleteness,
            priority: HealthFindingPriority.medium,
            type: HealthFindingType.notLinkedToRelationship,
            messageKey: HealthMessageKeys.evidenceNotLinkedToRelationship,
            affectedObjectId: item.id,
            recommendationKey: HealthRecommendationKeys.linkToRelationship,
          ),
        );
      }

      if (!context.narrativeReferencedEvidenceIds.contains(item.id)) {
        findings.add(
          HealthFinding(
            id: _findingId(
              HealthFindingCategory.evidenceCompleteness,
              HealthFindingType.notReferencedByNarrative,
              item.id,
            ),
            category: HealthFindingCategory.evidenceCompleteness,
            priority: HealthFindingPriority.low,
            type: HealthFindingType.notReferencedByNarrative,
            messageKey: HealthMessageKeys.evidenceNotReferencedByNarrative,
            affectedObjectId: item.id,
            recommendationKey: HealthRecommendationKeys.referenceInNarrative,
          ),
        );
      }
    }

    return findings;
  }

  static List<HealthFinding> _relationshipCoverageFindings(
    InvestigationHealthContext context,
  ) {
    final findings = <HealthFinding>[];

    for (final item in context.items) {
      if (item.kind != WorkspaceEvidenceKind.note &&
          item.kind != WorkspaceEvidenceKind.attachment) {
        continue;
      }
      if (context.groupMemberEvidenceIds.contains(item.id)) {
        continue;
      }
      if (EvidenceSemantics.isInCollection(item) ||
          EvidenceSemantics.hasStructuralRelationship(
            evidenceId: item.id,
            items: context.items,
            relationships: context.enrichmentContext.relationships,
          )) {
        continue;
      }
      findings.add(
        HealthFinding(
          id: _findingId(
            HealthFindingCategory.relationshipCoverage,
            HealthFindingType.isolatedEvidence,
            item.id,
          ),
          category: HealthFindingCategory.relationshipCoverage,
          priority: HealthFindingPriority.medium,
          type: HealthFindingType.isolatedEvidence,
          messageKey: HealthMessageKeys.relationshipIsolatedEvidence,
          affectedObjectId: item.id,
          recommendationKey: HealthRecommendationKeys.connectEvidence,
        ),
      );
    }

    for (final group in context.groups) {
      if (group.memberEvidenceIds.length == 1) {
        findings.add(
          HealthFinding(
            id: _findingId(
              HealthFindingCategory.relationshipCoverage,
              HealthFindingType.groupWithSingleMember,
              group.id,
            ),
            category: HealthFindingCategory.relationshipCoverage,
            priority: HealthFindingPriority.low,
            type: HealthFindingType.groupWithSingleMember,
            messageKey: HealthMessageKeys.relationshipGroupSingleMember,
            affectedObjectId: group.id,
            recommendationKey: HealthRecommendationKeys.expandRelationshipGroup,
          ),
        );
      }
    }

    return findings;
  }

  static List<HealthFinding> _timelineIntegrityFindings(
    InvestigationHealthContext context,
    InvestigationHealthRules rules,
  ) {
    final findings = <HealthFinding>[];
    final nodes = context.timelineNodes;

    for (final node in nodes) {
      if (!EvidenceSemantics.hasStructuralSupport(
        evidenceId: node.capturedItem.id,
        items: context.items,
        relationships: context.enrichmentContext.relationships,
      )) {
        findings.add(
          HealthFinding(
            id: _findingId(
              HealthFindingCategory.timelineIntegrity,
              HealthFindingType.anchorWithoutSupportingEvidence,
              node.anchor.id,
            ),
            category: HealthFindingCategory.timelineIntegrity,
            priority: HealthFindingPriority.high,
            type: HealthFindingType.anchorWithoutSupportingEvidence,
            messageKey:
                HealthMessageKeys.timelineAnchorWithoutSupportingEvidence,
            affectedObjectId: node.capturedItem.id,
            recommendationKey: HealthRecommendationKeys.attachSupportingEvidence,
          ),
        );
      }
    }

    for (var index = 1; index < nodes.length; index++) {
      final gap = nodes[index].anchor.anchoredAt
          .difference(nodes[index - 1].anchor.anchoredAt);
      if (gap < rules.significantTimeGap) {
        continue;
      }
      findings.add(
        HealthFinding(
          id: _findingId(
            HealthFindingCategory.timelineIntegrity,
            HealthFindingType.chronologicalGap,
            '${nodes[index - 1].anchor.id}:${nodes[index].anchor.id}',
          ),
          category: HealthFindingCategory.timelineIntegrity,
          priority: gap >= rules.largeTimeGap
              ? HealthFindingPriority.high
              : HealthFindingPriority.medium,
          type: HealthFindingType.chronologicalGap,
          messageKey: HealthMessageKeys.timelineChronologicalGap,
          affectedObjectId: nodes[index].capturedItem.id,
          recommendationKey: HealthRecommendationKeys.documentTimelineGap,
        ),
      );
    }

    return findings;
  }

  static List<HealthFinding> _narrativeSupportFindings(
    InvestigationHealthContext context,
  ) {
    final findings = <HealthFinding>[];

    for (final event in context.narrativeEvents) {
      final validation = event.validation;
      if (validation.status == RelationshipGroupConfidence.low) {
        findings.add(
          HealthFinding(
            id: _findingId(
              HealthFindingCategory.narrativeSupport,
              HealthFindingType.unsupportedNarrativeStatement,
              event.event.id,
            ),
            category: HealthFindingCategory.narrativeSupport,
            priority: HealthFindingPriority.high,
            type: HealthFindingType.unsupportedNarrativeStatement,
            messageKey: HealthMessageKeys.narrativeUnsupportedStatement,
            affectedObjectId: event.event.id,
            recommendationKey:
                HealthRecommendationKeys.strengthenNarrativeSupport,
          ),
        );
      } else if (!validation.isSufficientlySupported) {
        findings.add(
          HealthFinding(
            id: _findingId(
              HealthFindingCategory.narrativeSupport,
              HealthFindingType.insufficientSupportingEvidence,
              event.event.id,
            ),
            category: HealthFindingCategory.narrativeSupport,
            priority: HealthFindingPriority.medium,
            type: HealthFindingType.insufficientSupportingEvidence,
            messageKey:
                HealthMessageKeys.narrativeInsufficientSupportingEvidence,
            affectedObjectId: event.event.id,
            recommendationKey: HealthRecommendationKeys.strengthenNarrativeSupport,
          ),
        );
      }
    }

    return findings;
  }

  static List<HealthFinding> _trustReadinessFindings(
    InvestigationHealthContext context,
  ) {
    final findings = <HealthFinding>[];

    for (final indicator in context.trustPackageQuality.indicators) {
      if (indicator.isMet) {
        continue;
      }
      final slug = _slugify(indicator.label);
      findings.add(
        HealthFinding(
          id: _findingId(
            HealthFindingCategory.trustReadiness,
            HealthFindingType.missingRequiredComponent,
            slug,
          ),
          category: HealthFindingCategory.trustReadiness,
          priority: HealthFindingPriority.medium,
          type: HealthFindingType.missingRequiredComponent,
          messageKey: HealthMessageKeys.trustMissingRequiredComponent,
          affectedObjectId: slug,
          recommendationKey: HealthRecommendationKeys.completeTrustRequirements,
        ),
      );
    }

    return findings;
  }

  static Set<String> _linkedEvidenceIds(InvestigationHealthContext context) {
    final linked = <String>{};
    for (final relationship in context.enrichmentContext.relationships) {
      if (EvidenceSemantics.isSuggestedRelated(relationship)) {
        continue;
      }
      linked.add(relationship.sourceEvidenceId);
      linked.add(relationship.targetEvidenceId);
    }
    for (final item in context.items) {
      if (EvidenceSemantics.hasStructuralRelationship(
        evidenceId: item.id,
        items: context.items,
        relationships: context.enrichmentContext.relationships,
      )) {
        linked.add(item.id);
        final parent = item.parentEvidenceId;
        if (parent != null && parent.isNotEmpty) {
          linked.add(parent);
        }
      }
    }
    return linked;
  }

  static String _findingId(
    HealthFindingCategory category,
    HealthFindingType type,
    String objectId,
  ) {
    return '${category.name}:${type.name}:$objectId';
  }

  static String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
