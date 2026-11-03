import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/workspace_session.dart';
import '../../diagnostics/file_final_trace.dart';
import '../../models/workspace_capture_mode.dart';
import '../../models/workspace_resume_target.dart';
import '../../navigation/app_navigator.dart';
import '../user_session_service.dart';
import 'capture_media_service.dart';
import 'durable_attach_intent.dart';
import 'durable_attach_intent_store.dart';
import 'evidence_upload_coordinator.dart';
import 'file_attachment_classifier.dart';
import 'file_attachment_persist.dart';
import 'saf_staging_bridge.dart';

/// Origin of a File attach attempt.
enum FileAttachOrigin { homeCaptureNow, workspaceSticky }

/// Result of a complete File attach transaction.
enum FileAttachOutcome {
  /// User cancelled the system picker (or empty result).
  cancelled,

  /// Local evidence committed for [sourceIncidentId].
  succeeded,

  /// Readable validation / persist failure — Workspace should remain.
  failed,
}

class FileAttachResult {
  const FileAttachResult({
    required this.outcome,
    required this.sourceIncidentId,
    this.userMessage,
    this.evidenceId,
  });

  final FileAttachOutcome outcome;
  final String sourceIncidentId;
  final String? userMessage;
  final String? evidenceId;
}

/// Session-scoped File attach orchestration that survives SAF activity resume.
///
/// Transaction (one lock):
/// pick → validate → durableize/persist → ensure Workspace → release lock.
///
/// Cloud sync is never awaited. `!mounted` is never treated as cancellation
/// once a valid file has been selected.
abstract final class FileAttachFlow {
  static final _attachLock = ValueNotifier<bool>(false);
  static final _settling = ValueNotifier<bool>(false);
  static final _lifecycleGuard = _FileAttachLifecycleGuard();

  /// Rebuilds Incident Workspace [PopScope] when attach or settling changes.
  ///
  /// [PopScope.canPop] is a build-time snapshot; listeners also keep a live
  /// [PopEntry] in sync so a pop cannot race the next frame.
  static final Listenable attachLock = Listenable.merge([
    _attachLock,
    _settling,
  ]);

  /// True from picker open through Workspace reveal.
  static bool get attachInProgress => _attachLock.value;
  static set attachInProgress(bool value) => _attachLock.value = value;

  /// True across the SAF resume/settling window after the transaction ends.
  static bool get fileAttachSettling => _settling.value;

  /// Incident Workspace must not pop while either flag is set.
  static bool get blocksWorkspacePop => attachInProgress || fileAttachSettling;

  /// Set by ContinuousCaptureScreen and IncidentWorkspaceShell init/dispose.
  static bool workspaceRouteVisible = false;

  static FileAttachOrigin? _origin;
  static String? _incidentIdAtOpen;
  static String? _operationId;
  static int _attachGeneration = 0;
  static bool _observerAttached = false;
  static bool _releaseSettlingWhenResumed = false;
  static AppLifecycleState _lifecycle =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  /// Incident ID captured when the picker opened (attach target).
  static String? get expectedIncidentId => _incidentIdAtOpen;

  /// Legacy alias — PopScope and diagnostics still read [pickerActive].
  static bool get pickerActive => attachInProgress;

