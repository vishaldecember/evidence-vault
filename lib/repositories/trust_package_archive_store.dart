import '../models/trust_package_archive_record.dart';

/// In-memory archive index — immutable snapshots linked to incidents.
abstract final class TrustPackageArchiveStore {
  static final List<TrustPackageArchiveRecord> _records = [];

  static List<TrustPackageArchiveRecord> get all =>
      List.unmodifiable(_records);

  static List<TrustPackageArchiveRecord> forIncident(String incidentId) {
    return _records
        .where((record) => record.originatingIncidentId == incidentId)
        .toList(growable: false);
  }

  static void add(TrustPackageArchiveRecord record) {
    _records.add(record);
  }

  static void removeForIncident(String incidentId) {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    _records.removeWhere((record) => record.originatingIncidentId == id);
  }

  static void clearAll() {
    _records.clear();
  }

  static void replaceAll(List<TrustPackageArchiveRecord> records) {
    _records
      ..clear()
      ..addAll(records);
  }

  static void resetForTests() {
    _records.clear();
  }
}
