import 'package:flutter/material.dart';

import '../controllers/workspace_evidence_controller.dart';
import '../controllers/workspace_session.dart';
import '../diagnostics/file_p0_trace.dart';
import '../models/workspace_capture_mode.dart';
import '../navigation/app_navigation.dart';
import '../navigation/app_navigator.dart';
import '../navigation/library_incident_routes.dart';
import '../services/capture/capture_session_manager.dart';
import '../services/storage/capture_media_service.dart';
import '../services/storage/file_attach_flow.dart';
import '../services/user_session_service.dart';
import '../widgets/capture/text_note_capture_sheet.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/home/home_body.dart';
import '../widgets/home/quick_capture_button.dart';
import 'capture/capture_cockpit_screen.dart';
import 'capture/continuous_capture_screen.dart';

/// Result of a Home Capture Now Note/File attempt.
enum CaptureNowOutcome {
  /// User dismissed sheet / cancelled picker; no evidence created.
  cancelled,

  /// Local evidence persisted successfully.
  succeeded,

  /// Persist/acquire failed; no successful evidence commit for navigation.
  failed,
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static bool _isCockpitModality(WorkspaceCaptureMode mode) {
    return mode == WorkspaceCaptureMode.photo ||
        mode == WorkspaceCaptureMode.video ||
        mode == WorkspaceCaptureMode.voice;
  }

  /// Capture Now — always a new incident.
  ///
  /// Photo/Video/Voice/Note: Workspace opens only after evidence is created;
  /// cancel abandons the empty draft and stays on Home.
  ///
  /// File: incident is created before the picker; success, cancel, and failure
  /// all open that same incident Workspace (never bounce to Home mid-attach).
  Future<void> _handleCaptureTap(
    BuildContext context,
    QuickCaptureType type,
  ) async {
    final session = WorkspaceSession.instance;
    final manager = CaptureSessionManager.instance;
    final userId = UserSessionService.account?.userId ?? '';
    final mode = type.workspaceMode;
    final controller = session.controller;

    await session.beginNewCaptureIncident();
    await manager.getOrCreateActiveSession(
      incidentId: controller.currentIncident.id,
      userId: userId,
    );
    // File attach must continue even if Home BuildContext unmounted during
    // session create (SAF / shell rebuild). Other modalities still need UI.
    if (!context.mounted && mode != WorkspaceCaptureMode.file) {
      return;
    }

    final evidenceBefore = controller.currentIncident.evidenceCount;

    if (_isCockpitModality(mode)) {
      await CaptureCockpitScreen.open(
        context,
        initialMode: mode,
        controller: controller,
        boundIncidentId: controller.currentIncident.id,
      );
      if (!context.mounted) {
        return;
      }
      await finishCaptureNowAfterUi(
        context: context,
        session: session,
        evidenceBefore: evidenceBefore,
      );
      return;
    }

    if (mode == WorkspaceCaptureMode.file) {
      final sourceIncidentId = controller.currentIncident.id;
      // Do NOT abort on !mounted after incident create — SAF/async can unmount
      // Home without cancelling the attach. The transaction is context-free.
      final result = await FileAttachFlow.attach(
        origin: FileAttachOrigin.homeCaptureNow,
        context: context.mounted ? context : null,
        buildWorkspace: () => ContinuousCaptureScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      );
      if (result.outcome == FileAttachOutcome.failed) {
        final msg = result.userMessage ??
            'Couldn’t attach that file. Try again.';
        final snackCtx = context.mounted
            ? context
            : appNavigatorKey.currentContext;
        if (snackCtx != null && snackCtx.mounted) {
          AppSnackBar.showError(snackCtx, msg);
        }
      }
      // Workspace was ensured inside attach() without awaiting route pop.
      // Incident lock: result.sourceIncidentId must match created incident.
      assert(
        result.sourceIncidentId == sourceIncidentId ||
            result.outcome != FileAttachOutcome.succeeded,
        'File attach must keep the Capture Now incident',
      );
      return;
    }

    if (mode == WorkspaceCaptureMode.note) {
      final outcome = await captureNowNoteOrFile(
        context: context,
        mode: mode,
        controller: controller,
      );
      if (!context.mounted) {
        return;
      }
      if (outcome == CaptureNowOutcome.succeeded) {
        await AppNavigation.openContinuousCapture(context);
        return;
      }
      if (outcome == CaptureNowOutcome.failed && context.mounted) {
        AppSnackBar.showError(
          context,
          'Couldn’t save that note. Try again.',
        );
      }
      await session.abandonEmptyCaptureNow();
      return;
    }

    await session.abandonEmptyCaptureNow();
  }

  /// Opens Workspace only when Capture Now produced evidence; else stays Home.
  @visibleForTesting
  static Future<void> finishCaptureNowAfterUi({
    required BuildContext context,
    required WorkspaceSession session,
    required int evidenceBefore,
  }) async {
    final produced =
        session.controller.currentIncident.evidenceCount > evidenceBefore;
    if (produced) {
      if (context.mounted) {
        await AppNavigation.openContinuousCapture(context);
      }
      return;
    }
    await session.abandonEmptyCaptureNow();
  }

