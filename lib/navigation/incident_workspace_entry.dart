import 'dart:async';
import 'dart:io' show Platform;

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

  /// Uses the local working set already established by [WorkspaceSession.openIncident].
  ///
  /// When evidence is already in memory, routes immediately. When the session
  /// is still an empty shell, waits for the existing local hydrate — never a
  /// new Firestore query. Times out to [fallbackStage] rather than guessing
  /// ready or blocking Incident access.
  static Future<InvestigationMethodologyStage> resolveAfterHydrate(
    WorkspaceSession session,
  ) async {
    final controller = session.controller;
    if (controller.currentIncident.evidence.isNotEmpty) {
      return stageFromWorkingSet(controller);
    }
    if (_isFlutterTest) {
      return stageFromWorkingSet(controller);
    }
    try {
      await session.ensureLocalHydrateSettled().timeout(
        const Duration(seconds: 3),
      );
    } on TimeoutException {
      debugPrint(
        '[Entry] local hydrate wait timed out; using current working set',
      );
    } catch (error) {
      debugPrint('[Entry] local hydrate wait failed: $error');
    }
    final resolved = stageFromWorkingSet(session.controller);
    final incident = session.controller.currentIncident;
    debugPrint(
      '[Entry] hydrate settled incident=${incident.id} '
      'count=${incident.evidenceCount} '
      'ids=${[for (final item in incident.evidence) item.id]} '
      'stage=$resolved',
    );
    return resolved;
  }

  static bool get _isFlutterTest {
    return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  }
}
