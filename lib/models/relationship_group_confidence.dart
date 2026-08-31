/// Workspace coaching indicator for relationship group completeness.
///
/// Never persisted — always derived from current group membership and enrichment.
enum RelationshipGroupConfidence {
  low,
  medium,
  high;

  String get label => switch (this) {
        RelationshipGroupConfidence.low => 'Low',
        RelationshipGroupConfidence.medium => 'Medium',
        RelationshipGroupConfidence.high => 'High',
      };

  String get emoji => switch (this) {
        RelationshipGroupConfidence.low => '🔴',
        RelationshipGroupConfidence.medium => '🟡',
        RelationshipGroupConfidence.high => '🟢',
      };
}
