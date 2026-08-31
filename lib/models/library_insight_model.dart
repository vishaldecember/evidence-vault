import 'library_insight_type.dart';

/// One observable cross-incident pattern in the Library of Truth.
///
/// Describes what appears across preserved incidents — never speculates,
/// judges, or recommends action.
/// Extension points reserved for AI-assisted pattern recognition,
/// relationship clustering, and trend analysis.
class LibraryInsightModel {
  const LibraryInsightModel({
    required this.id,
    required this.type,
    required this.message,
    required this.incidentCount,
    required this.relatedIncidentIds,
    this.subject,
  });

  final String id;
  final LibraryInsightType type;
  final String message;
  final int incidentCount;
  final List<String> relatedIncidentIds;

  /// The shared location, organisation, person, evidence type, or period label.
  final String? subject;
}