  /// Note/File Capture Now capture step (sheet/picker + local persist).
  ///
  /// Does not open Workspace — caller navigates only on [CaptureNowOutcome.succeeded].
  @visibleForTesting
  static Future<CaptureNowOutcome> captureNowNoteOrFile({
    required BuildContext context,
    required WorkspaceCaptureMode mode,
    required WorkspaceEvidenceController controller,
    Future<String?> Function(BuildContext context)? openNote,
    Future<CapturedMediaFile?> Function()? acquireFile,
  }) async {
    assert(
      mode == WorkspaceCaptureMode.note || mode == WorkspaceCaptureMode.file,
      'Capture Now immediate capture is only for note/file',
    );

    try {
      if (mode == WorkspaceCaptureMode.note) {
        final text = await (openNote ?? TextNoteCaptureSheet.open)(context);
        if (!context.mounted) {
          return CaptureNowOutcome.cancelled;
        }
        if (text == null || text.trim().isEmpty) {
          return CaptureNowOutcome.cancelled;
        }
        await controller.preserveTextNote(text);
        return CaptureNowOutcome.succeeded;
      }

      var releaseLockHere = true;
      try {
        final media = await (acquireFile ??
            () => FileAttachFlow.pick(
                  origin: FileAttachOrigin.homeCaptureNow,
                ))();
        // Never treat a successful pick as cancel merely because SAF unmounted
        // this BuildContext — persist against WorkspaceSession instead.
        if (media == null) {
          FileP0Trace.step(
            'HOME_PICK_RESULT',
            result: 'CANCEL_OR_NULL',
            mounted: context.mounted,
          );
          return CaptureNowOutcome.cancelled;
        }

        FileP0Trace.step(
          'HOME_PICK_RESULT',
          result: 'VALID',
          mounted: context.mounted,
          fileName: media.fileName,
          fileSize: media.fileSizeBytes,
          path: media.localPath,
        );
        final preserved = await FileAttachFlow.persistSelected(
          media,
          context: context.mounted ? context : null,
        );
        FileP0Trace.step(
          'HOME_PERSIST_RESULT',
          result: preserved ? 'OK' : 'FAIL',
          mounted: context.mounted,
          extra: 'count=${controller.currentIncident.evidenceCount}',
        );
        if (preserved) {
          releaseLockHere = false;
          return CaptureNowOutcome.succeeded;
        }
        return CaptureNowOutcome.failed;
      } finally {
        if (releaseLockHere) {
          FileAttachFlow.endAttach();
        }
      }
    } catch (error, stack) {
      FileP0Trace.failure(
        'HOME_CAPTURE_NOW_FILE',
        error: error,
        stackTrace: stack,
        mounted: context.mounted,
      );
      debugPrint('[Home] Capture Now note/file failed: $error');
      return CaptureNowOutcome.failed;
    }
  }

  /// Test helper: Capture Now Note/File then open Workspace only on success.
  @visibleForTesting
  static Future<CaptureNowOutcome> captureNowNoteOrFileThenWorkspace({
    required BuildContext context,
    required WorkspaceCaptureMode mode,
    required WorkspaceEvidenceController controller,
    Future<String?> Function(BuildContext context)? openNote,
    Future<CapturedMediaFile?> Function()? acquireFile,
  }) async {
    final outcome = await captureNowNoteOrFile(
      context: context,
      mode: mode,
      controller: controller,
      openNote: openNote,
      acquireFile: acquireFile,
    );
    if (outcome == CaptureNowOutcome.succeeded && context.mounted) {
      try {
        await AppNavigation.openContinuousCapture(context);
      } finally {
        FileAttachFlow.endAttach();
      }
    } else {
      FileAttachFlow.endAttach();
    }
    return outcome;
  }

  Future<void> _handleContinueCapture(
    BuildContext context,
    String incidentId,
  ) async {
    final opened = await WorkspaceSession.instance.openIncident(incidentId);
    if (!context.mounted) {
      return;
    }
    if (!opened) {
      AppSnackBar.showSuccess(
        context,
        'Couldn’t open that incident yet. Try again.',
      );
      return;
    }
    await AppNavigation.openContinuousCapture(context);
  }

  Future<void> _handleIncidentCardTap(
    BuildContext context,
    String incidentId,
  ) async {
    final opened = await _openIncidentOrNotify(context, incidentId);
    if (!opened || !context.mounted) {
      return;
    }
    await AppNavigation.openIncidentWorkspaceFromLibrary(context);
  }

  Future<void> _handleContinueInvestigation(
    BuildContext context,
    String incidentId,
  ) async {
    final opened = await _openIncidentOrNotify(context, incidentId);
    if (!opened || !context.mounted) {
      return;
    }
    await AppNavigation.openIncidentWorkspace(
      context,
      initialStage: LibraryIncidentRoutes.continueInvestigationStage,
      initialInvestigationTab: LibraryIncidentRoutes.continueInvestigationTab,
    );
  }

  Future<bool> _openIncidentOrNotify(
    BuildContext context,
    String incidentId,
  ) async {
    final targetId = incidentId.trim();
    if (targetId.isEmpty) {
      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          'Couldn’t open that investigation yet. Try again.',
        );
      }
      return false;
    }
    final opened = await WorkspaceSession.instance.openIncident(targetId);
    if (!opened && context.mounted) {
      AppSnackBar.showSuccess(
        context,
        'Couldn’t open that investigation yet. Try again.',
      );
    }
    return opened;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: HomeBody(
          onCaptureTap: (type) => _handleCaptureTap(context, type),
          onCaptureNewIncident: () =>
              _handleCaptureTap(context, QuickCaptureType.photo),
          onContinueCapture: (incidentId) =>
              _handleContinueCapture(context, incidentId),
          onResume: (incidentId) =>
              _handleContinueInvestigation(context, incidentId),
          onIncidentTap: (incidentId) =>
              _handleIncidentCardTap(context, incidentId),
        ),
      ),
    );
  }
}
