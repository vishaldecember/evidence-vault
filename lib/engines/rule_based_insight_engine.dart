import '../models/insight_model.dart';
import '../models/insight_severity.dart';
import '../models/insight_type.dart';
import 'insight_engine.dart';

/// Rule-based insight generation from observable workspace facts.
class RuleBasedInsightEngine implements InsightEngine {
  const RuleBasedInsightEngine();

  static int _counter = 0;

  static String _nextId() {
    _counter += 1;
    return 'insight-$_counter';
  }

  @override
  List<InsightModel> generateInsights(InsightContext context) {
    final insights = <InsightModel>[];

    if (context.artifactCount == 0) {
      return insights;
    }

    if (_hasMissingContext(context)) {
      insights.add(
        InsightModel(
          id: _nextId(),
          type: InsightType.missingContext,
          severity: InsightSeverity.informational,
          title: 'Context not yet added',
          explanation:
              'This evidence has not yet been enriched with context.',
          suggestedAction: 'Add Context',
        ),
      );
    }

    if (context.reflectionCount == 0) {
      insights.add(
        InsightModel(
          id: _nextId(),
          type: InsightType.missingReflection,
          severity: InsightSeverity.informational,
          title: 'Reflection not yet recorded',
          explanation: 'This incident has no reflection yet.',
          suggestedAction: 'Add Reflection',
        ),
      );
    }

    if (context.artifactCount >= 2 && context.relationshipCount == 0) {
      insights.add(
        InsightModel(
          id: _nextId(),
          type: InsightType.disconnectedEvidence,
          severity: InsightSeverity.neutral,
          title: 'Evidence not yet connected',
          explanation:
              'Several pieces of evidence are preserved but not yet linked '
              'to one another.',
          suggestedAction: 'Link Existing Evidence',
        ),
      );
    }

    if (context.relationshipCount >= 2) {
      insights.add(
        InsightModel(
          id: _nextId(),
          type: InsightType.highlyConnectedEvidence,
          severity: InsightSeverity.positive,
          title: 'Connected evidence',
          explanation: 'Several pieces of evidence are connected.',
        ),
      );
    }

    if (context.contextCount > 0 && context.artifactCount > 0) {
      insights.add(
        InsightModel(
          id: _nextId(),
          type: InsightType.timelineComplete,
          severity: InsightSeverity.positive,
          title: 'Timeline includes context',
          explanation:
              'Your incident timeline includes both preserved evidence '
              'and added context.',
        ),
      );
    } else if (context.artifactCount > 0 && context.contextCount == 0) {
      insights.add(
        InsightModel(
          id: _nextId(),
          type: InsightType.timelineIncomplete,
          severity: InsightSeverity.informational,
          title: 'Timeline beginning',
          explanation:
              'Your timeline currently reflects preserved evidence. '
              'Context will appear here as you enrich the record.',
        ),
      );
    }

    return insights;
  }

  bool _hasMissingContext(InsightContext context) {
    if (context.contextCount == 0) {
      return true;
    }

    final itemById = {for (final item in context.items) item.id: item};

    return context.artifacts.any((artifact) {
      final hasContextualLink = artifact.relatedEvidenceIds.any((id) {
        final related = itemById[id];
        return related != null && related.isContextual;
      });
      return !hasContextualLink;
    });
  }
}
