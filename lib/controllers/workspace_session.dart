import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../controllers/reconstruction_canvas_controller.dart';
import '../domain/incident/incident_aggregate.dart';
import '../models/investigation_canvas_state.dart';
import '../models/investigation_methodology_stage.dart';
import '../models/investigation_workspace_tab.dart';
import '../models/library_incident_summary.dart';
import '../models/workspace_resume_target.dart';
import '../repositories/narrative_event_repository.dart';
import '../repositories/reconstruction_repository.dart';
import '../repositories/timeline_repository.dart';
import '../services/persistence/incident_cloud_sync_service.dart';
import '../services/persistence/incident_library_service.dart';
import '../services/persistence/local_incident_pointer.dart';
import '../services/capture/capture_session_manager.dart';
import '../domain/capture/capture_session_status.dart';
import '../services/storage/local_evidence_cache.dart';
import '../services/storage/local_evidence_hydrator.dart';
import '../services/sync/evidence_sync_manager.dart';
import '../services/user_session_service.dart';
import '../diagnostics/sprint6c_file_trace.dart';
import 'workspace_evidence_controller.dart';

/// Holds the active incident working set shared between Home and Workspace.
///
/// Subordinate to [IncidentWorkspaceShell.boundIncidentId] for any visible
/// workspace route. This session must not override a shell's bound identity.
///
/// Lives above individual routes so quick capture from Home and subsequent
/// workspace visits append to the same Incident Journey.
///
/// Sprint 4B: restores the active incident + evidence from Firestore on sign-in.
class WorkspaceSession extends ChangeNotifier {
  WorkspaceSession._();

  static final WorkspaceSession instance = WorkspaceSession._();

  WorkspaceEvidenceController controller = WorkspaceEvidenceController();

  InvestigationMethodologyStage activeMethodologyStage =
      InvestigationMethodologyStage.capture;

  InvestigationWorkspaceTab activeInvestigationTab =
      InvestigationWorkspaceTab.timeline;

  WorkspaceResumeTarget resumeTarget = WorkspaceResumeTarget.incidentWorkspace;

  InvestigationCanvasController? investigationCanvasController;

  bool _notifyPending = false;
  bool _restored = false;
  bool _restoring = false;

  /// Bumped on each Library open so stale async hydrate/enrich cannot land on
  /// a newer selected incidentId.
  int _openGeneration = 0;

  Future<void>? _pendingOpenWork;

  /// Completes local hydrate started by [openIncident].
  ///
  /// Callers that need the working-set projection (e.g. Organize Readiness
  /// entry routing) wait here. Does not await cloud enrich.
  Future<void> ensureLocalHydrateSettled() async {
    final pending = _pendingOpenWork;
    if (pending != null) {
      await pending;
    }
  }

  /// Awaits background local hydrate started by [openIncident].
  @visibleForTesting
  Future<void> waitForPendingOpenWork() => ensureLocalHydrateSettled();

  /// True after a restore attempt completed (success or empty local fallback).
  bool get isCloudRestored => _restored;

  bool get isRestoring => _restoring;

  /// Loads the signed-in user's active incident + evidence from Firestore.
  Future<void> restoreForSignedInUser() async {
    if (_restored || _restoring) {
      Sprint6cFileTrace.session(
        'restoreForSignedInUser SKIP restored=$_restored restoring=$_restoring',
      );
      return;
    }
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _restored = true;
      notifyListeners();
      return;
    }

