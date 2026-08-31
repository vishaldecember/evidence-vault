import '../../models/journey_stage.dart';
import '../../models/relationship_group.dart';
import '../../models/workspace_evidence_item.dart';
import '../collection/evidence_collection.dart';
import 'incident.dart';
import 'incident_status.dart';

/// Shared read model for the active investigation — single source of truth.
///
/// Every Capture, Organize, Investigation, and Trust Package surface must read
/// from this projection. Screens never own a separate Incident or evidence list.
///
/// Owned by the repository layer via [IncidentAggregate] / incident store;
/// projected for UI through [WorkspaceEvidenceController.currentIncident].
class CurrentIncident {
  const CurrentIncident({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.manuallyComplete,
    this.coverEvidenceId,
    required this.journeyStage,
    required this.captureProgressPercent,
    required this.timelineAnchorCount,
    required this.relationshipGroupCount,
    required this.narrativeEventCount,
    required this.evidence,
    required this.journeyEvidence,
    required this.relationshipGroups,
    required this.evidenceCollections,
    required this.trustPackageReady,
    required this.trustPackageProgressPercent,
  });

  final String id;
  final String title;
  final IncidentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool manuallyComplete;

  /// Presentation pointer only. Not evidence ownership.
  final String? coverEvidenceId;

  /// Enrichment maturity — Capture / Organize progress signal.
  final JourneyStage journeyStage;

  /// 0–100 enrichment coverage of primary evidence.
  final int captureProgressPercent;

  final int timelineAnchorCount;
  final int relationshipGroupCount;
  final int narrativeEventCount;

  /// Full evidence collection for the active incident (one list, shared).
  ///
  /// Includes captured and supporting items. Screens must not keep a local copy.
  final List<WorkspaceEvidenceItem> evidence;

  /// Chronological Capture / Organize journey strip — derived from [evidence]
  /// in capture order (primary + supporting; not a second repository).
  final List<WorkspaceEvidenceItem> journeyEvidence;

  final List<RelationshipGroup> relationshipGroups;

  /// Organize-stage suggested / refined Evidence Collections (Sprint 5B).
  final List<EvidenceCollection> evidenceCollections;

  /// Whether a Trust Package can be assembled with meaningful content.
  final bool trustPackageReady;

  /// Lightweight Trust Package readiness 0–100 (evidence + narrative coverage).
  final int trustPackageProgressPercent;

  int get evidenceCount => evidence.length;

  int get journeyEvidenceCount => journeyEvidence.length;

  /// Domain incident identity — never a screen-local duplicate.
  Incident get incident => Incident(
        id: id,
        title: title,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        manuallyComplete: manuallyComplete,
        coverEvidenceId: coverEvidenceId,
      );

  bool get hasTitle => title.trim().isNotEmpty;

  String get displayTitle {
    final trimmed = title.trim();
    return trimmed.isEmpty ? 'Untitled Incident' : trimmed;
  }

  WorkspaceEvidenceItem? evidenceById(String id) {
    for (final item in evidence) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}
