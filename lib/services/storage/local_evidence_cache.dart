import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/evidence/evidence_sync_status.dart';
import '../../diagnostics/file_p0_trace.dart';
import 'cached_evidence_entry.dart';
import 'capture_media_service.dart';

/// Durable local evidence cache — media binaries + metadata index (Sprint 6B).
///
/// **Capture is local. Sync is background.**
/// Files are plaintext. At-rest encryption is deferred because encrypting
/// this cache would break SAF recovery and local playback.
///
/// Media: `documents/evidence_cache/{incidentId}/{evidenceId}.*`
/// Metadata index: `documents/evidence_cache/metadata_index.json`
///
/// Isar is intentionally not introduced yet — JSON file index matches the
/// existing DurableUploadQueue pattern and preserves build health. Schema is
/// Isar-ready for a later migration.
abstract final class LocalEvidenceCache {
  static Directory? _root;
  static const int maxCachedFilesSoftLimit = 200;
  static const String _indexFileName = 'metadata_index.json';

  /// In-memory mirror of the durable metadata index.
  static final Map<String, CachedEvidenceEntry> _index = {};
  static bool _indexLoaded = false;
  static bool _indexLoadFailed = false;

  /// Test hook — clears in-memory + root override.
  @visibleForTesting
  static void resetForTests() {
    _index.clear();
    _indexLoaded = false;
    _indexLoadFailed = false;
    _root = null;
  }

