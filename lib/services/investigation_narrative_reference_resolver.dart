import '../engines/narrative_builder.dart';
import '../models/reflection_model.dart';
import '../models/relationship_group.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';
import '../services/relationship_group_color_service.dart';

/// Resolves narrative section references to timeline anchors and relationship groups.
class InvestigationNarrativeReferences {
  const InvestigationNarrativeReferences({
    this.anchorIds = const {},
    this.groupIds = const {},
  });

  final Set<String> anchorIds;
  final Set<String> groupIds;
}

abstract final class InvestigationNarrativeReferenceResolver {
  static InvestigationNarrativeReferences resolve({
    required ReflectionModel note,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
  }) {
    final anchorIds = <String>{};
    final groupIds = <String>{};
    final searchable = _searchableText(note);

    for (final node in timelineNodes) {
      if (_textReferencesEvidence(searchable, node.capturedItem)) {
        anchorIds.add(node.capturedItem.id);
      }
    }

    for (final item in items) {
      if (_textReferencesEvidence(searchable, item)) {
        for (final group
            in RelationshipGroupColorService.groupsForEvidence(item.id, groups)) {
          groupIds.add(group.id);
        }
      }
    }

    for (final group in groups) {
      if (_textReferencesGroup(searchable, group, groups)) {
        groupIds.add(group.id);
        for (final memberId in group.memberEvidenceIds) {
          if (timelineNodes.any((node) => node.capturedItem.id == memberId)) {
            anchorIds.add(memberId);
          }
        }
      }
    }

    return InvestigationNarrativeReferences(
      anchorIds: anchorIds,
      groupIds: groupIds,
    );
  }

  static Set<String> narrativeSectionsForEvidence({
    required String evidenceId,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
  }) {
    final matches = <String>{};
    for (final note in notes) {
      final references = resolve(
        note: note,
        items: items,
        groups: groups,
        timelineNodes: timelineNodes,
      );
      if (references.anchorIds.contains(evidenceId)) {
        matches.add(note.id);
        continue;
      }
      final item = _itemById(evidenceId, items);
      if (item != null && _textReferencesEvidence(_searchableText(note), item)) {
        matches.add(note.id);
      }
    }
    return matches;
  }

  static Set<String> narrativeSectionsForGroup({
    required String groupId,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
  }) {
    RelationshipGroup? group;
    for (final entry in groups) {
      if (entry.id == groupId) {
        group = entry;
        break;
      }
    }
    if (group == null) {
      return const {};
    }

    final matches = <String>{};
    for (final note in notes) {
      final references = resolve(
        note: note,
        items: items,
        groups: groups,
        timelineNodes: timelineNodes,
      );
      if (references.groupIds.contains(groupId) ||
          _textReferencesGroup(_searchableText(note), group, groups)) {
        matches.add(note.id);
      }
    }
    return matches;
  }

  static Set<String> narrativeEventsForEvidence({
    required String evidenceId,
    required List<NarrativeEventViewModel> events,
  }) {
    final matches = <String>{};
    for (final viewModel in events) {
      if (viewModel.event.timelineAnchorEvidenceId == evidenceId ||
          viewModel.supportingEvidence.any((item) => item.id == evidenceId)) {
        matches.add(viewModel.event.id);
      }
    }
    return matches;
  }

  static Set<String> narrativeEventsForGroup({
    required String groupId,
    required List<NarrativeEventViewModel> events,
  }) {
    final matches = <String>{};
    for (final viewModel in events) {
      if (viewModel.relationshipGroups.any((group) => group.id == groupId)) {
        matches.add(viewModel.event.id);
      }
    }
    return matches;
  }

  static InvestigationNarrativeReferences resolveEvent(
    NarrativeEventViewModel viewModel,
  ) {
    final anchorIds = <String>{};
    if (viewModel.anchorNode != null) {
      anchorIds.add(viewModel.event.timelineAnchorEvidenceId);
    }
    return InvestigationNarrativeReferences(
      anchorIds: anchorIds,
      groupIds: viewModel.relationshipGroups.map((group) => group.id).toSet(),
    );
  }

  static String _searchableText(ReflectionModel note) {
    return '${note.title ?? ''} ${note.body}'.toLowerCase();
  }

  static bool _textReferencesEvidence(String searchable, WorkspaceEvidenceItem item) {
    if (searchable.contains(item.id.toLowerCase())) {
      return true;
    }
    return searchable.contains(item.title.toLowerCase());
  }

  static bool _textReferencesGroup(
    String searchable,
    RelationshipGroup group,
    List<RelationshipGroup> allGroups,
  ) {
    if (searchable.contains(group.id.toLowerCase())) {
      return true;
    }
    final displayName =
        RelationshipGroupColorService.displayName(group, allGroups).toLowerCase();
    return searchable.contains(displayName);
  }

  static WorkspaceEvidenceItem? _itemById(
    String evidenceId,
    List<WorkspaceEvidenceItem> items,
  ) {
    for (final item in items) {
      if (item.id == evidenceId) {
        return item;
      }
    }
    return null;
  }
}
