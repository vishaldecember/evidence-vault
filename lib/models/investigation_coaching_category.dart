/// Coaching insight categories for the Investigation Workspace assistant.
enum InvestigationCoachingCategory {
  evidenceCompleteness('Evidence Completeness'),
  relationship('Relationship Coaching'),
  timeline('Timeline Coaching'),
  narrative('Narrative Coaching'),
  trustPackageReadiness('Trust Package Readiness');

  const InvestigationCoachingCategory(this.label);

  final String label;
}
