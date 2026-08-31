import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../models/workspace_capture_mode.dart';
import '../../repositories/storage_repository.dart';
import '../../services/metadata_service.dart';
import '../../services/persistence/media_preprocess_service.dart';
import '../../services/user_session_service.dart';
import 'evidence_upload_models.dart';
import 'evidence_upload_queue.dart';
import 'storage_upload_result.dart';

/// Orchestrates Firebase Storage uploads + local retry queue.
///
/// Progress is exposed without blocking capture. Goes through [StorageRepository]
/// so UI never touches the Storage SDK. Reads the active user from
/// [UserSessionService] — controllers/services avoid depending on
/// [AuthService] directly.
///
/// Loads the durable retry queue on first use and watches connectivity
/// (Sprint 4D) so queued uploads retry automatically once back online.
/// Failure UI is optional via [EvidenceUploadFeedback]; percent snackbars
/// are intentionally not used (Sprint 4F — quiet sync).
class EvidenceUploadCoordinator extends ChangeNotifier {
  EvidenceUploadCoordinator({
    StorageRepository? storage,
    EvidenceUploadQueue? queue,
    Connectivity? connectivity,
  })  : _storage = storage ?? FirebaseStorageRepository(),
        _queue = queue ?? EvidenceUploadQueue(),
        _connectivity = connectivity ?? Connectivity() {
    _queueReady = _queue.restore();
    _listenForConnectivity();
  }

  static final EvidenceUploadCoordinator instance = EvidenceUploadCoordinator();

  final StorageRepository _storage;
  final EvidenceUploadQueue _queue;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Future<void>? _queueReady;

  final Map<String, EvidenceUploadProgress> _progress = {};

  /// Resolves once the durable retry queue has been loaded from disk.
  Future<void> get queueReady => _queueReady ??= _queue.restore();

