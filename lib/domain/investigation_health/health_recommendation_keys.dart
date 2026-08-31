/// Structured recommendation keys consumed by coaching and presentation layers.
abstract final class HealthRecommendationKeys {
  static const addObservation = 'ADD_OBSERVATION';
  static const linkToRelationship = 'LINK_TO_RELATIONSHIP';
  static const referenceInNarrative = 'REFERENCE_IN_NARRATIVE';
  static const connectEvidence = 'CONNECT_EVIDENCE';
  static const expandRelationshipGroup = 'EXPAND_RELATIONSHIP_GROUP';
  static const attachSupportingEvidence = 'ATTACH_SUPPORTING_EVIDENCE';
  static const documentTimelineGap = 'DOCUMENT_TIMELINE_GAP';
  static const strengthenNarrativeSupport = 'STRENGTHEN_NARRATIVE_SUPPORT';
  /// Internal legacy key. Corroboration is not a domain state. Do not map
  /// this to user-facing copy. Health remains non-UI in Step 4C.
  static const addCorroboratingEvidence = 'ADD_CORROBORATING_EVIDENCE';
  static const completeTrustRequirements = 'COMPLETE_TRUST_REQUIREMENTS';
}
