/// Result of a successful Firebase Storage upload.
class StorageUploadResult {
  const StorageUploadResult({
    required this.storagePath,
    required this.downloadUrl,
    required this.fileSize,
    required this.contentType,
    this.thumbnailUrl,
  });

  final String storagePath;
  final String downloadUrl;
  final int fileSize;
  final String contentType;

  /// Optional compressed preview URL (photos).
  final String? thumbnailUrl;

  StorageUploadResult copyWith({
    String? storagePath,
    String? downloadUrl,
    int? fileSize,
    String? contentType,
    String? thumbnailUrl,
  }) {
    return StorageUploadResult(
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      contentType: contentType ?? this.contentType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
