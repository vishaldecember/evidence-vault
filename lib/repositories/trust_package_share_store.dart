import '../models/trust_package_share_link.dart';

/// In-memory secure share link registry — supports future authentication layer.
abstract final class TrustPackageShareStore {
  static final List<TrustPackageShareLink> _links = [];

  static List<TrustPackageShareLink> get all => List.unmodifiable(_links);

  static TrustPackageShareLink? findByShareId(String shareId) {
    for (final link in _links) {
      if (link.shareId == shareId) {
        return link;
      }
    }
    return null;
  }

  static TrustPackageShareLink? findByPackageId(String packageId) {
    for (final link in _links) {
      if (link.packageId == packageId) {
        return link;
      }
    }
    return null;
  }

  static void add(TrustPackageShareLink link) {
    _links.add(link);
  }

  static void clearAll() {
    _links.clear();
  }

  static void replaceAll(List<TrustPackageShareLink> links) {
    _links
      ..clear()
      ..addAll(links);
  }

  static void resetForTests() {
    _links.clear();
  }
}
