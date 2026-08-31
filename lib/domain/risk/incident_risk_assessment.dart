/// Sprint 5E — Risk Coach domain (incident attention, not legal advice).
library;

/// Future incident-specific rule libraries (not used heavily in 5E).
enum IncidentRiskDomain {
  property,
  vehicle,
  bullying,
  workplace,
  travel,
  financial,
  safety,
  other;

  String get wireName => name.toUpperCase();
}

/// Deterministic / future AI risk kinds.
///
/// Only types supported by available data are generated in Sprint 5E.
enum RiskType {
  missingEvidence,
  unresolved,
  contradiction,
  timeSensitive,
  followUp,
  documentationGap,
  relationshipGap,
  pattern,
  potentialEscalation,
  unknown;

  String get wireName => switch (this) {
        RiskType.missingEvidence => 'MISSING_EVIDENCE',
        RiskType.unresolved => 'UNRESOLVED',
        RiskType.contradiction => 'CONTRADICTION',
        RiskType.timeSensitive => 'TIME_SENSITIVE',
        RiskType.followUp => 'FOLLOW_UP',
        RiskType.documentationGap => 'DOCUMENTATION_GAP',
        RiskType.relationshipGap => 'RELATIONSHIP_GAP',
        RiskType.pattern => 'PATTERN',
        RiskType.potentialEscalation => 'POTENTIAL_ESCALATION',
        RiskType.unknown => 'UNKNOWN',
      };

  String get displayLabel => switch (this) {
        RiskType.missingEvidence => 'Missing evidence',
        RiskType.unresolved => 'Unresolved',
        RiskType.contradiction => 'Possible contradiction',
        RiskType.timeSensitive => 'Time-sensitive',
        RiskType.followUp => 'Follow-up',
        RiskType.documentationGap => 'Documentation gap',
        RiskType.relationshipGap => 'Investigation gap',
        RiskType.pattern => 'Pattern',
        RiskType.potentialEscalation => 'Potential escalation',
        RiskType.unknown => 'Potential attention',
      };
}

enum RiskSeverity {
  low,
  medium,
  high,
  critical;

  String get wireName => name.toUpperCase();
}

/// User-facing preference state — incidents themselves are never deleted.
enum RiskAssessmentStatus {
  active,
  dismissed,
  reviewed,
  resolved;

  String get wireName => name;
}

/// Suggested next step — Risk Coach never auto-performs these.
enum RiskRecommendedAction {
  reviewEvidence,
  addEvidence,
  reviewInvestigation,
  addFollowUp,
  dismiss;

  String get label => switch (this) {
        RiskRecommendedAction.reviewEvidence => 'Review Evidence',
        RiskRecommendedAction.addEvidence => 'Add Evidence',
        RiskRecommendedAction.reviewInvestigation => 'Review Investigation',
        RiskRecommendedAction.addFollowUp => 'Add Follow-up',
        RiskRecommendedAction.dismiss => 'Dismiss',
      };
}

/// Minimal follow-up concept — not a task manager (Sprint 5E).
enum FollowUpKind {
  awaitingDocument,
  awaitingWitness,
  awaitingOutcome,
  awaitingResponse,
  needsReview;

  String get label => switch (this) {
        FollowUpKind.awaitingDocument => 'Awaiting document',
        FollowUpKind.awaitingWitness => 'Awaiting witness information',
        FollowUpKind.awaitingOutcome => 'Awaiting outcome',
        FollowUpKind.awaitingResponse => 'Awaiting response',
        FollowUpKind.needsReview => 'Investigation needs review',
      };
}

/// One explainable risk insight — always backed by real incident data.
class IncidentRiskAssessment {
  const IncidentRiskAssessment({
    required this.id,
    required this.incidentId,
    required this.riskType,
    required this.severity,
    required this.confidence,
    required this.reason,
    required this.recommendedAction,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sourceEvidenceIds = const [],
    this.sourceLabel,
    this.followUpKind,
    this.domainHint = IncidentRiskDomain.other,
  });

  final String id;
  final String incidentId;
  final RiskType riskType;
  final RiskSeverity severity;

  /// 0.0–1.0 — meaningful for ranking / future AI; UI may omit when low.
  final double confidence;

  /// Explainable reason — never an unexplained AI claim.
  final String reason;
  final List<String> sourceEvidenceIds;
  final RiskRecommendedAction recommendedAction;
  final RiskAssessmentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional calm source line, e.g. "Voice Note · 14 Aug".
  final String? sourceLabel;
  final FollowUpKind? followUpKind;
  final IncidentRiskDomain domainHint;

  IncidentRiskAssessment copyWith({
    RiskAssessmentStatus? status,
    DateTime? updatedAt,
  }) {
    return IncidentRiskAssessment(
      id: id,
      incidentId: incidentId,
      riskType: riskType,
      severity: severity,
      confidence: confidence,
      reason: reason,
      sourceEvidenceIds: sourceEvidenceIds,
      recommendedAction: recommendedAction,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceLabel: sourceLabel,
      followUpKind: followUpKind,
      domainHint: domainHint,
    );
  }
}
