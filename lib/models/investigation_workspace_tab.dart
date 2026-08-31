/// Active workspace tab within the Investigation Workspace.
enum InvestigationWorkspaceTab {
  timeline,
  graph,
  connections,
  reconstruction;

  String get label => switch (this) {
        InvestigationWorkspaceTab.timeline => 'Timeline',
        InvestigationWorkspaceTab.graph => 'Graph',
        InvestigationWorkspaceTab.connections => 'Connections',
        InvestigationWorkspaceTab.reconstruction => 'Reconstruct',
      };

  String get perspectiveQuestion => switch (this) {
        InvestigationWorkspaceTab.timeline => 'When did it happen?',
        InvestigationWorkspaceTab.graph => 'How is evidence connected?',
        InvestigationWorkspaceTab.connections => 'What belongs together?',
        InvestigationWorkspaceTab.reconstruction => 'What happened?',
      };
}

/// Legacy alias retained for incremental migration.
@Deprecated('Use InvestigationWorkspaceTab')
typedef ReconstructionCanvasSegment = InvestigationWorkspaceTab;
