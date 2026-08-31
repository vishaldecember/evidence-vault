import '../models/evidence_record.dart';
import '../models/evidence_status.dart';
import '../models/pending_evidence.dart';

abstract final class EvidenceStorageShared {
  static List<EvidenceRecord> filterSaved(List<EvidenceRecord> records) {
    return records
        .where((record) => record.status == EvidenceStatus.saved)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static bool isImageExtension(String extension) {
    final lower = extension.toLowerCase();
    return lower == '.jpg' || lower == '.jpeg' || lower == '.png';
  }

  static EvidenceRecord recordFromPending(
    PendingEvidence pending, {
    required String filePath,
    String? thumbnail,
  }) {
    return EvidenceRecord(
      id: pending.metadata.evidenceId,
      title: pending.title,
      description: pending.description,
      category: pending.category,
      type: pending.type,
      createdAt: pending.metadata.capturedAt,
      location: pending.metadata.location,
      device: pending.metadata.device,
      filePath: filePath,
      thumbnail: thumbnail,
      status: EvidenceStatus.saved,
      metadata: pending.metadata,
    );
  }
}
