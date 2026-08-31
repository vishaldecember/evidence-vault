import '../../domain/trust_package/trust_package.dart';

/// Standardised Trust Package export filenames.
abstract final class TrustPackageFilenameService {
  static String baseName(TrustPackage package) {
    final incidentName = _sanitize(package.incidentSummary.incidentName);
    final versionToken = _versionToken(package.metadata.packageVersion);
    final dateToken = _formatDate(package.metadata.generatedAt);
    return '${incidentName}_TrustPackage_${versionToken}_$dateToken';
  }

  static String pdf(TrustPackage package) => '${baseName(package)}.pdf';

  static String archive(TrustPackage package) => '${baseName(package)}.zip';

  static String _sanitize(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    if (sanitized.isEmpty) {
      return 'Incident';
    }
    return sanitized;
  }

  static String _versionToken(String packageVersion) {
    final major = packageVersion.split('.').first;
    if (major.isEmpty) {
      return 'v1';
    }
    return 'v$major';
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}
