import 'capture_session.dart';
import 'capture_session_status.dart';

/// Read-only rollup for a [CaptureSession] (Sprint 6C Task 2).
class CaptureSessionSummary {
  const CaptureSessionSummary({
    required this.sessionId,
    required this.incidentId,
    required this.status,
    required this.startedAt,
    required this.evidenceCount,
    required this.photoCount,
    required this.videoCount,
    required this.voiceCount,
    required this.noteCount,
    required this.fileCount,
    required this.duration,
    this.endedAt,
  });

  final String sessionId;
  final String incidentId;
  final CaptureSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration duration;
  final int evidenceCount;
  final int photoCount;
  final int videoCount;
  final int voiceCount;
  final int noteCount;
  final int fileCount;

  int get mediaCount => photoCount + videoCount + voiceCount + fileCount;

  factory CaptureSessionSummary.fromSession(
    CaptureSession session, {
    int photoCount = 0,
    int videoCount = 0,
    int voiceCount = 0,
    int noteCount = 0,
    int fileCount = 0,
    DateTime? now,
  }) {
    final end = session.endedAt ?? now ?? DateTime.now();
    final duration = end.difference(session.startedAt);
    return CaptureSessionSummary(
      sessionId: session.id,
      incidentId: session.incidentId,
      status: session.status,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      duration: duration.isNegative ? Duration.zero : duration,
      evidenceCount: session.evidenceIds.length,
      photoCount: photoCount,
      videoCount: videoCount,
      voiceCount: voiceCount,
      noteCount: noteCount,
      fileCount: fileCount,
    );
  }
}
