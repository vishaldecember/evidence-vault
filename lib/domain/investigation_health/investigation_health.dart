import 'health_finding.dart';

/// Structured investigation health projection — never persisted as domain truth.
class InvestigationHealth {
  const InvestigationHealth({
    required this.overallScore,
    required this.evidenceCompletenessScore,
    required this.relationshipCoverageScore,
    required this.timelineIntegrityScore,
    required this.narrativeSupportScore,
    required this.trustReadinessScore,
    required this.generatedAt,
    required this.findings,
  });

  final int overallScore;
  final int evidenceCompletenessScore;
  final int relationshipCoverageScore;
  final int timelineIntegrityScore;
  final int narrativeSupportScore;
  final int trustReadinessScore;
  final DateTime generatedAt;
  final List<HealthFinding> findings;
}
