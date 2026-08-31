import 'package:uuid/uuid.dart';

import '../../domain/trust_package/trust_package.dart';
import '../../models/trust_package_share_link.dart';
import '../../repositories/trust_package_share_store.dart';
import 'trust_package_export_metadata.dart';

/// Secure sharing framework for Trust Package distribution.
///
/// Designed for future authentication — links are registered locally for now.
class TrustPackageShareService {
  const TrustPackageShareService();

  static const _uuid = Uuid();

  TrustPackageShareLink createShareLink(
    TrustPackage package, {
    TrustPackageShareSettings settings = const TrustPackageShareSettings(),
  }) {
    final packageId = _uuid.v4();
    final shareId = _uuid.v4();
    final shareUrl = _buildShareUrl(packageId);

    final link = TrustPackageShareLink(
      shareId: shareId,
      packageId: packageId,
      trustPackageId: package.metadata.trustPackageId,
      packageName: package.incidentSummary.incidentName,
      packageVersion: package.metadata.packageVersion,
      generatedAt: package.metadata.generatedAt,
      createdAt: DateTime.now(),
      viewOnly: settings.viewOnly,
      expiresAt: settings.expiresAt,
      recipientNotes: settings.recipientNotes,
      shareUrl: shareUrl,
    );

    TrustPackageShareStore.add(link);
    return link;
  }

  TrustPackageShareLink? findByPackageId(String packageId) {
    return TrustPackageShareStore.findByPackageId(packageId);
  }

  String _buildShareUrl(String packageId) {
    final incidentIdPlaceholder = 'secure-share';
    return 'https://evidencevault.app/share/$incidentIdPlaceholder/$packageId';
  }

  String originatingIncidentId(TrustPackage package) {
    return TrustPackageExportMetadata.originatingIncidentId(package);
  }
}
