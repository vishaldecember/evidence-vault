import '../models/journey_stage.dart';

/// Quantitative coaching output for the Workspace Incident Journey.
class WorkspaceCoaching {
  const WorkspaceCoaching({
    required this.journeyStatus,
    required this.progressMessage,
    required this.coachingMessage,
  });

  /// EMPTY, BUILDING, or RICH — derived from enrichment metrics.
  final String journeyStatus;

  /// Quantitative progress line; null when no primary evidence exists.
  final String? progressMessage;

  final String coachingMessage;

  /// Backward-compatible alias for presentation widgets.
  String get title => journeyStatus;

  /// Backward-compatible alias for presentation widgets.
  String get message => coachingMessage;
}

/// Single source of truth for Workspace coaching copy and progress.
abstract final class WorkspaceCoachingService {
  static const Duration coachingAnimationDuration =
      Duration(milliseconds: 275);

  static const String emptyMessage =
      'Capture your first evidence and add context to begin building your incident.';

  static const String richCoaching =
      'Recorded context is present on all primary chronology items.';

  static WorkspaceCoaching coachingFor({
    required int primaryEvidenceCount,
    required int enrichedEvidenceCount,
    required int enrichmentPercentage,
    int? primaryWithRecordedContextCount,
  }) {
    if (primaryEvidenceCount == 0) {
      return const WorkspaceCoaching(
        journeyStatus: 'EMPTY',
        progressMessage: null,
        coachingMessage: emptyMessage,
      );
    }

    final contextCount =
        primaryWithRecordedContextCount ?? enrichedEvidenceCount;
    final remaining = primaryEvidenceCount - contextCount;

    if (enrichmentPercentage == 100 &&
        contextCount == primaryEvidenceCount) {
      return WorkspaceCoaching(
        journeyStatus: 'RICH',
        progressMessage:
            'All $primaryEvidenceCount primary chronology items have recorded context.',
        coachingMessage: richCoaching,
      );
    }

    if (enrichmentPercentage == 100) {
      return WorkspaceCoaching(
        journeyStatus: 'RICH',
        progressMessage: contextCount == 0
            ? 'None of $primaryEvidenceCount primary chronology items have recorded location, description, or notes.'
            : '$contextCount of $primaryEvidenceCount primary chronology items have recorded context.',
        coachingMessage: richCoaching,
      );
    }

    return WorkspaceCoaching(
      journeyStatus: 'BUILDING',
      progressMessage: contextCount == 0
          ? 'None of $primaryEvidenceCount primary chronology items have recorded location, description, or notes.'
          : '$contextCount of $primaryEvidenceCount primary chronology items have recorded context.',
      coachingMessage: remaining <= 0
          ? 'Recorded context is present. Enrichment coverage is still incomplete.'
          : 'Consider adding location, description, or notes to the remaining $remaining primary chronology items.',
    );
  }

  /// Coaching copy for inactive timeline stages in the Incident Journey card.
  static String messageForStage(JourneyStage stage) {
    return switch (stage) {
      JourneyStage.empty => emptyMessage,
      JourneyStage.building =>
        'Consider adding location, description, or notes to primary chronology items that have none recorded.',
      JourneyStage.rich => richCoaching,
      JourneyStage.reflective =>
        'Add reflections to capture what this incident means for you.',
    };
  }

  /// Organize-stage coaching — organiser guidance, not investigation prompts.
  ///
  /// Reuses enrichment metrics from [base]; only presentation copy changes.
  static WorkspaceCoaching organizeCoachingFrom(
    WorkspaceCoaching base, {
    required int relationshipGroupCount,
  }) {
    final hasGroups = relationshipGroupCount > 0;
    final coachingMessage = switch (base.journeyStatus) {
      'EMPTY' =>
        'Capture evidence first, then build your first relationship group.',
      'RICH' => hasGroups
          ? 'Consider creating a witness group for people in this record.'
          : 'Build your first relationship group from related files.',
      _ => hasGroups
          ? 'Connect matching evidence and keep organising your groups.'
          : 'Group related photos and connect matching evidence.',
    };

    return WorkspaceCoaching(
      journeyStatus: base.journeyStatus,
      progressMessage: base.progressMessage,
      coachingMessage: coachingMessage,
    );
  }

  /// Inactive-stage copy on the Organize Records card.
  static String organizeMessageForStage(JourneyStage stage) {
    return switch (stage) {
      JourneyStage.empty =>
        'Build your first relationship group after you capture evidence.',
      JourneyStage.building =>
        'Group related photos and connect matching evidence.',
      JourneyStage.rich =>
        'Related files found — connect them into relationship groups.',
      JourneyStage.reflective =>
        'Add reflections that help organise what this record means.',
    };
  }
}
