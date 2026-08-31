import '../engines/enrichment_engine.dart';
import '../models/connection_group_node.dart';
import '../models/relationship_group.dart';
import '../models/relationship_group_confidence.dart';
import '../models/workspace_evidence_item.dart';
import 'narrative_validation_service.dart';

/// Backward-compatible wrapper around [NarrativeValidationService].
abstract final class NarrativeEventConfidenceService {
  static NarrativeEventConfidence compute({
    required List<RelationshipGroup> relationshipGroups,
    required List<ConnectionGroupNode> groupNodes,
    required List<WorkspaceEvidenceItem> displayEvidence,
    required EnrichmentContext enrichmentContext,
  }) {
    final validation = NarrativeValidationService.validateEvent(
      displayEvidence: displayEvidence,
      supportingEvidence: const [],
      reconstructionNotes: const [],
      hasMissingReferencedEvidence: false,
      enrichmentContext: enrichmentContext,
    );

    return NarrativeEventConfidence(
      level: validation.status,
      typeCounts: validation.typeCounts,
    );
  }
}

/// Derived narrative confidence — never persisted.
class NarrativeEventConfidence {
  const NarrativeEventConfidence({
    required this.level,
    required this.typeCounts,
  });

  final RelationshipGroupConfidence level;
  final List<NarrativeEvidenceTypeCount> typeCounts;

  String get badgeLabel => '${level.emoji} ${level.label}';

  List<String> get supportedByLines {
    if (typeCounts.isEmpty) {
      return const ['No evidence attached'];
    }
    return typeCounts
        .map((entry) => '${entry.emoji} ${entry.count} ${entry.label}')
        .toList();
  }
}
