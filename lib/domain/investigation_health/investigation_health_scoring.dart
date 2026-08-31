import 'health_finding.dart';
import 'health_finding_category.dart';
import 'health_finding_priority.dart';
import 'investigation_health_weights.dart';

/// Shared scoring utilities for investigation health evaluation.
abstract final class InvestigationHealthScoring {
  InvestigationHealthScoring._();

  static const Map<HealthFindingPriority, int> priorityPenalties = {
    HealthFindingPriority.high: 25,
    HealthFindingPriority.medium: 15,
    HealthFindingPriority.low: 8,
  };

  static int categoryScore(
    HealthFindingCategory category,
    List<HealthFinding> findings,
  ) {
    final categoryFindings =
        findings.where((finding) => finding.category == category);
    var penalty = 0;
    for (final finding in categoryFindings) {
      penalty += priorityPenalties[finding.priority] ?? 0;
    }
    return (100 - penalty).clamp(0, 100);
  }

  static int overallScore({
    required int evidenceCompletenessScore,
    required int relationshipCoverageScore,
    required int timelineIntegrityScore,
    required int narrativeSupportScore,
    required int trustReadinessScore,
    InvestigationHealthWeights weights = InvestigationHealthWeights.defaults,
  }) {
    weights.validate();
    final weighted = evidenceCompletenessScore * weights.evidenceCompleteness +
        relationshipCoverageScore * weights.relationshipCoverage +
        timelineIntegrityScore * weights.timelineIntegrity +
        narrativeSupportScore * weights.narrativeSupport +
        trustReadinessScore * weights.trustReadiness;
    return weighted.round().clamp(0, 100);
  }
}
