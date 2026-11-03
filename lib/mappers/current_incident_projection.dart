import '../domain/incident/current_incident.dart';
import '../domain/incident/incident_aggregate.dart';
import '../engines/enrichment_engine.dart';
import '../models/journey_stage.dart';
import '../models/relationship_group.dart';
import '../models/workspace_evidence_item.dart';
import '../repositories/workspace_evidence_repository.dart';

/// Projects the repository-owned incident aggregate into [CurrentIncident].
///
/// Evidence collection is projected once — journey order is derived from the
/// same store, never from a screen-owned list.
abstract final class CurrentIncidentProjection {
  static CurrentIncident fromAggregate(
    IncidentAggregate aggregate, {
    EnrichmentSnapshot? enrichment,
    int? narrativeEventCount,
  }) {
    final incident = aggregate.incidentRepository.currentIncident;
    final state = aggregate.projectedState;
    final evidence = List<WorkspaceEvidenceItem>.unmodifiable(state.items);
    final journeyEvidence = WorkspaceEvidenceRepository.journeySequence(
      aggregate.store,
      aggregate.timelineRepository,
    );
    final snapshot = enrichment ??
        EnrichmentEngine.compute(
          EnrichmentContext(
            items: evidence,
            relationships: state.relationships,
          ),
        );
    final timelineAnchorCount =
    aggregate.timelineRepository
        .orderedCapturedEvidenceIds()
        .where((id) => aggregate.store.capturedEvidence
            .any((evidence) => evidence.id == id))
        .length;
    final relationshipGroups = state.relationshipGroups;
    final resolvedNarrativeCount =
        narrativeEventCount ?? aggregate.narrativeEventRepository.events.length;

    final captureProgress = snapshot.enrichmentPercentage.clamp(0, 100);
    final trustPackageProgress = _trustPackageProgress(
      evidenceCount: evidence.length,
      timelineAnchorCount: timelineAnchorCount,
      relationshipGroupCount: relationshipGroups.length,
      narrativeEventCount: resolvedNarrativeCount,
      journeyStage: snapshot.journeyStage,
    );

    return CurrentIncident(
      id: incident.id,
      title: incident.title,
      status: incident.status,
      createdAt: incident.createdAt,
      updatedAt: incident.updatedAt,
      manuallyComplete: incident.manuallyComplete,
      coverEvidenceId: incident.coverEvidenceId,
      journeyStage: snapshot.journeyStage,
      captureProgressPercent: captureProgress,
      timelineAnchorCount: timelineAnchorCount,
      relationshipGroupCount: relationshipGroups.length,
      narrativeEventCount: resolvedNarrativeCount,
      evidence: evidence,
      journeyEvidence: journeyEvidence,
      relationshipGroups:
          List<RelationshipGroup>.unmodifiable(relationshipGroups),
      evidenceCollections: List.unmodifiable(aggregate.store.evidenceCollections),
      trustPackageReady: evidence.isNotEmpty,
      trustPackageProgressPercent: trustPackageProgress,
    );
  }

  static int _trustPackageProgress({
    required int evidenceCount,
    required int timelineAnchorCount,
    required int relationshipGroupCount,
    required int narrativeEventCount,
    required JourneyStage journeyStage,
  }) {
    if (evidenceCount == 0) {
      return 0;
    }

    var score = 20;
    if (timelineAnchorCount > 0) {
      score += 20;
    }
    if (relationshipGroupCount > 0) {
      score += 20;
    }
    if (narrativeEventCount > 0) {
      score += 20;
    }
    score += switch (journeyStage) {
      JourneyStage.empty => 0,
      JourneyStage.building => 10,
      JourneyStage.rich => 20,
      JourneyStage.reflective => 20,
    };
    return score.clamp(0, 100);
  }
}