  /// Full File attach transaction for Home or Workspace.
  ///
  /// Does **not** await Workspace route completion (pop). Lock is released
  /// after local persist + Workspace push/ensure.
  static Future<FileAttachResult> attach({
    required FileAttachOrigin origin,
    BuildContext? context,
    required Widget Function() buildWorkspace,
    Future<CapturedMediaFile?> Function()? acquireFile,
    bool asOrganizeContext = false,
  }) async {
    final entry = origin == FileAttachOrigin.homeCaptureNow
        ? 'HOME_CAPTURE_NOW'
        : 'WORKSPACE';
    FileFinalTrace.entryPoint = entry;

    final session = WorkspaceSession.instance;
    final sourceIncidentId = session.controller.currentIncident.id;
    FileFinalTrace.sourceIncidentId = sourceIncidentId;
    _origin = origin;
    _incidentIdAtOpen = sourceIncidentId;
    _startAttachLock();

    final idsBefore = {
      for (final item in session.controller.currentIncident.evidence) item.id,
    };

    Future<void> revealWorkspace() {
      return ensureWorkspaceVisible(
        buildWorkspace: buildWorkspace,
        sourceIncidentId: sourceIncidentId,
        restoreOrganize: asOrganizeContext,
      );
    }

    FileFinalTrace.stage(
      'FILE_TAP',
      mounted: context?.mounted,
      extra:
          'origin=${origin.name} asOrganizeContext=$asOrganizeContext',
    );
    FileFinalTrace.stage(
      'INCIDENT_LOCKED',
      extra: 'sourceIncidentId=$sourceIncidentId',
    );

    try {
      await _saveDurableIntent(
        origin: origin,
        sourceIncidentId: sourceIncidentId,
        asOrganizeContext: asOrganizeContext,
      );
      await _awaitWorkspacePopGuard();
      FileFinalTrace.stage('PICKER_OPEN', mounted: context?.mounted);
      final media =
          await (acquireFile ??
              () => CaptureMediaService.acquire(WorkspaceCaptureMode.file))();

      if (media == null) {
        FileFinalTrace.stage(
          'PICKER_RETURN',
          result: 'CANCEL_OR_NULL',
          mounted: context?.mounted,
        );
        // Living process + null picker = explicit user cancel.
        // Process death never returns here, so the durable intent remains.
        await _discardNativeStaging();
        await _clearDurableIntent('user_cancelled');
        await revealWorkspace();
        FileFinalTrace.stage('COMPLETE', result: 'CANCELLED');
        return FileAttachResult(
          outcome: FileAttachOutcome.cancelled,
          sourceIncidentId: sourceIncidentId,
        );
      }

      final selected = await _preferNativeStaging(media);
      final ext = FileAttachmentClassifier.extensionOf(selected.fileName);
      final mime = FileAttachmentClassifier.guessMimeType(selected.fileName) ??
          FileAttachmentClassifier.guessMimeType(media.fileName);
      FileFinalTrace.stage(
        'PICKER_RETURN',
        result: 'VALID',
        mounted: context?.mounted,
        fileName: selected.fileName,
        extension: ext,
        mimeType: mime,
        fileSize: selected.fileSizeBytes,
        path: selected.localPath,
      );
      FileFinalTrace.stage(
        'FILE_URI_RESOLVED',
        fileName: selected.fileName,
        extension: ext,
        mimeType: mime,
        fileSize: selected.fileSizeBytes,
        path: selected.localPath,
      );
      FileFinalTrace.stage(
        'FILE_METADATA_RESOLVED',
        fileName: selected.fileName,
        extension: ext,
        mimeType: mime,
        fileSize: selected.fileSizeBytes,
        path: selected.localPath,
      );

      // Access test — path must remain readable after SAF resume.
      try {
        final file = File(selected.localPath);
        if (!await file.exists()) {
          throw StateError('file missing after picker: ${selected.localPath}');
        }
        final length = await file.length();
        FileFinalTrace.stage(
          'FILE_ACCESS_TEST',
          result: 'OK',
          fileName: selected.fileName,
          fileSize: length,
          path: selected.localPath,
        );
      } catch (error, stack) {
        FileFinalTrace.failure(
          'FILE_ACCESS_TEST',
          error: error,
          stackTrace: stack,
          fileName: selected.fileName,
          path: selected.localPath,
        );
        await revealWorkspace();
        await _clearDurableIntent('failed_unreadable');
        return FileAttachResult(
          outcome: FileAttachOutcome.failed,
          sourceIncidentId: sourceIncidentId,
          userMessage: 'We couldn’t read this file. Please try again.',
        );
      }

      if (!FileAttachmentClassifier.isSupported(
        fileName: selected.fileName,
        mimeType: mime,
      )) {
        FileFinalTrace.failure(
          'UNSUPPORTED_TYPE',
          fileName: selected.fileName,
          extension: ext,
          mimeType: mime,
        );
        await revealWorkspace();
        await _clearDurableIntent('failed_unsupported');
        return FileAttachResult(
          outcome: FileAttachOutcome.failed,
          sourceIncidentId: sourceIncidentId,
          userMessage: 'This file type isn’t supported.',
        );
      }

      // Abort only if the *session* switched incidents — never because of UI.
      final liveId = session.controller.currentIncident.id;
      if (liveId != sourceIncidentId) {
        FileFinalTrace.failure(
          'INCIDENT_SWITCH',
          extra: 'source=$sourceIncidentId live=$liveId',
        );
        await revealWorkspace();
        await _clearDurableIntent('failed_incident_switch');
        return FileAttachResult(
          outcome: FileAttachOutcome.failed,
          sourceIncidentId: sourceIncidentId,
          userMessage: 'Couldn’t save this evidence locally.',
        );
      }

      final persistMode = FileAttachmentClassifier.persistMode(
        fileName: selected.fileName,
        mimeType: mime,
      );
      FileFinalTrace.stage(
        'LOCAL_COPY_START',
        fileName: selected.fileName,
        extension: ext,
        mimeType: mime,
        fileSize: selected.fileSizeBytes,
        extra: 'persistMode=${persistMode.name}',
      );

      final preserved = await persistSelected(
        selected,
        context: (context != null && context.mounted) ? context : null,
        persistMode: persistMode,
        mimeType: mime,
        lockedIncidentId: sourceIncidentId,
        asOrganizeContext: asOrganizeContext,
      );

      if (!preserved) {
        FileFinalTrace.failure(
          'EVIDENCE_PERSIST',
          fileName: selected.fileName,
          extension: ext,
        );
        await revealWorkspace();
        await _clearDurableIntent('failed_persist');
        return FileAttachResult(
          outcome: FileAttachOutcome.failed,
          sourceIncidentId: sourceIncidentId,
          userMessage: 'Couldn’t save this evidence locally.',
        );
      }

      FileFinalTrace.stage(
        'LOCAL_COPY_SUCCESS',
        fileName: selected.fileName,
        fileSize: selected.fileSizeBytes,
      );
      FileFinalTrace.stage(
        'EVIDENCE_CREATE',
        result: 'OK',
        extra: 'persistMode=${persistMode.name}',
      );
      FileFinalTrace.stage(
        'EVIDENCE_PERSIST',
        result: 'OK',
        extra:
            'count=${session.controller.currentIncident.evidenceCount} '
            'incident=${session.controller.currentIncident.id}',
      );

      if (asOrganizeContext) {
        markOrganizeCreatedSince(idsBefore);
      }

      FileFinalTrace.stage('WORKSPACE_UPDATE');
      await revealWorkspace();
      FileFinalTrace.stage(
        'WORKSPACE_VISIBLE',
        result: workspaceRouteVisible ? 'YES' : 'PUSHED_OR_PENDING',
      );
      FileFinalTrace.stage(
        'CLOUD_SYNC_QUEUED',
        result: 'ASYNC',
        extra: 'localFirst=true',
      );
      FileFinalTrace.stage('COMPLETE', result: 'SUCCESS');
      await _clearDurableIntent('succeeded');

      return FileAttachResult(
        outcome: FileAttachOutcome.succeeded,
        sourceIncidentId: sourceIncidentId,
      );
    } catch (error, stack) {
      FileFinalTrace.failure(
        'ATTACH_EXCEPTION',
        error: error,
        stackTrace: stack,
        mounted: context?.mounted,
      );
      try {
        await revealWorkspace();
      } catch (_) {}
      await _clearDurableIntent('failed_exception');
      return FileAttachResult(
        outcome: FileAttachOutcome.failed,
        sourceIncidentId: sourceIncidentId,
        userMessage: 'Couldn’t save this evidence locally.',
      );
    } finally {
      // In-memory PopScope lock only. Durable intent is cleared solely at
      // terminal success / explicit cancel / failed persist — not on pause.
      _scheduleEndAttach();
    }
  }

