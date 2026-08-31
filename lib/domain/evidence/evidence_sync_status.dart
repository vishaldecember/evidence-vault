/// Canonical evidence lifecycle states (Sprint 6A).
///
/// Domain source of truth for Workspace visibility and sync orchestration.
/// UI must not infer status from Firebase callbacks — read [EvidenceSyncStatus]
/// via the evidence repository / lifecycle service.
///
/// Wire compatibility: Firestore may still contain Sprint 4D names
/// (`localOnly`, `pendingSync`, `syncing`, `synchronized`, `syncFailed`).
/// Always decode with [EvidenceSyncStatus.fromWire] and encode with [wireName].
enum EvidenceSyncStatus {
  /// Evidence exists only on device. Workspace shows it immediately.
  localCaptured,

  /// Waiting for Firebase Storage / metadata synchronization.
  queuedForUpload,

  /// Binary (and/or metadata) upload actively running.
  uploading,

  /// File + metadata successfully exist in cloud.
  synced,

  /// AI enrichment, relationships, thumbnails, transcripts, intelligence.
  processing,

  /// Fully available for investigation (sync + processing complete).
  ready,

  /// Upload or processing failed; requires retry.
  failed;

  /// Product-facing label (quiet sync — no upload %).
  String get displayLabel => switch (this) {
        EvidenceSyncStatus.localCaptured => 'Saved',
        EvidenceSyncStatus.queuedForUpload => 'Saved',
        EvidenceSyncStatus.uploading => 'Syncing',
        EvidenceSyncStatus.synced => 'Synced',
        EvidenceSyncStatus.processing => 'Processing',
        EvidenceSyncStatus.ready => 'Ready',
        EvidenceSyncStatus.failed => 'Saved on device',
      };

  bool get isLocalOnly =>
      this == EvidenceSyncStatus.localCaptured ||
      this == EvidenceSyncStatus.queuedForUpload ||
      this == EvidenceSyncStatus.failed;

  bool get isInFlight =>
      this == EvidenceSyncStatus.uploading ||
      this == EvidenceSyncStatus.processing;

  bool get isCloudDurable =>
      this == EvidenceSyncStatus.synced ||
      this == EvidenceSyncStatus.processing ||
      this == EvidenceSyncStatus.ready;

  bool get isTerminalSuccess => this == EvidenceSyncStatus.ready;

  bool get canRetry => this == EvidenceSyncStatus.failed;

  /// Firestore / SharedPreferences wire token (new canonical names).
  String get wireName => name;

  /// Decodes Sprint 6A names and legacy Sprint 4D names.
  static EvidenceSyncStatus fromWire(String? name) {
    if (name == null || name.isEmpty) {
      return EvidenceSyncStatus.localCaptured;
    }
    switch (name) {
      // Legacy Sprint 4D
      case 'localOnly':
        return EvidenceSyncStatus.localCaptured;
      case 'pendingSync':
        return EvidenceSyncStatus.queuedForUpload;
      case 'syncing':
        return EvidenceSyncStatus.uploading;
      case 'synchronized':
        return EvidenceSyncStatus.synced;
      case 'syncFailed':
        return EvidenceSyncStatus.failed;
      default:
        return EvidenceSyncStatus.values.firstWhere(
          (value) => value.name == name,
          orElse: () => EvidenceSyncStatus.localCaptured,
        );
    }
  }
}
