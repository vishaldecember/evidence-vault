import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../domain/evidence/evidence_record_type.dart';
import '../../domain/evidence/evidence_sync_status.dart';
import '../../models/workspace_capture_mode.dart';
import '../storage/cached_evidence_entry.dart';
import '../storage/capture_media_service.dart';
import '../storage/evidence_upload_coordinator.dart';
import '../storage/local_evidence_cache.dart';
import '../storage/storage_upload_result.dart';
import '../user_session_service.dart';
import 'evidence_sync_queue.dart';
import 'evidence_upload_worker.dart';

/// Called when background sync finishes an upload for an evidence id.
typedef EvidenceSyncUploadSucceeded = void Function(
  CachedEvidenceEntry entry,
  StorageUploadResult result,
);

/// Called when background sync fails an upload.
typedef EvidenceSyncUploadFailed = void Function(String evidenceId);

/// Called when cache lifecycle changes (workspace mirror).
typedef EvidenceSyncLifecycleChanged = void Function(
  String evidenceId,
  EvidenceSyncStatus status,
);

/// Central dual-lane sync coordinator (Sprint 6B Task 3).
///
/// ```
/// EvidenceRepository
///        ↓
/// EvidenceSyncManager
///     /        \
/// FAST_SYNC   INTELLIGENCE
/// Upload workers   Processing workers
///        ↓
/// Firebase Storage + Firestore
/// ```
///
/// Local cache is the immediate source of truth. Firebase is destination only.
/// UI must never await this manager.
class EvidenceSyncManager extends ChangeNotifier {
  EvidenceSyncManager({
    EvidenceSyncQueue? queue,
    EvidenceUploadCoordinator? uploadCoordinator,
    Connectivity? connectivity,
    int maxConcurrentUploads = defaultMaxConcurrentUploads,
    EvidenceSyncUploadFn? uploadFn,
    this.enableDebugLogging = kDebugMode,
  })  : _queue = queue ?? EvidenceSyncQueue(),
        _uploadCoordinator =
            uploadCoordinator ?? EvidenceUploadCoordinator.instance,
        _connectivity = connectivity ?? Connectivity() {
    _maxConcurrentUploads = maxConcurrentUploads;
    _uploadFn = uploadFn;
    _rebuildWorkers();
  }

  static const int defaultMaxConcurrentUploads = 2;
  static const int maxRetryAttempts = 8;

  static final EvidenceSyncManager instance = EvidenceSyncManager();

  final EvidenceSyncQueue _queue;
  final EvidenceUploadCoordinator _uploadCoordinator;
  final Connectivity _connectivity;
  final bool enableDebugLogging;

  EvidenceSyncUploadFn? _uploadFn;
  late int _maxConcurrentUploads;
  List<EvidenceUploadWorker> _workers = [];

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _backoffTimer;
  bool _started = false;
  bool _schedulingFast = false;
  bool _schedulingIntel = false;
  bool _online = true;

  /// Evidence IDs currently held by a FAST_SYNC worker (duplicate protection).
  final Set<String> _inFlightFast = {};

  /// Evidence IDs currently held by an intelligence worker.
  final Set<String> _inFlightIntel = {};

  /// Optional workspace bridge — set by [WorkspaceSession] (avoids import cycles).
  EvidenceSyncUploadSucceeded? onUploadSucceeded;
  EvidenceSyncUploadFailed? onUploadFailed;
  EvidenceSyncLifecycleChanged? onLifecycleChanged;

  EvidenceSyncQueue get queue => _queue;

  int get maxConcurrentUploads => _maxConcurrentUploads;

  List<EvidenceUploadWorker> get workers =>
      List<EvidenceUploadWorker>.unmodifiable(_workers);

  int get activeUploadCount => _inFlightFast.length;

  /// Updates concurrency (WiFi / mobile / offline tuning later).
  void setMaxConcurrentUploads(int value) {
    _maxConcurrentUploads = value.clamp(0, 16);
    _rebuildWorkers();
    unawaited(schedule());
  }

