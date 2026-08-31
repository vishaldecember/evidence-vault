import '../domain/risk/incident_risk_assessment.dart';
import '../models/coaching_statement_kind.dart';
import '../models/evidence_relationship.dart';
import '../models/investigation_coaching_category.dart';
import '../models/investigation_coaching_item.dart';
import '../models/investigation_coaching_priority.dart';
import '../models/investigation_coaching_target.dart';
import '../models/workspace_evidence_item.dart';
import 'evidence_semantics.dart';
import 'incident_coaching_maturity.dart';

/// Inputs AdaptiveCoaching needs — not a store.
class AdaptiveCoachingInput {
  const AdaptiveCoachingInput({
    required this.items,
    required this.relationships,
    required this.primaryEvidenceCount,
    this.previouslySeenEvidenceIds,
    this.groupMemberEvidenceIds = const {},
    this.narrativeEventCount = 0,
  });

  final List<WorkspaceEvidenceItem> items;
  final List<EvidenceRelationship> relationships;
  final int primaryEvidenceCount;
  final Set<String>? previouslySeenEvidenceIds;
  final Set<String> groupMemberEvidenceIds;
  final int narrativeEventCount;
}

/// Session-free adaptive normalization for coaching output.
///
/// Lifecycle:
/// - SATISFIED / SUPERSEDED / STALE: derived — a rule that no longer matches
///   is omitted. No coaching store.
/// - NEW development: derived from [AdaptiveCoachingInput.previouslySeenEvidenceIds]
///   compared with current IDs. A null/empty previous set is the session
///   baseline (existing evidence is not "newly captured").
///
/// Maturity is derived from current incident state and changes which cards
/// survive. Does not mutate evidence, incidents, or relationships.
abstract final class AdaptiveCoaching {
  AdaptiveCoaching._();

  /// Meaningful pause before later captures are treated as a development.
  static const Duration developmentGap = Duration(hours: 24);

  static List<InvestigationCoachingItem> normalize({
    required AdaptiveCoachingInput input,
    required List<InvestigationCoachingItem> items,
  }) {
    final maturity = IncidentCoachingMaturityEval.evaluate(
      items: input.items,
      relationships: input.relationships,
    );
    var next = List<InvestigationCoachingItem>.from(items);
    next = _collapseMissingContext(next);
    next = _collapseMissingStructuralSupport(input, next);
    next = _scopeReconstruction(input, next);
    next = _dropAggregateWhenEventScopedExists(next);
    next = _withDevelopment(input, next);
    next = _applyMaturity(input, maturity, next);
    next.sort(_byAdaptivePriority);
    next = _cap(maturity, next);
    return List<InvestigationCoachingItem>.unmodifiable(next);
  }

  static IncidentCoachingMaturity maturityFor(AdaptiveCoachingInput input) {
    return IncidentCoachingMaturityEval.evaluate(
      items: input.items,
      relationships: input.relationships,
    );
  }

  /// Risk types already covered — Risk Coach is not a second documentation checklist.
  static Set<RiskType> riskTypesCoveredBy(
    Iterable<InvestigationCoachingItem> items, {
    IncidentCoachingMaturity? maturity,
  }) {
    final types = <RiskType>{
      RiskType.documentationGap,
      RiskType.missingEvidence,
    };
    for (final item in items) {
      if (item.fingerprint.contains('no_support')) {
        types.add(RiskType.documentationGap);
        types.add(RiskType.missingEvidence);
      }
    }
    if (maturity == IncidentCoachingMaturity.rich) {
      types.add(RiskType.unresolved);
    }
    return types;
  }

  static List<InvestigationCoachingItem> _collapseMissingContext(
    List<InvestigationCoachingItem> items,
  ) {
    final hasPhotosNo = items.any(
      (item) =>
          item.fingerprint == 'evidence_completeness:photos_no_observations',
    );
    final hasRelevance = items.any(
      (item) => item.fingerprint == 'narrative:document_relevance',
    );
    if (!hasPhotosNo || !hasRelevance) {
      return items;
    }
    return [
      for (final item in items)
        if (item.fingerprint != 'narrative:document_relevance') item,
    ];
  }

