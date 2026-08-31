import '../models/investigation_methodology_stage.dart';
import '../models/investigation_workspace_tab.dart';

/// Deterministic Library / Home destinations for one bound incident.
///
/// Destinations are action-specific. They must not inherit leftover
/// [WorkspaceSession] stage or tab from a previous incident.
abstract final class LibraryIncidentRoutes {
  /// Fallback Library card destination when Organize Readiness cannot be
  /// evaluated. Active card taps use [IncidentWorkspaceEntry] instead of
  /// always opening Capture.
  static const cardBodyStage = InvestigationMethodologyStage.capture;

  /// Continue Preserving opens Capture for the same incident.
  static const continuePreservingStage = InvestigationMethodologyStage.capture;

  /// Continue Organizing opens Organize for the same incident.
  static const continueOrganizingStage = InvestigationMethodologyStage.evidence;

  /// Continue Investigation opens Investigate for the same incident.
  static const continueInvestigationStage =
      InvestigationMethodologyStage.investigation;

  static const continueInvestigationTab = InvestigationWorkspaceTab.timeline;

  /// Continue Trust opens Trust Package for the same incident.
  static const continueTrustStage = InvestigationMethodologyStage.trustPackage;

  /// Organize destination formerly used by the Library "View Evidence Map" link.
  ///
  /// Library cards no longer expose that action. Active card taps route
  /// through [IncidentWorkspaceEntry] using Phase 3D Organize Readiness.
  static const viewEvidenceMapStage = InvestigationMethodologyStage.evidence;
}
