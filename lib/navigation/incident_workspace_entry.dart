import 'package:flutter/foundation.dart';

import '../controllers/workspace_evidence_controller.dart';
import '../controllers/workspace_session.dart';
import '../domain/organize/organize_readiness.dart';
import '../models/investigation_methodology_stage.dart';
import 'library_incident_routes.dart';

/// Navigation-only decision: which Incident Workspace section is most useful
/// to open right now, derived from Phase 3D [OrganizeReadiness].
///
/// Not an Incident field. Not persisted. Does not mutate evidence or chronology.
abstract final class IncidentWorkspaceEntry {
  /// Existing default Library card destination when readiness cannot be
  /// evaluated. Never treat an unevaluable working set as ready.
  static const InvestigationMethodologyStage fallbackStage =
      LibraryIncidentRoutes.cardBodyStage;

  /// Explicit routing rule from the canonical Phase 3D result.
  static InvestigationMethodologyStage stageFor(OrganizeReadiness readiness) {
    return switch (readiness.status) {
      OrganizeReadinessStatus.ready =>
        InvestigationMethodologyStage.evidence,
      OrganizeReadinessStatus.notReady =>
        InvestigationMethodologyStage.capture,
    };
  }

  /// Assesses the hydrated working set. Returns null when readiness cannot
  /// be evaluated — callers must use [fallbackStage], never invent ready.
  static OrganizeReadiness? tryAssess(WorkspaceEvidenceController controller) {
    try {
      if (controller.currentIncident.id.trim().isEmpty) {
        return null;
      }
      return controller.organizeReadiness;
    } catch (_) {
      return null;
    }
  }

  static InvestigationMethodologyStage stageFromWorkingSet(
    WorkspaceEvidenceController controller,
  ) {
    final readiness = tryAssess(controller);
    if (readiness == null) {
      return fallbackStage;
    }
    return stageFor(readiness);
  }

  /// Routes from the working set already bound by [WorkspaceSession.openIncident].
  ///
  /// Does not wait for cache hydrate or cloud enrich. Evidence already in
  /// memory is assessed; an empty shell uses [fallbackStage] rather than
  /// guessing Organize-ready. Hydrate continues in the background and
  /// existing listeners fill the destination.
  static Future<InvestigationMethodologyStage> resolveAfterHydrate(
    WorkspaceSession session,
  ) async {
    final controller = session.controller;
    final resolved = stageFromWorkingSet(controller);
    final incident = controller.currentIncident;
    debugPrint(
      '[Entry] route incident=${incident.id} '
      'count=${incident.evidenceCount} '
      'stage=$resolved',
    );
    return resolved;
  }
}
