import 'capture_job.dart';
import '../sync/evidence_sync_manager.dart';

/// Applies upload success/failure onto local evidence and notifies the UI.
///
/// Sprint 6B Task 3: local files are retained after SYNCED (no reclaim).
/// Prefer [EvidenceSyncManager] workers; this job remains for legacy callers.
class SyncCompletionJob extends CaptureJob {
  @override
  String get name => 'SyncCompletionJob';

  @override
  Future<void> run(CaptureJobContext context) async {
    if (context.failed || context.uploadResult == null) {
      context.controller.failCaptureUpload(context.evidenceId);
      await EvidenceSyncManager.instance
          .markFailedFromCapturePipeline(context.evidenceId);
      return;
    }

    final result = context.uploadResult!;

    context.controller.completeCaptureUpload(
      evidenceId: context.evidenceId,
      storagePath: result.storagePath,
      downloadUrl: result.downloadUrl,
      mimeType: result.contentType,
      fileSizeBytes: result.fileSize,
      thumbnailUrl: result.thumbnailUrl,
      deviceModel: context.deviceModel,
      latitude: context.latitude,
      longitude: context.longitude,
    );

    await EvidenceSyncManager.instance.markSyncedFromCapturePipeline(
      evidenceId: context.evidenceId,
      incidentId: context.incidentId,
      cloudPath: result.storagePath,
      downloadUrl: result.downloadUrl,
    );
    // Intentionally no LocalEvidenceCache.reclaimSynced — cache retained.
  }
}
