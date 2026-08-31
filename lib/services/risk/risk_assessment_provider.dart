import '../../domain/collection/evidence_collection.dart';
import '../../domain/evidence/captured_evidence.dart';
import '../../domain/relationship/relationship_suggestion.dart';
import '../../domain/risk/incident_risk_assessment.dart';
import '../../models/evidence_relationship.dart';
import '../../models/journey_stage.dart';
import '../../models/library_incident_summary.dart';
import '../../models/workspace_evidence_item.dart';
import '../relationship/relationship_engine.dart';

/// Input for Risk Coach — existing investigation data only (Sprint 5E).
///
/// Internal uncertainty framing (known known / known unknown / …) is a
/// reasoning aid for providers — not exposed heavily in UI.
class RiskAssessmentContext {
  const RiskAssessmentContext({
    required this.incidentId,
    required this.incidentTitle,
    required this.journeyStage,
    required this.createdAt,
    required this.updatedAt,
    required this.now,
    required this.evidence,
    required this.capturedEvidence,
    required this.relationships,
    required this.collections,
    required this.graph,
    this.relationshipSuggestions = const [],
    this.narrativeEventCount = 0,
    this.dismissedIds = const {},
    this.reviewedIds = const {},
    this.librarySummaries = const [],
    this.memoryRecallHints = const [],
    this.domainHint = IncidentRiskDomain.other,
  });

  final String incidentId;
  final String incidentTitle;
  final JourneyStage journeyStage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime now;
  final List<WorkspaceEvidenceItem> evidence;
  final List<CapturedEvidence> capturedEvidence;
  final List<EvidenceRelationship> relationships;
  final List<EvidenceCollection> collections;
  final InvestigationGraphView graph;
  final List<RelationshipSuggestion> relationshipSuggestions;
  final int narrativeEventCount;
  final Set<String> dismissedIds;
  final Set<String> reviewedIds;

  /// Library context for future recurrence (Memory Recall / Vault signals).
  final List<LibraryIncidentSummary> librarySummaries;

  /// Optional Memory Recall reason strings for this incident (no fabrication).
  final List<String> memoryRecallHints;
  final IncidentRiskDomain domainHint;
}

/// Future AI plugs in here — UI never knows which provider ran.
///
/// Reserved: [AIRiskAssessmentProvider]. Every AI assessment must include
/// reason, confidence, sourceEvidenceIds, and recommendedAction.
abstract class RiskAssessmentProvider {
  Future<List<IncidentRiskAssessment>> assess(RiskAssessmentContext context);

  /// True when the investigation appears well supported (positive feedback).
  bool looksWellSupported(RiskAssessmentContext context);
}
