import '../../domain/trust_package/trust_package.dart';

/// Embedded export metadata and integrity notice content.
abstract final class TrustPackageExportMetadata {
  static const integrityNoticeTitle = 'Integrity Notice';

  static const integrityNoticeBody =
      'This Trust Package was generated directly from the Incident Aggregate.\n'
      'The package contains evidence references, chronological reconstruction, '
      'relationship analysis and investigator-authored narrative.\n'
      'My Truth does not alter investigator observations.';

  static Map<String, String> embedded(TrustPackage package) {
    final metadata = package.metadata;
    return {
      'trustPackageId': metadata.trustPackageId,
      'packageVersion': metadata.packageVersion,
      'generatedTimestamp': metadata.generatedAt.toIso8601String(),
      'incidentVersion': metadata.incidentVersion,
      'generatedBy': metadata.generatedBy,
      'incidentName': package.incidentSummary.incidentName,
    };
  }

  static String originatingIncidentId(TrustPackage package) {
    final trustPackageId = package.metadata.trustPackageId;
    final separatorIndex = trustPackageId.indexOf('@');
    if (separatorIndex <= 0) {
      return trustPackageId;
    }
    return trustPackageId.substring(0, separatorIndex);
  }
}
