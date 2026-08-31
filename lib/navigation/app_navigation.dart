import 'package:flutter/material.dart';

import '../diagnostics/sprint6c_file_trace.dart';
import '../navigation/auth_navigation.dart';
import '../models/evidence_relationship.dart';
import '../models/investigation_methodology_stage.dart';
import '../models/relationship_group.dart';
import '../models/workspace_capture_mode.dart';
import '../models/workspace_resume_target.dart';
import '../controllers/workspace_evidence_controller.dart';
import '../controllers/workspace_session.dart';
import '../models/timeline_anchor_node.dart';
import '../models/story_model.dart';
import '../domain/trust_package/trust_package.dart';
import '../domain/vault/incident_collection.dart';
import '../models/library_incident_summary.dart';
import '../models/workspace_evidence_item.dart';
import '../services/vault/incident_collection_store.dart';
import '../screens/capture/continuous_capture_screen.dart';
import '../screens/collection_browser_screen.dart';
import '../screens/create_evidence_screen.dart';
import '../screens/evidence_record_screen.dart';
import '../screens/incident_workspace_shell.dart';
import '../screens/evidence_image_inspection_screen.dart';
import '../screens/evidence_video_inspection_screen.dart';
import '../screens/pdf_evidence_viewer_screen.dart';
import '../screens/story_screen.dart';
import '../models/investigation_workspace_tab.dart';
import '../screens/main_shell_screen.dart';
import 'incident_workspace_entry.dart';
import 'investigation_journey_navigation.dart';

abstract final class AppNavigation {
  /// Route name for [IncidentWorkspaceShell] so only one bound identity stays active.
  static const incidentWorkspaceRouteName = 'incident-workspace';

  /// Dedicated in-app PDF viewer — pops back to the caller (Workspace/Inspector).
  static const pdfViewerRouteName = 'pdf-evidence-viewer';

  /// Focused photo examination — pops back to Inspector.
  static const imageInspectionRouteName = 'image-evidence-inspection';

  /// Expanded video playback — pops back to Inspector.
  static const videoInspectionRouteName = 'video-evidence-inspection';

  /// Collection Browser — pops back to Vault.
  static const collectionBrowserRouteName =
      CollectionBrowserScreen.routeName;

