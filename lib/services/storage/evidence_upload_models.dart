import 'package:flutter/foundation.dart';

import '../../domain/evidence/evidence_sync_status.dart';
import 'evidence_status_bridge.dart';

/// Capture / upload progress enum for Storage coordinator (Sprint 5A).
///
/// Prefer [EvidenceSyncStatus] for domain lifecycle. This enum remains for
/// Firebase Storage job progress and existing UI badges. Map with
/// [EvidenceStatusBridge].
///
/// Wire name [uploaded] is retained for Firestore compatibility (= Synced in UI).
enum EvidenceUploadStatus {
  /// Local evidence created; background work not started.
  pending,

  /// Binary upload to Firebase Storage in flight.
  uploading,

  /// Thumbnail / compression / post-process in flight.
  processing,

  /// Stored in Firebase Storage; [storagePath] / [downloadUrl] set (= Synced).
  uploaded,

  /// Upload failed; queued for retry. Local file retained.
  failed;

  /// User-facing sync label (delegates to lifecycle where possible).
  String get displayLabel =>
      EvidenceStatusBridge.fromUploadStatus(this).displayLabel;

  bool get isTerminal =>
      this == EvidenceUploadStatus.uploaded || this == EvidenceUploadStatus.failed;

  bool get showsProgressBadge =>
      this == EvidenceUploadStatus.pending ||
      this == EvidenceUploadStatus.uploading ||
      this == EvidenceUploadStatus.processing;
}

/// Progress snapshot for non-blocking upload UI.
class EvidenceUploadProgress {
  const EvidenceUploadProgress({
    required this.evidenceId,
    required this.status,
    required this.fraction,
    this.errorMessage,
  });

  final String evidenceId;
  final EvidenceUploadStatus status;

  /// 0.0 – 1.0
  final double fraction;
  final String? errorMessage;

  int get percent => (fraction.clamp(0.0, 1.0) * 100).round();

  EvidenceSyncStatus get lifecycleStatus =>
      EvidenceStatusBridge.fromUploadStatus(status);

  String get label => switch (status) {
        EvidenceUploadStatus.pending => EvidenceUploadStatus.pending.displayLabel,
        EvidenceUploadStatus.uploading =>
          EvidenceUploadStatus.uploading.displayLabel,
        EvidenceUploadStatus.processing =>
          EvidenceUploadStatus.processing.displayLabel,
        EvidenceUploadStatus.uploaded => EvidenceUploadStatus.uploaded.displayLabel,
        EvidenceUploadStatus.failed =>
          errorMessage ?? EvidenceUploadStatus.failed.displayLabel,
      };
}

/// Debug logging for Storage uploads. Release builds omit paths (uid/incident).
abstract final class StorageUploadLog {
  static void started(String storagePath) {
    _log('[Storage] upload started → $storagePath');
  }

  static void completed(String storagePath) {
    _log('[Storage] upload completed → $storagePath');
  }

  static void failed(String storagePath, Object error) {
    _log('[Storage] upload failed → $storagePath | $error');
  }

  static void queued(String evidenceId, String storagePath) {
    _log('[Storage] queued retry → evidence=$evidenceId path=$storagePath');
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
