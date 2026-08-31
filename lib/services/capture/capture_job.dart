import '../../domain/evidence/evidence_provenance_event.dart';
import '../../domain/evidence/evidence_sync_status.dart';
import '../../models/workspace_capture_mode.dart';
import '../storage/capture_media_service.dart';
import '../storage/evidence_upload_coordinator.dart';
import '../storage/storage_upload_result.dart';
import 'capture_provenance.dart';

/// Host surface for capture background jobs (avoids repository interface changes).
abstract class CapturePipelineHost {
  String get captureIncidentId;

  /// Optional display title for local incident pointer persistence.
  String get captureIncidentTitle => '';

  /// Capture-time device/location. Default no-op for test fakes.
  void applyCaptureProvenance({
    required String evidenceId,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {}

  /// Records SHA-256 of the preserved original. Default no-op for test fakes.
  void recordContentHash({
    required String evidenceId,
    required String hash,
  }) {}

  /// Appends one provenance event. Default no-op for test fakes.
  void appendEvidenceProvenance(EvidenceProvenanceEvent event) {}

  /// Last capture-time provenance snapshot. Default no-op for test fakes.
  void rememberCaptureProvenance(CaptureProvenanceSnapshot snapshot) {}

  void attachCaptureThumbnail({
    required String evidenceId,
    required String filePath,
    String? fileName,
    String? thumbnailPath,
    int? fileSizeBytes,
  });

  void scheduleCaptureMetadataPersist();

  void completeCaptureUpload({
    required String evidenceId,
    required String storagePath,
    required String downloadUrl,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    String? deviceModel,
    double? latitude,
    double? longitude,
  });

  void failCaptureUpload(String evidenceId);

  /// Domain lifecycle transition (Sprint 6A). Default no-op for test fakes.
  bool updateLifecycleStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  }) =>
      false;

  /// Removes a just-created local row when durable media or ownership fails.
  void abandonFailedLocalCapture(String evidenceId) {}
}

/// Shared context for a single capture's background job pipeline.
class CaptureJobContext {
  CaptureJobContext({
    required this.evidenceId,
    required this.incidentId,
    required this.mode,
    required this.media,
    required this.controller,
    this.uploadCoordinator,
  });

  final String evidenceId;
  final String incidentId;
  final WorkspaceCaptureMode mode;
  CapturedMediaFile media;
  final CapturePipelineHost controller;
  final EvidenceUploadCoordinator? uploadCoordinator;

  String get localFilePath => media.localPath;

  String? thumbnailPath;
  StorageUploadResult? uploadResult;
  Object? error;
  bool failed = false;
  String? deviceModel;
  double? latitude;
  double? longitude;
}

/// Lightweight background unit for the Capture Engine pipeline.
abstract class CaptureJob {
  String get name;

  Future<void> run(CaptureJobContext context);
}

/// Reserved AI / intelligence step — marks PROCESSING then READY until
/// enrichment workers exist (Sprint 6B+).
class AiPreparationJob extends CaptureJob {
  @override
  String get name => 'AiPreparationJob';

  @override
  Future<void> run(CaptureJobContext context) async {
    // Enter processing briefly so lifecycle graph is exercised; READY follows
    // because full AI pipeline is not yet active.
    context.controller.updateLifecycleStatus(
      evidenceId: context.evidenceId,
      status: EvidenceSyncStatus.processing,
      force: true,
    );
    context.controller.updateLifecycleStatus(
      evidenceId: context.evidenceId,
      status: EvidenceSyncStatus.ready,
      force: true,
    );
  }
}
