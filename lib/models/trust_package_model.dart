import 'reflection_model.dart';
import 'story_model.dart';
import 'timeline_item_model.dart';
import 'verification_model.dart';
import 'workspace_evidence_item.dart';

/// Canonical presentation model for sharing a preserved incident.
///
/// Assembles existing information only — nothing is generated or altered.
/// Extension points reserved for PDF, court bundle, insurance submission,
/// legal export, secure sharing, encryption, and digital signatures.
class TrustPackageModel {
  const TrustPackageModel({
    this.incidentSummary,
    required this.story,
    this.timeline = const [],
    this.evidence = const [],
    this.context = const [],
    this.linkedEvidence = const [],
    this.reflections = const [],
    required this.integrityVerified,
    required this.integrityExplanation,
    required this.verification,
  });

  final String? incidentSummary;
  final StoryModel story;
  final List<TimelineItemModel> timeline;
  final List<WorkspaceEvidenceItem> evidence;
  final List<StoryContextGroup> context;
  final List<StoryLinkedEntry> linkedEvidence;
  final List<ReflectionModel> reflections;
  final bool integrityVerified;
  final String integrityExplanation;
  final VerificationModel verification;

  bool get isEmpty =>
      incidentSummary == null &&
      story.isEmpty &&
      timeline.isEmpty &&
      evidence.isEmpty &&
      context.isEmpty &&
      linkedEvidence.isEmpty &&
      reflections.isEmpty;

  bool get hasIncidentSummary =>
      incidentSummary != null && incidentSummary!.isNotEmpty;

  bool get hasStory => !story.isEmpty;

  bool get hasTimeline => timeline.isNotEmpty;

  bool get hasEvidence => evidence.isNotEmpty;

  bool get hasContext => context.isNotEmpty;

  bool get hasLinkedEvidence => linkedEvidence.isNotEmpty;

  bool get hasReflections => reflections.isNotEmpty;
}
