/// Lifecycle for a [CaptureSession] — one period of active evidence collection.
enum CaptureSessionStatus {
  active,
  paused,
  completed,
  archived;

  String get label => switch (this) {
        CaptureSessionStatus.active => 'Active',
        CaptureSessionStatus.paused => 'Paused',
        CaptureSessionStatus.completed => 'Completed',
        CaptureSessionStatus.archived => 'Archived',
      };

  /// Wire / persistence name (uppercase per Sprint 6C domain contract).
  String get wireName => name.toUpperCase();

  static CaptureSessionStatus fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return CaptureSessionStatus.active;
    }
    final normalized = raw.trim().toLowerCase();
    return CaptureSessionStatus.values.firstWhere(
      (value) => value.name == normalized,
      orElse: () => CaptureSessionStatus.active,
    );
  }
}
