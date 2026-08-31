import '../models/workspace_capture_mode.dart';
import '../services/storage/evidence_storage_service.dart';
import '../services/storage/storage_upload_result.dart';

/// Repository boundary for Firebase Storage — UI never calls Storage SDK.
abstract class StorageRepository {
  Future<StorageUploadResult> uploadPhoto({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  });

  Future<StorageUploadResult> uploadVideo({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  });

  Future<StorageUploadResult> uploadVoice({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  });

  Future<StorageUploadResult> uploadAttachment({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  });

  Future<StorageUploadResult> uploadThumbnail({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  });

  Future<void> deleteObject(String storagePath);

  Future<void> deleteEvidenceFiles({
    required String userId,
    required String incidentId,
    required String evidenceId,
  });

  Future<StorageUploadResult> uploadForMode({
    required WorkspaceCaptureMode mode,
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  });
}

/// Firebase Storage implementation used by Sprint 4A / 4B upload pipeline.
class FirebaseStorageRepository implements StorageRepository {
  FirebaseStorageRepository({
    EvidenceStorageService? storage,
  }) : _storage = storage ?? EvidenceStorageService();

  final EvidenceStorageService _storage;

  @override
  Future<StorageUploadResult> uploadPhoto({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _storage.uploadPhoto(
      userId: userId,
      incidentId: incidentId,
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  @override
  Future<StorageUploadResult> uploadVideo({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _storage.uploadVideo(
      userId: userId,
      incidentId: incidentId,
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  @override
  Future<StorageUploadResult> uploadVoice({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _storage.uploadVoice(
      userId: userId,
      incidentId: incidentId,
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  @override
  Future<StorageUploadResult> uploadAttachment({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _storage.uploadAttachment(
      userId: userId,
      incidentId: incidentId,
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  @override
  Future<StorageUploadResult> uploadThumbnail({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _storage.uploadThumbnail(
      userId: userId,
      incidentId: incidentId,
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> deleteObject(String storagePath) {
    return _storage.deleteObject(storagePath);
  }

  @override
  Future<void> deleteEvidenceFiles({
    required String userId,
    required String incidentId,
    required String evidenceId,
  }) {
    return _storage.deleteEvidenceFiles(
      userId: userId,
      incidentId: incidentId,
      evidenceId: evidenceId,
    );
  }

  @override
  Future<StorageUploadResult> uploadForMode({
    required WorkspaceCaptureMode mode,
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return switch (mode) {
      WorkspaceCaptureMode.photo => uploadPhoto(
          userId: userId,
          incidentId: incidentId,
          localFilePath: localFilePath,
          evidenceId: evidenceId,
          customMetadata: customMetadata,
          onProgress: onProgress,
        ),
      WorkspaceCaptureMode.video => uploadVideo(
          userId: userId,
          incidentId: incidentId,
          localFilePath: localFilePath,
          evidenceId: evidenceId,
          customMetadata: customMetadata,
          onProgress: onProgress,
        ),
      WorkspaceCaptureMode.voice => uploadVoice(
          userId: userId,
          incidentId: incidentId,
          localFilePath: localFilePath,
          evidenceId: evidenceId,
          customMetadata: customMetadata,
          onProgress: onProgress,
        ),
      WorkspaceCaptureMode.file => uploadAttachment(
          userId: userId,
          incidentId: incidentId,
          localFilePath: localFilePath,
          evidenceId: evidenceId,
          customMetadata: customMetadata,
          onProgress: onProgress,
        ),
      WorkspaceCaptureMode.note => throw StateError(
          'Text notes do not upload to Firebase Storage.',
        ),
    };
  }
}
