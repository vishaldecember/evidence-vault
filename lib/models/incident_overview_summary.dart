import 'evidence_relationship.dart';
import 'journey_stage.dart';
import 'relationship_group.dart';
import 'workspace_evidence_item.dart';

/// Read-only snapshot of what an incident currently contains.
///
/// Derived from existing workspace state — no duplicated business logic.
/// Extension points reserved for timeline, AI insights, missing context,
/// reflection readiness, and export readiness.
class IncidentOverviewSummary {
  const IncidentOverviewSummary({
    required this.evidenceArtifactCount,
    required this.contextItemCount,
    required this.linkedRelationshipCount,
    required this.journeyStage,
  });

  final int evidenceArtifactCount;
  final int contextItemCount;
  final int linkedRelationshipCount;
  final JourneyStage journeyStage;

  String get evidenceLabel =>
      '$evidenceArtifactCount ${_pluralize(evidenceArtifactCount, 'Artifact')}';

  String get contextLabel =>
      '$contextItemCount ${_pluralize(contextItemCount, 'Enrichment')}';

  String get linkedEvidenceLabel =>
      '$linkedRelationshipCount ${_pluralize(linkedRelationshipCount, 'Connection')}';

  String get journeyLabel => journeyStage.overviewLabel;

  factory IncidentOverviewSummary.fromWorkspace({
    required List<WorkspaceEvidenceItem> items,
    required List<EvidenceRelationship> relationships,
    required List<RelationshipGroup> relationshipGroups,
    required JourneyStage journeyStage,
  }) {
    var artifactCount = 0;
    var contextCount = 0;

    for (final item in items) {
      if (item.isContextual) {
        contextCount++;
      } else {
        artifactCount++;
      }
    }

    final connectionCount = relationshipGroups.isNotEmpty
        ? relationshipGroups.length
        : relationships.length;

    return IncidentOverviewSummary(
      evidenceArtifactCount: artifactCount,
      contextItemCount: contextCount,
      linkedRelationshipCount: connectionCount,
      journeyStage: journeyStage,
    );
  }

  static String _pluralize(int count, String singular) {
    return count == 1 ? singular : '${singular}s';
  }
}