  /// Opens the system picker only (legacy). Prefer [attach].
  static Future<CapturedMediaFile?> pick({
    required FileAttachOrigin origin,
  }) async {
    final session = WorkspaceSession.instance;
    _origin = origin;
    _incidentIdAtOpen = session.controller.currentIncident.id;
    FileFinalTrace.sourceIncidentId = _incidentIdAtOpen;
    FileFinalTrace.entryPoint = origin == FileAttachOrigin.homeCaptureNow
        ? 'HOME_CAPTURE_NOW'
        : 'WORKSPACE';
    _startAttachLock();
    FileFinalTrace.stage('PICKER_OPEN', extra: 'origin=${origin.name}');
    try {
      await _awaitWorkspacePopGuard();
      final media = await CaptureMediaService.acquire(
        WorkspaceCaptureMode.file,
      );
      if (media == null) {
        FileFinalTrace.stage('PICKER_RETURN', result: 'CANCEL_OR_NULL');
        return null;
      }
      FileFinalTrace.stage(
        'PICKER_RETURN',
        result: 'VALID',
        fileName: media.fileName,
        fileSize: media.fileSizeBytes,
        path: media.localPath,
        extension: FileAttachmentClassifier.extensionOf(media.fileName),
      );
      return media;
    } catch (error, stack) {
      FileFinalTrace.failure(
        'PICKER_EXCEPTION',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @visibleForTesting
  static void beginAttachForTests({
    required FileAttachOrigin origin,
    required String incidentId,
  }) {
    _origin = origin;
    _incidentIdAtOpen = incidentId;
    FileFinalTrace.sourceIncidentId = incidentId;
    _startAttachLock();
  }

  @visibleForTesting
  static String? get debugOperationId => _operationId;

  /// Persists attach metadata before SAF. Must run before pickFiles.
  static Future<void> _saveDurableIntent({
    required FileAttachOrigin origin,
    required String sourceIncidentId,
    bool asOrganizeContext = false,
  }) async {
    final userId = UserSessionService.account?.userId ?? '';
    _operationId =
        'att-${DateTime.now().microsecondsSinceEpoch}-$_attachGeneration';
    final intent = DurableAttachIntent(
      userId: userId,
      sourceIncidentId: sourceIncidentId,
      origin: origin == FileAttachOrigin.homeCaptureNow
          ? DurableAttachIntent.originHomeCaptureNow
          : DurableAttachIntent.originWorkspaceSticky,
      operationId: _operationId!,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      modality: asOrganizeContext
          ? DurableAttachIntent.modalityOrganizeFile
          : DurableAttachIntent.modalityFile,
    );
    await DurableAttachIntentStore.savePendingIntent(intent);
  }

  /// Clears only this operation's record. A newer overlapping attach is kept.
  static Future<void> _clearDurableIntent(String reason) async {
    final userId = UserSessionService.account?.userId ?? '';
    final operationId = _operationId;
    await DurableAttachIntentStore.clearPendingIntent(
      userId: userId,
      operationId: operationId,
      reason: reason,
    );
    await _discardNativeStaging();
  }

  static Future<void> _discardNativeStaging() async {
    final operationId = _operationId;
    if (operationId == null || operationId.isEmpty) {
      return;
    }
    await SafStagingBridge.discard(operationId);
  }

  /// Prefers COMPLETE native staging over file_picker's cache path.
  static Future<CapturedMediaFile> _preferNativeStaging(
    CapturedMediaFile pickerMedia,
  ) async {
    final staged = await SafStagingBridge.awaitComplete(
      operationId: _operationId,
    );
    if (staged == null) {
      FileFinalTrace.stage(
        'NATIVE_STAGING_ABSENT',
        extra: 'operationId=${_operationId ?? 'none'}',
      );
      return pickerMedia;
    }
    FileFinalTrace.stage(
      'NATIVE_STAGING_READY',
      fileName: staged.fileName,
      fileSize: staged.fileSizeBytes,
      path: staged.localPath,
      extra: 'operationId=${_operationId ?? 'none'}',
    );
    return staged;
  }

  /// Drops [attachInProgress] after the current frame, then keeps
  /// [fileAttachSettling] until the app is resumed and one further frame.
  static void _scheduleEndAttach() {
    final generation = _attachGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _attachGeneration) {
        return;
      }
      if (attachInProgress) {
        FileFinalTrace.stage(
          'ATTACH_LOCK_RELEASE',
          extra: 'origin=${_origin?.name ?? 'unknown'} settling=true',
        );
        attachInProgress = false;
      }
      _armSettlingRelease(generation);
    });
  }

