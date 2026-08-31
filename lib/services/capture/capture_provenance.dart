import '../../models/evidence_device.dart';
import '../../models/evidence_location.dart';

/// Outcome of attempting to record location at capture time.
enum CaptureLocationStatus {
  captured,
  servicesDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  temporarilyUnavailable,
  skipped,
}

/// Device + location collected at the capture moment. Not a second evidence store.
class CaptureProvenanceSnapshot {
  const CaptureProvenanceSnapshot({
    required this.device,
    required this.location,
    required this.locationStatus,
  });

  final EvidenceDevice device;
  final EvidenceLocation location;
  final CaptureLocationStatus locationStatus;

  bool get hasCoordinates => location.hasCoordinates;

  bool get shouldPromptForLocation =>
      !hasCoordinates &&
      locationStatus != CaptureLocationStatus.skipped &&
      locationStatus != CaptureLocationStatus.captured;
}
