/// Immutable chronological anchor for one [CapturedEvidence] item.
///
/// Timeline order is determined exclusively by [sequenceOrder] and [anchoredAt],
/// never by UI sorting or [lastPreservedAt] projections.
class TimelineAnchor {
  const TimelineAnchor({
    required this.id,
    required this.incidentId,
    required this.capturedEvidenceId,
    required this.anchoredAt,
    required this.sequenceOrder,
  });

  final String id;
  final String incidentId;
  final String capturedEvidenceId;
  final DateTime anchoredAt;
  final int sequenceOrder;
}
