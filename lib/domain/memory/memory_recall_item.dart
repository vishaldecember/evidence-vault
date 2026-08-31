/// Deterministic Memory Recall kinds (Sprint 5D).
///
/// Only types supported by available library data are generated.
enum MemoryRecallType {
  oldIncident,
  unresolvedIncident,
  buildingIncident,
  recentlyChanged,
  relatedIncident,
  recurringContext,
  unreviewedEvidence,
  importantEvidence;

  String get wireName => switch (this) {
        MemoryRecallType.oldIncident => 'OLD_INCIDENT',
        MemoryRecallType.unresolvedIncident => 'UNRESOLVED_INCIDENT',
        MemoryRecallType.buildingIncident => 'BUILDING_INCIDENT',
        MemoryRecallType.recentlyChanged => 'RECENTLY_CHANGED',
        MemoryRecallType.relatedIncident => 'RELATED_INCIDENT',
        MemoryRecallType.recurringContext => 'RECURRING_CONTEXT',
        MemoryRecallType.unreviewedEvidence => 'UNREVIEWED_EVIDENCE',
        MemoryRecallType.importantEvidence => 'IMPORTANT_EVIDENCE',
      };
}

/// Primary CTA for a recall card.
enum MemoryRecallAction {
  reviewIncident,
  viewInvestigation,
  viewEvidence;
}

/// One explainable Memory Recall candidate — always backed by real incident data.
class MemoryRecallItem {
  const MemoryRecallItem({
    required this.id,
    required this.type,
    required this.incidentId,
    required this.title,
    required this.headline,
    required this.reason,
    required this.action,
    required this.score,
    required this.createdAt,
    this.maturityLabel,
    this.evidenceCount,
    this.relationshipCount,
    this.ageLabel,
  });

  /// Stable id for dismiss/snooze (type + incident).
  final String id;
  final MemoryRecallType type;
  final String incidentId;
  final String title;

  /// Short premium line, e.g. "Something you may want to revisit".
  final String headline;

  /// Explainable reason — never an unexplained AI claim.
  final String reason;
  final MemoryRecallAction action;

  /// Internal ranking only — never shown to users.
  final double score;
  final DateTime createdAt;
  final String? maturityLabel;
  final int? evidenceCount;
  final int? relationshipCount;
  final String? ageLabel;

  String get actionLabel => switch (action) {
        MemoryRecallAction.reviewIncident => 'Review Incident',
        MemoryRecallAction.viewInvestigation => 'View Investigation',
        MemoryRecallAction.viewEvidence => 'View Evidence',
      };
}

/// Calendar-month activity summary for Vault "This Month" (incident-focused).
class MemoryMonthSummary {
  const MemoryMonthSummary({
    required this.evidenceCaptured,
    required this.incidentsTouched,
    required this.investigationsStrengthened,
    required this.becameReady,
  });

  final int evidenceCaptured;
  final int incidentsTouched;
  final int investigationsStrengthened;
  final int becameReady;

  bool get isEmpty =>
      evidenceCaptured == 0 &&
      incidentsTouched == 0 &&
      investigationsStrengthened == 0 &&
      becameReady == 0;
}
