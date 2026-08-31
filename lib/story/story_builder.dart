import '../engines/evidence_semantics.dart';
import '../models/evidence_relationship.dart';
import '../models/linked_evidence_item.dart';
import '../models/reflection_model.dart';
import '../models/story_model.dart';
import '../models/timeline_item_model.dart';
import '../models/workspace_evidence_item.dart';

/// Input snapshot for story assembly — reads existing domain data only.
class StoryBuildContext {
  const StoryBuildContext({
    required this.items,
    required this.relationships,
    required this.reflections,
  });

  final List<WorkspaceEvidenceItem> items;
  final List<EvidenceRelationship> relationships;
  final List<ReflectionModel> reflections;
}

/// Assembles a [StoryModel] from preserved information.
///
/// Deterministic. No AI. No speculation. No inferred events.
/// Future AI may suggest improvements but never replaces this builder.
abstract class StoryBuilder {
  StoryModel build(StoryBuildContext context);
}

/// Default deterministic story assembly from workspace state.
class DefaultStoryBuilder implements StoryBuilder {
  const DefaultStoryBuilder();

  @override
  StoryModel build(StoryBuildContext context) {
    final itemById = {for (final item in context.items) item.id: item};
    final artifacts =
        context.items.where((item) => !item.isContextual).toList();

    return StoryModel(
      summary: _buildSummary(context.items, artifacts),
      timeline: TimelineItemModel.fromWorkspace(
        items: context.items,
        newestFirst: false,
      ),
      evidenceHighlights: _sortedArtifacts(artifacts),
      supportingContext: _buildContextGroups(artifacts, itemById),
      linkedEvidence: _buildLinkedEntries(context.relationships, itemById),
      reflections: _sortedReflections(context.reflections),
    );
  }

  String? _buildSummary(
    List<WorkspaceEvidenceItem> allItems,
    List<WorkspaceEvidenceItem> artifacts,
  ) {
    if (artifacts.isEmpty) {
      return null;
    }

    final count = artifacts.length;
    final artifactWord = count == 1 ? 'artifact' : 'artifacts';

    if (allItems.length <= 1) {
      return 'This incident contains $count preserved evidence $artifactWord.';
    }

    final dates = allItems.map((item) => item.lastPreservedAt).toList()
      ..sort();
    final spanDays = dates.last.difference(dates.first).inDays;

    final spanPhrase = switch (spanDays) {
      0 => 'on the same day',
      1 => 'over two days',
      _ => 'over ${spanDays + 1} days',
    };

    return 'This incident contains $count preserved evidence '
        '$artifactWord collected $spanPhrase.';
  }

  List<WorkspaceEvidenceItem> _sortedArtifacts(
    List<WorkspaceEvidenceItem> artifacts,
  ) {
    final sorted = List<WorkspaceEvidenceItem>.from(artifacts)
      ..sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));
    return sorted;
  }

  List<StoryContextGroup> _buildContextGroups(
    List<WorkspaceEvidenceItem> artifacts,
    Map<String, WorkspaceEvidenceItem> itemById,
  ) {
    final groups = <StoryContextGroup>[];

    for (final artifact in artifacts) {
      final contextItems = artifact.relatedEvidenceIds
          .map((id) => itemById[id])
          .whereType<WorkspaceEvidenceItem>()
          .where((item) => item.isContextual)
          .toList()
        ..sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));

      if (contextItems.isNotEmpty) {
        groups.add(
          StoryContextGroup(
            parentEvidence: artifact,
            contextItems: contextItems,
          ),
        );
      }
    }

    return groups;
  }

  List<StoryLinkedEntry> _buildLinkedEntries(
    List<EvidenceRelationship> relationships,
    Map<String, WorkspaceEvidenceItem> itemById,
  ) {
    final entries = <StoryLinkedEntry>[];

    for (final relationship in relationships) {
      if (EvidenceSemantics.isSuggestedRelated(relationship)) {
        continue;
      }
      final source = itemById[relationship.sourceEvidenceId];
      final target = itemById[relationship.targetEvidenceId];
      if (source == null || target == null) {
        continue;
      }

      entries.add(
        StoryLinkedEntry(
          link: LinkedEvidenceItem.fromRelationship(
            relationship: relationship,
            targetItem: target,
          ),
          sourceEvidence: source,
        ),
      );
    }

    entries.sort(
      (a, b) => a.link.preservedAt.compareTo(b.link.preservedAt),
    );

    return entries;
  }

  List<ReflectionModel> _sortedReflections(List<ReflectionModel> reflections) {
    final sorted = List<ReflectionModel>.from(reflections)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }
}
