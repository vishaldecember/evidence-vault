import '../models/evidence_relationship.dart';
import '../models/insight_model.dart';
import '../models/reflection_model.dart';
import '../models/workspace_evidence_item.dart';

/// Input snapshot for insight generation — reads existing domain data only.
class InsightContext {
  const InsightContext({
    required this.items,
    required this.relationships,
    required this.reflections,
  });

  final List<WorkspaceEvidenceItem> items;
  final List<EvidenceRelationship> relationships;
  final List<ReflectionModel> reflections;

  List<WorkspaceEvidenceItem> get artifacts =>
      items.where((item) => !item.isContextual).toList();

  List<WorkspaceEvidenceItem> get contextItems =>
      items.where((item) => item.isContextual).toList();

  int get artifactCount => artifacts.length;

  int get contextCount => contextItems.length;

  int get relationshipCount => relationships.length;

  int get reflectionCount => reflections.length;
}

/// Generates observations from existing incident information.
///
/// No AI. No external services. No speculation.
/// Extension points reserved for AI insights, risk detection, missing
/// evidence suggestions, contradiction detection, and narrative summaries.
abstract class InsightEngine {
  List<InsightModel> generateInsights(InsightContext context);
}
