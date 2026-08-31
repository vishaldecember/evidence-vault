import '../../domain/relationship/relationship_suggestion.dart';
import '../../domain/risk/incident_risk_assessment.dart';
import '../../engines/evidence_semantics.dart';
import '../../models/journey_stage.dart';
import 'contradiction_detector.dart';
import 'risk_assessment_provider.dart';

/// Deterministic Risk Coach — no external AI (Sprint 5E).
///
/// Uses Investigation Graph, Evidence Collections, and library hints only.
/// Never manufactures urgency or legal/financial claims.
class DeterministicRiskAssessmentProvider implements RiskAssessmentProvider {
  const DeterministicRiskAssessmentProvider({
    this.maxItems = 4,
  });

  final int maxItems;

  static const Duration _followUpAge = Duration(days: 7);
  static const Duration _timeSensitiveAge = Duration(days: 90);

  @override
  Future<List<IncidentRiskAssessment>> assess(
    RiskAssessmentContext context,
  ) async {
    final scoped = _scoped(context);
    if (scoped.evidence.isEmpty) {
      return const [];
    }

    final candidates = <IncidentRiskAssessment>[
      ..._unresolved(scoped),
      ..._documentationGap(scoped),
      ..._missingSupportingForPrimary(scoped),
      ..._collectionRelationshipGap(scoped),
      ..._pendingRelationshipSuggestions(scoped),
      ..._followUp(scoped),
      ..._timeSensitive(scoped),
      ..._contradictions(scoped),
      ..._memoryPattern(scoped),
    ];

    final filtered = [
      for (final item in candidates)
        if (!context.dismissedIds.contains(item.id) &&
            !context.reviewedIds.contains(item.id))
          item,
    ]..sort(_compare);

    // One card per risk type — highest severity/confidence wins.
    final seenTypes = <RiskType>{};
    final selected = <IncidentRiskAssessment>[];
    for (final item in filtered) {
      if (!seenTypes.add(item.riskType)) {
        continue;
      }
      selected.add(item);
      if (selected.length >= maxItems) {
        break;
      }
    }
    return selected;
  }

  @override
  bool looksWellSupported(RiskAssessmentContext context) {
    final scoped = _scoped(context);
    if (scoped.evidence.isEmpty) {
      return false;
    }
    final mature = scoped.journeyStage == JourneyStage.rich ||
        scoped.journeyStage == JourneyStage.reflective;
    if (!mature) {
      return false;
    }
    final hasPrimary =
        EvidenceSemantics.primaryChronologyCount(scoped.evidence) > 0;
    final hasSupporting = EvidenceSemantics.primaryChronology(scoped.evidence)
        .any(
          (item) => EvidenceSemantics.hasStructuralSupport(
            evidenceId: item.id,
            items: scoped.evidence,
            relationships: scoped.relationships,
          ),
        );
    final hasCollections = scoped.collections.isNotEmpty;
    return hasPrimary && hasSupporting && hasCollections;
  }

  static int _compare(IncidentRiskAssessment a, IncidentRiskAssessment b) {
    final severity = b.severity.index.compareTo(a.severity.index);
    if (severity != 0) {
      return severity;
    }
    return b.confidence.compareTo(a.confidence);
  }

  List<IncidentRiskAssessment> _unresolved(RiskAssessmentContext context) {
    if (context.journeyStage != JourneyStage.building) {
      return const [];
    }
    final age = context.now.difference(context.updatedAt);
    return [
      IncidentRiskAssessment(
        id: '${RiskType.unresolved.wireName}_${context.incidentId}',
        incidentId: context.incidentId,
        riskType: RiskType.unresolved,
        severity: age >= _timeSensitiveAge
            ? RiskSeverity.medium
            : RiskSeverity.low,
        confidence: 0.85,
        reason: 'This investigation has remained in Building status.',
        recommendedAction: RiskRecommendedAction.reviewInvestigation,
        status: RiskAssessmentStatus.active,
        createdAt: context.now,
        updatedAt: context.now,
        domainHint: context.domainHint,
      ),
    ];
  }

