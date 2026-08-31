import 'package:flutter/foundation.dart';

import '../models/connection_group_node.dart';
import '../models/investigation_canvas_state.dart';
import '../models/investigation_workspace_tab.dart';
import '../models/reflection_model.dart';
import '../models/relationship_group.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';
import '../engines/enrichment_engine.dart';
import '../engines/narrative_builder.dart';
import '../services/investigation_canvas_sync_engine.dart';
import '../services/relationship_group_color_service.dart';

/// Reactive shared state for the Reconstruction Canvas investigation surface.
class InvestigationCanvasController extends ChangeNotifier {
  InvestigationCanvasController({
    InvestigationCanvasState? initialState,
  }) : _state = initialState ?? const InvestigationCanvasState();

  InvestigationCanvasState _state;

  InvestigationCanvasState get state => _state;

  void setActiveTab(InvestigationWorkspaceTab tab) {
    if (_state.activeTab == tab) {
      return;
    }
    _state = _state.copyWith(activeTab: tab);
    notifyListeners();
  }

  @Deprecated('Use setActiveTab')
  void setActiveSegment(InvestigationWorkspaceTab segment) =>
      setActiveTab(segment);

  void selectTimelineAnchor({
    required String anchorId,
    required List<RelationshipGroup> groups,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    _state = InvestigationCanvasSyncEngine.selectTimelineAnchor(
      current: _state,
      anchorId: anchorId,
      groups: groups,
      notes: notes,
      items: items,
      timelineNodes: timelineNodes,
      narrativeEvents: narrativeEvents,
    );
    notifyListeners();
  }

  void selectEvidence({
    required WorkspaceEvidenceItem evidence,
    required List<RelationshipGroup> groups,
    required List<ConnectionGroupNode> groupNodes,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    if (EnrichmentEngine.isPrimaryEvidence(evidence)) {
      selectTimelineAnchor(
        anchorId: evidence.id,
        groups: groups,
        notes: notes,
        items: items,
        timelineNodes: timelineNodes,
        narrativeEvents: narrativeEvents,
      );
      return;
    }

    final group = RelationshipGroupColorService.groupForEvidence(
      evidence.id,
      groups,
    );
    if (group != null) {
      _state = InvestigationCanvasSyncEngine.selectRelationshipGroup(
        current: _state,
        groupId: group.id,
        groupNodes: groupNodes,
        groups: groups,
        notes: notes,
        items: items,
        timelineNodes: timelineNodes,
        narrativeEvents: narrativeEvents,
      ).copyWith(selectedEvidenceId: evidence.id);
    } else {
      _state = _state.copyWith(selectedEvidenceId: evidence.id);
    }
    notifyListeners();
  }

  void selectRelationshipGroup({
    required String groupId,
    required List<ConnectionGroupNode> groupNodes,
    required List<RelationshipGroup> groups,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    _state = InvestigationCanvasSyncEngine.selectRelationshipGroup(
      current: _state,
      groupId: groupId,
      groupNodes: groupNodes,
      groups: groups,
      notes: notes,
      items: items,
      timelineNodes: timelineNodes,
      narrativeEvents: narrativeEvents,
    );
    notifyListeners();
  }

  void selectNarrativeSection({
    required String sectionId,
    required List<ReflectionModel> notes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<TimelineAnchorNode> timelineNodes,
    List<NarrativeEventViewModel> narrativeEvents = const [],
  }) {
    _state = InvestigationCanvasSyncEngine.selectNarrativeSection(
      current: _state,
      sectionId: sectionId,
      notes: notes,
      items: items,
      groups: groups,
      timelineNodes: timelineNodes,
      narrativeEvents: narrativeEvents,
    );
    notifyListeners();
  }

  void clearEvidenceSelection() {
    _state = _state.copyWith(clearEvidence: true);
    notifyListeners();
  }

  /// Clears selections and returns to Timeline without disposing this notifier.
  void clearSelectionsAndReturnToTimeline() {
    _state = const InvestigationCanvasState();
    notifyListeners();
  }
}

@Deprecated('Use InvestigationCanvasController')
typedef ReconstructionCanvasController = InvestigationCanvasController;
