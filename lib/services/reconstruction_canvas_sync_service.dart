import '../models/connection_group_node.dart';
import '../models/investigation_canvas_state.dart';
import '../models/reflection_model.dart';
import '../models/relationship_group.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';
import 'investigation_canvas_sync_engine.dart';

/// Backward-compatible facade over [InvestigationCanvasSyncEngine].
abstract final class ReconstructionCanvasSyncService {
  static InvestigationCanvasState selectTimelineAnchor({
    required InvestigationCanvasState current,
    required String anchorId,
    required List<RelationshipGroup> groups,
    List<ReflectionModel> notes = const [],
    List<WorkspaceEvidenceItem> items = const [],
    List<TimelineAnchorNode> timelineNodes = const [],
  }) {
    return InvestigationCanvasSyncEngine.selectTimelineAnchor(
      current: current,
      anchorId: anchorId,
      groups: groups,
      notes: notes,
      items: items,
      timelineNodes: timelineNodes,
    );
  }

  static InvestigationCanvasState selectRelationshipGroup({
    required InvestigationCanvasState current,
    required String groupId,
    required List<ConnectionGroupNode> groupNodes,
    List<ReflectionModel> notes = const [],
    List<RelationshipGroup> groups = const [],
    List<WorkspaceEvidenceItem> items = const [],
    List<TimelineAnchorNode> timelineNodes = const [],
  }) {
    return InvestigationCanvasSyncEngine.selectRelationshipGroup(
      current: current,
      groupId: groupId,
      groupNodes: groupNodes,
      groups: groups,
      notes: notes,
      items: items,
      timelineNodes: timelineNodes,
    );
  }

  static InvestigationCanvasState selectNarrativeSection({
    required InvestigationCanvasState current,
    required String sectionId,
    List<ReflectionModel> notes = const [],
    List<WorkspaceEvidenceItem> items = const [],
    List<RelationshipGroup> groups = const [],
    List<TimelineAnchorNode> timelineNodes = const [],
  }) {
    return InvestigationCanvasSyncEngine.selectNarrativeSection(
      current: current,
      sectionId: sectionId,
      notes: notes,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
    );
  }

  static Set<String> highlightedTimelineAnchorIds({
    required InvestigationCanvasState state,
    required List<ConnectionGroupNode> groupNodes,
    List<ReflectionModel> notes = const [],
    List<WorkspaceEvidenceItem> items = const [],
    List<RelationshipGroup> groups = const [],
    List<TimelineAnchorNode> timelineNodes = const [],
  }) {
    return InvestigationCanvasSyncEngine.highlightedTimelineAnchorIds(
      state: state,
      groupNodes: groupNodes,
      notes: notes,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
    );
  }

  static Set<String> highlightedRelationshipGroupIds({
    required InvestigationCanvasState state,
    required List<RelationshipGroup> groups,
    List<ConnectionGroupNode> groupNodes = const [],
    List<ReflectionModel> notes = const [],
    List<WorkspaceEvidenceItem> items = const [],
    List<TimelineAnchorNode> timelineNodes = const [],
  }) {
    return InvestigationCanvasSyncEngine.highlightedRelationshipGroupIds(
      state: state,
      groups: groups,
      groupNodes: groupNodes,
      notes: notes,
      items: items,
      timelineNodes: timelineNodes,
    );
  }

  static Set<String> highlightedEvidenceIds({
    required InvestigationCanvasState state,
    required List<ConnectionGroupNode> groupNodes,
  }) {
    return InvestigationCanvasSyncEngine.highlightedEvidenceIds(
      state: state,
      groupNodes: groupNodes,
    );
  }

  static Set<String> highlightedNarrativeSectionIds({
    required InvestigationCanvasState state,
    List<ReflectionModel> notes = const [],
    List<WorkspaceEvidenceItem> items = const [],
    List<RelationshipGroup> groups = const [],
    List<TimelineAnchorNode> timelineNodes = const [],
  }) {
    return InvestigationCanvasSyncEngine.highlightedNarrativeSectionIds(
      state: state,
      notes: notes,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
    );
  }
}
