import '../domain/trust_package/trust_package.dart';

/// Immutable archived Trust Package snapshot linked to an originating incident.
class TrustPackageArchiveRecord {
  const TrustPackageArchiveRecord({
    required this.archiveId,
    required this.originatingIncidentId,
    required this.packageVersion,
    required this.generatedAt,
    required this.generatedBy,
    required this.archivedAt,
    required this.snapshot,
    this.archiveFilePath,
  });

  final String archiveId;
  final String originatingIncidentId;
  final String packageVersion;
  final DateTime generatedAt;
  final String generatedBy;
  final DateTime archivedAt;
  final TrustPackage snapshot;
  final String? archiveFilePath;

  Map<String, dynamic> toJson(Map<String, dynamic> Function(TrustPackage) serialize) {
    return {
      'archiveId': archiveId,
      'originatingIncidentId': originatingIncidentId,
      'packageVersion': packageVersion,
      'generatedAt': generatedAt.toIso8601String(),
      'generatedBy': generatedBy,
      'archivedAt': archivedAt.toIso8601String(),
      'archiveFilePath': archiveFilePath,
      'snapshot': serialize(snapshot),
    };
  }
}
