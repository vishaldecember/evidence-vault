/// Canonical insight categories for the Insight Engine.
///
/// Phase 1 supports six observable pattern types only.
/// Extension points reserved for AI-generated insights, risk detection,
/// missing evidence suggestions, contradiction detection, and narratives.
enum InsightType {
  missingContext,
  missingReflection,
  disconnectedEvidence,
  highlyConnectedEvidence,
  timelineComplete,
  timelineIncomplete;

  String get label => switch (this) {
        InsightType.missingContext => 'Missing Context',
        InsightType.missingReflection => 'Missing Reflection',
        InsightType.disconnectedEvidence => 'Disconnected Evidence',
        InsightType.highlyConnectedEvidence => 'Highly Connected Evidence',
        InsightType.timelineComplete => 'Timeline Complete',
        InsightType.timelineIncomplete => 'Timeline Incomplete',
      };
}