  List<IncidentRiskAssessment> _documentationGap(
    RiskAssessmentContext context,
  ) {
    final chronology = context.evidence
        .where(EvidenceSemantics.isPrimaryChronologyEvidence)
        .toList();
    final hasStructuralSupporting = chronology.any(
      (item) => EvidenceSemantics.hasStructuralSupport(
        evidenceId: item.id,
        items: context.evidence,
        relationships: context.relationships,
      ),
    );
    if (chronology.isEmpty || hasStructuralSupporting) {
      return const [];
    }
    return [
      IncidentRiskAssessment(
        id: '${RiskType.documentationGap.wireName}_${context.incidentId}',
        incidentId: context.incidentId,
        riskType: RiskType.documentationGap,
        severity: RiskSeverity.medium,
        confidence: 0.8,
        reason:
            'None of the primary chronology items currently have parent-linked '
            'supporting evidence. You may add supporting material if available.',
        sourceEvidenceIds: chronology.take(3).map((e) => e.id).toList(),
        recommendedAction: RiskRecommendedAction.reviewInvestigation,
        status: RiskAssessmentStatus.active,
        createdAt: context.now,
        updatedAt: context.now,
        sourceLabel: chronology.first.title,
        domainHint: context.domainHint,
      ),
    ];
  }

  List<IncidentRiskAssessment> _missingSupportingForPrimary(
    RiskAssessmentContext context,
  ) {
    final designated =
        EvidenceSemantics.primaryChronology(context.evidence);
    if (designated.isEmpty || designated.length >= 2) {
      return const [];
    }

    for (final primary in designated) {
      if (EvidenceSemantics.hasStructuralSupport(
        evidenceId: primary.id,
        items: context.evidence,
        relationships: context.relationships,
      )) {
        continue;
      }
      return [
        IncidentRiskAssessment(
          id: '${RiskType.missingEvidence.wireName}_${primary.id}',
          incidentId: context.incidentId,
          riskType: RiskType.missingEvidence,
          severity: RiskSeverity.medium,
          confidence: 0.78,
          reason:
              'Primary chronology item “${primary.title}” has no parent-linked '
              'supporting evidence. You may add supporting material if available.',
          sourceEvidenceIds: [primary.id],
          recommendedAction: RiskRecommendedAction.reviewInvestigation,
          status: RiskAssessmentStatus.active,
          createdAt: context.now,
          updatedAt: context.now,
          sourceLabel: primary.title,
          domainHint: context.domainHint,
        ),
      ];
    }
    return const [];
  }

  List<IncidentRiskAssessment> _collectionRelationshipGap(
    RiskAssessmentContext context,
  ) {
    final connected = _connectedEvidenceIds(context);
    for (final collection in context.collections) {
      if (collection.memberEvidenceIds.length < 2) {
        continue;
      }
      final disconnected = [
        for (final id in collection.memberEvidenceIds)
          if (!connected.contains(id)) id,
      ];
      if (disconnected.isEmpty) {
        continue;
      }
      final disconnectedCount = disconnected.length;
      return [
        IncidentRiskAssessment(
          id: '${RiskType.relationshipGap.wireName}_${collection.id}',
          incidentId: context.incidentId,
          riskType: RiskType.relationshipGap,
          severity: disconnectedCount >= 3
              ? RiskSeverity.medium
              : RiskSeverity.low,
          confidence: 0.74,
          reason:
              'Some collection members in “${collection.name}” do not have an '
              'explicit parent-link or SUPPORTS relationship.',
          sourceEvidenceIds: disconnected.take(4).toList(),
          recommendedAction: RiskRecommendedAction.reviewInvestigation,
          status: RiskAssessmentStatus.active,
          createdAt: context.now,
          updatedAt: context.now,
          sourceLabel: collection.name,
          domainHint: context.domainHint,
        ),
      ];
    }
    return const [];
  }

