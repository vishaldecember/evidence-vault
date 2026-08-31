import 'package:flutter/foundation.dart';

import '../domain/organize/organize_readiness.dart';
import '../engines/evidence_semantics.dart';
import '../models/evidence_maturity.dart';
import '../models/evidence_relationship.dart';
import '../models/journey_stage.dart';
import '../models/workspace_evidence_item.dart';

/// Capture-section steps. Labels only — scoring stays in existing engines.
enum CaptureMaturityStep {
  incidentCreated,
  evidenceCaptured,
  contextsAdded,
  chronologyReady,
  investigationReady;

  String get label => switch (this) {
    CaptureMaturityStep.incidentCreated => 'Incident created',
    CaptureMaturityStep.evidenceCaptured => 'Evidence captured',
    CaptureMaturityStep.contextsAdded => 'Contexts added',
    CaptureMaturityStep.chronologyReady => 'Chronology ready',
    CaptureMaturityStep.investigationReady => 'Investigation ready',
  };

  static Key keyFor(CaptureMaturityStep step) =>
      Key('capture_maturity_step_${step.name}');
}

/// Presentation mapping over [OrganizeReadiness], [JourneyStage], and
/// [EvidenceSemantics]. Not a second progress engine and not a percentage.
class CaptureMaturityProgress {
  const CaptureMaturityProgress({
    required this.readiness,
    required this.reached,
  });

  final OrganizeReadiness readiness;
  final Map<CaptureMaturityStep, bool> reached;

  bool isReached(CaptureMaturityStep step) => reached[step] == true;

  static Key keyFor(CaptureMaturityStep step) =>
      CaptureMaturityStep.keyFor(step);

  static CaptureMaturityProgress evaluate({
    required List<WorkspaceEvidenceItem> evidence,
    required JourneyStage journeyStage,
    List<String> orderedCapturedEvidenceIds = const [],
    List<EvidenceRelationship> relationships = const [],
  }) {
    final readiness = OrganizeReadiness.assess(
      evidence: evidence,
      orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
    );
    final hasEvidence =
        evidence.any((item) => item.maturity == EvidenceMaturity.capture) ||
        EvidenceSemantics.primaryChronology(evidence).isNotEmpty;
    final hasContexts = evidence.any((item) {
      if (item.isContextual || (item.parentEvidenceId?.isNotEmpty ?? false)) {
        return true;
      }
      if (item.kind == WorkspaceEvidenceKind.witness) {
        return true;
      }
      return EvidenceSemantics.hasRecordedContext(
        item,
        incidentItems: evidence,
        relationships: relationships,
      );
    });
    final investigationReady =
        journeyStage == JourneyStage.rich ||
        journeyStage == JourneyStage.reflective;

    return CaptureMaturityProgress(
      readiness: readiness,
      reached: {
        CaptureMaturityStep.incidentCreated: true,
        CaptureMaturityStep.evidenceCaptured: hasEvidence,
        CaptureMaturityStep.contextsAdded: hasContexts,
        CaptureMaturityStep.chronologyReady: readiness.isReady,
        CaptureMaturityStep.investigationReady: investigationReady,
      },
    );
  }
}
