import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'capture_media_service.dart';

/// Complete native SAF staging artifact. Temporary — not Evidence.
class SafStagedArtifact {
  const SafStagedArtifact({
    required this.operationId,
    required this.path,
    required this.size,
    this.fileName,
    this.mimeType,
    this.sha256,
    this.createdAtMs,
  });

  final String operationId;
  final String path;
  final int size;
  final String? fileName;
  final String? mimeType;
  final String? sha256;
  final int? createdAtMs;

  CapturedMediaFile toMedia() {
    return CapturedMediaFile(
      localPath: path,
      fileName: (fileName != null && fileName!.trim().isNotEmpty)
          ? fileName!.trim()
          : 'document',
      fileSizeBytes: size,
    );
  }
}

/// Smallest Dart façade over the Android SAF staging MethodChannel.
///
/// `discardAll` exists so logout / Clear Vault can wipe leftover user documents
/// without knowing the current operationId.
abstract final class SafStagingBridge {
  static const channelName = 'evidence_vault/saf_staging';
  static const _channel = MethodChannel(channelName);

  static Future<SafStagedArtifact?> Function(String operationId)? debugGetArtifact;
  static Future<void> Function(String operationId)? debugDiscard;
  static Future<void> Function()? debugDiscardAll;

  @visibleForTesting
  static void debugReset() {
    debugGetArtifact = null;
    debugDiscard = null;
    debugDiscardAll = null;
  }

  static Future<SafStagedArtifact?> getArtifact(String operationId) async {
    final id = operationId.trim();
    if (id.isEmpty) {
      return null;
    }
    final override = debugGetArtifact;
    if (override != null) {
      return override(id);
    }
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('getArtifact', {
        'operationId': id,
      });
      return _parse(raw);
    } catch (error) {
      debugPrint('[SafStagingBridge] getArtifact failed: $error');
      return null;
    }
  }

  /// Waits for a COMPLETE native artifact. Never returns a `.part` path.
  static Future<CapturedMediaFile?> awaitComplete({
    required String? operationId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final id = operationId?.trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    if (debugGetArtifact != null) {
      final artifact = await getArtifact(id);
      return artifact?.toMedia();
    }
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final artifact = await getArtifact(id);
      if (artifact != null) {
        return artifact.toMedia();
      }
      if (DateTime.now().isAfter(deadline)) {
        return null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  static Future<void> discard(String? operationId) async {
    final id = operationId?.trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    final override = debugDiscard;
    if (override != null) {
      await override(id);
      return;
    }
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('discard', {'operationId': id});
    } catch (error) {
      debugPrint('[SafStagingBridge] discard failed: $error');
    }
  }

  static Future<void> discardAll() async {
    final override = debugDiscardAll;
    if (override != null) {
      await override();
      return;
    }
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('discardAll');
    } catch (error) {
      debugPrint('[SafStagingBridge] discardAll failed: $error');
    }
  }

  static SafStagedArtifact? _parse(Map<String, Object?>? raw) {
    if (raw == null) {
      return null;
    }
    final status = (raw['status'] as String?)?.trim();
    final path = (raw['path'] as String?)?.trim() ?? '';
    final operationId = (raw['operationId'] as String?)?.trim() ?? '';
    if (status != 'complete' || path.isEmpty || operationId.isEmpty) {
      return null;
    }
    if (path.endsWith('.part')) {
      return null;
    }
    final sizeRaw = raw['size'];
    final size = sizeRaw is int
        ? sizeRaw
        : sizeRaw is num
        ? sizeRaw.toInt()
        : 0;
    if (size < 0) {
      return null;
    }
    final createdRaw = raw['createdAtMs'];
    return SafStagedArtifact(
      operationId: operationId,
      path: path,
      size: size,
      fileName: (raw['fileName'] as String?)?.trim(),
      mimeType: (raw['mimeType'] as String?)?.trim(),
      sha256: (raw['sha256'] as String?)?.trim(),
      createdAtMs: createdRaw is int
          ? createdRaw
          : createdRaw is num
          ? createdRaw.toInt()
          : null,
    );
  }
}
