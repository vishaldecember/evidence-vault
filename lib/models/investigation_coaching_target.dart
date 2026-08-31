import 'investigation_methodology_stage.dart';
import 'investigation_workspace_tab.dart';

/// Workspace destination for a coaching Review action.
enum InvestigationCoachingTarget {
  evidenceStage,
  timelineTab,
  connectionsTab,
  reconstructionTab,
  trustPackageStage,
}

extension InvestigationCoachingTargetNavigation on InvestigationCoachingTarget {
  InvestigationMethodologyStage? get methodologyStage => switch (this) {
        InvestigationCoachingTarget.evidenceStage =>
          InvestigationMethodologyStage.evidence,
        InvestigationCoachingTarget.trustPackageStage =>
          InvestigationMethodologyStage.trustPackage,
        _ => InvestigationMethodologyStage.investigation,
      };

  InvestigationWorkspaceTab? get investigationTab => switch (this) {
        InvestigationCoachingTarget.timelineTab =>
          InvestigationWorkspaceTab.timeline,
        InvestigationCoachingTarget.connectionsTab =>
          InvestigationWorkspaceTab.connections,
        InvestigationCoachingTarget.reconstructionTab =>
          InvestigationWorkspaceTab.reconstruction,
        _ => null,
      };
}
