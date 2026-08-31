/// Localization keys for health finding messages — never user-facing copy in the engine.
abstract final class HealthMessageKeys {
  static const evidenceMissingObservation =
      'health.evidence.missing_observation';
  static const evidenceNotLinkedToRelationship =
      'health.evidence.not_linked_to_relationship';
  static const evidenceNotReferencedByNarrative =
      'health.evidence.not_referenced_by_narrative';
  static const relationshipIsolatedEvidence =
      'health.relationship.isolated_evidence';
  static const relationshipGroupSingleMember =
      'health.relationship.group_single_member';
  static const timelineAnchorWithoutSupportingEvidence =
      'health.timeline.anchor_without_supporting_evidence';
  static const timelineChronologicalGap = 'health.timeline.chronological_gap';
  static const narrativeInsufficientSupportingEvidence =
      'health.narrative.insufficient_supporting_evidence';
  static const narrativeUnsupportedStatement =
      'health.narrative.unsupported_statement';
  static const trustMissingRequiredComponent =
      'health.trust.missing_required_component';
}
