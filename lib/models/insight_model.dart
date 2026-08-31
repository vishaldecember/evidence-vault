import 'insight_severity.dart';
import 'insight_type.dart';

/// One observable observation about the incident record.
///
/// Generated from existing data — never inferred beyond observable facts.
/// Extension points reserved for AI-generated insights and narrative summaries.
class InsightModel {
  const InsightModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.explanation,
    this.suggestedAction,
  });

  final String id;
  final InsightType type;
  final InsightSeverity severity;
  final String title;
  final String explanation;
  final String? suggestedAction;
}
