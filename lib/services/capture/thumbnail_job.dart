import 'package:flutter/foundation.dart';

import '../../models/workspace_capture_mode.dart';
import '../persistence/media_preprocess_service.dart';
import '../storage/evidence_upload_coordinator.dart';
import '../storage/evidence_upload_models.dart';
import '../storage/local_evidence_cache.dart';
import 'capture_job.dart';

/// Generates a local preview thumbnail without blocking capture.
class ThumbnailJob extends CaptureJob {
  @override
  String get name => 'ThumbnailJob';

  /// Test seam — must still durableize whatever path is returned.
  @visibleForTesting
  static Future<String?> Function({
    required WorkspaceCaptureMode mode,
    required String localFilePath,
  })? debugPreviewThumbnailForMode;

  @override
  Future<void> run(CaptureJobContext context) async {
    try {
      final coordinator =
          context.uploadCoordinator ?? EvidenceUploadCoordinator.instance;
      coordinator.announceStatus(
        context.evidenceId,
        EvidenceUploadStatus.processing,
        fraction: 0.05,
      );

      final generated = await (debugPreviewThumbnailForMode ??
          MediaPreprocessService.previewThumbnailForMode)(
        mode: context.mode,
        localFilePath: context.localFilePath,
      );
      if (generated == null || generated.isEmpty) {
        return;
      }

      final durable = await LocalEvidenceCache.durableizeThumbnail(
        incidentId: context.incidentId,
        evidenceId: context.evidenceId,
        thumbnailPath: generated,
      );
      if (durable == null || durable.isEmpty) {
        return;
      }

      context.thumbnailPath = durable;
      context.controller.attachCaptureThumbnail(
        evidenceId: context.evidenceId,
        filePath: context.localFilePath,
        fileName: context.media.fileName,
        thumbnailPath: durable,
        fileSizeBytes: context.media.fileSizeBytes,
      );
    } catch (error) {
      debugPrint('[ThumbnailJob] skipped: $error');
    }
  }
}
