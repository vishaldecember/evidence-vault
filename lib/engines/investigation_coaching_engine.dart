import '../controllers/workspace_evidence_controller.dart';
import '../engines/adaptive_coaching.dart';
import '../engines/evidence_semantics.dart';
import '../engines/narrative_builder.dart';
import '../models/evidence_relationship.dart';
import '../models/investigation_coaching_category.dart';
import '../models/investigation_coaching_item.dart';
import '../models/investigation_coaching_priority.dart';
import '../models/investigation_coaching_target.dart';
import '../models/relationship_group_confidence.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';
import '../services/trust_package_scorecard_service.dart';

/// Snapshot of investigation state used to derive coaching insights.
class InvestigationCoachingContext {
  const InvestigationCoachingContext({
    required this.incidentId,
    required this.items,
    required this.timelineNodes,
    required this.narrativeEvents,
    required this.relationships,
    required this.groupMemberEvidenceIds,
    required this.primaryEvidenceCount,
    required this.enrichedEvidenceCount,
    required this.trustPackageQuality,
    this.previouslySeenEvidenceIds,
  });

  final String incidentId;
  final List<WorkspaceEvidenceItem> items;
  final List<TimelineAnchorNode> timelineNodes;
  final List<NarrativeEventViewModel> narrativeEvents;
  final List<EvidenceRelationship> relationships;
  final Set<String> groupMemberEvidenceIds;
  final int primaryEvidenceCount;
  final int enrichedEvidenceCount;
  final TrustPackageInvestigationQuality trustPackageQuality;

  /// Session snapshot of evidence IDs already observed by coaching.
  /// Null/empty = first evaluation; existing items are not "new".
  final Set<String>? previouslySeenEvidenceIds;

  factory InvestigationCoachingContext.fromController(
    WorkspaceEvidenceController controller, {
    Set<String>? previouslySeenEvidenceIds,
  }) {
    final incidentId = controller.currentIncident.id;
    final items = EvidenceSemantics.incidentScopedItems(
      controller.currentIncident.evidence,
      incidentId,
    );
    final relationships = EvidenceSemantics.incidentScopedRelationships(
      relationships: controller.state.relationships,
      scopedItems: items,
    );
    final groupMemberIds = <String>{};
    for (final group in controller.state.relationshipGroups) {
      if (group.incidentId.isEmpty || group.incidentId != incidentId) {
        continue;
      }
      groupMemberIds.addAll(group.memberEvidenceIds);
    }

    return InvestigationCoachingContext(
      incidentId: incidentId,
      items: items,
      timelineNodes: EvidenceSemantics.incidentScopedTimeline(
        controller.anchoredTimeline,
        incidentId,
      ),
      narrativeEvents: [
        for (final event in controller.narrativeEvents)
          if (event.event.incidentId.isNotEmpty &&
              event.event.incidentId == incidentId)
            event,
      ],
      relationships: relationships,
      groupMemberEvidenceIds: groupMemberIds,
      primaryEvidenceCount: EvidenceSemantics.primaryChronologyCount(items),
      enrichedEvidenceCount: controller.enrichment.enrichedEvidenceCount,
      trustPackageQuality: TrustPackageScorecardService.evaluate(
        controller.canonicalTrustPackage,
      ),
      previouslySeenEvidenceIds: previouslySeenEvidenceIds,
    );
  }
}

/// Rule-based coaching engine — never infers intent or legal conclusions.
abstract final class InvestigationCoachingEngine {
  static const Duration _significantTimeGap = Duration(hours: 2);