  static List<InvestigationCoachingItem> _collapseMissingStructuralSupport(
    AdaptiveCoachingInput input,
    List<InvestigationCoachingItem> items,
  ) {
    final chronology = EvidenceSemantics.primaryChronology(input.items);
    final unsupportedChronology = [
      for (final item in chronology)
        if (!EvidenceSemantics.hasStructuralSupport(
          evidenceId: item.id,
          items: input.items,
          relationships: input.relationships,
        ))
          item,
    ];
    final collapseAll = chronology.length >= 2 &&
        unsupportedChronology.length == chronology.length;

    if (collapseAll) {
      return [
        for (final item in items)
          if (!item.fingerprint.startsWith('timeline:no_support:')) item,
        InvestigationCoachingItem(
          fingerprint: 'timeline:no_support:incident',
          category: InvestigationCoachingCategory.timeline,
          observation:
              'This incident contains ${chronology.length} primary chronology items. None of the primary chronology items currently have parent-linked supporting evidence.',
          suggestedAction:
              'You may add supporting material if available.',
          priority: InvestigationCoachingPriority.low,
          target: InvestigationCoachingTarget.timelineTab,
          kind: CoachingStatementKind.fact,
          relatedEvidenceIds: [
            for (final item in chronology) item.id,
          ],
        ),
      ];
    }

    return [
      for (final item in items)
        if (item.fingerprint.startsWith('timeline:no_support:'))
          InvestigationCoachingItem(
            fingerprint: item.fingerprint,
            category: item.category,
            observation: item.observation,
            suggestedAction: item.suggestedAction,
            priority: InvestigationCoachingPriority.medium,
            target: item.target,
            targetAnchorId: item.targetAnchorId,
            kind: CoachingStatementKind.fact,
            relatedEvidenceIds: item.relatedEvidenceIds,
          )
        else
          item,
    ];
  }

  static List<InvestigationCoachingItem> _scopeReconstruction(
    AdaptiveCoachingInput input,
    List<InvestigationCoachingItem> items,
  ) {
    final hideDefaultSingleSource = input.primaryEvidenceCount >= 2;
    return [
      for (final item in items)
        if (item.fingerprint.startsWith('narrative:single_source:'))
          ..._keepSingleSource(
            item,
            hideDefaultSingleSource: hideDefaultSingleSource,
          )
        else
          item,
    ];
  }

  static List<InvestigationCoachingItem> _keepSingleSource(
    InvestigationCoachingItem item, {
    required bool hideDefaultSingleSource,
  }) {
    if (hideDefaultSingleSource) {
      return const [];
    }
    return [item];
  }

  static List<InvestigationCoachingItem> _dropAggregateWhenEventScopedExists(
    List<InvestigationCoachingItem> items,
  ) {
    final hasEventLow = items.any(
      (item) => item.fingerprint.startsWith('narrative:low_confidence:'),
    );
    if (!hasEventLow) {
      return items;
    }
    return [
      for (final item in items)
        if (item.fingerprint != 'trust_package:events_need_support') item,
    ];
  }

  static List<InvestigationCoachingItem> _applyMaturity(
    AdaptiveCoachingInput input,
    IncidentCoachingMaturity maturity,
    List<InvestigationCoachingItem> items,
  ) {
    return switch (maturity) {
      IncidentCoachingMaturity.early => _early(items),
      IncidentCoachingMaturity.developing => _developing(input, items),
      IncidentCoachingMaturity.documented => _documented(items),
      IncidentCoachingMaturity.rich => _rich(input, items),
    };
  }

  static List<InvestigationCoachingItem> _early(
    List<InvestigationCoachingItem> items,
  ) {
    final kept = [
      for (final item in items)
        if (!_isEarlyNoise(item.fingerprint)) item,
    ];
    final hasContextGap = kept.any(
      (item) =>
          item.fingerprint == 'evidence_completeness:photos_no_observations' ||
          item.fingerprint == 'narrative:document_relevance',
    );
    final withoutContextCards = [
      for (final item in kept)
        if (item.fingerprint != 'evidence_completeness:photos_no_observations' &&
            item.fingerprint != 'narrative:document_relevance')
          item,
    ];
    if (hasContextGap) {
      return [
        const InvestigationCoachingItem(
          fingerprint: 'incident:early_start',
          category: InvestigationCoachingCategory.evidenceCompleteness,
          observation: 'You have started documenting this incident.',
          suggestedAction:
              'Consider adding a short observation describing what happened and what this evidence shows.',
          priority: InvestigationCoachingPriority.medium,
          target: InvestigationCoachingTarget.evidenceStage,
          kind: CoachingStatementKind.suggestion,
        ),
        ...withoutContextCards,
      ];
    }
    return withoutContextCards;
  }

