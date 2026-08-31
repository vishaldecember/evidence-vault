import '../models/evidence_relationship.dart';
import '../models/workspace_evidence_item.dart';
import 'evidence_semantics.dart';

/// Internal coaching maturity — not a legal or completeness judgment.
///
/// Derived from current incident state. Not persisted.
enum IncidentCoachingMaturity {
  early,
  developing,
  documented,
  rich,
}

/// Deterministic maturity from EvidenceSemantics. Not a store.
abstract final class IncidentCoachingMaturityEval {
  IncidentCoachingMaturityEval._();

  static IncidentCoachingMaturity evaluate({
    required List<WorkspaceEvidenceItem> items,
    required List<EvidenceRelationship> relationships,
  }) {
    final primary = EvidenceSemantics.primaryChronology(items);
    if (primary.length <= 1) {
      return IncidentCoachingMaturity.early;
    }

    final kindCount = primary.map((item) => item.kind).toSet().length;
    final withContext = primary
        .where(
          (item) => EvidenceSemantics.hasRecordedContext(
            item,
            incidentItems: items,
            relationships: relationships,
          ),
        )
        .length;
    final anySupport = primary.any(
      (item) => EvidenceSemantics.hasStructuralSupport(
        evidenceId: item.id,
        items: items,
        relationships: relationships,
      ),
    );
    final anyCollection = items.any(EvidenceSemantics.isInCollection);
    final anyStructuralLink = items.any(
      (item) => EvidenceSemantics.hasStructuralRelationship(
        evidenceId: item.id,
        items: items,
        relationships: relationships,
      ),
    );

    final allHaveContext = withContext == primary.length;
    if (kindCount >= 2 && allHaveContext && anySupport) {
      return IncidentCoachingMaturity.rich;
    }

    if (kindCount >= 2 &&
        withContext > 0 &&
        (anySupport || anyCollection || anyStructuralLink)) {
      return IncidentCoachingMaturity.documented;
    }

    return IncidentCoachingMaturity.developing;
  }

  static int maxVisible(IncidentCoachingMaturity maturity) {
    return switch (maturity) {
      IncidentCoachingMaturity.early => 3,
      IncidentCoachingMaturity.developing => 3,
      IncidentCoachingMaturity.documented => 2,
      IncidentCoachingMaturity.rich => 1,
    };
  }
}
