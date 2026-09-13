import '../../domain/evidence/evidence_sync_status.dart';
import '../storage/evidence_upload_coordinator.dart';
import '../sync/evidence_sync_manager.dart';
import 'capture_job.dart';

/// Uploads media to Firebase Storage via [EvidenceUploadCoordinator].
class UploadJob extends CaptureJob {
  @override
  String get name => 'UploadJob';

  @override
  Future<void> run(CaptureJobContext context) async {
    context.controller.updateLifecycleStatus(
      evidenceId: context.evidenceId,
      status: EvidenceSyncStatus.uploading,
    );
    await EvidenceSyncManager.instance.markUploading(context.evidenceId);

    final coordinator =
        context.uploadCoordinator ?? EvidenceUploadCoordinator.instance;
    final device = await EvidenceUploadCoordinator.collectDeviceContext();
    context.deviceModel = device.deviceModel;
    context.latitude = device.latitude;
    context.longitude = device.longitude;

    final result = await coordinator.uploadCapturedMedia(
      evidenceId: context.evidenceId,
      incidentId: context.incidentId,
      localFilePath: context.localFilePath,
      mode: context.mode,
      deviceModel: device.deviceModel,
      latitude: device.latitude,
      longitude: device.longitude,
      captureTime: DateTime.now(),
    );

    if (result == null) {
      context.failed = true;
      context.error = 'Upload failed.';
      return;
    }
    context.uploadResult = result;
    context.controller.updateLifecycleStatus(
      evidenceId: context.evidenceId,
      status: EvidenceSyncStatus.synced,
      uploadProgress: 1,
      force: true,
    );
  }
}
