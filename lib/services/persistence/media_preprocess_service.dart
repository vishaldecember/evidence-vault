import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail_gen/video_thumbnail_gen.dart';

import '../../models/workspace_capture_mode.dart';

/// Compresses photos and generates thumbnails before Firebase upload / journey
/// preview.
abstract final class MediaPreprocessService {
  static const int maxUploadWidth = 1920;
  static const int thumbnailMaxEdge = 512;
  static const int jpegQuality = 75;
  static const int thumbnailQuality = 70;

  /// Returns a compressed JPEG path for photos. Non-images pass through.
  static Future<String> compressForUpload({
    required String localFilePath,
    required bool isPhoto,
  }) async {
    if (!isPhoto || kIsWeb) {
      return localFilePath;
    }

    try {
      final file = File(localFilePath);
      if (!await file.exists()) {
        return localFilePath;
      }
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return localFilePath;
      }

      final resized = decoded.width > maxUploadWidth
          ? img.copyResize(
              decoded,
              width: maxUploadWidth,
              interpolation: img.Interpolation.linear,
            )
          : decoded;

      final encoded = img.encodeJpg(resized, quality: jpegQuality);
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(
          dir.path,
          'ev_upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      await out.writeAsBytes(encoded, flush: true);
      debugPrint(
        '[Media] compressed ${bytes.length} → ${encoded.length} bytes',
      );
      return out.path;
    } catch (error) {
      debugPrint('[Media] compress failed, using original: $error');
      return localFilePath;
    }
  }

  /// Generates a small JPEG thumbnail beside the source (photos only).
  static Future<String?> generateThumbnail(String localFilePath) async {
    if (kIsWeb) {
      return null;
    }
    try {
      final file = File(localFilePath);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return null;
      }

      final edge = math.max(decoded.width, decoded.height);
      final scale = edge > thumbnailMaxEdge ? thumbnailMaxEdge / edge : 1.0;
      final thumb = scale < 1.0
          ? img.copyResize(
              decoded,
              width: (decoded.width * scale).round(),
              height: (decoded.height * scale).round(),
              interpolation: img.Interpolation.average,
            )
          : decoded;

      final encoded = img.encodeJpg(thumb, quality: thumbnailQuality);
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(
          dir.path,
          'ev_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      await out.writeAsBytes(encoded, flush: true);
      return out.path;
    } catch (error) {
      debugPrint('[Media] thumbnail failed: $error');
      return null;
    }
  }

  /// Local preview thumb for [ThumbnailJob] — never throws; may return null.
  static Future<String?> previewThumbnailForMode({
    required WorkspaceCaptureMode mode,
    required String localFilePath,
  }) async {
    try {
      return switch (mode) {
        WorkspaceCaptureMode.photo => generateThumbnail(localFilePath),
        WorkspaceCaptureMode.video => generateVideoThumbnail(localFilePath),
        WorkspaceCaptureMode.file => _filePreviewOrNull(localFilePath),
        WorkspaceCaptureMode.voice || WorkspaceCaptureMode.note => null,
      };
    } catch (error) {
      debugPrint('[Media] preview thumbnail skipped: $error');
      return null;
    }
  }

  /// Images get a thumb; video extensions attempt a frame (null = graceful).
  static Future<String?> _filePreviewOrNull(String path) async {
    final lower = path.toLowerCase();
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
    if (isImage) {
      return generateThumbnail(path);
    }
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mpg') ||
        lower.endsWith('.mpeg') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.3gp');
    if (isVideo) {
      // MPG/MPEG often fail decode — return null, never throw / never block persist.
      return generateVideoThumbnail(path);
    }
    return null;
  }

  /// Extracts a first-frame JPEG glimpse from a local video file.
  static Future<String?> generateVideoThumbnail(String localVideoPath) async {
    if (kIsWeb) {
      return null;
    }
    try {
      final file = File(localVideoPath);
      if (!await file.exists()) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final outPath = p.join(
        dir.path,
        'ev_vthumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final generated = await VideoThumbnail.thumbnailFile(
        video: localVideoPath,
        thumbnailPath: outPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: thumbnailMaxEdge,
        quality: thumbnailQuality,
        timeMs: 0,
      );
      if (generated == null || generated.isEmpty) {
        return null;
      }
      final thumb = File(generated);
      if (!await thumb.exists()) {
        return null;
      }
      return thumb.path;
    } catch (error) {
      debugPrint('[Media] video thumbnail failed: $error');
      return null;
    }
  }
}
