/// Coaching priority derived from investigation completeness — not severity.
enum InvestigationCoachingPriority {
  high('High'),
  medium('Medium'),
  low('Low');

  const InvestigationCoachingPriority(this.label);

  final String label;
}
