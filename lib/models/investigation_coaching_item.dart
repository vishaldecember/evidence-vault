import 'coaching_statement_kind.dart';
import 'investigation_coaching_category.dart';
import 'investigation_coaching_priority.dart';
import 'investigation_coaching_target.dart';

/// One evidence-based coaching insight for the Investigation Workspace.
class InvestigationCoachingItem {
  const InvestigationCoachingItem({
    required this.fingerprint,
    required this.category,
    required this.observation,
    required this.suggestedAction,
    required this.priority,
    required this.target,
    this.targetAnchorId,
    this.targetEventId,
    this.targetEvidenceId,
    this.kind = CoachingStatementKind.suggestion,
    this.relatedEvidenceIds = const [],
  });

  /// Stable key for dismiss tracking — regenerated when underlying conditions persist.
  final String fingerprint;

  final InvestigationCoachingCategory category;
  final String observation;
  final String suggestedAction;
  final InvestigationCoachingPriority priority;
  final InvestigationCoachingTarget target;
  final CoachingStatementKind kind;

  /// Optional deep-link identifiers for Review navigation.
  final String? targetAnchorId;
  final String? targetEventId;
  final String? targetEvidenceId;

  /// Evidence the coach already identified as relevant — not a new conclusion.
  final List<String> relatedEvidenceIds;

  /// IDs Review should halo, derived from existing coach references only.
  Set<String> get reviewEvidenceIds => {
        ...relatedEvidenceIds,
        ?targetEvidenceId,
        ?targetAnchorId,
      };
}
