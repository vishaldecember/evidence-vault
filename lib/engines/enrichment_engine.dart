import 'dart:developer' as developer;

import '../models/evidence_relationship.dart';
import '../models/journey_stage.dart';
import '../services/workspace_coaching_service.dart';
import '../models/workspace_evidence_item.dart';
import 'evidence_semantics.dart';

/// Optional enrichment signals beyond attached artifacts and links.
///
/// Future AI summaries, metadata, tags, and witness details populate these
/// flags so [EnrichmentEngine] picks them up without UI changes.
class EvidenceEnrichmentSignals {
  const EvidenceEnrichmentSignals({
    this.hasContextFields = false,
    this.hasTags = false,
    this.hasLocation = false,
    this.hasTimeClarification = false,
    this.hasWitnessDetails = false,
    this.hasAiEnrichment = false,
  });

  final bool hasContextFields;
  final bool hasTags;
  final bool hasLocation;
  final bool hasTimeClarification;
  final bool hasWitnessDetails;
  final bool hasAiEnrichment;

  bool get hasAny =>
      hasContextFields ||
      hasTags ||
      hasLocation ||
      hasTimeClarification ||
      hasWitnessDetails ||
      hasAiEnrichment;
}

/// Workspace snapshot used to evaluate incident enrichment maturity.
class EnrichmentContext {
  const EnrichmentContext({
    required this.items,
    required this.relationships,
    this.signalsByEvidenceId = const {},
    this.richBaselinePrimaryCount,
  });

  final List<WorkspaceEvidenceItem> items;
  final List<EvidenceRelationship> relationships;
  final Map<String, EvidenceEnrichmentSignals> signalsByEvidenceId;
  /// Primary evidence count when the incident last reached RICH.
  final int? richBaselinePrimaryCount;

  EvidenceEnrichmentSignals signalsFor(String evidenceId) =>
      signalsByEvidenceId[evidenceId] ?? const EvidenceEnrichmentSignals();
}

/// Official maturity output of the Incident Reconstruction Platform.
///
/// [journeyStage] is derived exclusively from [enrichmentPercentage].
class EnrichmentSnapshot {
  const EnrichmentSnapshot({
    required this.primaryEvidenceCount,
    required this.enrichedEvidenceCount,
    required this.enrichmentPercentage,
    required this.journeyStage,
    required this.coaching,
  });

  final int primaryEvidenceCount;
  final int enrichedEvidenceCount;
  final int enrichmentPercentage;
  final JourneyStage journeyStage;
  final WorkspaceCoaching coaching;

  /// Backward-compatible coaching text accessor.
  String get coachingMessage => coaching.coachingMessage;
}

/// Single source of truth for incident enrichment maturity.
///
/// All platform services (Story Engine, Trust Engine, AI services) must consume
/// [EnrichmentEngine.compute] instead of implementing their own calculations.
abstract final class EnrichmentEngine {
  EnrichmentEngine._();

  /// Computes the three maturity values and derived journey stage.
  static EnrichmentSnapshot compute(EnrichmentContext context) {
    final primaryItems = primaryEvidence(context.items);
    final primaryEvidenceCount = primaryItems.length;
    final primaryWithRecordedContextCount = primaryItems
        .where(
          (item) => EvidenceSemantics.hasRecordedContext(
            item,
            incidentItems: context.items,
            relationships: context.relationships,
          ),
        )
        .length;

    if (primaryEvidenceCount == 0) {
      final coaching = WorkspaceCoachingService.coachingFor(
        primaryEvidenceCount: 0,
        enrichedEvidenceCount: 0,
        enrichmentPercentage: 0,
        primaryWithRecordedContextCount: 0,
      );
      final snapshot = EnrichmentSnapshot(
        primaryEvidenceCount: 0,
        enrichedEvidenceCount: 0,
        enrichmentPercentage: 0,
        journeyStage: JourneyStage.empty,
        coaching: coaching,
      );
      _logSnapshot(snapshot);
      return snapshot;
    }

    final enrichedEvidenceCount = primaryItems
        .where((item) => isEnriched(item, context))
        .length;

    final enrichmentPercentage = _percentage(
      enrichedEvidenceCount,
      primaryEvidenceCount,
    );

    final journeyStage = _journeyStageForPercentage(enrichmentPercentage);

    final coaching = WorkspaceCoachingService.coachingFor(
      primaryEvidenceCount: primaryEvidenceCount,
      enrichedEvidenceCount: enrichedEvidenceCount,
      enrichmentPercentage: enrichmentPercentage,
      primaryWithRecordedContextCount: primaryWithRecordedContextCount,
    );

    final snapshot = EnrichmentSnapshot(
      primaryEvidenceCount: primaryEvidenceCount,
      enrichedEvidenceCount: enrichedEvidenceCount,
      enrichmentPercentage: enrichmentPercentage,
      journeyStage: journeyStage,
      coaching: coaching,
    );

    _logSnapshot(snapshot);
    return snapshot;
  }

  /// Core incident records: photo, video, and voice captures.
  static bool isPrimaryEvidence(WorkspaceEvidenceItem item) {
    return EvidenceSemantics.isPrimaryChronologyEvidence(item);
  }

  /// Whether [item] has recorded context — not suggested RELATED, not
  /// timestamp-only, not related-person metadata.
  ///
  /// Journey RICH is derived from this predicate. Auto-persisted metadata
  /// RELATED is not sufficient enrichment.
  static bool isEnriched(
    WorkspaceEvidenceItem item,
    EnrichmentContext context,
  ) {
    if (!isPrimaryEvidence(item)) {
      return false;
    }

    if (EvidenceSemantics.hasRecordedContext(
      item,
      incidentItems: context.items,
      relationships: context.relationships,
    )) {
      return true;
    }

    if (context.signalsFor(item.id).hasAny) {
      return true;
    }

    return false;
  }

  static List<WorkspaceEvidenceItem> primaryEvidence(
    List<WorkspaceEvidenceItem> items,
  ) {
    return items.where(isPrimaryEvidence).toList();
  }

  static int _percentage(int enrichedCount, int primaryCount) {
    if (primaryCount == 0) {
      return 0;
    }
    return ((enrichedCount / primaryCount) * 100).round();
  }

  static JourneyStage _journeyStageForPercentage(int enrichmentPercentage) {
    if (enrichmentPercentage == 0) {
      return JourneyStage.empty;
    }
    if (enrichmentPercentage == 100) {
      return JourneyStage.rich;
    }
    return JourneyStage.building;
  }

  static void _logSnapshot(EnrichmentSnapshot snapshot) {
    assert(() {
      developer.log(
        'Primary Evidence: ${snapshot.primaryEvidenceCount}\n'
        'Enriched Evidence: ${snapshot.enrichedEvidenceCount}\n'
        'Enrichment: ${snapshot.enrichmentPercentage}%\n'
        'Journey State: ${snapshot.journeyStage.label}',
        name: 'EnrichmentEngine',
      );
      return true;
    }());
  }
}

extension WorkspaceEvidenceEnrichment on WorkspaceEvidenceItem {
  bool get isPrimaryEvidence => EnrichmentEngine.isPrimaryEvidence(this);

  bool isEnriched(EnrichmentContext context) =>
      EnrichmentEngine.isEnriched(this, context);
}