  static List<InvestigationCoachingItem> generate(
    InvestigationCoachingContext context,
  ) {
    if (context.primaryEvidenceCount == 0) {
      return const [];
    }

    final items = <InvestigationCoachingItem>[
      ..._evidenceCompleteness(context),
      ..._relationshipCoaching(context),
      ..._timelineCoaching(context),
      ..._narrativeCoaching(context),
      ..._trustPackageReadiness(context),
    ];

    return AdaptiveCoaching.normalize(
      input: AdaptiveCoachingInput(
        items: context.items,
        relationships: context.relationships,
        primaryEvidenceCount: context.primaryEvidenceCount,
        previouslySeenEvidenceIds: context.previouslySeenEvidenceIds,
        groupMemberEvidenceIds: context.groupMemberEvidenceIds,
        narrativeEventCount: context.narrativeEvents.length,
      ),
      items: items,
    );
  }

  static List<InvestigationCoachingItem> _evidenceCompleteness(
    InvestigationCoachingContext context,
  ) {
    final insights = <InvestigationCoachingItem>[];
    final primaryItems =
        EvidenceSemantics.primaryChronology(context.items);
    final photos = primaryItems
        .where((item) => item.kind == WorkspaceEvidenceKind.image)
        .toList();
    final photosWithoutContext = photos.where(
      (item) => !EvidenceSemantics.hasRecordedContext(
        item,
        incidentItems: context.items,
        relationships: context.relationships,
      ),
    );

    if (photos.length >= 2 && photosWithoutContext.length == photos.length) {
      final photoLabel = photos.length == 1 ? 'photo' : 'photos';
      insights.add(
        InvestigationCoachingItem(
          fingerprint: 'evidence_completeness:photos_no_observations',
          category: InvestigationCoachingCategory.evidenceCompleteness,
          observation:
              'You have ${photos.length} $photoLabel but no recorded written observations.',
          suggestedAction:
              'Consider adding a description or note for what each photo shows.',
          priority: photos.length >= 4
              ? InvestigationCoachingPriority.high
              : InvestigationCoachingPriority.medium,
          target: InvestigationCoachingTarget.evidenceStage,
          relatedEvidenceIds: [
            for (final item in photosWithoutContext) item.id,
          ],
        ),
      );
    }

    if (!EvidenceSemantics.hasWitnessKind(context.items) &&
        context.primaryEvidenceCount >= 2) {
      insights.add(
        InvestigationCoachingItem(
          fingerprint: 'evidence_completeness:no_witness',
          category: InvestigationCoachingCategory.evidenceCompleteness,
          observation:
              'A witness statement is optional if someone else observed the event.',
          suggestedAction:
              'You may consider adding a witness statement if someone else observed the event.',
          priority: context.primaryEvidenceCount >= 4
              ? InvestigationCoachingPriority.medium
              : InvestigationCoachingPriority.low,
          target: InvestigationCoachingTarget.evidenceStage,
        ),
      );
    }

    for (final node in context.timelineNodes) {
      final supportCount = EvidenceSemantics.structuralSupportCount(
        evidenceId: node.capturedItem.id,
        items: context.items,
        relationships: context.relationships,
      );
      if (supportCount == 1 &&
          node.capturedItem.kind == WorkspaceEvidenceKind.image) {
        insights.add(
          InvestigationCoachingItem(
            fingerprint:
                'evidence_completeness:single_support:${node.anchor.id}',
            category: InvestigationCoachingCategory.evidenceCompleteness,
            observation:
                'This timeline item contains 1 parent-linked supporting item.',
            suggestedAction:
                'You may consider attaching additional parent-linked supporting evidence if it exists.',
            priority: InvestigationCoachingPriority.medium,
            target: InvestigationCoachingTarget.timelineTab,
            targetAnchorId: node.capturedItem.id,
          ),
        );
      }
    }

    return insights;
  }

