import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/workspace_session.dart';
import '../../diagnostics/file_final_trace.dart';
import '../../navigation/app_navigator.dart';
import '../../models/investigation_methodology_stage.dart';
import '../../screens/capture/continuous_capture_screen.dart';
import '../../screens/incident_workspace_shell.dart';
import '../../widgets/common/app_snackbar.dart';
import '../capture/capture_session_manager.dart';
import '../persistence/local_capture_session_store.dart';
import '../persistence/local_incident_pointer.dart';
import '../user_session_service.dart';
import 'durable_attach_intent.dart';
import 'durable_attach_intent_store.dart';
import 'file_attach_flow.dart';
import 'file_attachment_classifier.dart';
import 'local_evidence_cache.dart';
import 'saf_staging_bridge.dart';

/// Result of evaluating a durable File attach intent after process death.
enum FileAttachRecoveryOutcome {
  /// No pending intent, or recovery is not applicable yet.
  none,

  /// Exact source incident Workspace restored; user must reselect the document.
  restoredReselectRequired,

  /// Native COMPLETE artifact persisted through the existing local path.
  persistedFromNative,

  /// Intent discarded (stale, ownership, or security fail-closed).
  abandoned,

  /// Session/navigator not ready; intent left in place for a later attempt.
  skipped,
}

/// Cold-start task restoration for File attach after Flutter process death.
///
/// AuthGate keeps the existing restore spinner until this recovery has had a
/// chance to push the originating Workspace, so Home is not painted first.
/// Does not pop or re-push based on Home visibility. After session restore,
/// if a durable attach intent exists, opens that exact [sourceIncidentId]
/// Workspace. A COMPLETE native SAF staging artifact is persisted through
/// the existing FileAttachFlow path. Otherwise the user is asked to reselect.
abstract final class FileAttachRecovery {
  static const reselectMessage =
      'Select the document again to attach it to this incident.';

  static bool _installed = false;
  static bool _inFlight = false;
  static Completer<FileAttachRecoveryOutcome>? _inFlightGate;
  static String? _evaluatedOperationId;
  static int _navRetries = 0;

  /// Test-only: allow [install] under `FLUTTER_TEST` to reproduce the
  /// AuthGate / install overlap. Production behavior is unchanged.
  @visibleForTesting
  static bool debugForceInstallInTests = false;

  /// Test-only: how many times the recovery body ran (not overlapping waiters).
  @visibleForTesting
  static int debugRecoveryBodyRuns = 0;

  @visibleForTesting
  static void debugReset() {
    if (_installed) {
      WorkspaceSession.instance.removeListener(_onSessionChanged);
    }
    _installed = false;
    _inFlight = false;
    final gate = _inFlightGate;
    _inFlightGate = null;
    if (gate != null && !gate.isCompleted) {
      gate.complete(FileAttachRecoveryOutcome.skipped);
    }
    _evaluatedOperationId = null;
    _navRetries = 0;
    debugForceInstallInTests = false;
    debugRecoveryBodyRuns = 0;
  }

  static bool get _inFlutterTest {
    if (kIsWeb) {
      return false;
    }
    return Platform.environment.containsKey('FLUTTER_TEST');
  }