  List<IncidentRiskAssessment> _pendingRelationshipSuggestions(
    RiskAssessmentContext context,
  ) {
    // Matter (source: ai, RELATED, suggested) is reviewable in Connections.
    // It is not a documentation gap, missing evidence, or structural defect.
    final pending = [
      for (final s in context.relationshipSuggestions)
        if (s.status == RelationshipSuggestionStatus.suggested &&
            s.source != RelationshipSuggestionSource.ai)
          s,
    ];
    if (pending.isEmpty) {
      return const [];
    }
    final first = pending.first;
    return [
      IncidentRiskAssessment(
        id: '${RiskType.relationshipGap.wireName}_suggestion_${context.incidentId}',
        incidentId: context.incidentId,
        riskType: RiskType.relationshipGap,
        severity: RiskSeverity.low,
        confidence: 0.65,
        reason:
            'A relationship was suggested between evidence items but has not '
            'been reviewed yet.',
        sourceEvidenceIds: [
          first.sourceEvidenceId,
          first.targetEvidenceId,
        ],
        recommendedAction: RiskRecommendedAction.reviewInvestigation,
        status: RiskAssessmentStatus.active,
        createdAt: context.now,
        updatedAt: context.now,
        sourceLabel: 'Investigation Graph',
        domainHint: context.domainHint,
      ),
    ];
  }

  List<IncidentRiskAssessment> _followUp(RiskAssessmentContext context) {
    if (context.journeyStage != JourneyStage.building) {
      return const [];
    }
    final age = context.now.difference(context.updatedAt);
    final hasSupporting = EvidenceSemantics.primaryChronology(context.evidence)
        .any(
          (item) => EvidenceSemantics.hasStructuralSupport(
            evidenceId: item.id,
            items: context.evidence,
            relationships: context.relationships,
          ),
        );
    final needsReview = age >= _followUpAge;
    final missingNarrative =
        hasSupporting && context.narrativeEventCount == 0;

    if (!needsReview &&
        !missingNarrative &&
        context.memoryRecallHints.isEmpty) {
      return const [];
    }

    final reason = missingNarrative
        ? 'Supporting evidence exists, but no follow-up reconstruction notes '
            'are recorded yet.'
        : needsReview
            ? 'This investigation has not been reviewed recently and may still '
                'need a follow-up.'
            : 'Memory Recall suggests this investigation may still need '
                'attention.';

    return [
      IncidentRiskAssessment(
        id: '${RiskType.followUp.wireName}_${context.incidentId}',
        incidentId: context.incidentId,
        riskType: RiskType.followUp,
        severity: RiskSeverity.low,
        confidence: 0.7,
        reason: reason,
        recommendedAction: RiskRecommendedAction.addFollowUp,
        status: RiskAssessmentStatus.active,
        createdAt: context.now,
        updatedAt: context.now,
        followUpKind: FollowUpKind.needsReview,
        domainHint: context.domainHint,
      ),
    ];
  }

  List<IncidentRiskAssessment> _timeSensitive(RiskAssessmentContext context) {
    if (context.journeyStage != JourneyStage.building) {
      return const [];
    }
    final age = context.now.difference(context.createdAt);
    if (age < _timeSensitiveAge) {
      return const [];
    }
    final months = (age.inDays / 30).floor().clamp(3, 24);
    return [
      IncidentRiskAssessment(
        id: '${RiskType.timeSensitive.wireName}_${context.incidentId}',
        incidentId: context.incidentId,
        riskType: RiskType.timeSensitive,
        severity: RiskSeverity.medium,
        confidence: 0.72,
        reason:
            'This incident was opened about $months months ago and is still '
            'Building. Consider reviewing what may still need attention.',
        recommendedAction: RiskRecommendedAction.reviewInvestigation,
        status: RiskAssessmentStatus.active,
        createdAt: context.now,
        updatedAt: context.now,
        domainHint: context.domainHint,
      ),
    ];
  }

