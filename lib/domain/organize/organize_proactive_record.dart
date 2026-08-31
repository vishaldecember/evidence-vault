import '../../models/workspace_evidence_item.dart';
import '../evidence/evidence_temporal_intent.dart';
import 'organize_chronology_eligibility.dart';

/// Derived Organize presentation for an explicit chronological Voice/Text
/// that was recorded before later chronological Photo/Video.
///
/// Record time is not event time. Does not write chronology, relationships,
/// placement, or persistence fields.
abstract final class OrganizeProactiveRecord {
  static const caption = 'Recorded before later evidence';

  /// True when [item] is explicit chronological Voice/Text whose record
  /// instant strictly precedes a later chronological Photo/Video in the
  /// same incident. Null and context intent never qualify.
  static bool isPriorObservation({
    required WorkspaceEvidenceItem item,
    required Iterable<WorkspaceEvidenceItem> incidentEvidence,
  }) {
    if (item.temporalIntent != EvidenceTemporalIntent.chronological) {
      return false;
    }
    if (item.kind != WorkspaceEvidenceKind.voice &&
        item.kind != WorkspaceEvidenceKind.note) {
      return false;
    }
    final incidentId = item.incidentId.trim();
    if (incidentId.isEmpty) {
      return false;
    }
    final priorInstant = OrganizeChronologyEligibilityPolicy.fallbackInstant(
      item,
    );
    for (final other in incidentEvidence) {
      if (other.id == item.id) {
        continue;
      }
      if (!other.belongsToIncident(incidentId)) {
        continue;
      }
      if (!_isLaterChronologicalVisual(other, priorInstant)) {
        continue;
      }
      return true;
    }
    return false;
  }

  static bool _isLaterChronologicalVisual(
    WorkspaceEvidenceItem other,
    DateTime priorInstant,
  ) {
    if (other.kind != WorkspaceEvidenceKind.image &&
        other.kind != WorkspaceEvidenceKind.video) {
      return false;
    }
    if (other.temporalIntent == EvidenceTemporalIntent.context) {
      return false;
    }
    return OrganizeChronologyEligibilityPolicy.fallbackInstant(other)
        .isAfter(priorInstant);
  }
}
