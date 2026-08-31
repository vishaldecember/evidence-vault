import 'workspace_evidence_item.dart';

/// Preserved incident metadata used for cross-incident pattern detection.
///
/// Every field is traceable to preserved information — nothing is inferred.
class LibraryIncidentRecord {
  const LibraryIncidentRecord({
    required this.id,
    required this.title,
    required this.preservedAt,
    this.location,
    this.organisation,
    this.referencedPeople = const [],
    this.evidenceTypes = const [],
  });

  final String id;
  final String title;
  final DateTime preservedAt;
  final String? location;
  final String? organisation;
  final List<String> referencedPeople;
  final List<WorkspaceEvidenceKind> evidenceTypes;
}