  static List<InvestigationCoachingItem> _relationshipCoaching(
    InvestigationCoachingContext context,
  ) {
    // relationship:similar_photos is not generated: there is no visual
    // similarity signal. Do not infer similarity from ungrouped photos.
    final insights = <InvestigationCoachingItem>[];
    final ungroupedPrimary =
        EvidenceSemantics.primaryChronology(context.items)
            .where((item) => !context.groupMemberEvidenceIds.contains(item.id))
            .toList();

    if (ungroupedPrimary.isNotEmpty &&
        context.groupMemberEvidenceIds.isNotEmpty) {
      final count = ungroupedPrimary.length;
      insights.add(
        InvestigationCoachingItem(
          fingerprint: 'relationship:unconnected_evidence',
          category: InvestigationCoachingCategory.relationship,
          observation:
              '$count primary chronology ${count == 1 ? 'item is' : 'items are'} not included in an investigation group.',
          suggestedAction:
              'Review ungrouped evidence if a group is useful. Group membership is not the same as a structural relationship.',
          priority: count >= 3
              ? InvestigationCoachingPriority.high
              : InvestigationCoachingPriority.medium,
          target: InvestigationCoachingTarget.connectionsTab,
          relatedEvidenceIds: [
            for (final item in ungroupedPrimary) item.id,
          ],
        ),
      );
    }

    return insights;
  }

  static List<InvestigationCoachingItem> _timelineCoaching(
    InvestigationCoachingContext context,
  ) {
    final insights = <InvestigationCoachingItem>[];
    final nodes = context.timelineNodes;

    for (var index = 1; index < nodes.length; index++) {
      final previous = nodes[index - 1].anchor.anchoredAt;
      final current = nodes[index].anchor.anchoredAt;
      final gap = current.difference(previous);
      if (gap >= _significantTimeGap) {
        insights.add(
          InvestigationCoachingItem(
            fingerprint:
                'timeline:time_gap:${nodes[index - 1].anchor.id}:${nodes[index].anchor.id}',
            category: InvestigationCoachingCategory.timeline,
            observation:
                'There is a ${gap.inHours}-hour gap between consecutive capture timestamps.',
            suggestedAction:
                'You may consider documenting activity during the gap if it is relevant.',
            priority: gap.inHours >= 6
                ? InvestigationCoachingPriority.high
                : InvestigationCoachingPriority.medium,
            target: InvestigationCoachingTarget.timelineTab,
            targetAnchorId: nodes[index].capturedItem.id,
            relatedEvidenceIds: [
              nodes[index - 1].capturedItem.id,
              nodes[index].capturedItem.id,
            ],
          ),
        );
      }
    }

    for (final node in nodes) {
      if (!EvidenceSemantics.hasStructuralSupport(
        evidenceId: node.capturedItem.id,
        items: context.items,
        relationships: context.relationships,
      )) {
        insights.add(
        InvestigationCoachingItem(
          fingerprint: 'timeline:no_support:${node.anchor.id}',
          category: InvestigationCoachingCategory.timeline,
          observation:
              'This timeline item has no parent-linked supporting evidence.',
          suggestedAction:
              'You may add supporting material if available.',
          priority: InvestigationCoachingPriority.high,
          target: InvestigationCoachingTarget.timelineTab,
          targetAnchorId: node.capturedItem.id,
        ),
        );
      }
    }

    return insights;
  }

