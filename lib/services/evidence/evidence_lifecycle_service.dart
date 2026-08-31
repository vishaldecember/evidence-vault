import 'package:flutter/foundation.dart';

import '../../domain/evidence/evidence_record.dart';
import '../../domain/evidence/evidence_sync_status.dart';
import '../../repositories/evidence_repository.dart';

/// Domain façade for evidence lifecycle (Sprint 6A).
///
/// UI and future Dual Queue Sync Manager (6B) observe status here — never by
/// interpreting raw Firebase callbacks.
class EvidenceLifecycleService extends ChangeNotifier {
  EvidenceLifecycleService(this._repository);

  final EvidenceRepository _repository;

  List<EvidenceRecord> get records => _repository.evidenceRecords;

  EvidenceRecord? byId(String evidenceId) => _repository.recordById(evidenceId);

  EvidenceSyncStatus? statusOf(String evidenceId) =>
      _repository.recordById(evidenceId)?.syncStatus;

  /// Creates are performed by CaptureEngine → repository; this service only
  /// exposes reads + explicit lifecycle updates for orchestration layers.
  bool updateStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  }) {
    final ok = _repository.updateLifecycleStatus(
      evidenceId: evidenceId,
      status: status,
      uploadProgress: uploadProgress,
      retryCount: retryCount,
      force: force,
    );
    if (ok) {
      notifyListeners();
    }
    return ok;
  }

  void notifyEvidenceChanged() => notifyListeners();
}
