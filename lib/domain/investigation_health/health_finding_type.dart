/// Deterministic finding types emitted by [InvestigationHealthEngine].
enum HealthFindingType {
  missingObservation,
  notLinkedToRelationship,
  notReferencedByNarrative,
  /// Internal only — ungrouped note/file, not user-facing "isolated evidence".
  isolatedEvidence,
  groupWithSingleMember,
  anchorWithoutSupportingEvidence,
  chronologicalGap,
  insufficientSupportingEvidence,
  unsupportedNarrativeStatement,
  missingRequiredComponent,
}