  static List<InvestigationCoachingItem> _narrativeCoaching(
    InvestigationCoachingContext context,
  ) {
    final insights = <InvestigationCoachingItem>[];
    final unenrichedPrimary =
        EvidenceSemantics.primaryChronology(context.items).where(
      (item) => !EvidenceSemantics.hasRecordedContext(
        item,
        incidentItems: context.items,
        relationships: context.relationships,
      ),
    );

    if (unenrichedPrimary.isNotEmpty) {
      insights.add(
        InvestigationCoachingItem(
          fingerprint: 'narrative:document_relevance',
          category: InvestigationCoachingCategory.narrative,
          observation:
              '${unenrichedPrimary.length} primary chronology ${unenrichedPrimary.length == 1 ? 'item has' : 'items have'} no recorded location, description, or note.',
          suggestedAction:
              'Consider adding location, a description, or a note if that information exists.',
          priority: unenrichedPrimary.length >= 3
              ? InvestigationCoachingPriority.high
              : InvestigationCoachingPriority.medium,
          target: InvestigationCoachingTarget.evidenceStage,
          relatedEvidenceIds: [
            for (final item in unenrichedPrimary) item.id,
          ],
        ),
      );
    }

    for (final event in context.narrativeEvents) {
      final evidenceCount = event.displayEvidence.length;
      if (evidenceCount == 1) {
        insights.add(
          InvestigationCoachingItem(
            fingerprint: 'narrative:single_source:${event.event.id}',
            category: InvestigationCoachingCategory.narrative,
            observation:
                'This reconstructed event currently references 1 evidence item.',
            suggestedAction:
                'You may consider linking additional evidence to this event if it exists.',
            priority: InvestigationCoachingPriority.medium,
            target: InvestigationCoachingTarget.reconstructionTab,
            targetEventId: event.event.id,
            relatedEvidenceIds: [
              for (final evidence in event.displayEvidence) evidence.id,
            ],
          ),
        );
      }

      if (event.validation.status == RelationshipGroupConfidence.low) {
        insights.add(
          InvestigationCoachingItem(
            fingerprint: 'narrative:low_confidence:${event.event.id}',
            category: InvestigationCoachingCategory.narrative,
            observation:
                'This reconstructed event currently has low documentation completeness.',
            suggestedAction:
                'Add recorded context or parent-linked supporting evidence if available.',
            priority: InvestigationCoachingPriority.high,
            target: InvestigationCoachingTarget.reconstructionTab,
            targetEventId: event.event.id,
            relatedEvidenceIds: [
              for (final evidence in event.displayEvidence) evidence.id,
            ],
          ),
        );
      }
    }

    return insights;
  }

  static List<InvestigationCoachingItem> _trustPackageReadiness(
    InvestigationCoachingContext context,
  ) {
    final insights = <InvestigationCoachingItem>[];
    final quality = context.trustPackageQuality;
    final unmetCount =
        quality.indicators.where((entry) => !entry.isMet).length;
    final lowSupportEvents = context.narrativeEvents
        .where(
          (event) =>
              event.validation.status == RelationshipGroupConfidence.low,
        )
        .length;

    if (quality.overallRating == TrustPackageQualityRating.excellent &&
        unmetCount == 0) {
      insights.add(
        InvestigationCoachingItem(
          fingerprint: 'trust_package:ready_for_review',
          category: InvestigationCoachingCategory.trustPackageReadiness,
          observation: 'This investigation is ready for review.',
          suggestedAction:
              'Open the Trust Package to confirm completeness before sharing.',
          priority: InvestigationCoachingPriority.low,
          target: InvestigationCoachingTarget.trustPackageStage,
        ),
      );
    } else if (quality.overallRating == TrustPackageQualityRating.good &&
        unmetCount <= 2) {
      insights.add(
        InvestigationCoachingItem(
          fingerprint: 'trust_package:almost_complete',
          category: InvestigationCoachingCategory.trustPackageReadiness,
          observation: 'The Trust Package is almost complete.',
          suggestedAction:
              'Address remaining quality indicators before final review.',
          priority: InvestigationCoachingPriority.medium,
          target: InvestigationCoachingTarget.trustPackageStage,
        ),
      );
    }

    if (lowSupportEvents >= 2) {
      insights.add(
        InvestigationCoachingItem(
          fingerprint: 'trust_package:events_need_support',
          category: InvestigationCoachingCategory.trustPackageReadiness,
          observation:
              '$lowSupportEvents reconstructed events currently have low documentation completeness.',
          suggestedAction:
              'Review those reconstructed events and add recorded context or parent-linked supporting evidence if available.',
          priority: InvestigationCoachingPriority.high,
          target: InvestigationCoachingTarget.reconstructionTab,
        ),
      );
    }

    return insights;
  }
}
