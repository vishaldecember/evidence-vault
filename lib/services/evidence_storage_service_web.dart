import '../models/evidence_record.dart';
import '../models/pending_evidence.dart';
import 'evidence_storage_shared.dart';

abstract final class EvidenceStorageService {
  static List<EvidenceRecord>? _webRecords;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _webRecords = [];
    _initialized = true;
  }

  static Future<List<EvidenceRecord>> getAll() async {
    await _ensureInitialized();
    return EvidenceStorageShared.filterSaved(_webRecords ?? []);
  }

  static Future<EvidenceRecord> save(PendingEvidence pending) async {
    await _ensureInitialized();

    final record = EvidenceStorageShared.recordFromPending(
      pending,
      filePath: pending.filePath,
      thumbnail: pending.thumbnailPath,
    );

    _webRecords!.add(record);
    return record;
  }

  static Future<void> discardTempFile(String filePath) async {}

  static Future<void> clearAll() async {
    await _ensureInitialized();
    _webRecords = [];
  }

  static Future<void> clearTrustPackageExports() async {}

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }
}
