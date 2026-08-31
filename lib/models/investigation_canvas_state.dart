import 'reconstruction_canvas_segment.dart';

/// Single source of truth for investigation selection in the Investigation Workspace.
class InvestigationCanvasState {
  const InvestigationCanvasState({
    this.activeTab = InvestigationWorkspaceTab.timeline,
    this.selectedTimelineAnchorId,
    this.selectedRelationshipGroupId,
    this.selectedNarrativeSectionId,
    this.selectedEvidenceId,
  });

  final InvestigationWorkspaceTab activeTab;
  final String? selectedTimelineAnchorId;
  final String? selectedRelationshipGroupId;
  final String? selectedNarrativeSectionId;

  /// Inspector target — derived from evidence taps, not a fourth sync axis.
  final String? selectedEvidenceId;

  @Deprecated('Use activeTab')
  InvestigationWorkspaceTab get activeSegment => activeTab;

  InvestigationCanvasState copyWith({
    InvestigationWorkspaceTab? activeTab,
    String? selectedTimelineAnchorId,
    String? selectedRelationshipGroupId,
    String? selectedNarrativeSectionId,
    String? selectedEvidenceId,
    bool clearTimelineAnchor = false,
    bool clearRelationshipGroup = false,
    bool clearNarrativeSection = false,
    bool clearEvidence = false,
  }) {
    return InvestigationCanvasState(
      activeTab: activeTab ?? this.activeTab,
      selectedTimelineAnchorId: clearTimelineAnchor
          ? null
          : (selectedTimelineAnchorId ?? this.selectedTimelineAnchorId),
      selectedRelationshipGroupId: clearRelationshipGroup
          ? null
          : (selectedRelationshipGroupId ?? this.selectedRelationshipGroupId),
      selectedNarrativeSectionId: clearNarrativeSection
          ? null
          : (selectedNarrativeSectionId ?? this.selectedNarrativeSectionId),
      selectedEvidenceId:
          clearEvidence ? null : (selectedEvidenceId ?? this.selectedEvidenceId),
    );
  }
}