  void _listenForConnectivity() {
    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (results) {
          final isOnline = results.any(
            (result) => result != ConnectivityResult.none,
          );
          if (isOnline && _queue.hasPending) {
            unawaited(retryAll());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[Storage] connectivity stream error: $error');
        },
      );
    } catch (error) {
      debugPrint('[Storage] connectivity listener unavailable: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  EvidenceUploadQueue get queue => _queue;

  EvidenceUploadProgress? progressFor(String evidenceId) =>
      _progress[evidenceId];

  Map<String, EvidenceUploadProgress> get allProgress =>
      Map.unmodifiable(_progress);

  /// Publishes a calm sync status for the Capture Engine / UI observers.
  void announceStatus(
    String evidenceId,
    EvidenceUploadStatus status, {
    double fraction = 0,
    String? errorMessage,
  }) {
    _setProgress(
      evidenceId,
      EvidenceUploadProgress(
        evidenceId: evidenceId,
        status: status,
        fraction: fraction,
        errorMessage: errorMessage,
      ),
    );
  }

  String? get activeUserId => UserSessionService.account?.userId;

  Future<StorageUploadResult?> uploadCapturedMedia({
    required String evidenceId,
    required String incidentId,
    required String localFilePath,
    required WorkspaceCaptureMode mode,
    String? ownerUserId,
    String? deviceModel,
    double? latitude,
    double? longitude,
    DateTime? captureTime,
  }) async {
    final userId = activeUserId;
    if (ownerUserId != null &&
        (ownerUserId.isEmpty || userId == null || ownerUserId != userId)) {
      _setProgress(
        evidenceId,
        EvidenceUploadProgress(
          evidenceId: evidenceId,
          status: EvidenceUploadStatus.failed,
          fraction: 0,
          errorMessage: 'Upload ownership could not be verified.',
        ),
      );
      return null;
    }
    if (userId == null || userId.isEmpty) {
      _setProgress(
        evidenceId,
        EvidenceUploadProgress(
          evidenceId: evidenceId,
          status: EvidenceUploadStatus.failed,
          fraction: 0,
          errorMessage: 'Sign in required to upload evidence.',
        ),
      );
      _enqueueFailure(
        evidenceId: evidenceId,
        incidentId: incidentId,
        localFilePath: localFilePath,
        mode: mode,
        deviceModel: deviceModel,
        latitude: latitude,
        longitude: longitude,
        captureTime: captureTime,
      );
      return null;
    }

    final folder = _folderFor(mode);
    final intendedPath =
        'users/$userId/incidents/$incidentId/$folder/$evidenceId';

    _setProgress(
      evidenceId,
      EvidenceUploadProgress(
        evidenceId: evidenceId,
        status: EvidenceUploadStatus.processing,
        fraction: 0.05,
      ),
    );

    final metadata = <String, String>{
      'incidentId': incidentId,
      'userId': userId,
      'captureTime': (captureTime ?? DateTime.now()).toIso8601String(),
      if (deviceModel != null && deviceModel.isNotEmpty)
        'deviceModel': deviceModel,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    };

    try {
      // Compress photos before upload; generate thumbnail in parallel path.
      final uploadPath = await MediaPreprocessService.compressForUpload(
        localFilePath: localFilePath,
        isPhoto: mode == WorkspaceCaptureMode.photo,
      );
      _setProgress(
        evidenceId,
        EvidenceUploadProgress(
          evidenceId: evidenceId,
          status: EvidenceUploadStatus.processing,
          fraction: 0.15,
        ),
      );

      String? thumbnailLocal;
      if (mode == WorkspaceCaptureMode.photo) {
        thumbnailLocal =
            await MediaPreprocessService.generateThumbnail(uploadPath);
      } else if (mode == WorkspaceCaptureMode.video) {
        thumbnailLocal = await MediaPreprocessService.generateVideoThumbnail(
          uploadPath,
        );
      }

      _setProgress(
        evidenceId,
        EvidenceUploadProgress(
          evidenceId: evidenceId,
          status: EvidenceUploadStatus.uploading,
          fraction: 0.2,
        ),
      );

      final result = await _storage.uploadForMode(
        mode: mode,
        userId: userId,
        incidentId: incidentId,
        localFilePath: uploadPath,
        evidenceId: evidenceId,
        customMetadata: metadata,
        onProgress: (fraction) {
          _setProgress(
            evidenceId,
            EvidenceUploadProgress(
              evidenceId: evidenceId,
              status: EvidenceUploadStatus.uploading,
              fraction: fraction * (thumbnailLocal == null ? 1.0 : 0.85),
            ),
          );
        },
      );

      String? thumbnailUrl;
      if (thumbnailLocal != null) {
        try {
          final thumbResult = await _storage.uploadThumbnail(
            userId: userId,
            incidentId: incidentId,
            localFilePath: thumbnailLocal,
            evidenceId: evidenceId,
            customMetadata: {
              ...metadata,
              'contentType': 'image/jpeg',
              'role': 'thumbnail',
            },
            onProgress: (fraction) {
              _setProgress(
                evidenceId,
                EvidenceUploadProgress(
                  evidenceId: evidenceId,
                  status: EvidenceUploadStatus.uploading,
                  fraction: 0.85 + (fraction * 0.15),
                ),
              );
            },
          );
          thumbnailUrl = thumbResult.downloadUrl;
        } catch (error) {
          debugPrint('[Storage] thumbnail upload skipped: $error');
        }
      }

      _queue.remove(evidenceId);
      _setProgress(
        evidenceId,
        EvidenceUploadProgress(
          evidenceId: evidenceId,
          status: EvidenceUploadStatus.uploaded,
          fraction: 1,
        ),
      );
      return result.copyWith(thumbnailUrl: thumbnailUrl);
    } catch (error) {
      _setProgress(
        evidenceId,
        EvidenceUploadProgress(
          evidenceId: evidenceId,
          status: EvidenceUploadStatus.failed,
          fraction: _progress[evidenceId]?.fraction ?? 0,
          errorMessage: 'Upload failed.',
        ),
      );
      _enqueueFailure(
        evidenceId: evidenceId,
        incidentId: incidentId,
        localFilePath: localFilePath,
        mode: mode,
        deviceModel: deviceModel,
        latitude: latitude,
        longitude: longitude,
        captureTime: captureTime,
        intendedPath: intendedPath,
      );
      return null;
    }
  }

  Future<StorageUploadResult?> retry(String evidenceId) async {
    final queued = _queue.byEvidenceId(evidenceId);
    if (queued == null) {
      return null;
    }
    final currentUserId = activeUserId ?? '';
    if (!queued.isOwnedBy(currentUserId)) {
      return null;
    }
    return uploadCapturedMedia(
      evidenceId: queued.evidenceId,
      incidentId: queued.incidentId,
      localFilePath: queued.localFilePath,
      mode: queued.mode,
      ownerUserId: queued.userId,
      deviceModel: queued.deviceModel,
      latitude: queued.latitude,
      longitude: queued.longitude,
      captureTime: queued.captureTime,
    );
  }

  Future<void> retryAll() async {
    final ids = _queue.items.map((item) => item.evidenceId).toList();
    for (final id in ids) {
      await retry(id);
    }
  }

  /// Collects device/location metadata for Storage custom metadata.
  static Future<({String? deviceModel, double? latitude, double? longitude})>
      collectDeviceContext() async {
    try {
      final meta = await MetadataService.collect();
      return (
        deviceModel: meta.device.name,
        latitude: meta.location.latitude,
        longitude: meta.location.longitude,
      );
    } catch (_) {
      return (deviceModel: null, latitude: null, longitude: null);
    }
  }

  void _enqueueFailure({
    required String evidenceId,
    required String incidentId,
    required String localFilePath,
    required WorkspaceCaptureMode mode,
    String? deviceModel,
    double? latitude,
    double? longitude,
    DateTime? captureTime,
    String? intendedPath,
  }) {
    final userId = activeUserId ?? '';
    final folder = _folderFor(mode);
    _queue.enqueue(
      buildQueuedEvidenceUpload(
        evidenceId: evidenceId,
        incidentId: incidentId,
        userId: userId,
        localFilePath: localFilePath,
        mode: mode,
        intendedStoragePath: intendedPath ??
            (userId.isEmpty
                ? 'unattributed/incidents/$incidentId/$folder/$evidenceId'
                : 'users/$userId/incidents/$incidentId/$folder/$evidenceId'),
        deviceModel: deviceModel,
        latitude: latitude,
        longitude: longitude,
        captureTime: captureTime,
      ),
    );
  }

  static String _folderFor(WorkspaceCaptureMode mode) => switch (mode) {
        WorkspaceCaptureMode.photo => 'photos',
        WorkspaceCaptureMode.video => 'videos',
        WorkspaceCaptureMode.voice => 'voice',
        WorkspaceCaptureMode.file => 'attachments',
        WorkspaceCaptureMode.note => 'attachments',
      };

  void _setProgress(String evidenceId, EvidenceUploadProgress progress) {
    final existing = _progress[evidenceId];
    // Never regress a finished upload back via late Storage events.
    if (existing != null &&
        (existing.status == EvidenceUploadStatus.uploaded ||
            existing.status == EvidenceUploadStatus.failed) &&
        (progress.status == EvidenceUploadStatus.uploading ||
            progress.status == EvidenceUploadStatus.processing ||
            progress.status == EvidenceUploadStatus.pending)) {
      return;
    }
    _progress[evidenceId] = progress;
    notifyListeners();
  }

  /// Removes completed/failed progress so the UI can hide the bar after 100%.
  void clearProgress(String evidenceId) {
    if (_progress.remove(evidenceId) != null) {
      notifyListeners();
    }
  }
}
