/// Secure share link for a Trust Package — designed for future authentication.
class TrustPackageShareLink {
  const TrustPackageShareLink({
    required this.shareId,
    required this.packageId,
    required this.trustPackageId,
    required this.packageName,
    required this.packageVersion,
    required this.generatedAt,
    required this.createdAt,
    required this.viewOnly,
    this.expiresAt,
    this.recipientNotes,
    this.shareUrl,
  });

  final String shareId;
  final String packageId;
  final String trustPackageId;
  final String packageName;
  final String packageVersion;
  final DateTime generatedAt;
  final DateTime createdAt;
  final bool viewOnly;
  final DateTime? expiresAt;
  final String? recipientNotes;
  final String? shareUrl;

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return DateTime.now().isAfter(expiry);
  }

  Map<String, dynamic> toJson() {
    return {
      'shareId': shareId,
      'packageId': packageId,
      'trustPackageId': trustPackageId,
      'packageName': packageName,
      'packageVersion': packageVersion,
      'generatedAt': generatedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'viewOnly': viewOnly,
      'expiresAt': expiresAt?.toIso8601String(),
      'recipientNotes': recipientNotes,
      'shareUrl': shareUrl,
    };
  }
}

/// Settings captured when creating a secure share link.
class TrustPackageShareSettings {
  const TrustPackageShareSettings({
    this.recipientNotes,
    this.expiresAt,
    this.viewOnly = true,
  });

  final String? recipientNotes;
  final DateTime? expiresAt;
  final bool viewOnly;
}
