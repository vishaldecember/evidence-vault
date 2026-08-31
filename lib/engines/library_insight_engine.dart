import '../models/library_incident_record.dart';
import '../models/library_insight_model.dart';

/// Input snapshot for library insight generation — reads preserved records only.
class LibraryInsightContext {
  const LibraryInsightContext({required this.incidents});

  final List<LibraryIncidentRecord> incidents;

  int get incidentCount => incidents.length;
}

/// Surfaces observable cross-incident patterns across the Library of Truth.
///
/// No AI. No external services. No speculation, conclusions, or intent.
/// Extension points reserved for AI-assisted pattern recognition,
/// relationship clustering, recurring entities, and trend analysis.
abstract class LibraryInsightEngine {
  List<LibraryInsightModel> generateInsights(LibraryInsightContext context);
}
