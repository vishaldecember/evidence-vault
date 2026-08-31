/// Calm severity levels — never alarmist.
///
/// Insights describe; they do not judge or warn.
enum InsightSeverity {
  informational,
  neutral,
  positive;

  String get label => switch (this) {
        InsightSeverity.informational => 'Informational',
        InsightSeverity.neutral => 'Neutral',
        InsightSeverity.positive => 'Positive',
      };
}
