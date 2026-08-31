import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/evidence_record_model.dart';
import '../../models/workspace_evidence_item.dart';
import '../../utils/evidence_formatters.dart';

/// Resolves local media paths for inspector previews.
abstract final class EvidenceMediaSource {
  static String? previewPath(WorkspaceEvidenceItem evidence) {
    return evidence.thumbnailPath ?? evidence.filePath;
  }

  static String? playbackPath(WorkspaceEvidenceItem evidence) {
    return evidence.filePath ?? evidence.thumbnailPath;
  }

  /// Close-inspection path: original when it is a readable image, else preview.
  ///
  /// Does not download, copy, or decode. Presentation only.
  static String? inspectionPath(WorkspaceEvidenceItem evidence) {
    final original = evidence.filePath;
    if (isReadableFile(original) && isImagePath(original)) {
      return original;
    }
    return previewPath(evidence);
  }

  /// True when close inspection can only use a derived thumbnail.
  static bool isInspectionPreviewOnly(WorkspaceEvidenceItem evidence) {
    final original = evidence.filePath;
    if (isReadableFile(original) && isImagePath(original)) {
      return false;
    }
    final preview = previewPath(evidence);
    return preview != null &&
        preview != original &&
        isReadableFile(preview);
  }

  /// Decode width for [Image.file] so originals are not decoded at native size.
  static int decodeWidth({
    required double logicalWidth,
    required double devicePixelRatio,
    double scale = 1,
    int maxPx = 4096,
  }) {
    final px = (logicalWidth * devicePixelRatio * scale).round();
    if (px < 64) {
      return 64;
    }
    return px > maxPx ? maxPx : px;
  }

  static bool isReadableFile(String? path) {
    if (path == null || path.isEmpty || kIsWeb) {
      return false;
    }
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static bool isImagePath(String? path) {
    if (path == null) {
      return false;
    }
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic');
  }

  static String extensionOf(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return 'FILE';
    }
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) {
      return 'FILE';
    }
    return fileName.substring(dot + 1).toUpperCase();
  }

  static String displayName(String? fileName, {String fallback = 'Attachment'}) {
    if (fileName == null || fileName.trim().isEmpty) {
      return fallback;
    }
    return fileName.trim();
  }

  static String? fileSizeLabel(EvidenceRecordModel record) {
    final labeled = record.metadata.fileSize;
    if (labeled != null && labeled.isNotEmpty) {
      return labeled;
    }
    final bytes = record.evidence.fileSizeBytes;
    if (bytes == null || bytes <= 0) {
      return null;
    }
    return EvidenceFormatters.fileSize(bytes);
  }

  static String? durationLabel(EvidenceRecordModel record) {
    final labeled = record.metadata.duration;
    if (labeled == null || labeled.isEmpty) {
      return null;
    }
    return labeled;
  }

  static Duration parsedDuration(EvidenceRecordModel record) {
    final label = durationLabel(record);
    if (label == null || label.isEmpty) {
      return Duration.zero;
    }
    final parts = label.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return Duration(minutes: minutes, seconds: seconds);
    }
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final seconds = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }
    return Duration.zero;
  }
}