  static Route<T> route<T>(Widget page) => AuthNavigation.route(page);

  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(context, route(page));
  }

  static Future<T?> replace<T>(BuildContext context, Widget page) {
    Sprint6cFileTrace.nav(
      'AppNavigation.replace → ${page.runtimeType}',
    );
    return Navigator.pushReplacement<T, void>(context, route(page));
  }

  static void openHome(BuildContext context) {
    Sprint6cFileTrace.nav(
      'AppNavigation.openHome → pushReplacement(MainShell) '
      '← EXPLICIT HOME NAVIGATION',
    );
    replace(context, const MainShellScreen());
  }

  /// Opens the primary Incident Workspace (Continuous Capture hub).
  ///
  /// Capture Now Photo / Video / Voice open Cockpit from Home before this.
  /// Sticky-bar modalities enter Cockpit from the Workspace itself.
  static Future<void> openContinuousCapture(
    BuildContext context, {
    WorkspaceCaptureMode? initialMode,
    bool beginNewIncident = false,
  }) {
    return ContinuousCaptureScreen.open(
      context,
      initialMode: initialMode,
      beginNewIncident: beginNewIncident,
    );
  }

  /// Legacy capture flow — retained for Sprint 4 wiring, not linked from Home.
  static Future<void> openCreateEvidence(BuildContext context) {
    return push(context, const CreateEvidenceScreen());
  }

  /// Opens the Collection Browser for one persisted IncidentCollection.
  static Future<void> openCollectionBrowser(
    BuildContext context, {
    required String collectionId,
    required String userId,
    IncidentCollection? initialCollection,
    IncidentCollectionStore? store,
    ValueChanged<LibraryIncidentSummary>? onIncidentOpen,
  }) {
    return Navigator.of(context).push<void>(
      AuthNavigation.route(
        CollectionBrowserScreen(
          collectionId: collectionId,
          userId: userId,
          initialCollection: initialCollection,
          store: store,
          onIncidentOpen: onIncidentOpen,
        ),
        name: collectionBrowserRouteName,
      ),
    );
  }

  /// Library / Vault / Collection card tap after [WorkspaceSession.openIncident].
  ///
  /// Evaluates Phase 3D Organize Readiness on the hydrated working set, then
  /// opens the existing Incident Workspace at Capture or Organize. Not a
  /// second opening path — still [openIncidentWorkspace].
  static Future<void> openIncidentWorkspaceFromLibrary(
    BuildContext context,
  ) async {
    final stage = await IncidentWorkspaceEntry.resolveAfterHydrate(
      WorkspaceSession.instance,
    );
    if (!context.mounted) {
      return;
    }
    return openIncidentWorkspace(context, initialStage: stage);
  }

  /// Opens the unified incident workspace shell.
  static Future<void> openIncidentWorkspace(
    BuildContext context, {
    WorkspaceCaptureMode? initialCaptureMode,
    bool captureInitiated = false,
    InvestigationMethodologyStage? initialStage,
    InvestigationWorkspaceTab? initialInvestigationTab,
  }) {
    final session = WorkspaceSession.instance;
    if (captureInitiated || initialCaptureMode != null) {
      session.enterCapture();
    } else if (initialStage != null) {
      session.setActiveStage(
        initialStage,
        investigationTab: initialInvestigationTab,
      );
      session.resumeTarget =
          InvestigationJourneyNavigation.resumeTargetFor(initialStage);
    } else {
      session.resumeTarget = WorkspaceResumeTarget.incidentWorkspace;
    }

    final incidentId = session.controller.currentIncident.id.trim();
    if (incidentId.isEmpty) {
      debugPrint('[Nav] openIncidentWorkspace rejected — empty incidentId');
      return Future<void>.value();
    }

    final navigator = Navigator.of(context);
    navigator.popUntil((route) {
      return route.settings.name != incidentWorkspaceRouteName;
    });
    return navigator.push(
      AuthNavigation.route(
        IncidentWorkspaceShell(
          incidentId: incidentId,
          initialCaptureMode: initialCaptureMode,
          initialStage: initialStage ?? session.activeMethodologyStage,
          initialInvestigationTab: initialInvestigationTab,
        ),
        name: incidentWorkspaceRouteName,
      ),
    );
  }

  /// Opens the Evidence Workspace after capture or from Home quick actions.
  ///
  /// Routes to the primary Incident Workspace ([ContinuousCaptureScreen]).
  /// Photo / Video / Voice Cockpit entry remains caller-owned (Home Capture Now
  /// or Workspace sticky). Legacy shell Capture body is not opened here.
  static Future<void> openEvidenceWorkspace(
    BuildContext context, {
    WorkspaceCaptureMode? initialCaptureMode,
    bool captureInitiated = false,
  }) {
    final session = WorkspaceSession.instance;
    if (captureInitiated || initialCaptureMode != null) {
      session.enterCapture();
    }
    // Ignore initialCaptureMode for auto-launch — empty Workspace staging is
    // forbidden; Cockpit must be opened by Capture Now / sticky callers.
    return openContinuousCapture(context);
  }

  /// Reopens the workspace at the investigator's last methodology stage.
  ///
  /// Capture-stage resume uses the primary Incident Workspace
  /// ([ContinuousCaptureScreen]), not the legacy shell Capture body that used
  /// to open a titled direct-camera session.
  static Future<void> resumeWorkspace(BuildContext context) {
    final session = WorkspaceSession.instance;

    return switch (session.resumeTarget) {
      WorkspaceResumeTarget.incidentWorkspace =>
        session.activeMethodologyStage == InvestigationMethodologyStage.capture
            ? openContinuousCapture(context)
            : openIncidentWorkspace(
                context,
                initialStage: session.activeMethodologyStage,
                initialInvestigationTab: session.activeInvestigationTab,
              ),
      WorkspaceResumeTarget.trustPackageScreen => openIncidentWorkspace(
          context,
          initialStage: InvestigationMethodologyStage.trustPackage,
        ),
    };
  }

  /// Opens the assembled incident story in a dedicated reading view.
  static Future<void> openStory(
    BuildContext context, {
    required StoryModel Function() getStory,
    required List<WorkspaceEvidenceItem> Function() getAllItems,
    required ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected,
  }) {
    return push(
      context,
      StoryScreen(
        getStory: getStory,
        getAllItems: getAllItems,
        onEvidenceSelected: onEvidenceSelected,
      ),
    );
  }

  /// Opens the Investigation Workspace — unified Timeline, Connections,
  /// and Reconstruction perspectives.
  static Future<void> openInvestigationWorkspace(
    BuildContext context, {
    required WorkspaceEvidenceController controller,
    required Future<void> Function(WorkspaceEvidenceItem) onOpenFullEvidenceRecord,
    InvestigationWorkspaceTab initialTab = InvestigationWorkspaceTab.timeline,
  }) {
    WorkspaceSession.instance.obtainInvestigationCanvasController(
      initialTab: initialTab,
    );

    return openIncidentWorkspace(
      context,
      initialStage: InvestigationMethodologyStage.investigation,
      initialInvestigationTab: initialTab,
    );
  }

  /// Opens the Timeline perspective within the Investigation Workspace shell.
  static Future<void> openTimelineWorkspace(
    BuildContext context, {
    WorkspaceEvidenceController? controller,
    InvestigationWorkspaceTab initialTab = InvestigationWorkspaceTab.timeline,
    Future<void> Function(WorkspaceEvidenceItem)? onEvidenceSelected,
  }) {
    final resolvedController =
        controller ?? WorkspaceSession.instance.controller;

    return openInvestigationWorkspace(
      context,
      controller: resolvedController,
      onOpenFullEvidenceRecord: onEvidenceSelected ?? (_) async {},
      initialTab: initialTab,
    );
  }

  /// Opens the dedicated Connections Workspace for relationship editing.
  static Future<void> openConnectionsWorkspace(
    BuildContext context, {
    required WorkspaceEvidenceController controller,
    required Future<void> Function(WorkspaceEvidenceItem) onEvidenceSelected,
  }) {
    return openInvestigationWorkspace(
      context,
      controller: controller,
      onOpenFullEvidenceRecord: onEvidenceSelected,
      initialTab: InvestigationWorkspaceTab.connections,
    );
  }

  /// Opens the Reconstruction perspective within the Investigation Workspace.
  static Future<void> openReconstructionCanvas(
    BuildContext context, {
    required WorkspaceEvidenceController controller,
    required Future<void> Function(WorkspaceEvidenceItem) onOpenFullEvidenceRecord,
  }) {
    return openInvestigationWorkspace(
      context,
      controller: controller,
      onOpenFullEvidenceRecord: onOpenFullEvidenceRecord,
      initialTab: InvestigationWorkspaceTab.reconstruction,
    );
  }

  /// Opens the Trust Package preview for review before future sharing.
  static Future<void> openTrustPackage(
    BuildContext context, {
    required WorkspaceEvidenceController controller,
    required TrustPackage trustPackage,
    required WorkspaceEvidenceItem? Function(String evidenceId) resolveEvidence,
    required List<TimelineAnchorNode> timelineNodes,
    required List<RelationshipGroup> relationshipGroups,
    required Future<void> Function(WorkspaceEvidenceItem) onOpenFullEvidenceRecord,
  }) {
    return openIncidentWorkspace(
      context,
      initialStage: InvestigationMethodologyStage.trustPackage,
    );
  }

  /// Opens the permanent Evidence Record for one preserved artifact.
  static Future<void> openEvidenceRecord(
    BuildContext context, {
    required String evidenceId,
    required List<WorkspaceEvidenceItem> Function() getItems,
    required List<EvidenceRelationship> Function() getRelationships,
    List<RelationshipGroup> Function()? getRelationshipGroups,
    required void Function(String evidenceId, WorkspaceCaptureMode mode)
        onAddContext,
    void Function(String evidenceId, String text)? onAddContextText,
  }) {
    WorkspaceSession.instance.enterEvidenceEditing();

    return push(
      context,
      EvidenceRecordScreen(
        evidenceId: evidenceId,
        getItems: getItems,
        getRelationships: getRelationships,
        getRelationshipGroups: getRelationshipGroups ?? () => const [],
        onAddContext: onAddContext,
        onAddContextText: onAddContextText,
      ),
    );
  }

  /// Opens focused photo inspection. Back returns to the caller Inspector.
  static Future<void> openImageInspection(
    BuildContext context, {
    required WorkspaceEvidenceItem evidence,
  }) {
    final currentName = ModalRoute.of(context)?.settings.name;
    if (currentName == imageInspectionRouteName) {
      return Future<void>.value();
    }
    return Navigator.of(context).push<void>(
      AuthNavigation.route(
        EvidenceImageInspectionScreen(evidence: evidence),
        name: imageInspectionRouteName,
      ),
    );
  }

  /// Opens expanded video playback. Back returns to the caller Inspector.
  static Future<void> openVideoInspection(
    BuildContext context, {
    required WorkspaceEvidenceItem evidence,
  }) {
    final currentName = ModalRoute.of(context)?.settings.name;
    if (currentName == videoInspectionRouteName) {
      return Future<void>.value();
    }
    return Navigator.of(context).push<void>(
      AuthNavigation.route(
        EvidenceVideoInspectionScreen(evidence: evidence),
        name: videoInspectionRouteName,
      ),
    );
  }

  /// Opens the in-app PDF viewer on the current navigator.
  ///
  /// Android Back / Close pops this route only — caller Workspace stays put.
  static Future<void> openPdfViewer(
    BuildContext context, {
    required WorkspaceEvidenceItem evidence,
  }) {
    final currentName = ModalRoute.of(context)?.settings.name;
    if (currentName == pdfViewerRouteName) {
      return Future<void>.value();
    }
    return Navigator.of(context).push<void>(
      AuthNavigation.route(
        PdfEvidenceViewerScreen(evidence: evidence),
        name: pdfViewerRouteName,
      ),
    );
  }
}
