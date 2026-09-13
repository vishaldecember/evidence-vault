import 'package:flutter/foundation.dart';

import '../../models/workspace_capture_mode.dart';
import '../../repositories/storage_repository.dart';
import '../../services/metadata_service.dart';
import '../../services/persistence/media_preprocess_service.dart';
import '../../services/user_session_service.dart';
import 'evidence_upload_models.dart';
import 'evidence_upload_queue.dart';
import 'storage_upload_result.dart';

/// Orchestrates Firebase Storage uploads and publishes progress.
///
/// Progress is exposed without blocking capture. Goes through [StorageRepository]
/// so UI never touches the Storage SDK. Reads the active user from
/// [UserSessionService] — controllers/services avoid depending on
/// [AuthService] directly.
///
/// **Phase 2(B)-1:** retry ownership is [EvidenceSyncManager] /
/// [EvidenceSyncQueue]. This coordinator must not persist a second durable
/// retry queue or independently retry uploads on connectivity.
/// Failure UI is optional via [EvidenceUploadFeedback]; percent snackbars
/// are intentionally not used (Sprint 4F — quiet sync).
class EvidenceUploadCoordinator extends ChangeNotifier {
  EvidenceUploadCoordinator({
    StorageRepository? storage,
    EvidenceUploadQueue? queue,
  })  : _storage = storage ?? FirebaseStorageRepository(),
        _queue = queue ?? EvidenceUploadQueue() {
    _queueReady = _queue.restore();
  }

  static final EvidenceUploadCoordinator instance = EvidenceUploadCoordinator();

  final StorageRepository _storage;
  final EvidenceUploadQueue _queue;
  Future<void>? _queueReady;

  final Map<String, EvidenceUploadProgress> _progress = {};

  /// Resolves once leftover durable rows (if any) have been loaded from disk.
  Future<void> get queueReady => _queueReady ??= _queue.restore();

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
      return null;
    }

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
      return null;
    }
  }

  /// Manual retry is owned by [EvidenceSyncManager.retry].
  /// Leftover durable rows are not independently retried from this coordinator.
  Future<StorageUploadResult?> retry(String evidenceId) async {
    return null;
  }

  /// No-op: connectivity-driven retry is owned by [EvidenceSyncManager].
  Future<void> retryAll() async {}

  /// Wipes leftover independent retry rows (Clear Vault / account deletion).
  Future<void> clearIndependentRetryState() async {
    await _queue.clear();
    if (_progress.isNotEmpty) {
      _progress.clear();
      notifyListeners();
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
