/// Summary of an incident in the Library of Truth.
class LibraryIncidentSummary {
  const LibraryIncidentSummary({
    required this.id,
    required this.title,
    required this.evidenceCount,
    required this.contextEnrichedCount,
    required this.integrityVerified,
    required this.lastPreserved,
    this.narrativeCount = 0,
    this.isInProgress = false,
    this.isArchived = false,
    this.isRecentlyDeleted = false,
    this.deletedAt,
    this.coverEvidenceId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final int evidenceCount;
  final int contextEnrichedCount;
  final bool integrityVerified;
  final String lastPreserved;
  final int narrativeCount;
  final bool isInProgress;

  /// Persisted lifecycle — [IncidentStatus.archived]. Same incident, not a copy.
  final bool isArchived;

  /// Persisted lifecycle — Recently Deleted. Same incident, not a copy.
  final bool isRecentlyDeleted;

  /// When the incident entered Recently Deleted. Source of 30-day retention.
  final DateTime? deletedAt;

  /// Optional cover pointer from the Incident document. Not a media path.
  final String? coverEvidenceId;

  /// Raw timestamps for Memory Recall ranking (Sprint 5D) — optional for mocks.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LibraryIncidentSummary copyWith({
    String? id,
    String? title,
    int? evidenceCount,
    int? contextEnrichedCount,
    bool? integrityVerified,
    String? lastPreserved,
    int? narrativeCount,
    bool? isInProgress,
    bool? isArchived,
    bool? isRecentlyDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? coverEvidenceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LibraryIncidentSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      contextEnrichedCount: contextEnrichedCount ?? this.contextEnrichedCount,
      integrityVerified: integrityVerified ?? this.integrityVerified,
      lastPreserved: lastPreserved ?? this.lastPreserved,
      narrativeCount: narrativeCount ?? this.narrativeCount,
      isInProgress: isInProgress ?? this.isInProgress,
      isArchived: isArchived ?? this.isArchived,
      isRecentlyDeleted: isRecentlyDeleted ?? this.isRecentlyDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      coverEvidenceId: coverEvidenceId ?? this.coverEvidenceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
