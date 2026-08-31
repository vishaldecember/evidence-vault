import 'package:path/path.dart' as p;

import '../../models/workspace_capture_mode.dart';

/// Classifies a File-picker selection for local preservation.
///
/// Preservation does **not** require successful video decode/thumbnail.
abstract final class FileAttachmentClassifier {
  static const _videoExt = {
    'mp4',
    'mov',
    'm4v',
    'mpg',
    'mpeg',
    'webm',
    '3gp',
    'mkv',
  };

  static const _imageExt = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
    'bmp',
  };

  static const _documentExt = {
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf',
    'csv',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'odt',
    'ods',
    'odp',
    'json',
    'xml',
    'html',
    'htm',
    'md',
    'zip',
  };

  static const _audioExt = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'caf',
    'ogg',
  };

  /// Dangerous / non-evidence binaries we refuse to attach.
  static const _blockedExt = {
    'exe',
    'bat',
    'cmd',
    'com',
    'msi',
    'apk',
    'ipa',
    'dmg',
    'sh',
    'ps1',
    'dll',
    'so',
  };

  static String extensionOf(String fileNameOrPath) =>
      p.extension(fileNameOrPath).replaceFirst('.', '').toLowerCase();

  static bool isVideo({
    required String fileName,
    String? mimeType,
  }) {
    final ext = extensionOf(fileName);
    if (_videoExt.contains(ext)) {
      return true;
    }
    final mime = (mimeType ?? '').toLowerCase();
    return mime.startsWith('video/');
  }

  static bool isPdf({
    required String fileName,
    String? mimeType,
  }) {
    if (extensionOf(fileName) == 'pdf') {
      return true;
    }
    final mime = (mimeType ?? '').toLowerCase().trim();
    return mime == 'application/pdf';
  }

  static bool isBlocked({
    required String fileName,
    String? mimeType,
  }) {
    final ext = extensionOf(fileName);
    if (_blockedExt.contains(ext)) {
      return true;
    }
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.contains('x-msdownload') || mime.contains('x-msdos-program')) {
      return true;
    }
    return false;
  }

  static bool isSupported({
    required String fileName,
    String? mimeType,
  }) {
    if (isBlocked(fileName: fileName, mimeType: mimeType)) {
      return false;
    }
    final ext = extensionOf(fileName);
    if (ext.isEmpty) {
      // Extension-less files: allow if MIME looks like evidence media/text.
      final mime = (mimeType ?? '').toLowerCase();
      return mime.startsWith('video/') ||
          mime.startsWith('image/') ||
          mime.startsWith('audio/') ||
          mime.startsWith('text/') ||
          mime.contains('pdf');
    }
    return _videoExt.contains(ext) ||
        _imageExt.contains(ext) ||
        _documentExt.contains(ext) ||
        _audioExt.contains(ext);
  }

  /// Persist mode: video files become captured VIDEO; others stay File attachment.
  static WorkspaceCaptureMode persistMode({
    required String fileName,
    String? mimeType,
  }) {
    if (isVideo(fileName: fileName, mimeType: mimeType)) {
      return WorkspaceCaptureMode.video;
    }
    return WorkspaceCaptureMode.file;
  }

  static String? guessMimeType(String fileName) {
    final ext = extensionOf(fileName);
    return switch (ext) {
      'pdf' => 'application/pdf',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'mpg' || 'mpeg' => 'video/mpeg',
      'webm' => 'video/webm',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      _ => null,
    };
  }
}
