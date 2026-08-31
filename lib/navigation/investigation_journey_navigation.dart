import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/reconstruction_canvas_controller.dart';
import '../controllers/workspace_evidence_controller.dart';
import '../controllers/workspace_session.dart';
import '../models/investigation_methodology_stage.dart';
import '../models/investigation_workspace_tab.dart';
import '../models/workspace_evidence_item.dart';
import '../models/workspace_resume_target.dart';
import '../screens/incident_workspace_shell.dart';
import 'app_navigation.dart';

/// Routes Investigation Journey stage taps through existing workspace navigation.
abstract final class InvestigationJourneyNavigation {
  static void navigateToStage(
    BuildContext context, {
    required InvestigationMethodologyStage stage,
    required InvestigationMethodologyStage activeStage,
    required WorkspaceEvidenceController controller,
    required Future<void> Function(WorkspaceEvidenceItem) onOpenFullEvidenceRecord,
    InvestigationCanvasController? canvasController,
  }) {
    if (stage == activeStage) {
      return;
    }

    final session = WorkspaceSession.instance;

    if (_switchStageInShell(
      context,
      stage: stage,
      canvasController: canvasController,
    )) {
      return;
    }

    session.setActiveStage(
      stage,
      investigationTab: defaultTabFor(stage) ?? session.activeInvestigationTab,
    );
    session.resumeTarget = resumeTargetFor(stage);

    switch (stage) {
      case InvestigationMethodologyStage.capture:
        session.enterCapture();
        // Primary Incident Workspace — not legacy shell Capture body.
        AppNavigation.openContinuousCapture(context);
      case InvestigationMethodologyStage.evidence:
        AppNavigation.openIncidentWorkspace(
          context,
          initialStage: InvestigationMethodologyStage.evidence,
        );
      case InvestigationMethodologyStage.investigation:
        AppNavigation.openIncidentWorkspace(
          context,
          initialStage: InvestigationMethodologyStage.investigation,
          initialInvestigationTab: session.activeInvestigationTab,
        );
      case InvestigationMethodologyStage.trustPackage:
        AppNavigation.openTrustPackage(
          context,
          controller: controller,
          trustPackage: controller.canonicalTrustPackage,
          resolveEvidence: (evidenceId) {
            for (final item in controller.state.items) {
              if (item.id == evidenceId) {
                return item;
              }
            }
            return null;
          },
          timelineNodes: controller.anchoredTimeline,
          relationshipGroups: controller.state.relationshipGroups,
          onOpenFullEvidenceRecord: onOpenFullEvidenceRecord,
        );
    }
  }

  static void switchStageInShell({
    required InvestigationMethodologyStage stage,
    InvestigationCanvasController? canvasController,
  }) {
    final session = WorkspaceSession.instance;
    session.setActiveStage(
      stage,
      investigationTab: stage == InvestigationMethodologyStage.investigation
          ? session.activeInvestigationTab
          : defaultTabFor(stage),
    );
    session.resumeTarget = resumeTargetFor(stage);

    if (stage == InvestigationMethodologyStage.investigation) {
      final canvas = canvasController ??
          session.obtainInvestigationCanvasController(
            initialTab: session.activeInvestigationTab,
          );
      final tab = session.activeInvestigationTab;
      if (canvas.state.activeTab != tab) {
        scheduleMicrotask(() => canvas.setActiveTab(tab));
      }
    }
  }

  static bool _switchStageInShell(
    BuildContext context, {
    required InvestigationMethodologyStage stage,
    InvestigationCanvasController? canvasController,
  }) {
    if (IncidentWorkspaceShell.of(context) == null) {
      return false;
    }

    switchStageInShell(
      stage: stage,
      canvasController: canvasController,
    );

    return true;
  }

  static InvestigationMethodologyStage stageForInvestigationTab(
    InvestigationWorkspaceTab tab,
  ) {
    return InvestigationMethodologyStage.investigation;
  }

  static InvestigationWorkspaceTab? defaultTabFor(
    InvestigationMethodologyStage stage,
  ) {
    return switch (stage) {
      InvestigationMethodologyStage.investigation =>
        InvestigationWorkspaceTab.timeline,
      _ => null,
    };
  }

  static WorkspaceResumeTarget resumeTargetFor(
    InvestigationMethodologyStage stage,
  ) {
    return switch (stage) {
      InvestigationMethodologyStage.trustPackage =>
        WorkspaceResumeTarget.trustPackageScreen,
      _ => WorkspaceResumeTarget.incidentWorkspace,
    };
  }
}