  static bool _isEarlyNoise(String fingerprint) {
    return fingerprint == 'evidence_completeness:no_witness' ||
        fingerprint == 'relationship:unconnected_evidence' ||
        fingerprint.startsWith('timeline:no_support:') ||
        fingerprint.startsWith('evidence_completeness:single_support:') ||
        fingerprint.startsWith('narrative:single_source:') ||
        fingerprint.startsWith('narrative:low_confidence:') ||
        fingerprint.startsWith('timeline:time_gap:') ||
        fingerprint == 'trust_package:events_need_support';
  }

  static List<InvestigationCoachingItem> _developing(
    AdaptiveCoachingInput input,
    List<InvestigationCoachingItem> items,
  ) {
    final withoutOptionals = [
      for (final item in items)
        if (item.fingerprint != 'evidence_completeness:no_witness' &&
            !item.fingerprint.startsWith(
              'evidence_completeness:single_support:',
            ) &&
            !item.fingerprint.startsWith('narrative:single_source:') &&
            !item.fingerprint.startsWith('narrative:low_confidence:'))
          item,
    ];
    final hasHigherValue = withoutOptionals.any((item) => _rank(item) <= 2);
    if (hasHigherValue) {
      return withoutOptionals;
    }
    final count = input.primaryEvidenceCount;
    if (count < 2) {
      return withoutOptionals;
    }
    final kinds = EvidenceSemantics.primaryChronology(input.items)
        .map((item) => item.kind)
        .toSet()
        .length;
    final typeLabel = kinds >= 3
        ? 'photo, video and voice evidence'
        : 'several pieces of evidence';
    return [
      InvestigationCoachingItem(
        fingerprint: 'incident:record_summary',
        category: InvestigationCoachingCategory.evidenceCompleteness,
        observation:
            'Your record now contains $count chronology items across $typeLabel.',
        suggestedAction:
            'Separate chronology items are not supporting evidence for one another.',
        priority: InvestigationCoachingPriority.low,
        target: InvestigationCoachingTarget.evidenceStage,
        kind: CoachingStatementKind.fact,
      ),
      ...withoutOptionals,
    ];
  }

  static List<InvestigationCoachingItem> _documented(
    List<InvestigationCoachingItem> items,
  ) {
    return [
      for (final item in items)
        if (item.fingerprint != 'evidence_completeness:no_witness' &&
            item.fingerprint !=
                'evidence_completeness:photos_no_observations' &&
            !item.fingerprint.startsWith(
              'evidence_completeness:single_support:',
            ) &&
            !item.fingerprint.startsWith('narrative:single_source:') &&
            !item.fingerprint.startsWith('narrative:low_confidence:'))
          item,
    ];
  }

  static List<InvestigationCoachingItem> _rich(
    AdaptiveCoachingInput input,
    List<InvestigationCoachingItem> items,
  ) {
    final development = [
      for (final item in items)
        if (item.fingerprint.startsWith('incident:development')) item,
    ];
    if (development.isNotEmpty) {
      return development;
    }
    final structural = [
      for (final item in items)
        if (_rank(item) <= 1) item,
    ];
    if (structural.isNotEmpty) {
      return [structural.first];
    }
    return [
      InvestigationCoachingItem(
        fingerprint: 'incident:well_documented',
        category: InvestigationCoachingCategory.evidenceCompleteness,
        observation:
            'This incident is now well documented across multiple evidence types.',
        suggestedAction:
            'Continue only if something in the record still needs attention.',
        priority: InvestigationCoachingPriority.low,
        target: InvestigationCoachingTarget.evidenceStage,
        kind: CoachingStatementKind.fact,
      ),
    ];
  }

