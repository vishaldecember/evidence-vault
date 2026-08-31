/// Structured narrative event — a traceable reconstruction section.
///
/// Narrative events are projections over incident evidence. Persisted fields
/// are investigator-authored metadata and references only; evidence is never
/// duplicated.
class NarrativeEvent {
  const NarrativeEvent({
    required this.id,
    required this.incidentId,
    required this.sortOrder,
    required this.title,
    this.summary,
    required this.timelineAnchorEvidenceId,
    this.relationshipGroupIds = const [],
    this.reconstructionNoteIds = const [],
    this.supportingEvidenceIds = const [],
    this.titleCustomized = false,
    this.summaryCustomized = false,
  });

  static const int maxSummaryLength = 500;
  static const String defaultTitlePrefix = 'Event';

  final String id;
  final String incidentId;
  final int sortOrder;
  final String title;
  final String? summary;

  /// Primary timeline anchor reference — captured evidence identifier.
  final String timelineAnchorEvidenceId;

  /// Traceability references — never duplicate evidence payloads.
  final List<String> relationshipGroupIds;
  final List<String> reconstructionNoteIds;
  final List<String> supportingEvidenceIds;
  final bool titleCustomized;
  final bool summaryCustomized;

  bool get hasSummary => summary != null && summary!.trim().isNotEmpty;

  /// Manual narrative beat with no direct captured-evidence anchor.
  bool get isInvestigatorAdded => timelineAnchorEvidenceId.trim().isEmpty;

  bool get isDefaultTitle =>
      !titleCustomized &&
      title.startsWith(defaultTitlePrefix) &&
      RegExp(r'^Event \d+$').hasMatch(title);

  NarrativeEvent copyWith({
    int? sortOrder,
    String? title,
    String? summary,
    String? timelineAnchorEvidenceId,
    List<String>? relationshipGroupIds,
    List<String>? reconstructionNoteIds,
    List<String>? supportingEvidenceIds,
    bool? titleCustomized,
    bool? summaryCustomized,
    bool clearSummary = false,
  }) {
    return NarrativeEvent(
      id: id,
      incidentId: incidentId,
      sortOrder: sortOrder ?? this.sortOrder,
      title: title ?? this.title,
      summary: clearSummary ? null : (summary ?? this.summary),
      timelineAnchorEvidenceId:
          timelineAnchorEvidenceId ?? this.timelineAnchorEvidenceId,
      relationshipGroupIds: relationshipGroupIds ?? this.relationshipGroupIds,
      reconstructionNoteIds:
          reconstructionNoteIds ?? this.reconstructionNoteIds,
      supportingEvidenceIds:
          supportingEvidenceIds ?? this.supportingEvidenceIds,
      titleCustomized: titleCustomized ?? this.titleCustomized,
      summaryCustomized: summaryCustomized ?? this.summaryCustomized,
    );
  }
}