  static Future<Directory> _ensureRoot() async {
    if (_root != null) {
      return _root!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'evidence_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _root = dir;
    return dir;
  }

  static Future<File> _indexFile() async {
    final root = await _ensureRoot();
    return File(p.join(root.path, _indexFileName));
  }

  static Future<void> _ensureIndexLoaded() async {
    if (_indexLoaded) {
      if (_indexLoadFailed) {
        throw StateError(
          'Evidence metadata index is corrupt or unreadable; mutations are blocked.',
        );
      }
      return;
    }

    if (kIsWeb) {
      _indexLoaded = true;
      return;
    }

    try {
      final file = await _indexFile();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! List) {
          throw const FormatException(
            'Evidence metadata index root must be a JSON list.',
          );
        }

        _index.clear();
        for (final raw in decoded) {
          if (raw is Map<String, dynamic>) {
            final entry = CachedEvidenceEntry.fromJson(raw);
            if (entry.evidenceId.isNotEmpty) {
              _index[entry.evidenceId] = entry;
            }
          } else if (raw is Map) {
            final entry = CachedEvidenceEntry.fromJson(
              Map<String, dynamic>.from(raw),
            );
            if (entry.evidenceId.isNotEmpty) {
              _index[entry.evidenceId] = entry;
            }
          } else {
            throw const FormatException(
              'Evidence metadata index contains a non-object record.',
            );
          }
        }
      }

      _indexLoaded = true;
    } catch (error) {
      _index.clear();
      _indexLoadFailed = true;
      _indexLoaded = true;
      debugPrint(
        '[LocalEvidenceCache] index load failed; writes blocked: $error',
      );
      throw StateError(
        'Evidence metadata index is corrupt or unreadable. '
        'Original index preserved; writes and deletions are blocked. '
        'Cause: $error',
      );
    }
  }

  static Future<void> _persistIndex() async {
    if (kIsWeb) {
      return;
    }
    try {
      final file = await _indexFile();
      final payload = [for (final entry in _index.values) entry.toJson()];
      await file.writeAsString(jsonEncode(payload));
    } catch (error) {
      debugPrint('[LocalEvidenceCache] index save failed: $error');
    }
  }

  /// Upserts evidence metadata immediately after capture (source of truth).
  static Future<void> upsert(CachedEvidenceEntry entry) async {
    await _ensureIndexLoaded();
    _index[entry.evidenceId] = entry;
    await _persistIndex();
  }

  static Future<CachedEvidenceEntry?> byId(String evidenceId) async {
    await _ensureIndexLoaded();
    return _index[evidenceId];
  }

  /// Evidence for [incidentId], optionally scoped to [userId].
  ///
  /// Rows with an empty `userId` (legacy / unsigned capture) remain visible so
  /// crash recovery still works; non-empty foreign userIds are excluded.
  static Future<List<CachedEvidenceEntry>> forIncident(
    String incidentId, {
    String? userId,
  }) async {
    await _ensureIndexLoaded();
    final list = _index.values.where((entry) {
      if (entry.incidentId != incidentId) {
        return false;
      }
      if (userId == null || userId.isEmpty) {
        return true;
      }
      if (entry.userId.isEmpty) {
        return true;
      }
      return entry.userId == userId;
    }).toList()..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return list;
  }

  /// Incident with the most cached rows for [userId] (logout/login recovery).
  static Future<String?> richestIncidentId({String? userId}) async {
    await _ensureIndexLoaded();
    final counts = <String, int>{};
    for (final entry in _index.values) {
      if (entry.incidentId.isEmpty) {
        continue;
      }
      if (userId != null &&
          userId.isNotEmpty &&
          entry.userId.isNotEmpty &&
          entry.userId != userId) {
        continue;
      }
      counts[entry.incidentId] = (counts[entry.incidentId] ?? 0) + 1;
    }
    String? bestId;
    var bestCount = 0;
    counts.forEach((id, count) {
      if (count > bestCount) {
        bestId = id;
        bestCount = count;
      }
    });
    return bestCount > 0 ? bestId : null;
  }

  static Future<List<CachedEvidenceEntry>> pendingSync({String? userId}) async {
    await _ensureIndexLoaded();
    return _index.values
        .where(
          (entry) =>
              entry.needsUpload &&
              (userId == null ||
                  userId.isEmpty ||
                  entry.userId.isEmpty ||
                  entry.userId == userId),
        )
        .toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
  }

  static Future<List<CachedEvidenceEntry>> all() async {
    await _ensureIndexLoaded();
    return List<CachedEvidenceEntry>.unmodifiable(_index.values);
  }

  static Future<void> updateStatus({
    required String evidenceId,
    required EvidenceSyncStatus syncStatus,
    double? uploadProgress,
    int? retryCount,
    String? cloudPath,
    String? downloadUrl,
    String? localFilePath,
    String? thumbnailPath,
    String? hash,
  }) async {
    await _ensureIndexLoaded();
    final existing = _index[evidenceId];
    if (existing == null) {
      return;
    }
    _index[evidenceId] = existing.copyWith(
      syncStatus: syncStatus,
      uploadProgress: uploadProgress,
      retryCount: retryCount,
      cloudPath: cloudPath,
      downloadUrl: downloadUrl,
      localFilePath: localFilePath,
      thumbnailPath: thumbnailPath,
      hash: hash,
    );
    await _persistIndex();
  }

  static Future<void> remove(String evidenceId) async {
    await _ensureIndexLoaded();
    if (_index.remove(evidenceId) != null) {
      await _persistIndex();
    }
  }

  /// Removes only cache rows and the durable folder owned by [incidentId].
  static Future<void> removeForIncident(String incidentId) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    await _ensureIndexLoaded();
    final owned = [
      for (final entry in _index.values)
        if (entry.incidentId == id) entry.evidenceId,
    ];
    for (final evidenceId in owned) {
      _index.remove(evidenceId);
    }
    if (owned.isNotEmpty) {
      await _persistIndex();
    }
    if (kIsWeb) {
      return;
    }
    try {
      final root = await _ensureRoot();
      final incidentDir = Directory(p.join(root.path, id));
      if (await incidentDir.exists()) {
        await incidentDir.delete(recursive: true);
      }
    } catch (error) {
      debugPrint('[LocalEvidenceCache] removeForIncident skipped: $error');
    }
  }

  /// Clears every cached evidence row (Clear Vault).
  static Future<void> clearAll() async {
    await _ensureIndexLoaded();
    _index.clear();
    await _persistIndex();
    debugPrint('[LocalEvidenceCache] clearAll');
  }

  /// Copies [media] into a durable per-incident folder. Returns updated paths.
  ///
  /// Throws [MediaDurabilityException] when the source is missing or the copy
  /// cannot be verified. Callers must not treat the original ephemeral path as
  /// preserved evidence.
  static Future<CapturedMediaFile> durableize({
    required String incidentId,
    required String evidenceId,
    required CapturedMediaFile media,
  }) async {
    if (kIsWeb) {
      return media;
    }

    try {
      FileP0Trace.step(
        'DURABLEIZE_COPY_START',
        incidentId: incidentId,
        fileName: media.fileName,
        fileSize: media.fileSizeBytes,
        path: media.localPath,
        extra: 'evidenceId=$evidenceId',
      );
      final root = await _ensureRoot();
      final incidentDir = Directory(p.join(root.path, incidentId));
      if (!await incidentDir.exists()) {
        await incidentDir.create(recursive: true);
      }

      final source = File(media.localPath);
      if (!await source.exists()) {
        FileP0Trace.failure(
          'DURABLEIZE_SOURCE_MISSING',
          incidentId: incidentId,
          path: media.localPath,
          extra: 'evidenceId=$evidenceId',
        );
        throw MediaDurabilityException(
          'Local media is missing and cannot be preserved.',
        );
      }

      final ext = p.extension(media.fileName).isNotEmpty
          ? p.extension(media.fileName)
          : p.extension(media.localPath);
      final durablePath = p.join(incidentDir.path, '$evidenceId$ext');
      if (p.normalize(source.path) != p.normalize(durablePath)) {
        await _copyFileOffUiIfLarge(
          sourcePath: source.path,
          destPath: durablePath,
          fileSizeBytes: media.fileSizeBytes,
        );
      }

      String? durableThumb = media.thumbnailPath;
      if (media.thumbnailPath != null &&
          media.thumbnailPath != media.localPath) {
        final thumbSource = File(media.thumbnailPath!);
        if (await thumbSource.exists()) {
          final thumbExt = p.extension(media.thumbnailPath!);
          durableThumb = p.join(
            incidentDir.path,
            '${evidenceId}_thumb$thumbExt',
          );
          if (p.normalize(thumbSource.path) != p.normalize(durableThumb)) {
            final thumbBytes = await thumbSource.length();
            await _copyFileOffUiIfLarge(
              sourcePath: thumbSource.path,
              destPath: durableThumb,
              fileSizeBytes: thumbBytes,
            );
          }
        }
      } else if (media.thumbnailPath == media.localPath) {
        durableThumb = durablePath;
      }

      await _softTrimIfNeeded(root);

      final durableFile = File(durablePath);
      if (!await durableFile.exists()) {
        throw MediaDurabilityException('Durable media copy was not written.');
      }

      final out = CapturedMediaFile(
        localPath: durablePath,
        fileName: media.fileName,
        fileSizeBytes: await durableFile.length(),
        thumbnailPath: durableThumb,
      );
      FileP0Trace.step(
        'DURABLEIZE_COPY_DONE',
        incidentId: incidentId,
        fileName: out.fileName,
        fileSize: out.fileSizeBytes,
        path: out.localPath,
        extra: 'evidenceId=$evidenceId',
      );
      return out;
    } catch (error, stack) {
      FileP0Trace.failure(
        'DURABLEIZE_COPY',
        error: error,
        stackTrace: stack,
        incidentId: incidentId,
        fileName: media.fileName,
        fileSize: media.fileSizeBytes,
        path: media.localPath,
        extra: 'evidenceId=$evidenceId returningOriginal=true',
      );
      debugPrint('[LocalEvidenceCache] durableize failed: $error');
      if (error is MediaDurabilityException) {
        rethrow;
      }
      throw MediaDurabilityException(
        'Local media could not be durably stored.',
      );
    }
  }

  /// Copies a generated thumbnail into the durable incident folder.
  ///
  /// Fail-open: returns null when the source is missing or the copy fails.
  /// Never returns a path outside [evidence_cache] as the long-term location.
  static Future<String?> durableizeThumbnail({
    required String incidentId,
    required String evidenceId,
    required String thumbnailPath,
  }) async {
    if (kIsWeb) {
      return thumbnailPath;
    }
    try {
      final trimmed = thumbnailPath.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final source = File(trimmed);
      if (!await source.exists()) {
        return null;
      }
      final root = await _ensureRoot();
      final normalized = p.normalize(source.path);
      if (p.isWithin(root.path, normalized)) {
        return normalized;
      }

      final incidentDir = Directory(p.join(root.path, incidentId));
      if (!await incidentDir.exists()) {
        await incidentDir.create(recursive: true);
      }
      var ext = p.extension(trimmed);
      if (ext.isEmpty) {
        ext = '.jpg';
      }
      final destPath = p.join(incidentDir.path, '${evidenceId}_thumb$ext');
      if (p.normalize(source.path) != p.normalize(destPath)) {
        await source.copy(destPath);
      }
      final dest = File(destPath);
      if (!await dest.exists()) {
        return null;
      }
      return destPath;
    } catch (error) {
      debugPrint('[LocalEvidenceCache] durableizeThumbnail skipped: $error');
      return null;
    }
  }

  /// Deletes local upload binaries after Storage + Firestore sync confirmed.
  static Future<void> reclaimSynced({
    required String? filePath,
    String? thumbnailPath,
    String? keepThumbnailPath,
  }) async {
    if (kIsWeb) {
      return;
    }

    Future<void> deleteIfSafe(String? path) async {
      if (path == null || path.isEmpty) {
        return;
      }
      if (keepThumbnailPath != null &&
          p.normalize(path) == p.normalize(keepThumbnailPath)) {
        return;
      }
      try {
        final root = await _ensureRoot();
        if (!p.isWithin(root.path, path) &&
            !path.contains('${p.separator}evidence_cache${p.separator}')) {
          return;
        }
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error) {
        debugPrint('[LocalEvidenceCache] reclaim skipped: $error');
      }
    }

    await deleteIfSafe(filePath);
    if (thumbnailPath != null &&
        thumbnailPath != filePath &&
        thumbnailPath != keepThumbnailPath) {
      await deleteIfSafe(thumbnailPath);
    }
  }

  /// Copies large binaries off the UI isolate so attach progress stays responsive.
  ///
  /// Small files keep the normal async [File.copy]. Paths only — never bytes.
  static Future<void> _copyFileOffUiIfLarge({
    required String sourcePath,
    required String destPath,
    required int fileSizeBytes,
  }) async {
    const largeThresholdBytes = 5 * 1024 * 1024;
    if (fileSizeBytes >= largeThresholdBytes && !kIsWeb) {
      await Isolate.run(() {
        File(sourcePath).copySync(destPath);
      });
      return;
    }
    await File(sourcePath).copy(destPath);
  }

  static Future<void> _softTrimIfNeeded(Directory root) async {
    try {
      final files = <File>[];
      await for (final entity in root.list(recursive: true)) {
        if (entity is File && !entity.path.endsWith(_indexFileName)) {
          files.add(entity);
        }
      }
      if (files.length <= maxCachedFilesSoftLimit) {
        return;
      }
      debugPrint(
        '[LocalEvidenceCache] ${files.length} cached files '
        '(soft limit $maxCachedFilesSoftLimit) — waiting for sync reclaim',
      );
    } catch (_) {}
  }
}

/// Thrown when photo / video / voice / file media cannot be durably stored.
class MediaDurabilityException implements Exception {
  const MediaDurabilityException(this.message);

  final String message;

  @override
  String toString() => 'MediaDurabilityException: $message';
}
