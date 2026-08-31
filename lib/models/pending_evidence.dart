import 'evidence_category.dart';
import 'evidence_metadata.dart';
import 'evidence_type.dart';

/// In-memory draft passed between capture and preview screens.
class PendingEvidence {
  const PendingEvidence({
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.filePath,
    required this.metadata,
    required this.fileSizeBytes,
    this.thumbnailPath,
  });

  final String title;
  final String description;
  final EvidenceCategory category;
  final EvidenceType type;
  final String filePath;
  final String? thumbnailPath;
  final EvidenceMetadata metadata;
  final int fileSizeBytes;
}