  List<IncidentRiskAssessment> _contradictions(RiskAssessmentContext context) {
    final hits = ContradictionDetector.geoTimestampConflicts(
      captured: context.capturedEvidence,
    );
    if (hits.isEmpty) {
      return const [];
    }
    final hit = hits.first;
    return [
      IncidentRiskAssessment(
        id: '${RiskType.contradiction.wireName}_${hit.evidenceIds.join('_')}',
        incidentId: context.incidentId,
        riskType: RiskType.contradiction,
        severity: RiskSeverity.medium,
        confidence: 0.68,
        reason: hit.reason,
        sourceEvidenceIds: hit.evidenceIds,
        recommendedAction: RiskRecommendedAction.reviewEvidence,
        status: RiskAssessmentStatus.active,
        createdAt: context.now,
        updatedAt: context.now,
        sourceLabel: hit.sourceLabel,
        domainHint: context.domainHint,
      ),
    ];
  }

  /// Recurrence only when library titles match exactly (no speculative AI).
  List<IncidentRiskAssessment> _memoryPattern(RiskAssessmentContext context) {
    final title = context.incidentTitle.trim().toLowerCase();
    if (title.isEmpty || title == 'untitled incident') {
      return const [];
    }
    final peers = [
      for (final s in context.librarySummaries)
        if (s.id != context.incidentId &&
            s.title.trim().toLowerCase() == title)
          s,
    ];
    if (peers.length < 2) {
      return const [];
    }
    final total = peers.length + 1;
    return [
      IncidentRiskAssessment(
        id: '${RiskType.pattern.wireName}_${context.incidentId}',
        incidentId: context.incidentId,
        riskType: RiskType.pattern,
        severity: RiskSeverity.low,
        confidence: 0.6,
        reason:
            'You have captured $total incidents with this same title. '
            'This may represent a recurring situation worth reviewing together.',
        recommendedAction: RiskRecommendedAction.reviewInvestigation,
        status: RiskAssessmentStatus.active,
        createdAt: context.now,
        updatedAt: context.now,
        domainHint: context.domainHint,
      ),
    ];
  }

  static Set<String> _connectedEvidenceIds(RiskAssessmentContext context) {
    final ids = <String>{};
    for (final rel in context.relationships) {
      if (EvidenceSemantics.isSuggestedRelated(rel)) {
        continue;
      }
      ids.add(rel.sourceEvidenceId);
      ids.add(rel.targetEvidenceId);
    }
    for (final item in context.evidence) {
      if (EvidenceSemantics.hasStructuralRelationship(
        evidenceId: item.id,
        items: context.evidence,
        relationships: context.relationships,
      )) {
        ids.add(item.id);
        final parent = item.parentEvidenceId;
        if (parent != null && parent.isNotEmpty) {
          ids.add(parent);
        }
      }
    }
    return ids;
  }

  static RiskAssessmentContext _scoped(RiskAssessmentContext context) {
    final evidence = EvidenceSemantics.incidentScopedItems(
      context.evidence,
      context.incidentId,
    );
    final relationships = EvidenceSemantics.incidentScopedRelationships(
      relationships: context.relationships,
      scopedItems: evidence,
    );
    final captured = EvidenceSemantics.incidentScopedCaptured(
      context.capturedEvidence,
      context.incidentId,
    );
    final ownedIds = {for (final item in evidence) item.id};
    return RiskAssessmentContext(
      incidentId: context.incidentId,
      incidentTitle: context.incidentTitle,
      journeyStage: context.journeyStage,
      createdAt: context.createdAt,
      updatedAt: context.updatedAt,
      now: context.now,
      evidence: evidence,
      capturedEvidence: captured,
      relationships: relationships,
      collections: [
        for (final collection in context.collections)
          if (collection.incidentId.isNotEmpty &&
              collection.incidentId == context.incidentId)
            collection,
      ],
      graph: context.graph,
      relationshipSuggestions: [
        for (final suggestion in context.relationshipSuggestions)
          if (suggestion.incidentId.isNotEmpty &&
              suggestion.incidentId == context.incidentId &&
              ownedIds.contains(suggestion.sourceEvidenceId) &&
              ownedIds.contains(suggestion.targetEvidenceId))
            suggestion,
      ],
      narrativeEventCount: context.narrativeEventCount,
      dismissedIds: context.dismissedIds,
      reviewedIds: context.reviewedIds,
      librarySummaries: context.librarySummaries,
      memoryRecallHints: context.memoryRecallHints,
      domainHint: context.domainHint,
    );
  }
}
