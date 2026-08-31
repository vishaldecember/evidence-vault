import '../engines/narrative_builder.dart';
import '../models/connection_group_node.dart';
import '../models/investigation_canvas_state.dart';
import '../models/reflection_model.dart';
import '../models/relationship_group.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';
import 'investigation_narrative_reference_resolver.dart';
import 'relationship_group_color_service.dart';

/// Shared investigation synchronization engine for the Reconstruction Canvas.
abstract final class InvestigationCanvasSyncEngine {
  static InvestigationCanvasState selectTimelineAnchor({
    required InvestigationCanvasState current,
    required String anchorId,
    required List<RelationshipGroup> groups,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    final matchingGroups =
        RelationshipGroupColorService.groupsForEvidence(anchorId, groups);
    final narrativeMatches = _narrativeMatchesForEvidence(
      evidenceId: anchorId,
      narrativeEvents: narrativeEvents,
      notes: notes,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
    );

    return current.copyWith(
      selectedTimelineAnchorId: anchorId,
      selectedRelationshipGroupId: matchingGroups.length == 1
          ? matchingGroups.first.id
          : null,
      clearRelationshipGroup: matchingGroups.length != 1,
      selectedNarrativeSectionId:
          narrativeMatches.length == 1 ? narrativeMatches.first : null,
      clearNarrativeSection: narrativeMatches.isEmpty,
      selectedEvidenceId: anchorId,
    );
  }

  static InvestigationCanvasState selectRelationshipGroup({
    required InvestigationCanvasState current,
    required String groupId,
    required List<ConnectionGroupNode> groupNodes,
    required List<RelationshipGroup> groups,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    final narrativeMatches = _narrativeMatchesForGroup(
      groupId: groupId,
      narrativeEvents: narrativeEvents,
      notes: notes,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
    );

    return current.copyWith(
      selectedRelationshipGroupId: groupId,
      clearTimelineAnchor: true,
      selectedNarrativeSectionId:
          narrativeMatches.length == 1 ? narrativeMatches.first : null,
      clearNarrativeSection: narrativeMatches.isEmpty,
      clearEvidence: true,
    );
  }

  static InvestigationCanvasState selectNarrativeSection({
    required InvestigationCanvasState current,
    required String sectionId,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    final event = _eventById(sectionId, narrativeEvents);
    if (event != null) {
      final references =
          InvestigationNarrativeReferenceResolver.resolveEvent(event);
      return current.copyWith(
        selectedNarrativeSectionId: sectionId,
        selectedTimelineAnchorId: references.anchorIds.length == 1
            ? references.anchorIds.first
            : null,
        clearTimelineAnchor: references.anchorIds.length != 1,
        selectedRelationshipGroupId: references.groupIds.length == 1
            ? references.groupIds.first
            : null,
        clearRelationshipGroup: references.groupIds.length != 1,
        clearEvidence: true,
      );
    }

    final note = _noteById(sectionId, notes);
    if (note == null) {
      return current;
    }

    final references = InvestigationNarrativeReferenceResolver.resolve(
      note: note,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
    );

    return current.copyWith(
      selectedNarrativeSectionId: sectionId,
      selectedTimelineAnchorId: references.anchorIds.length == 1
          ? references.anchorIds.first
          : null,
      clearTimelineAnchor: references.anchorIds.length != 1,
      selectedRelationshipGroupId: references.groupIds.length == 1
          ? references.groupIds.first
          : null,
      clearRelationshipGroup: references.groupIds.length != 1,
      clearEvidence: true,
    );
  }

  static Set<String> highlightedTimelineAnchorIds({
    required InvestigationCanvasState state,
    required List<ConnectionGroupNode> groupNodes,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    if (state.selectedNarrativeSectionId != null) {
      final event = _eventById(state.selectedNarrativeSectionId!, narrativeEvents);
      if (event != null) {
        return InvestigationNarrativeReferenceResolver.resolveEvent(event)
            .anchorIds;
      }

      final note = _noteById(state.selectedNarrativeSectionId!, notes);
      if (note != null) {
        return InvestigationNarrativeReferenceResolver.resolve(
          note: note,
          items: items,
          groups: groups,
          timelineNodes: timelineNodes,
        ).anchorIds;
      }
    }

    if (state.selectedRelationshipGroupId != null) {
      final node = _nodeForGroup(state.selectedRelationshipGroupId!, groupNodes);
      if (node == null) {
        return const {};
      }
      return {
        for (final entry in node.capturedEntries) entry.captured.id,
      };
    }

    if (state.selectedTimelineAnchorId != null) {
      return {state.selectedTimelineAnchorId!};
    }

    return const {};
  }

  static Set<String> highlightedRelationshipGroupIds({
    required InvestigationCanvasState state,
    required List<RelationshipGroup> groups,
    required List<ConnectionGroupNode> groupNodes,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    if (state.selectedNarrativeSectionId != null) {
      final event = _eventById(state.selectedNarrativeSectionId!, narrativeEvents);
      if (event != null) {
        return InvestigationNarrativeReferenceResolver.resolveEvent(event)
            .groupIds;
      }

      final note = _noteById(state.selectedNarrativeSectionId!, notes);
      if (note != null) {
        return InvestigationNarrativeReferenceResolver.resolve(
          note: note,
          items: items,
          groups: groups,
          timelineNodes: timelineNodes,
        ).groupIds;
      }
    }

    if (state.selectedRelationshipGroupId != null) {
      return {state.selectedRelationshipGroupId!};
    }

    if (state.selectedTimelineAnchorId != null) {
      return {
        for (final group in RelationshipGroupColorService.groupsForEvidence(
          state.selectedTimelineAnchorId!,
          groups,
        ))
          group.id,
      };
    }

    return const {};
  }

  static Set<String> highlightedNarrativeSectionIds({
    required InvestigationCanvasState state,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    if (state.selectedNarrativeSectionId != null) {
      return {state.selectedNarrativeSectionId!};
    }

    if (state.selectedRelationshipGroupId != null) {
      return _narrativeMatchesForGroup(
        groupId: state.selectedRelationshipGroupId!,
        narrativeEvents: narrativeEvents,
        notes: notes,
        items: items,
        groups: groups,
        timelineNodes: timelineNodes,
      );
    }

    if (state.selectedTimelineAnchorId != null) {
      return _narrativeMatchesForEvidence(
        evidenceId: state.selectedTimelineAnchorId!,
        narrativeEvents: narrativeEvents,
        notes: notes,
        items: items,
        groups: groups,
        timelineNodes: timelineNodes,
      );
    }

    return const {};
  }

  static Set<String> highlightedEvidenceIds({
    required InvestigationCanvasState state,
    required List<ConnectionGroupNode> groupNodes,
  }) {
    if (state.selectedEvidenceId != null) {
      return {state.selectedEvidenceId!};
    }

    if (state.selectedRelationshipGroupId != null) {
      final node = _nodeForGroup(state.selectedRelationshipGroupId!, groupNodes);
      if (node == null) {
        return const {};
      }
      return {
        for (final entry in node.capturedEntries) entry.captured.id,
        for (final entry in node.capturedEntries)
          ...entry.supportingItems.map((item) => item.id),
        ...node.standaloneSupporting.map((item) => item.id),
      };
    }

    if (state.selectedTimelineAnchorId != null) {
      return {state.selectedTimelineAnchorId!};
    }

    return const {};
  }

  static Set<String> _narrativeMatchesForEvidence({
    required String evidenceId,
    required List<NarrativeEventViewModel> narrativeEvents,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
  }) {
    if (narrativeEvents.isNotEmpty) {
      return InvestigationNarrativeReferenceResolver.narrativeEventsForEvidence(
        evidenceId: evidenceId,
        events: narrativeEvents,
      );
    }

    return InvestigationNarrativeReferenceResolver.narrativeSectionsForEvidence(
      evidenceId: evidenceId,
      notes: notes,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
    );
  }

  static Set<String> _narrativeMatchesForGroup({
    required String groupId,
    required List<NarrativeEventViewModel> narrativeEvents,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
  }) {
    if (narrativeEvents.isNotEmpty) {
      return InvestigationNarrativeReferenceResolver.narrativeEventsForGroup(
        groupId: groupId,
        events: narrativeEvents,
      );
    }

    return InvestigationNarrativeReferenceResolver.narrativeSectionsForGroup(
      groupId: groupId,
      notes: notes,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
    );
  }

  static ConnectionGroupNode? _nodeForGroup(
    String groupId,
    List<ConnectionGroupNode> groupNodes,
  ) {
    for (final node in groupNodes) {
      if (node.group.id == groupId) {
        return node;
      }
    }
    return null;
  }

  static NarrativeEventViewModel? _eventById(
    String eventId,
    List<NarrativeEventViewModel> events,
  ) {
    for (final event in events) {
      if (event.event.id == eventId) {
        return event;
      }
    }
    return null;
  }

  static ReflectionModel? _noteById(String noteId, List<ReflectionModel> notes) {
    for (final note in notes) {
      if (note.id == noteId) {
        return note;
      }
    }
    return null;
  }
}