  static List<InvestigationCoachingItem> _withDevelopment(
    AdaptiveCoachingInput input,
    List<InvestigationCoachingItem> items,
  ) {
    final previous = input.previouslySeenEvidenceIds;
    if (previous == null || previous.isEmpty) {
      return items;
    }
    final currentIds = {for (final item in input.items) item.id};
    final addedIds = currentIds.difference(previous);
    if (addedIds.isEmpty) {
      return items;
    }

    DateTime? previousLatest;
    for (final item in input.items) {
      if (!previous.contains(item.id)) {
        continue;
      }
      final at = item.lastPreservedAt;
      if (previousLatest == null || at.isAfter(previousLatest)) {
        previousLatest = at;
      }
    }
    if (previousLatest == null) {
      return items;
    }

    DateTime? addedEarliest;
    for (final item in input.items) {
      if (!addedIds.contains(item.id)) {
        continue;
      }
      final at = item.lastPreservedAt;
      if (addedEarliest == null || at.isBefore(addedEarliest)) {
        addedEarliest = at;
      }
    }
    if (addedEarliest == null) {
      return items;
    }

    final gap = addedEarliest.difference(previousLatest);
    if (gap < developmentGap) {
      return items;
    }

    final withoutMatchingTimeGap = [
      for (final item in items)
        if (!item.fingerprint.startsWith('timeline:time_gap:')) item,
    ];

    return [
      InvestigationCoachingItem(
        fingerprint: 'incident:development:${_stableIdKey(addedIds)}',
        category: InvestigationCoachingCategory.timeline,
        observation:
            'New evidence was added after a ${_formatElapsed(gap)} gap.',
        suggestedAction:
            'You may want to review how this new evidence relates to the earlier record.',
        priority: InvestigationCoachingPriority.high,
        target: InvestigationCoachingTarget.timelineTab,
        kind: CoachingStatementKind.fact,
      ),
      ...withoutMatchingTimeGap,
    ];
  }

  static List<InvestigationCoachingItem> _cap(
    IncidentCoachingMaturity maturity,
    List<InvestigationCoachingItem> items,
  ) {
    final max = IncidentCoachingMaturityEval.maxVisible(maturity);
    if (items.length <= max) {
      return items;
    }
    return items.take(max).toList(growable: false);
  }

  static String _stableIdKey(Set<String> ids) {
    final sorted = ids.toList()..sort();
    return sorted.join(',');
  }

  static String _formatElapsed(Duration gap) {
    if (gap.inDays >= 1) {
      final days = gap.inDays;
      return days == 1 ? '1-day' : '$days-day';
    }
    final hours = gap.inHours;
    return hours == 1 ? '1-hour' : '$hours-hour';
  }

  static int _byAdaptivePriority(
    InvestigationCoachingItem a,
    InvestigationCoachingItem b,
  ) {
    final rank = _rank(a).compareTo(_rank(b));
    if (rank != 0) {
      return rank;
    }
    final priority = a.priority.index.compareTo(b.priority.index);
    if (priority != 0) {
      return priority;
    }
    return a.category.index.compareTo(b.category.index);
  }

  /// P0 integrity … P5 positive summary.
  static int _rank(InvestigationCoachingItem item) {
    final fingerprint = item.fingerprint;
    if (fingerprint.startsWith('narrative:low_confidence:') &&
        fingerprint.contains('removed')) {
      return 0;
    }
    if (fingerprint == 'relationship:unconnected_evidence' ||
        fingerprint.startsWith('timeline:no_support:') ||
        fingerprint.startsWith('timeline:time_gap:')) {
      return 1;
    }
    if (fingerprint == 'evidence_completeness:photos_no_observations' ||
        fingerprint == 'narrative:document_relevance' ||
        fingerprint == 'incident:early_start') {
      return 2;
    }
    if (fingerprint.startsWith('incident:development')) {
      return 3;
    }
    if (fingerprint == 'evidence_completeness:no_witness' ||
        fingerprint.startsWith('evidence_completeness:single_support:')) {
      return 4;
    }
    if (fingerprint == 'incident:record_summary' ||
        fingerprint == 'incident:well_documented' ||
        fingerprint.startsWith('trust_package:')) {
      return 5;
    }
    return 2;
  }
}