  void _rebuildWorkers() {
    final next = <EvidenceUploadWorker>[];
    for (var i = 0; i < _maxConcurrentUploads; i++) {
      if (i < _workers.length) {
        next.add(_workers[i]);
      } else {
        next.add(EvidenceUploadWorker(id: i + 1));
      }
    }
    _workers = next;
  }

  void _log(String message) {
    if (enableDebugLogging) {
      debugPrint('[Sync] $message');
    }
  }

  /// Exponential backoff: 2s, 4s, 8s… capped at 60s.
  @visibleForTesting
  static Duration backoffForAttempt(int attempts) {
    final capped = math.min(attempts, 6);
    final seconds = math.min(60, 2 * math.pow(2, math.max(0, capped - 1))).toInt();
    return Duration(seconds: seconds);
  }

  /// Loads durable queues + pending cache rows and starts worker scheduling.
  Future<void> start() async {
    if (_started) {
      unawaited(schedule());
      return;
    }
    _started = true;
    await _queue.restore();
    await _requeuePendingFromCache();
    // Probe before assuming online — airplane mode must not start Storage work.
    await _probeConnectivity();
    _listenConnectivity();
    unawaited(schedule());
  }

  Future<void> _probeConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _online = results.any(
        (result) => result != ConnectivityResult.none,
      );
      _log('connectivity probe online=$_online');
    } catch (error) {
      // Fail closed for uploads — local capture must stay unblocked.
      _online = false;
      _log('connectivity probe failed: $error');
    }
  }

  void _listenConnectivity() {
    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (results) {
          final online = results.any(
            (result) => result != ConnectivityResult.none,
          );
          _online = online;
          if (online) {
            unawaited(schedule());
          }
        },
        onError: (Object error) {
          _log('connectivity error: $error');
        },
      );
    } catch (error) {
      _log('connectivity unavailable: $error');
    }
  }

  /// After capture: persist locally then enqueue FAST_SYNC (HIGH).
  ///
  /// Returns after local upsert + enqueue — never waits on Firebase.
  Future<void> registerLocalCapture({
    required String evidenceId,
    required String incidentId,
    required EvidenceRecordType evidenceType,
    required DateTime capturedAt,
    WorkspaceCaptureMode? mode,
    CapturedMediaFile? media,
    String? hash,
    Map<String, String> metadata = const {},
    String? noteText,
    String? mimeType,
    String? parentEvidenceId,
    String? captureSessionId,
    bool kickDrain = true,
  }) async {
    final userId = UserSessionService.account?.userId ?? '';
    final now = capturedAt.toUtc();
    final mergedMeta = <String, String>{
      ...metadata,
      if (noteText != null && noteText.isNotEmpty) 'noteText': noteText,
      if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
      if (captureSessionId != null && captureSessionId.isNotEmpty)
        'captureSessionId': captureSessionId,
    };
    final entry = CachedEvidenceEntry(
      evidenceId: evidenceId,
      incidentId: incidentId,
      userId: userId,
      evidenceType: evidenceType,
      localFilePath: media?.localPath,
      thumbnailPath: media?.thumbnailPath,
      createdAt: now,
      capturedAt: capturedAt,
      syncStatus: EvidenceSyncStatus.localCaptured,
      uploadProgress: 0,
      retryCount: 0,
      hash: hash,
      metadata: mergedMeta,
      captureMode: mode,
      fileName: media?.fileName,
      fileSizeBytes: media?.fileSizeBytes,
      noteText: noteText,
      mimeType: mimeType ?? mergedMeta['mimeType'],
      parentEvidenceId: parentEvidenceId,
      captureSessionId:
          captureSessionId ?? mergedMeta['captureSessionId'],
    );
    await LocalEvidenceCache.upsert(entry);

    await LocalEvidenceCache.updateStatus(
      evidenceId: evidenceId,
      syncStatus: EvidenceSyncStatus.queuedForUpload,
    );
    onLifecycleChanged?.call(
      evidenceId,
      EvidenceSyncStatus.queuedForUpload,
    );

    await _queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: evidenceId,
        incidentId: incidentId,
        userId: userId,
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: mode,
        localFilePath: media?.localPath,
      ),
    );
    _log('queued evidence=$evidenceId');
    notifyListeners();
    if (kickDrain) {
      unawaited(schedule());
    }
  }

  /// Enqueues INTELLIGENCE lane (NORMAL) — never blocks FAST_SYNC workers.
  Future<void> enqueueIntelligence({
    required String evidenceId,
    required String incidentId,
    String? userId,
    bool kickDrain = true,
  }) async {
    final ownerUserId = userId ??
        (await LocalEvidenceCache.byId(evidenceId))?.userId ??
        UserSessionService.account?.userId ??
        '';
    await _queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: evidenceId,
        incidentId: incidentId,
        userId: ownerUserId,
        lane: EvidenceSyncLane.intelligence,
        priority: SyncWorkPriority.normal,
        enqueuedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    if (kickDrain) {
      unawaited(schedule());
    }
  }

  /// CaptureEngine success path — mark READY, drop FAST_SYNC, enqueue intel.
  Future<void> markSyncedFromCapturePipeline({
    required String evidenceId,
    required String incidentId,
    String? cloudPath,
    String? downloadUrl,
  }) async {
    await LocalEvidenceCache.updateStatus(
      evidenceId: evidenceId,
      syncStatus: EvidenceSyncStatus.ready,
      uploadProgress: 1,
      cloudPath: cloudPath,
      downloadUrl: downloadUrl,
    );
    _inFlightFast.remove(evidenceId);
    await _queue.remove(evidenceId);
    await enqueueIntelligence(
      evidenceId: evidenceId,
      incidentId: incidentId,
      userId: (await LocalEvidenceCache.byId(evidenceId))?.userId,
    );
  }

  Future<void> markFailedFromCapturePipeline(String evidenceId) async {
    final cached = await LocalEvidenceCache.byId(evidenceId);
    final retry = (cached?.retryCount ?? 0) + 1;
    await LocalEvidenceCache.updateStatus(
      evidenceId: evidenceId,
      syncStatus: EvidenceSyncStatus.failed,
      retryCount: retry,
    );
    final delay = backoffForAttempt(retry);
    await _queue.bumpAttempt(
      evidenceId,
      nextAttemptAt: DateTime.now().add(delay),
    );
    _scheduleBackoffWake(delay);
    notifyListeners();
  }

  Future<void> markUploading(String evidenceId) async {
    await LocalEvidenceCache.updateStatus(
      evidenceId: evidenceId,
      syncStatus: EvidenceSyncStatus.uploading,
      uploadProgress: 0.05,
    );
  }

  Future<void> _requeuePendingFromCache() async {
    final pending = await LocalEvidenceCache.pendingSync(
      userId: UserSessionService.account?.userId,
    );
    for (final entry in pending) {
      final alreadyQueued =
          _queue.items.any((item) => item.evidenceId == entry.evidenceId);
      if (alreadyQueued) {
        continue;
      }
      // Interrupted UPLOADING → re-queue as QUEUED_FOR_UPLOAD.
      if (entry.syncStatus == EvidenceSyncStatus.uploading) {
        await LocalEvidenceCache.updateStatus(
          evidenceId: entry.evidenceId,
          syncStatus: EvidenceSyncStatus.queuedForUpload,
        );
      }
      await _queue.enqueue(
        EvidenceSyncQueueItem(
          evidenceId: entry.evidenceId,
          incidentId: entry.incidentId,
          userId: entry.userId,
          lane: EvidenceSyncLane.fastSync,
          priority: SyncWorkPriority.high,
          enqueuedAt: DateTime.now(),
          mode: entry.captureMode,
          localFilePath: entry.localFilePath,
          attempts: entry.retryCount,
        ),
      );
      _log('recovered evidence=${entry.evidenceId} after restart');
    }
  }

  /// Schedules FAST_SYNC workers and INTELLIGENCE independently.
  Future<void> schedule() async {
    await _queue.restore();
    unawaited(_scheduleFastLane());
    unawaited(_scheduleIntelligenceLane());
  }

  /// Legacy alias — Task 2 call sites / tests.
  Future<void> drain() => schedule();

  Future<void> _scheduleFastLane() async {
    if (_schedulingFast) {
      return;
    }
    _schedulingFast = true;
    try {
      while (true) {
        if (!_online || _maxConcurrentUploads <= 0) {
          break;
        }
        final idle = _workers.where((worker) => worker.isIdle).toList();
        if (idle.isEmpty) {
          break;
        }
        final ownerUserId = UserSessionService.account?.userId ?? '';
        final next = _queue.peekLane(
          EvidenceSyncLane.fastSync,
          excludeIds: _inFlightFast,
          ownerUserId: ownerUserId,
        );
        if (next == null) {
          break;
        }
        final worker = idle.first;
        final taken = await _queue.takeLane(
          EvidenceSyncLane.fastSync,
          excludeIds: _inFlightFast,
          ownerUserId: ownerUserId,
        );
        if (taken == null) {
          break;
        }
        _inFlightFast.add(taken.evidenceId);
        worker.busy = true;
        worker.currentEvidenceId = taken.evidenceId;
        unawaited(_runFastWorker(worker, taken));
      }
    } finally {
      _schedulingFast = false;
    }
  }

  Future<void> _runFastWorker(
    EvidenceUploadWorker worker,
    EvidenceSyncQueueItem item,
  ) async {
    try {
      _log('worker=${worker.id} uploading evidence=${item.evidenceId}');
      final outcome = await _processFastSync(item);
      if (outcome == _FastSyncOutcome.ownershipRejected) {
        // Fail closed — restore the original row. Never remap user/incident.
        await _queue.enqueue(item);
      } else if (outcome == _FastSyncOutcome.retryableFailure) {
        // Independent failure — other workers continue; item re-queued w/ backoff.
        await _requeueFailed(item);
      } else {
        _log('synced evidence=${item.evidenceId}');
        // Intelligence must not block — enqueue async without awaiting lane.
        unawaited(
          enqueueIntelligence(
            evidenceId: item.evidenceId,
            incidentId: item.incidentId,
            userId: item.userId,
            kickDrain: true,
          ),
        );
      }
    } catch (error) {
      _log('failed evidence=${item.evidenceId} error=$error');
      await _requeueFailed(item);
    } finally {
      _inFlightFast.remove(item.evidenceId);
      worker.busy = false;
      worker.currentEvidenceId = null;
      notifyListeners();
      unawaited(_scheduleFastLane());
    }
  }

  Future<void> _requeueFailed(EvidenceSyncQueueItem item) async {
    final cached = await LocalEvidenceCache.byId(item.evidenceId);
    final retry = (cached?.retryCount ?? item.attempts) + 1;
    await LocalEvidenceCache.updateStatus(
      evidenceId: item.evidenceId,
      syncStatus: EvidenceSyncStatus.failed,
      retryCount: retry,
    );
    onUploadFailed?.call(item.evidenceId);
    onLifecycleChanged?.call(item.evidenceId, EvidenceSyncStatus.failed);

    if (retry > maxRetryAttempts) {
      _log('failed evidence=${item.evidenceId} retry=$retry (exhausted)');
      return;
    }

    final delay = backoffForAttempt(retry);
    _log('failed evidence=${item.evidenceId} retry=$retry');
    await LocalEvidenceCache.updateStatus(
      evidenceId: item.evidenceId,
      syncStatus: EvidenceSyncStatus.queuedForUpload,
    );
    await _queue.enqueue(
      item.copyWith(
        attempts: retry,
        nextAttemptAt: DateTime.now().add(delay),
        priority: SyncWorkPriority.high,
        lane: EvidenceSyncLane.fastSync,
      ),
    );
    _scheduleBackoffWake(delay);
  }

  void _scheduleBackoffWake(Duration delay) {
    _backoffTimer?.cancel();
    _backoffTimer = Timer(delay + const Duration(milliseconds: 50), () {
      unawaited(schedule());
    });
  }

  Future<_FastSyncOutcome> _processFastSync(EvidenceSyncQueueItem item) async {
    final currentUserId = UserSessionService.account?.userId ?? '';
    if (!item.isOwnedBy(currentUserId)) {
      _log(
        'ownership rejected evidence=${item.evidenceId} '
        'queueUser=${item.userId} currentUser=$currentUserId',
      );
      return _FastSyncOutcome.ownershipRejected;
    }

    final cached = await LocalEvidenceCache.byId(item.evidenceId);
    if (cached == null) {
      return _FastSyncOutcome.success; // orphan — drop
    }
    if (cached.incidentId != item.incidentId) {
      _log(
        'incident mismatch evidence=${item.evidenceId} '
        'queueIncident=${item.incidentId} cacheIncident=${cached.incidentId}',
      );
      return _FastSyncOutcome.ownershipRejected;
    }
    if (cached.userId.isNotEmpty && cached.userId != item.userId) {
      _log(
        'cache user mismatch evidence=${item.evidenceId} '
        'queueUser=${item.userId} cacheUser=${cached.userId}',
      );
      return _FastSyncOutcome.ownershipRejected;
    }

    // Idempotent: already cloud-durable — skip re-upload.
    if (cached.syncStatus == EvidenceSyncStatus.ready ||
        cached.syncStatus == EvidenceSyncStatus.synced ||
        cached.syncStatus == EvidenceSyncStatus.processing) {
      return _FastSyncOutcome.success;
    }
    if (cached.cloudPath != null &&
        cached.cloudPath!.isNotEmpty &&
        cached.downloadUrl != null &&
        cached.downloadUrl!.isNotEmpty) {
      await LocalEvidenceCache.updateStatus(
        evidenceId: item.evidenceId,
        syncStatus: EvidenceSyncStatus.ready,
        uploadProgress: 1,
      );
      onLifecycleChanged?.call(item.evidenceId, EvidenceSyncStatus.ready);
      return _FastSyncOutcome.success;
    }

    await LocalEvidenceCache.updateStatus(
      evidenceId: item.evidenceId,
      syncStatus: EvidenceSyncStatus.uploading,
      uploadProgress: 0.05,
    );
    onLifecycleChanged?.call(item.evidenceId, EvidenceSyncStatus.uploading);

    final mode = item.mode ?? cached.captureMode ?? WorkspaceCaptureMode.photo;
    final path = item.localFilePath ?? cached.localFilePath;

    // Notes / metadata-only — no binary upload.
    if (mode == WorkspaceCaptureMode.note) {
      await LocalEvidenceCache.updateStatus(
        evidenceId: item.evidenceId,
        syncStatus: EvidenceSyncStatus.synced,
        uploadProgress: 1,
      );
      await LocalEvidenceCache.updateStatus(
        evidenceId: item.evidenceId,
        syncStatus: EvidenceSyncStatus.ready,
      );
      onLifecycleChanged?.call(item.evidenceId, EvidenceSyncStatus.ready);
      return _FastSyncOutcome.success;
    }

    if (path == null || path.isEmpty) {
      return _FastSyncOutcome.retryableFailure;
    }

    final userId = UserSessionService.account?.userId;
    if ((_uploadFn == null) && (userId == null || userId.isEmpty)) {
      return _FastSyncOutcome.retryableFailure;
    }

    try {
      final result = _uploadFn != null
          ? await _uploadFn!(item)
          : await _uploadCoordinator.uploadCapturedMedia(
              evidenceId: item.evidenceId,
              incidentId: item.incidentId,
              localFilePath: path,
              mode: mode,
              ownerUserId: item.userId,
            );
      if (result == null) {
        return _FastSyncOutcome.retryableFailure;
      }

      // LOCAL files retained after SYNCED (Task 3 — no aggressive reclaim).
      await LocalEvidenceCache.updateStatus(
        evidenceId: item.evidenceId,
        syncStatus: EvidenceSyncStatus.synced,
        uploadProgress: 1,
        cloudPath: result.storagePath,
        downloadUrl: result.downloadUrl,
      );
      onLifecycleChanged?.call(item.evidenceId, EvidenceSyncStatus.synced);

      await LocalEvidenceCache.updateStatus(
        evidenceId: item.evidenceId,
        syncStatus: EvidenceSyncStatus.processing,
      );
      await LocalEvidenceCache.updateStatus(
        evidenceId: item.evidenceId,
        syncStatus: EvidenceSyncStatus.ready,
      );
      onLifecycleChanged?.call(item.evidenceId, EvidenceSyncStatus.ready);

      onUploadSucceeded?.call(
        (await LocalEvidenceCache.byId(item.evidenceId)) ?? cached,
        result,
      );
      return _FastSyncOutcome.success;
    } catch (error) {
      _log('upload exception evidence=${item.evidenceId}: $error');
      return _FastSyncOutcome.retryableFailure;
    }
  }

  Future<void> _scheduleIntelligenceLane() async {
    if (_schedulingIntel) {
      return;
    }
    _schedulingIntel = true;
    try {
      while (true) {
        final next = await _queue.takeLane(
          EvidenceSyncLane.intelligence,
          excludeIds: _inFlightIntel,
          ownerUserId: UserSessionService.account?.userId ?? '',
        );
        if (next == null) {
          break;
        }
        _inFlightIntel.add(next.evidenceId);
        try {
          await _processIntelligence(next);
        } finally {
          _inFlightIntel.remove(next.evidenceId);
        }
      }
    } finally {
      _schedulingIntel = false;
    }
  }

  Future<void> _processIntelligence(EvidenceSyncQueueItem item) async {
    // Reserved — RelationshipEngine / AI workers plug in here.
    _log('intelligence noop evidence=${item.evidenceId}');
  }

  /// Manual / connectivity-driven retry for a failed evidence id.
  Future<void> retry(String evidenceId) async {
    final cached = await LocalEvidenceCache.byId(evidenceId);
    if (cached == null) {
      return;
    }
    await LocalEvidenceCache.updateStatus(
      evidenceId: evidenceId,
      syncStatus: EvidenceSyncStatus.queuedForUpload,
    );
    await _queue.enqueue(
      EvidenceSyncQueueItem(
        evidenceId: evidenceId,
        incidentId: cached.incidentId,
        userId: cached.userId,
        lane: EvidenceSyncLane.fastSync,
        priority: SyncWorkPriority.high,
        enqueuedAt: DateTime.now(),
        mode: cached.captureMode,
        localFilePath: cached.localFilePath,
        attempts: cached.retryCount,
      ),
    );
    await schedule();
  }

  @override
  void dispose() {
    _backoffTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  @visibleForTesting
  void setUploadFnForTests(EvidenceSyncUploadFn? fn) {
    _uploadFn = fn;
  }

  @visibleForTesting
  void setOnlineForTests(bool value) {
    _online = value;
  }

  /// Clears in-flight / queued sync work (Clear Vault). Does not touch auth.
  Future<void> clearLocalSyncState() async {
    _schedulingFast = false;
    _schedulingIntel = false;
    _inFlightFast.clear();
    _inFlightIntel.clear();
    _backoffTimer?.cancel();
    _backoffTimer = null;
    for (final worker in _workers) {
      worker.busy = false;
      worker.currentEvidenceId = null;
    }
    await _queue.clear();
  }

  @visibleForTesting
  Future<void> resetForTests() async {
    _started = false;
    _schedulingFast = false;
    _schedulingIntel = false;
    _online = true;
    _inFlightFast.clear();
    _inFlightIntel.clear();
    _backoffTimer?.cancel();
    _backoffTimer = null;
    onUploadSucceeded = null;
    onUploadFailed = null;
    onLifecycleChanged = null;
    _uploadFn = null;
    _maxConcurrentUploads = defaultMaxConcurrentUploads;
    _rebuildWorkers();
    for (final worker in _workers) {
      worker.busy = false;
      worker.currentEvidenceId = null;
    }
    await _queue.clear();
    for (final entry in await LocalEvidenceCache.all()) {
      await LocalEvidenceCache.remove(entry.evidenceId);
    }
  }
}

enum _FastSyncOutcome {
  success,
  retryableFailure,
  ownershipRejected,
}
