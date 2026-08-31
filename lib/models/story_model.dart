import 'linked_evidence_item.dart';
import 'reflection_model.dart';
import 'timeline_item_model.dart';
import 'workspace_evidence_item.dart';

/// Context items grouped beneath their parent preserved evidence.
class StoryContextGroup {
  const StoryContextGroup({
    required this.parentEvidence,
    required this.contextItems,
  });

  final WorkspaceEvidenceItem parentEvidence;
  final List<WorkspaceEvidenceItem> contextItems;
}

/// One linked relationship between two preserved artifacts.
class StoryLinkedEntry {
  const StoryLinkedEntry({
    required this.link,
    required this.sourceEvidence,
  });

  final LinkedEvidenceItem link;
  final WorkspaceEvidenceItem sourceEvidence;
}

/// Deterministic assembly of preserved information into a coherent narrative.
///
/// Every field is traceable to existing data — nothing is fabricated.
/// Extension points reserved for AI refinement, legal/insurance export,
/// court packages, and PDF generation.
class StoryModel {
  const StoryModel({
    this.summary,
    this.timeline = const [],
    this.evidenceHighlights = const [],
    this.supportingContext = const [],
    this.linkedEvidence = const [],
    this.reflections = const [],
  });

  final String? summary;
  final List<TimelineItemModel> timeline;
  final List<WorkspaceEvidenceItem> evidenceHighlights;
  final List<StoryContextGroup> supportingContext;
  final List<StoryLinkedEntry> linkedEvidence;
  final List<ReflectionModel> reflections;

  bool get isEmpty =>
      summary == null &&
      timeline.isEmpty &&
      evidenceHighlights.isEmpty &&
      supportingContext.isEmpty &&
      linkedEvidence.isEmpty &&
      reflections.isEmpty;

  bool get hasSummary => summary != null && summary!.isNotEmpty;

  bool get hasTimeline => timeline.isNotEmpty;

  bool get hasEvidenceHighlights => evidenceHighlights.isNotEmpty;

  bool get hasSupportingContext => supportingContext.isNotEmpty;

  bool get hasLinkedEvidence => linkedEvidence.isNotEmpty;

  bool get hasReflections => reflections.isNotEmpty;
}
