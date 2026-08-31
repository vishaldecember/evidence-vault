import 'evidence_sync_status.dart';

/// Validates and applies evidence lifecycle transitions (Sprint 6A).
///
/// Illegal transitions are rejected so CaptureEngine / dual-queue (6B) cannot
/// accidentally skip states. UI never drives transitions directly.
abstract final class EvidenceLifecycle {
  /// Allowed next states from [current]. Empty = terminal / no forward edge.
  static Set<EvidenceSyncStatus> allowedTransitions(EvidenceSyncStatus current) {
    return switch (current) {
      EvidenceSyncStatus.localCaptured => {
          EvidenceSyncStatus.queuedForUpload,
          EvidenceSyncStatus.failed,
        },
      EvidenceSyncStatus.queuedForUpload => {
          EvidenceSyncStatus.uploading,
          EvidenceSyncStatus.failed,
          EvidenceSyncStatus.localCaptured,
        },
      EvidenceSyncStatus.uploading => {
          EvidenceSyncStatus.synced,
          EvidenceSyncStatus.failed,
          EvidenceSyncStatus.queuedForUpload,
        },
      EvidenceSyncStatus.synced => {
          EvidenceSyncStatus.processing,
          EvidenceSyncStatus.ready,
        },
      EvidenceSyncStatus.processing => {
          EvidenceSyncStatus.ready,
          EvidenceSyncStatus.failed,
          EvidenceSyncStatus.synced,
        },
      EvidenceSyncStatus.ready => {
          EvidenceSyncStatus.processing,
        },
      EvidenceSyncStatus.failed => {
          EvidenceSyncStatus.queuedForUpload,
          EvidenceSyncStatus.uploading,
          EvidenceSyncStatus.localCaptured,
        },
    };
  }

  static bool canTransition(
    EvidenceSyncStatus from,
    EvidenceSyncStatus to,
  ) {
    if (from == to) return true;
    return allowedTransitions(from).contains(to);
  }

  /// Returns [to] when legal; otherwise keeps [from].
  static EvidenceSyncStatus transitionOrKeep({
    required EvidenceSyncStatus from,
    required EvidenceSyncStatus to,
  }) {
    return canTransition(from, to) ? to : from;
  }
}