  static void _armSettlingRelease(int generation) {
    if (generation != _attachGeneration) {
      return;
    }
    if (_lifecycle != AppLifecycleState.resumed) {
      _releaseSettlingWhenResumed = true;
      FileFinalTrace.stage(
        'ATTACH_SETTLING_WAIT_RESUME',
        extra: 'lifecycle=${_lifecycle.name}',
      );
      return;
    }
    // Clear at the *start* of the next frame so ListenableBuilder/PopScope
    // rebuild in the same frame. A post-frame clear left PopScope stale and
    // blocked explicit Back/DONE after settling had already ended.
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      if (generation != _attachGeneration) {
        return;
      }
      if (_lifecycle != AppLifecycleState.resumed) {
        _releaseSettlingWhenResumed = true;
        return;
      }
      _clearSettling();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static void _clearSettling() {
    if (!fileAttachSettling && _incidentIdAtOpen == null && _origin == null) {
      return;
    }
    FileFinalTrace.stage(
      'ATTACH_SETTLING_RELEASE',
      extra: 'origin=${_origin?.name ?? 'unknown'}',
    );
    _releaseSettlingWhenResumed = false;
    _setSettling(false);
    _incidentIdAtOpen = null;
    _origin = null;
  }

  static void endAttach() {
    _attachGeneration++;
    _releaseSettlingWhenResumed = false;
    if (!attachInProgress &&
        !fileAttachSettling &&
        _incidentIdAtOpen == null &&
        _origin == null) {
      return;
    }
    FileFinalTrace.stage(
      'ATTACH_LOCK_RELEASE',
      extra: 'origin=${_origin?.name ?? 'unknown'} forced=true',
    );
    attachInProgress = false;
    _setSettling(false);
    _incidentIdAtOpen = null;
    _origin = null;
  }

  static void _startAttachLock() {
    _ensureLifecycleObserver();
    _attachGeneration++;
    _releaseSettlingWhenResumed = false;
    attachInProgress = true;
    _setSettling(true);
  }

  static void _setSettling(bool value) {
    if (_settling.value == value) {
      return;
    }
    _settling.value = value;
  }

  /// Lets [PopScope] / [PopEntry] observe the lock before Android SAF starts.
  static Future<void> _awaitWorkspacePopGuard() async {
    FileFinalTrace.stage(
      'POP_GUARD_FLUSH',
      extra: 'blocksPop=$blocksWorkspacePop',
    );
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame;
  }

  static void _ensureLifecycleObserver() {
    if (_observerAttached) {
      return;
    }
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(_lifecycleGuard);
    _observerAttached = true;
  }

  static void _onLifecycle(AppLifecycleState state) {
    _lifecycle = state;
    if (state != AppLifecycleState.resumed) {
      return;
    }
    if (!_releaseSettlingWhenResumed || !fileAttachSettling) {
      return;
    }
    final generation = _attachGeneration;
    // Resume frame completes first (navigation settles), then release at the
    // start of the following frame so PopScope rebuilds with canPop:true.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _attachGeneration) {
        return;
      }
      if (_lifecycle != AppLifecycleState.resumed) {
        return;
      }
      WidgetsBinding.instance.scheduleFrameCallback((_) {
        if (generation != _attachGeneration) {
          return;
        }
        if (_lifecycle != AppLifecycleState.resumed) {
          return;
        }
        _clearSettling();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  /// Commits [media] to [lockedIncidentId] / expected incident.
  static Future<bool> persistSelected(
    CapturedMediaFile media, {
    BuildContext? context,
    WorkspaceCaptureMode persistMode = WorkspaceCaptureMode.file,
    String? mimeType,
    String? lockedIncidentId,
    bool asOrganizeContext = false,
  }) async {
    final controller = WorkspaceSession.instance.controller;
    final incidentId = controller.currentIncident.id;
    final expected = lockedIncidentId ?? _incidentIdAtOpen;

    FileFinalTrace.stage(
      'PERSIST_START',
      mounted: context?.mounted,
      fileName: media.fileName,
      fileSize: media.fileSizeBytes,
      path: media.localPath,
      mimeType: mimeType,
      extra: 'persistMode=${persistMode.name}',
    );

    if (expected != null && expected.isNotEmpty && incidentId != expected) {
      FileFinalTrace.failure(
        'PERSIST_ABORT_INCIDENT_SWITCH',
        extra: 'was=$expected now=$incidentId',
      );
      return false;
    }

    try {
      final ctx = (context != null && context.mounted)
          ? context
          : appNavigatorKey.currentContext;

      if (ctx != null && ctx.mounted) {
        final dialogResult = await FileAttachmentPersist.persistWithProgress(
          context: ctx,
          controller: controller,
          media: media,
          persistMode: persistMode,
          mimeType: mimeType,
          asOrganizeContext: asOrganizeContext,
        );
        switch (dialogResult) {
          case FilePersistDialogResult.success:
            return _verifyIncidentBinding(expected ?? incidentId);
          case FilePersistDialogResult.failed:
            FileFinalTrace.failure('PERSIST_DIALOG_FAILED');
            return false;
          case FilePersistDialogResult.contextLost:
            FileFinalTrace.stage(
              'PERSIST_DIALOG_CONTEXT_LOST',
              result: 'FALLBACK_HEADLESS',
            );
        }
      } else {
        FileFinalTrace.stage(
          'PERSIST_NO_MOUNTED_CONTEXT',
          mounted: false,
          result: 'HEADLESS',
        );
      }

      await controller.preserveEvidenceWithMedia(
        mode: persistMode,
        media: media,
        mimeType: mimeType,
        uploadCoordinator: EvidenceUploadCoordinator.instance,
        asOrganizeContext: asOrganizeContext,
      );
      return _verifyIncidentBinding(expected ?? incidentId);
    } catch (error, stack) {
      FileFinalTrace.failure(
        'PERSIST_EXCEPTION',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Marks evidence created since [idsBefore] as Organize Added context.
  /// Safe after SAF unmount — uses the session controller, not widget State.
  static void markOrganizeCreatedSince(Set<String> idsBefore) {
    final controller = WorkspaceSession.instance.controller;
    for (final item in controller.currentIncident.evidence) {
      if (!idsBefore.contains(item.id)) {
        controller.registerOrganizeCreatedEvidence(item.id);
      }
    }
  }

  static bool _verifyIncidentBinding(String expectedIncidentId) {
    final live = WorkspaceSession.instance.controller.currentIncident.id;
    if (live != expectedIncidentId) {
      FileFinalTrace.failure(
        'EVIDENCE_BINDING_LIVE_MISMATCH',
        extra: 'expected=$expectedIncidentId live=$live',
      );
      return false;
    }
    final captured =
        WorkspaceSession.instance.controller.aggregate.store.capturedEvidence;
    final supporting =
        WorkspaceSession.instance.controller.aggregate.store.supportingEvidence;
    final lastCaptured = captured.isEmpty ? null : captured.last;
    final lastSupporting = supporting.isEmpty ? null : supporting.last;
    final lastId = lastCaptured?.incidentId ?? lastSupporting?.incidentId;
    if (lastId != null && lastId != expectedIncidentId) {
      FileFinalTrace.failure(
        'EVIDENCE_BINDING_ITEM_MISMATCH',
        extra: 'evidence.incidentId=$lastId expected=$expectedIncidentId',
      );
      return false;
    }
    FileFinalTrace.stage(
      'EVIDENCE_PERSIST',
      result: 'BINDING_OK',
      extra: 'incident=$expectedIncidentId',
    );
    return true;
  }

  /// Ensures Workspace for the locked / source incident without awaiting pop.
  ///
  /// Never opens a different incident. If the session moved away from
  /// [sourceIncidentId], restores that incident via [WorkspaceSession.openIncident]
  /// then pushes Workspace when it is not already visible.
  static Future<void> ensureWorkspaceVisible({
    required Widget Function() buildWorkspace,
    String? sourceIncidentId,
    bool restoreOrganize = false,
  }) async {
    final expected =
        (sourceIncidentId ??
                _incidentIdAtOpen ??
                FileFinalTrace.sourceIncidentId)
            ?.trim();
    var incidentId = WorkspaceSession.instance.controller.currentIncident.id;
    FileFinalTrace.stage(
      'WORKSPACE_ENSURE_START',
      extra:
          'visible=$workspaceRouteVisible expected=$expected '
          'restoreOrganize=$restoreOrganize',
    );

    if (expected != null && expected.isNotEmpty && incidentId != expected) {
      FileFinalTrace.failure(
        'WORKSPACE_ENSURE_INCIDENT_MISMATCH',
        extra: 'expected=$expected live=$incidentId',
      );
      final restored = await WorkspaceSession.instance.openIncident(expected);
      incidentId = WorkspaceSession.instance.controller.currentIncident.id;
      if (!restored || incidentId != expected) {
        FileFinalTrace.failure(
          'WORKSPACE_ENSURE_SOURCE_RESTORE_FAILED',
          extra: 'expected=$expected live=$incidentId',
        );
        return;
      }
      FileFinalTrace.stage(
        'WORKSPACE_ENSURE_SOURCE_RESTORED',
        extra: 'incident=$expected',
      );
    }

    if (workspaceRouteVisible) {
      if (restoreOrganize) {
        WorkspaceSession.instance.enterEvidenceEditing();
      }
      FileFinalTrace.stage('WORKSPACE_VISIBLE', result: 'ALREADY');
      return;
    }

    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      FileFinalTrace.failure('WORKSPACE_ENSURE_NAVIGATOR_NULL');
      return;
    }

    final session = WorkspaceSession.instance;
    session.resumeTarget = WorkspaceResumeTarget.incidentWorkspace;
    if (restoreOrganize) {
      session.enterEvidenceEditing();
    } else {
      session.enterCapture();
    }
    FileFinalTrace.stage('WORKSPACE_PUSH', result: 'PUSHING');
    // Intentionally not awaited — push completes only on pop.
    nav.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: restoreOrganize
              ? 'IncidentWorkspaceShell'
              : 'ContinuousCaptureScreen',
        ),
        builder: (_) => buildWorkspace(),
      ),
    );
    FileFinalTrace.stage('WORKSPACE_VISIBLE', result: 'PUSHED');
  }

  static Future<void> ensureWorkspaceVisibleThenEnd({
    required Widget Function() buildWorkspace,
    String? sourceIncidentId,
  }) async {
    try {
      await ensureWorkspaceVisible(
        buildWorkspace: buildWorkspace,
        sourceIncidentId: sourceIncidentId,
      );
    } finally {
      _scheduleEndAttach();
    }
  }
}

class _FileAttachLifecycleGuard with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    FileAttachFlow._onLifecycle(state);
  }
}
