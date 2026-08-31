import 'capture_job.dart';

/// Persists evidence metadata to Firestore after local capture / sync updates.
///
/// Does not block capture — relies on the controller's existing debounced
/// cloud persist path (repository interfaces unchanged).
class FirestoreJob extends CaptureJob {
  @override
  String get name => 'FirestoreJob';

  @override
  Future<void> run(CaptureJobContext context) async {
    context.controller.scheduleCaptureMetadataPersist();
  }
}