    Sprint6cFileTrace.session('restoreForSignedInUser START');
    _restoring = true;
    notifyListeners();
    try {
      final userId = UserSessionService.account?.userId ?? '';
      debugPrint('[Recovery] authenticated user=$userId');

      final aggregate =
          await IncidentCloudSyncService.instance.restoreActiveIncident();
      if (aggregate != null) {
        final cloudId = aggregate.store.incident.id;
        final remoteCount = aggregate.store.capturedEvidence.length +
            aggregate.store.supportingEvidence.length;
        final localCacheCount =
            (await LocalEvidenceCache.forIncident(cloudId, userId: userId))
                .length;
        final localCount = controller.currentIncident.evidenceCount;

        debugPrint(
          '[Recovery] cloud active incident=$cloudId '
          'remoteCount=$remoteCount localCacheCount=$localCacheCount',
        );

        // Never wipe richer local captures with a sparser cloud snapshot.
        if (localCount > remoteCount &&
            controller.currentIncident.id == cloudId) {
          debugPrint(
            '[Session] restore kept richer local aggregate '
            '(local=$localCount remote=$remoteCount)',
          );
          unawaited(
            IncidentCloudSyncService.instance
                .persistAggregate(controller.aggregate),
          );
        } else if (localCount > 0 &&
            controller.currentIncident.id != cloudId) {
          debugPrint(
            '[Session] restore kept local draft '
            '${controller.currentIncident.id} with $localCount evidence',
          );
          unawaited(
            IncidentCloudSyncService.instance
                .persistAggregate(controller.aggregate),
          );
        } else if (remoteCount == 0 && localCacheCount == 0) {
          // Cloud "active" is empty — recover last capture incident instead of
          // binding Workspace to a blank draft.
          final recovered = await _resolveRecoverableIncidentId(userId);
          if (recovered != null && recovered != cloudId) {
            debugPrint(
              '[Recovery] empty cloud active; opening recovered=$recovered',
            );
            // Never fall back to another incident's title (identity isolation).
            final title = await _resolvedTitleForIncident(
              userId: userId,
              incidentId: recovered,
            );
            debugPrint('[Recovery] title=$title');
            controller.replaceAggregate(
              IncidentAggregate.shell(id: recovered, title: title),
            );
          } else {
            controller.replaceAggregate(aggregate);
            await _applyRememberedTitleIfNeeded(
              userId: userId,
              incidentId: cloudId,
            );
          }
        } else {
          controller.replaceAggregate(aggregate);
          await _applyRememberedTitleIfNeeded(
            userId: userId,
            incidentId: cloudId,
          );
        }
      } else {
        // Do NOT seed an empty post-logout draft as the cloud active incident.
        final recovered = await _resolveRecoverableIncidentId(userId);
        if (recovered != null) {
          debugPrint(
            '[Recovery] no cloud active; opening recovered=$recovered',
          );
          final title = await _resolvedTitleForIncident(
            userId: userId,
            incidentId: recovered,
          );
          debugPrint('[Recovery] title=$title');
          controller.replaceAggregate(
            IncidentAggregate.shell(id: recovered, title: title),
          );
        } else {
          debugPrint(
            '[Recovery] no recoverable local incident — '
            'keeping empty working set (no cloud seed)',
          );
        }
      }
      await _hydrateLocalCacheAndStartSync();
      _restored = true;
    } catch (error) {
      debugPrint('[Session] restore failed: $error');
      _restored = true;
    } finally {
      _restoring = false;
      notifyListeners();
      unawaited(IncidentLibraryService.instance.refresh());
    }
  }

  /// Flushes local identity + cloud write-through while the user is still
  /// authenticated. Call from [AuthenticationService.signOut] before clearing
  /// [UserSessionService].
  Future<void> flushBeforeSignOut() async {
    final userId = UserSessionService.account?.userId ?? '';
    final incidentId = controller.currentIncident.id;
    final title = controller.currentIncident.title;
    final count = controller.currentIncident.evidenceCount;
    final sessionId =
        CaptureSessionManager.instance.getOpenSession(incidentId)?.id ??
            CaptureSessionManager.instance.getActiveSession(incidentId)?.id;
    final trimmedTitle = title.trim();
    if (userId.isNotEmpty && incidentId.isNotEmpty && count > 0) {
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: incidentId,
        // Empty title must not wipe a durable per-incident remembered title.
        title: trimmedTitle.isEmpty ? null : trimmedTitle,
        captureSessionId: sessionId,
      );
      try {
        await IncidentCloudSyncService.instance
            .persistAggregate(controller.aggregate);
      } catch (error) {
        debugPrint('[Recovery] pre-sign-out persist failed: $error');
      }
    } else if (userId.isNotEmpty &&
        incidentId.isNotEmpty &&
        trimmedTitle.isNotEmpty) {
      // Named draft with no evidence yet — still keep identity for recovery.
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: incidentId,
        title: trimmedTitle,
        captureSessionId: sessionId,
      );
    }
  }

  Future<String?> _resolveRecoverableIncidentId(String userId) async {
    final remembered = await LocalIncidentPointer.recall(userId);
    if (remembered != null) {
      final cached =
          await LocalEvidenceCache.forIncident(remembered, userId: userId);
      if (cached.isNotEmpty) {
        return remembered;
      }
      // Named incident with pointer but empty cache still recovers identity.
      // Must be THIS incident's title — never the global/user-scoped slot alone.
      final title = await LocalIncidentPointer.recallTitleForIncident(
        userId: userId,
        incidentId: remembered,
      );
      if (title != null && title.isNotEmpty) {
        return remembered;
      }
    }
    final richest =
        await LocalEvidenceCache.richestIncidentId(userId: userId);
    if (richest != null) {
      return richest;
    }
    LibraryIncidentSummary? best;
    for (final summary in IncidentLibraryService.instance.summaries) {
      if (!summary.isInProgress) {
        continue;
      }
      if (best == null || summary.evidenceCount > best.evidenceCount) {
        best = summary;
      }
    }
    if (best != null && best.evidenceCount > 0) {
      return best.id;
    }
    return best?.id;
  }

  /// Resolves title for [incidentId] only — never borrows another incident.
  ///
  /// Sources (in order): incident-scoped local title, then Library row for the
  /// same id. Empty/Untitled when none exist.
  Future<String> _resolvedTitleForIncident({
    required String userId,
    required String incidentId,
  }) async {
    final remembered = await LocalIncidentPointer.recallTitleForIncident(
      userId: userId,
      incidentId: incidentId,
    );
    if (remembered != null && remembered.isNotEmpty) {
      return remembered;
    }
    for (final s in IncidentLibraryService.instance.summaries) {
      if (s.id == incidentId && s.title.trim().isNotEmpty) {
        final t = s.title.trim();
        if (t != 'Untitled Incident') {
          return t;
        }
      }
    }
    // Empty — never borrow another incident's title / active aggregate title.
    return '';
  }

  /// Test seam for recovery title isolation (recoveredId != cloudId cases).
  @visibleForTesting
  Future<String> resolveTitleForIncidentForTests({
    required String userId,
    required String incidentId,
  }) {
    return _resolvedTitleForIncident(
      userId: userId,
      incidentId: incidentId,
    );
  }

  /// Applies locally remembered title when cloud/shell title is blank.
  ///
  /// Hard identity guard: only applies when the active incident id equals
  /// [incidentId]. Never copies another incident's title.
  Future<void> _applyRememberedTitleIfNeeded({
    required String userId,
    required String incidentId,
  }) async {
    if (controller.currentIncident.id != incidentId) {
      debugPrint(
        '[Recovery] skip remembered title — active='
        '${controller.currentIncident.id} target=$incidentId',
      );
      return;
    }
    final current = controller.currentIncident.title.trim();
    if (current.isNotEmpty && current != 'Untitled Incident') {
      return;
    }
    final remembered = await LocalIncidentPointer.recallTitleForIncident(
      userId: userId,
      incidentId: incidentId,
    );
    if (remembered == null || remembered.isEmpty) {
      return;
    }
    debugPrint(
      '[Recovery] applying remembered title="$remembered" to $incidentId',
    );
    controller.updateIncidentName(remembered);
  }

  /// Starts a brand-new capture incident (Home → Capture Now).
  ///
  /// Always a NEW immutable id with empty title — never inherits prior
  /// WorkspaceSession title, remembered title, or aggregate metadata.
  Future<void> beginNewCaptureIncident() async {
    final current = controller.currentIncident;
    if (current.evidenceCount > 0) {
      // Capture the prior aggregate before reset; cloud write is best-effort.
      final prior = controller.aggregate;
      unawaited(() async {
        try {
          await IncidentCloudSyncService.instance.persistAggregate(prior);
        } catch (error) {
          debugPrint('[Session] pre-new-incident persist failed: $error');
        }
      }());
    }
    final priorId = current.id;
    controller.resetToEmpty();
    final created = controller.currentIncident;
    // Identity invariant: new id, empty title, no prior metadata.
    assert(created.id != priorId || priorId.isEmpty);
    assert(created.title.isEmpty);
    if (created.title.isNotEmpty) {
      controller.updateIncidentName('');
    }
    debugPrint(
      '[Recovery] created empty incident=${created.id} title="" '
      'prior=$priorId reason=beginNewCaptureIncident (explicit Capture Now)',
    );
    _resetNavigationState();
    enterCapture();
    notifyListeners();
    unawaited(IncidentLibraryService.instance.refresh());
  }

  /// Switches the active incident to [incidentId].
  ///
  /// Returns `true` when the session is on [incidentId] and safe to open
  /// Workspace. Returns `false` when restore failed — callers must not
  /// navigate (avoids blank Workspace).
  Future<bool> openIncident(String incidentId) async {
    // Library opens by immutable id — title is irrelevant. Empty ids are never
    // openable (Untitled cards must still carry a real persisted id).
    final targetId = incidentId.trim();
    if (targetId.isEmpty) {
      debugPrint('[Session] openIncident rejected — empty incidentId');
      return false;
    }

    // Wait out an in-flight restore instead of no-oping (blank Workspace risk).
    var spins = 0;
    while (_restoring && spins < 60) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      spins++;
    }
    if (_restoring) {
      debugPrint('[Session] openIncident aborted — restore still running');
      return controller.currentIncident.id == targetId;
    }

    final generation = ++_openGeneration;
    final current = controller.currentIncident;
    if (current.id == targetId) {
      // Same incident — navigate immediately; hydrate/enrich in background.
      resumeTarget = WorkspaceResumeTarget.incidentWorkspace;
      notifyListeners();
      final work = _finishOpenIncidentLocalWork(
        targetId: targetId,
        generation: generation,
        applyRememberedTitle: true,
      );
      _pendingOpenWork = work;
      unawaited(work);
      return true;
    }

    // Local-first: never block Library → Workspace on Firebase write-through.
    if (current.evidenceCount > 0) {
      final prior = controller.aggregate;
      unawaited(() async {
        try {
          await IncidentCloudSyncService.instance.persistAggregate(prior);
        } catch (error) {
          debugPrint('[Session] pre-switch persist failed: $error');
        }
      }());
    }

    // Resolve local title + shell only — do NOT await cloud or full hydrate
    // before callers can push Workspace.
    _restoring = true;
    notifyListeners();
    var opened = false;
    try {
      final userId = UserSessionService.account?.userId ?? '';
      final title = await _resolvedTitleForIncident(
        userId: userId,
        incidentId: targetId,
      );
      if (_openGeneration != generation) {
        return false;
      }
      debugPrint(
        '[Session] openIncident local-first shell id=$targetId title=$title',
      );
      controller.replaceAggregate(
        IncidentAggregate.shell(id: targetId, title: title),
      );
      _resetNavigationState(preserveMethodologyStage: false);
      resumeTarget = WorkspaceResumeTarget.incidentWorkspace;
      opened = true;
      _restored = true;
    } catch (error) {
      debugPrint('[Session] openIncident local open failed: $error');
    } finally {
      _restoring = false;
      notifyListeners();
    }

    if (opened && controller.currentIncident.id == targetId) {
      final work = _finishOpenIncidentLocalWork(
        targetId: targetId,
        generation: generation,
        applyRememberedTitle: true,
      );
      _pendingOpenWork = work;
      unawaited(work);
      return true;
    }
    return false;
  }

  /// Local hydrate + optional title + cloud enrich after Workspace can navigate.
  Future<void> _finishOpenIncidentLocalWork({
    required String targetId,
    required int generation,
    required bool applyRememberedTitle,
  }) async {
    try {
      await _hydrateLocalCacheAndStartSync();
      if (_openGeneration != generation ||
          controller.currentIncident.id != targetId) {
        return;
      }
      if (applyRememberedTitle) {
        final uid = UserSessionService.account?.userId ?? '';
        await _applyRememberedTitleIfNeeded(
          userId: uid,
          incidentId: targetId,
        );
      }
      if (_openGeneration != generation ||
          controller.currentIncident.id != targetId) {
        return;
      }
      notifyListeners();
      // Cloud restore is secondary: never invent or copy evidence, and never
      // keep Library / Vault navigation waiting on Firestore.
      unawaited(_enrichOpenIncidentFromCloud(targetId, generation));
      unawaited(IncidentLibraryService.instance.refresh());
    } catch (error) {
      debugPrint('[Session] finish open local work failed: $error');
    }
  }

  /// Background cloud hydrate after local Workspace open — must not block nav.
  Future<void> _enrichOpenIncidentFromCloud(
    String targetId,
    int generation,
  ) async {
    try {
      final aggregate =
          await IncidentCloudSyncService.instance.restoreIncident(targetId);
      if (aggregate == null) {
        return;
      }
      // Still on the same Library selection?
      if (_openGeneration != generation ||
          controller.currentIncident.id != targetId) {
        return;
      }
      final restoredId = aggregate.store.incident.id.trim().isEmpty
          ? targetId
          : aggregate.store.incident.id;
      if (restoredId != targetId) {
        debugPrint(
          '[Session] cloud enrich id mismatch requested=$targetId '
          'restored=$restoredId — ignored',
        );
        return;
      }
      final localCount = controller.currentIncident.evidenceCount;
      final remoteCount = aggregate.store.capturedEvidence.length +
          aggregate.store.supportingEvidence.length;
      if (remoteCount > localCount) {
        controller.replaceAggregate(aggregate);
        await _hydrateLocalCacheAndStartSync();
        if (_openGeneration != generation ||
            controller.currentIncident.id != targetId) {
          return;
        }
        notifyListeners();
        debugPrint(
          '[Session] cloud enrich applied for $targetId '
          'local=$localCount remote=$remoteCount',
        );
      }
    } catch (error) {
      debugPrint('[Session] cloud enrich failed: $error');
    }
  }

  /// Clears restore flags on sign-out. Keeps [LocalEvidenceCache] intact so
  /// the same user can reconstruct evidence after re-authentication.
  ///
  /// Prefer [flushBeforeSignOut] while the user is still authenticated.
  void onSignedOut() {
    Sprint6cFileTrace.session(
      'onSignedOut → clearInvestigation + _restored=false '
      'incidentWas=${controller.currentIncident.id}',
    );
    _restored = false;
    // Soft clear working set — durable cache + LocalIncidentPointer survive.
    clearInvestigation();
  }

  /// Soft-abandons a speculative Capture Now draft that never received evidence.
  ///
  /// Completes any open capture session for the empty incident. Does not delete
  /// evidence (none exists) and does not touch other incidents.
  Future<void> abandonEmptyCaptureNow() async {
    final incident = controller.currentIncident;
    if (incident.evidenceCount > 0) {
      return;
    }
    final open = CaptureSessionManager.instance.getOpenSession(incident.id) ??
        CaptureSessionManager.instance.getActiveSession(incident.id);
    if (open == null) {
      return;
    }
    if (open.status == CaptureSessionStatus.completed ||
        open.status == CaptureSessionStatus.archived) {
      return;
    }
    try {
      await CaptureSessionManager.instance.completeSession(sessionId: open.id);
    } catch (error) {
      debugPrint('[Session] abandonEmptyCaptureNow failed: $error');
    }
  }

  void setActiveStage(
    InvestigationMethodologyStage stage, {
    InvestigationWorkspaceTab? investigationTab,
  }) {
    activeMethodologyStage = stage;
    if (investigationTab != null) {
      activeInvestigationTab = investigationTab;
    } else if (stage == InvestigationMethodologyStage.investigation) {
      activeInvestigationTab = InvestigationWorkspaceTab.timeline;
    }
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyPending) {
      return;
    }
    _notifyPending = true;
    scheduleMicrotask(() {
      _notifyPending = false;
      notifyListeners();
    });
  }

  void enterCapture() {
    setActiveStage(InvestigationMethodologyStage.capture);
    resumeTarget = WorkspaceResumeTarget.incidentWorkspace;
  }

  void enterEvidenceEditing() {
    setActiveStage(InvestigationMethodologyStage.evidence);
  }

  InvestigationCanvasController obtainInvestigationCanvasController({
    InvestigationWorkspaceTab? initialTab,
  }) {
    final tab = initialTab ?? activeInvestigationTab;
    investigationCanvasController ??= InvestigationCanvasController(
      initialState: InvestigationCanvasState(activeTab: tab),
    );

    if (investigationCanvasController!.state.activeTab != tab) {
      scheduleMicrotask(
        () => investigationCanvasController!.setActiveTab(tab),
      );
    }

    return investigationCanvasController!;
  }

  /// Resets canvas selection and optionally the methodology stage.
  ///
  /// Incident switch / shell hydrate must not keep another incident's
  /// methodology stage — Home actions set the destination explicitly.
  /// Capture Now / sign-out / test reset still clear the stage.
  void _resetNavigationState({bool preserveMethodologyStage = false}) {
    // Reset canvas selection in place — never dispose while IndexedStack /
    // InvestigationWorkspaceScreen may still be listening.
    investigationCanvasController?.clearSelectionsAndReturnToTimeline();
    if (!preserveMethodologyStage) {
      activeMethodologyStage = InvestigationMethodologyStage.capture;
      activeInvestigationTab = InvestigationWorkspaceTab.timeline;
    }
    resumeTarget = WorkspaceResumeTarget.incidentWorkspace;
  }

  /// Merges durable local evidence into the working repository and starts
  /// background sync (Firebase is destination — local cache is temporary SoT).
  Future<void> _hydrateLocalCacheAndStartSync() async {
    final isFlutterTest =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    if (!isFlutterTest) {
      final sync = EvidenceSyncManager.instance;
      sync.onUploadSucceeded = (entry, result) {
        final active = controller;
        if (active.currentIncident.id != entry.incidentId) {
          return;
        }
        if (!active.evidenceRepository.containsEvidenceId(entry.evidenceId)) {
          active.evidenceRepository.upsertFromLocalCache(entry);
        }
        active.completeCaptureUpload(
          evidenceId: entry.evidenceId,
          storagePath: result.storagePath,
          downloadUrl: result.downloadUrl,
          mimeType: result.contentType,
          fileSizeBytes: result.fileSize,
          thumbnailUrl: result.thumbnailUrl,
        );
      };
      sync.onUploadFailed = (evidenceId) {
        if (controller.evidenceRepository.containsEvidenceId(evidenceId)) {
          controller.failCaptureUpload(evidenceId);
        }
      };
      sync.onLifecycleChanged = (evidenceId, status) {
        if (!controller.evidenceRepository.containsEvidenceId(evidenceId)) {
          return;
        }
        controller.updateLifecycleStatus(
          evidenceId: evidenceId,
          status: status,
          force: true,
        );
      };
    }

    final incidentId = controller.currentIncident.id;
    final userId = UserSessionService.account?.userId ?? '';
    debugPrint('[Recovery] opening incident=$incidentId');
    debugPrint(
      '[Recovery] title=${controller.currentIncident.title}',
    );
    final localBefore =
        await LocalEvidenceCache.forIncident(incidentId, userId: userId);
    // Drop stale hydrate if Library selected a different incident mid-await.
    if (controller.currentIncident.id != incidentId) {
      return;
    }
    debugPrint(
      '[Recovery] local evidence count=${localBefore.length}',
    );

    final inserted = await LocalEvidenceHydrator.hydrateIncident(
      incidentId: incidentId,
      repository: controller.evidenceRepository,
      userId: userId,
    );
    if (controller.currentIncident.id != incidentId) {
      return;
    }
    debugPrint(
      '[Recovery] hydrated evidence count=$inserted incident=$incidentId',
    );
    await controller.restoreOrganizeContextPersistence();
    if (controller.currentIncident.id != incidentId) {
      return;
    }
    await CaptureSessionManager.instance.restoreForIncident(
      incidentId: incidentId,
      userId: userId,
    );
    if (controller.currentIncident.id != incidentId) {
      return;
    }
    await _applyRememberedTitleIfNeeded(
      userId: userId,
      incidentId: incidentId,
    );
    if (controller.currentIncident.id != incidentId) {
      return;
    }
    if (inserted > 0) {
      controller.scheduleCaptureMetadataPersist();
      notifyListeners();
    }
    debugPrint(
      '[Recovery] working set incident=${controller.currentIncident.id} '
      'count=${controller.currentIncident.evidenceCount} '
      'ids=${[
        for (final item in controller.currentIncident.evidence) item.id,
      ]}',
    );
    if (userId.isNotEmpty &&
        (inserted > 0 || controller.currentIncident.evidenceCount > 0)) {
      final title = controller.currentIncident.title.trim();
      unawaited(
        LocalIncidentPointer.remember(
          userId: userId,
          incidentId: incidentId,
          // Do not overwrite a durable per-incident title with blank.
          title: title.isEmpty ? null : title,
          captureSessionId:
              CaptureSessionManager.instance.getOpenSession(incidentId)?.id,
        ),
      );
    }
    if (!isFlutterTest) {
      unawaited(EvidenceSyncManager.instance.start());
    }
  }

  /// Clears the active incident session — for widget tests only.
  void reset() {
    CaptureSessionManager.instance.clearMemory();
    controller.resetToEmpty();
    _restored = false;
    _pendingOpenWork = null;
    _openGeneration++;
    _resetNavigationState();
    notifyListeners();
  }

  /// Replaces the active investigation with a fresh empty incident.
  void clearInvestigation() {
    Sprint6cFileTrace.session(
      'clearInvestigation was=${controller.currentIncident.id}',
    );
    CaptureSessionManager.instance.clearMemory();
    controller.resetToEmpty();
    assert(
      controller.currentIncident.title.isEmpty,
      'clearInvestigation must yield empty title',
    );
    InMemoryNarrativeEventRepository.resetForTests();
    InMemoryTimelineRepository.resetForTests();
    InMemoryReconstructionRepository.resetForTests();
    _resetNavigationState();
    notifyListeners();
  }
}