  /// Observes session restore. Skipped under widget tests unless
  /// [debugForceInstallInTests] is set (call [recoverIfNeeded] directly).
  static void install() {
    if (_installed) {
      return;
    }
    if (_inFlutterTest && !debugForceInstallInTests) {
      return;
    }
    _installed = true;
    WorkspaceSession.instance.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  static void _onSessionChanged() {
    final session = WorkspaceSession.instance;
    if (!session.isCloudRestored || session.isRestoring) {
      return;
    }
    if (!UserSessionService.isSignedIn) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(recoverIfNeeded());
    });
  }

  /// True when a durable attach intent exists for the signed-in user.
  ///
  /// Used by AuthGate to keep the existing restore spinner up until recovery
  /// navigation has run. Reads the existing [DurableAttachIntentStore] only.
  static Future<bool> hasPendingRecoveryForCurrentUser() async {
    final userId = UserSessionService.account?.userId ?? '';
    if (userId.isEmpty) {
      return false;
    }
    try {
      final intent = await DurableAttachIntentStore.readPendingIntent(
        userId: userId,
      );
      return intent != null;
    } catch (_) {
      return false;
    }
  }

  /// Evaluates and, if valid, restores the stored incident Workspace.
  ///
  /// Overlapping callers await the existing in-flight recovery and receive
  /// its terminal outcome. They do not start a second recovery and do not
  /// return [FileAttachRecoveryOutcome.skipped] merely because one is running.
  ///
  /// Does not create a new incident. Does not invent a SAF picker result.
  /// A COMPLETE native staging artifact is persisted through the existing
  /// local path. Clears the intent only on fail-closed security/stale
  /// terminals or after successful native persist — not after a reselect prompt.
  static Future<FileAttachRecoveryOutcome> recoverIfNeeded() async {
    if (_inFlight) {
      final existing = _inFlightGate;
      if (existing != null) {
        return existing.future;
      }
    }
    if (FileAttachFlow.attachInProgress) {
      return FileAttachRecoveryOutcome.skipped;
    }

    final session = WorkspaceSession.instance;
    if (!session.isCloudRestored || session.isRestoring) {
      return FileAttachRecoveryOutcome.skipped;
    }

    final userId = UserSessionService.account?.userId ?? '';
    if (userId.isEmpty) {
      return FileAttachRecoveryOutcome.skipped;
    }

    final gate = Completer<FileAttachRecoveryOutcome>();
    _inFlightGate = gate;
    _inFlight = true;
    var outcome = FileAttachRecoveryOutcome.skipped;
    try {
      final intent = await DurableAttachIntentStore.readPendingIntent(
        userId: userId,
      );
      if (intent == null) {
        outcome = FileAttachRecoveryOutcome.none;
        return outcome;
      }

      if (_evaluatedOperationId == intent.operationId) {
        outcome = FileAttachRecoveryOutcome.skipped;
        return outcome;
      }
      debugRecoveryBodyRuns++;

      FileFinalTrace.sourceIncidentId = intent.sourceIncidentId;
      FileFinalTrace.entryPoint = intent.isHomeCaptureNow
          ? 'HOME_CAPTURE_NOW'
          : 'WORKSPACE';
      FileFinalTrace.stage(
        'ATTACH_RECOVERY_STARTED',
        extra:
            'origin=${intent.origin} operationId=${intent.operationId} '
            'status=${intent.status}',
      );
      FileFinalTrace.stage(
        'ATTACH_INTENT_RESTORED',
        extra:
            'origin=${intent.origin} operationId=${intent.operationId} '
            'sourceIncidentId=${intent.sourceIncidentId}',
      );

      FileFinalTrace.stage(
        'ATTACH_RECOVERY_OWNER_CHECK',
        extra:
            'storedUser=${intent.userId} currentUser=$userId '
            'incident=${intent.sourceIncidentId}',
      );
      if (intent.userId != userId) {
        FileFinalTrace.stage(
          'ATTACH_RECOVERY_ABANDONED',
          result: 'OWNER_USER_MISMATCH',
          extra: 'storedUser=${intent.userId} currentUser=$userId',
        );
        await DurableAttachIntentStore.clearPendingIntent(
          userId: userId,
          operationId: intent.operationId,
          reason: 'owner_user_mismatch',
        );
        await SafStagingBridge.discard(intent.operationId);
        _evaluatedOperationId = intent.operationId;
        outcome = FileAttachRecoveryOutcome.abandoned;
        return outcome;
      }

      final owned = await _userOwnsIncident(
        userId: userId,
        incidentId: intent.sourceIncidentId,
      );
      if (!owned) {
        FileFinalTrace.stage(
          'ATTACH_RECOVERY_ABANDONED',
          result: 'OWNER_INCIDENT_UNPROVEN',
          extra:
              'origin=${intent.origin} operationId=${intent.operationId} '
              'incident=${intent.sourceIncidentId}',
        );
        await DurableAttachIntentStore.clearPendingIntent(
          userId: userId,
          operationId: intent.operationId,
          reason: 'owner_incident_unproven',
        );
        await SafStagingBridge.discard(intent.operationId);
        _evaluatedOperationId = intent.operationId;
        outcome = FileAttachRecoveryOutcome.abandoned;
        return outcome;
      }

      final nav = appNavigatorKey.currentState;
      if (nav == null) {
        FileFinalTrace.stage(
          'ATTACH_RECOVERY_STARTED',
          result: 'WAIT_NAVIGATOR',
          extra: 'operationId=${intent.operationId}',
        );
        if (_navRetries < 20) {
          _navRetries++;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(recoverIfNeeded());
          });
        }
        outcome = FileAttachRecoveryOutcome.skipped;
        return outcome;
      }
      _navRetries = 0;

      final opened = await WorkspaceSession.instance.openIncident(
        intent.sourceIncidentId,
      );
      final live = WorkspaceSession.instance.controller.currentIncident.id;
      if (!opened || live != intent.sourceIncidentId) {
        FileFinalTrace.stage(
          'ATTACH_RECOVERY_ABANDONED',
          result: 'OPEN_FAILED',
          extra:
              'expected=${intent.sourceIncidentId} live=$live '
              'operationId=${intent.operationId}',
        );
        outcome = FileAttachRecoveryOutcome.skipped;
        return outcome;
      }

      FileFinalTrace.stage(
        'ATTACH_RECOVERY_WORKSPACE',
        extra:
            'origin=${intent.origin} incident=${intent.sourceIncidentId} '
            'operationId=${intent.operationId}',
      );

      final restoreOrganize =
          intent.modality == DurableAttachIntent.modalityOrganizeFile;
      await FileAttachFlow.ensureWorkspaceVisible(
        buildWorkspace: restoreOrganize
            ? () => IncidentWorkspaceShell(
                  incidentId: intent.sourceIncidentId,
                  controller: WorkspaceSession.instance.controller,
                  initialStage: InvestigationMethodologyStage.evidence,
                )
            : () => ContinuousCaptureScreen(
                  controller: WorkspaceSession.instance.controller,
                ),
        sourceIncidentId: intent.sourceIncidentId,
        restoreOrganize: restoreOrganize,
      );

      final persistedNative = await _persistCompleteNativeArtifact(
        intent: intent,
        userId: userId,
      );
      if (persistedNative) {
        FileFinalTrace.stage(
          'ATTACH_RECOVERY_COMPLETED',
          extra:
              'origin=${intent.origin} operationId=${intent.operationId} '
              'incident=${intent.sourceIncidentId} nativePersist=true',
        );
        _evaluatedOperationId = intent.operationId;
        outcome = FileAttachRecoveryOutcome.persistedFromNative;
        return outcome;
      }

      await DurableAttachIntentStore.savePendingIntent(
        intent.copyWith(status: DurableAttachIntent.reselectRequired),
      );

      FileFinalTrace.stage(
        'ATTACH_RECOVERY_RESELECT_REQUIRED',
        extra:
            'origin=${intent.origin} operationId=${intent.operationId} '
            'safUriRecoverable=false file_picker=8.3.7',
      );

      final snackCtx = appNavigatorKey.currentContext;
      if (snackCtx != null && snackCtx.mounted) {
        AppSnackBar.showError(snackCtx, reselectMessage);
      }

      FileFinalTrace.stage(
        'ATTACH_RECOVERY_COMPLETED',
        extra:
            'origin=${intent.origin} operationId=${intent.operationId} '
            'incident=${intent.sourceIncidentId}',
      );
      _evaluatedOperationId = intent.operationId;
      outcome = FileAttachRecoveryOutcome.restoredReselectRequired;
      return outcome;
    } catch (error, stack) {
      if (!gate.isCompleted) {
        gate.completeError(error, stack);
      }
      rethrow;
    } finally {
      if (!gate.isCompleted) {
        gate.complete(outcome);
      }
      if (identical(_inFlightGate, gate)) {
        _inFlightGate = null;
      }
      _inFlight = false;
    }
  }

  /// Fail-closed ownership: stored user must match, and the incident must
  /// already belong to that user locally. Never treats "current incident"
  /// as a substitute for [incidentId].
  static Future<bool> _userOwnsIncident({
    required String userId,
    required String incidentId,
  }) async {
    if (userId.isEmpty || incidentId.isEmpty) {
      return false;
    }

    final open = CaptureSessionManager.instance.getOpenSession(incidentId);
    if (open != null &&
        (open.userId.isEmpty || open.userId == userId) &&
        open.incidentId == incidentId) {
      return true;
    }

    final storedSessions = await LocalCaptureSessionStore.forIncident(
      incidentId,
      userId: userId,
    );
    if (storedSessions.any(
      (session) => session.userId.isEmpty || session.userId == userId,
    )) {
      return true;
    }

    final pointer = await LocalIncidentPointer.recall(userId);
    if (pointer == incidentId) {
      return true;
    }

    final title = await LocalIncidentPointer.recallTitleForIncident(
      userId: userId,
      incidentId: incidentId,
    );
    if (title != null && title.isNotEmpty) {
      return true;
    }

    final cached = await LocalEvidenceCache.forIncident(
      incidentId,
      userId: userId,
    );
    return cached.isNotEmpty;
  }

  /// Persists a COMPLETE native artifact through existing FileAttachFlow.
  /// Partial artifacts are never attached. Failed persist keeps reselect.
  static Future<bool> _persistCompleteNativeArtifact({
    required DurableAttachIntent intent,
    required String userId,
  }) async {
    final artifact = await SafStagingBridge.getArtifact(intent.operationId);
    if (artifact == null) {
      FileFinalTrace.stage(
        'ATTACH_RECOVERY_NATIVE_PARTIAL',
        extra:
            'operationId=${intent.operationId} complete=false '
            'file_picker=8.3.7',
      );
      return false;
    }

    FileFinalTrace.stage(
      'ATTACH_RECOVERY_NATIVE_COMPLETE',
      fileName: artifact.fileName,
      fileSize: artifact.size,
      path: artifact.path,
      extra: 'operationId=${intent.operationId} sha256=${artifact.sha256}',
    );

    if (await _alreadyPersisted(
      userId: userId,
      incidentId: intent.sourceIncidentId,
      intentCreatedAtMs: intent.createdAtMs,
      sha256: artifact.sha256,
      fileName: artifact.fileName,
      size: artifact.size,
    )) {
      FileFinalTrace.stage(
        'ATTACH_RECOVERY_NATIVE_PERSISTED',
        result: 'ALREADY',
        extra: 'operationId=${intent.operationId}',
      );
      await DurableAttachIntentStore.clearPendingIntent(
        userId: userId,
        operationId: intent.operationId,
        reason: 'succeeded_native_idempotent',
      );
      await SafStagingBridge.discard(intent.operationId);
      return true;
    }

    final media = artifact.toMedia();
    final mime =
        artifact.mimeType ??
        FileAttachmentClassifier.guessMimeType(media.fileName);
    if (!FileAttachmentClassifier.isSupported(
      fileName: media.fileName,
      mimeType: mime,
    )) {
      FileFinalTrace.failure(
        'ATTACH_RECOVERY_NATIVE_UNSUPPORTED',
        fileName: media.fileName,
        mimeType: mime,
      );
      await SafStagingBridge.discard(intent.operationId);
      return false;
    }

    final idsBefore = {
      for (final item
          in WorkspaceSession.instance.controller.currentIncident.evidence)
        item.id,
    };
    final preserved = await FileAttachFlow.persistSelected(
      media,
      persistMode: FileAttachmentClassifier.persistMode(
        fileName: media.fileName,
        mimeType: mime,
      ),
      mimeType: mime,
      lockedIncidentId: intent.sourceIncidentId,
      asOrganizeContext:
          intent.modality == DurableAttachIntent.modalityOrganizeFile,
    );
    if (!preserved) {
      FileFinalTrace.failure(
        'ATTACH_RECOVERY_NATIVE_PERSIST',
        fileName: media.fileName,
        extra: 'operationId=${intent.operationId}',
      );
      await SafStagingBridge.discard(intent.operationId);
      return false;
    }

    if (intent.modality == DurableAttachIntent.modalityOrganizeFile) {
      FileAttachFlow.markOrganizeCreatedSince(idsBefore);
    }

    await DurableAttachIntentStore.clearPendingIntent(
      userId: userId,
      operationId: intent.operationId,
      reason: 'succeeded_native',
    );
    await SafStagingBridge.discard(intent.operationId);
    FileFinalTrace.stage(
      'ATTACH_RECOVERY_NATIVE_PERSISTED',
      result: 'OK',
      extra: 'operationId=${intent.operationId}',
    );
    return true;
  }

  static Future<bool> _alreadyPersisted({
    required String userId,
    required String incidentId,
    required int intentCreatedAtMs,
    required String? sha256,
    required String? fileName,
    required int size,
  }) async {
    final cached = await LocalEvidenceCache.forIncident(
      incidentId,
      userId: userId,
    );
    if (cached.isEmpty) {
      return false;
    }
    final createdFloor = DateTime.fromMillisecondsSinceEpoch(intentCreatedAtMs);
    final hash = sha256?.trim() ?? '';
    if (hash.isNotEmpty && cached.any((entry) => entry.hash == hash)) {
      return true;
    }
    final name = fileName?.trim() ?? '';
    if (name.isEmpty) {
      return false;
    }
    return cached.any((entry) {
      if (entry.fileName != name || entry.fileSizeBytes != size) {
        return false;
      }
      return !entry.capturedAt.isBefore(createdFloor);
    });
  }
}
