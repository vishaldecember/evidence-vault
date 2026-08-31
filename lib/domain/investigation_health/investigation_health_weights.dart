/// Configurable category weights for overall investigation health scoring.
class InvestigationHealthWeights {
  const InvestigationHealthWeights({
    required this.evidenceCompleteness,
    required this.relationshipCoverage,
    required this.timelineIntegrity,
    required this.narrativeSupport,
    required this.trustReadiness,
  });

  final double evidenceCompleteness;
  final double relationshipCoverage;
  final double timelineIntegrity;
  final double narrativeSupport;
  final double trustReadiness;

  static const InvestigationHealthWeights defaults = InvestigationHealthWeights(
    evidenceCompleteness: 0.20,
    relationshipCoverage: 0.20,
    timelineIntegrity: 0.20,
    narrativeSupport: 0.25,
    trustReadiness: 0.15,
  );

  void validate() {
    final sum = evidenceCompleteness +
        relationshipCoverage +
        timelineIntegrity +
        narrativeSupport +
        trustReadiness;
    assert((sum - 1.0).abs() < 0.001, 'Category weights must sum to 1.0');
  }
}
