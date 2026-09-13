import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'evidence_upload_models.dart';
import 'storage_upload_result.dart';

/// Firebase Storage upload layer for Evidence Vault capture media.
///
/// Hierarchy (exact):
/// ```
/// users/{uid}/incidents/{incidentId}/photos|videos|voice|attachments/{fileName}
/// ```
///
/// Does not write Firestore. Metadata remains local until Sprint 4B.
class EvidenceStorageService {
  EvidenceStorageService({
    FirebaseStorage? storage,
  }) : _storageOverride = storage;

  final FirebaseStorage? _storageOverride;

  /// Lazy so unit tests can construct without Firebase.initializeApp().
  FirebaseStorage get _storage =>
      _storageOverride ?? FirebaseStorage.instance;

  /// Photo → `users/{uid}/incidents/{incidentId}/photos/{fileName}`
  Future<StorageUploadResult> uploadPhoto({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _upload(
      userId: userId,
      incidentId: incidentId,
      folder: 'photos',
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      defaultExtension: '.jpg',
      defaultContentType: 'image/jpeg',
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  /// Video → `users/{uid}/incidents/{incidentId}/videos/{fileName}`
  Future<StorageUploadResult> uploadVideo({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _upload(
      userId: userId,
      incidentId: incidentId,
      folder: 'videos',
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      defaultExtension: '.mp4',
      defaultContentType: 'video/mp4',
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  /// Voice → `users/{uid}/incidents/{incidentId}/voice/{fileName}`
  Future<StorageUploadResult> uploadVoice({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _upload(
      userId: userId,
      incidentId: incidentId,
      folder: 'voice',
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      defaultExtension: '.m4a',
      defaultContentType: 'audio/mp4',
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  /// Attachment → `users/{uid}/incidents/{incidentId}/attachments/{fileName}`
  Future<StorageUploadResult> uploadAttachment({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _upload(
      userId: userId,
      incidentId: incidentId,
      folder: 'attachments',
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      defaultExtension: '.bin',
      defaultContentType: 'application/octet-stream',
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  /// Thumbnail → `users/{uid}/incidents/{incidentId}/thumbnails/{evidenceId}.jpg`
  Future<StorageUploadResult> uploadThumbnail({
    required String userId,
    required String incidentId,
    required String localFilePath,
    required String evidenceId,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) {
    return _upload(
      userId: userId,
      incidentId: incidentId,
      folder: 'thumbnails',
      localFilePath: localFilePath,
      evidenceId: evidenceId,
      defaultExtension: '.jpg',
      defaultContentType: 'image/jpeg',
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  /// Deletes a single Storage object. Missing objects are treated as success.
  Future<void> deleteObject(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
      debugPrint('[Storage] deleted → $storagePath');
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }
      StorageUploadLog.failed(storagePath, error);
      rethrow;
    }
  }

  /// Best-effort delete of every capture / thumbnail variant for one evidence
  /// item — actual extension is unknown here, so common extensions per
  /// folder are attempted; missing objects are silently skipped.
  Future<void> deleteEvidenceFiles({
    required String userId,
    required String incidentId,
    required String evidenceId,
  }) async {
    final base = 'users/$userId/incidents/$incidentId';
    final candidates = <String>[
      for (final ext in const ['.jpg', '.jpeg', '.png', '.heic', '.webp'])
        '$base/photos/$evidenceId$ext',
      for (final ext in const ['.mp4', '.mov'])
        '$base/videos/$evidenceId$ext',
      for (final ext in const ['.m4a', '.aac', '.mp3', '.wav'])
        '$base/voice/$evidenceId$ext',
      for (final ext in const ['.pdf', '.doc', '.docx', '.bin'])
        '$base/attachments/$evidenceId$ext',
      for (final ext in const ['.jpg', '.jpeg', '.png'])
        '$base/thumbnails/$evidenceId$ext',
    ];
    for (final path in candidates) {
      await deleteObject(path);
    }
  }

  /// Deletes Storage objects under the incident-owned prefix only.
  ///
  /// Path: `users/{uid}/incidents/{incidentId}/…`
  /// Does not list or delete other incidents or user-level objects.
  Future<void> deleteIncidentOwnedPrefix({
    required String userId,
    required String incidentId,
  }) async {
    final id = incidentId.trim();
    if (userId.isEmpty || id.isEmpty) {
      return;
    }
    final prefix = 'users/$userId/incidents/$id';
    try {
      await _deletePrefix(_storage.ref(prefix));
    } catch (error) {
      debugPrint('[Storage] incident prefix cleanup skipped: $error');
    }
  }

  Future<void> _deletePrefix(Reference ref) async {
    final listed = await ref.listAll();
    for (final item in listed.items) {
      try {
        await item.delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          debugPrint('[Storage] prefix item skip ${item.fullPath}: $error');
        }
      }
    }
    for (final prefix in listed.prefixes) {
      await _deletePrefix(prefix);
    }
  }

  Future<StorageUploadResult> _upload({
    required String userId,
    required String incidentId,
    required String folder,
    required String localFilePath,
    required String evidenceId,
    required String defaultExtension,
    required String defaultContentType,
    Map<String, String>? customMetadata,
    void Function(double fraction)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase Storage capture uploads require a mobile/desktop file path.',
      );
    }

    final file = File(localFilePath);
    if (!await file.exists()) {
      throw StateError('Local evidence file missing: $localFilePath');
    }

    final extension = _extensionOf(localFilePath) ?? defaultExtension;
    final fileName = '$evidenceId$extension';
    final storagePath =
        'users/$userId/incidents/$incidentId/$folder/$fileName';
    final contentType = _contentTypeFor(extension) ?? defaultContentType;
    final fileSize = await file.length();

    StorageUploadLog.started(storagePath);

    try {
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'evidenceId': evidenceId,
          'incidentId': incidentId,
          'userId': userId,
          'contentType': contentType,
          ...?customMetadata,
        },
      );

      final task = ref.putFile(file, metadata);
      StreamSubscription<TaskSnapshot>? progressSub;
      if (onProgress != null) {
        progressSub = task.snapshotEvents.listen((snapshot) {
          final total = snapshot.totalBytes;
          if (total <= 0) {
            return;
          }
          onProgress(snapshot.bytesTransferred / total);
        });
      }

      try {
        final snapshot = await task;
        // Tokenized HTTPS URL. Possession of the URL is enough to GET the
        // object until Firebase revokes the token — not the same as Storage
        // rules. Do not log this value. Short-lived custom URLs are not
        // available from the client SDK without Cloud Functions.
        final downloadUrl = await snapshot.ref.getDownloadURL();
        StorageUploadLog.completed(storagePath);

        return StorageUploadResult(
          storagePath: storagePath,
          downloadUrl: downloadUrl,
          fileSize: fileSize,
          contentType: contentType,
        );
      } finally {
        await progressSub?.cancel();
      }
    } catch (error) {
      StorageUploadLog.failed(storagePath, error);
      rethrow;
    }
  }

  static String? _extensionOf(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) {
      return null;
    }
    return ext.startsWith('.') ? ext : '.$ext';
  }

  static String? _contentTypeFor(String extension) {
    return switch (extension.toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      '.gif' => 'image/gif',
      '.mp4' => 'video/mp4',
      '.mov' => 'video/quicktime',
      '.m4a' => 'audio/mp4',
      '.aac' => 'audio/aac',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.pdf' => 'application/pdf',
      '.doc' => 'application/msword',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => null,
    };
  }
}
