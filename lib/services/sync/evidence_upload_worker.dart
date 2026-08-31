import '../storage/storage_upload_result.dart';
import 'evidence_sync_queue.dart';

/// Injectable upload function for [EvidenceSyncManager] workers / tests.
typedef EvidenceSyncUploadFn = Future<StorageUploadResult?> Function(
  EvidenceSyncQueueItem item,
);

/// One parallel upload slot in the FAST_SYNC worker pool.
///
/// Workers are not hard-coded Firebase functions — the pool size is controlled
/// by [EvidenceSyncManager.maxConcurrentUploads].
class EvidenceUploadWorker {
  EvidenceUploadWorker({required this.id});

  final int id;
  bool busy = false;
  String? currentEvidenceId;

  bool get isIdle => !busy;
}
