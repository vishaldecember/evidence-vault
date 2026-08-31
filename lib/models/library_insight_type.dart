/// Observable cross-incident pattern categories for Library Intelligence.
///
/// Phase 1 supports five observable pattern types only.
/// Extension points reserved for AI-assisted pattern recognition,
/// relationship clustering, recurring locations/organisations/contacts,
/// recurring timelines, and trend analysis.
enum LibraryInsightType {
  sharedLocation,
  sharedOrganisation,
  sharedPersonOrWitness,
  similarTimePeriod,
  recurringEvidenceType;

  String get label => switch (this) {
        LibraryInsightType.sharedLocation => 'Shared Location',
        LibraryInsightType.sharedOrganisation => 'Shared Organisation',
        LibraryInsightType.sharedPersonOrWitness => 'Shared Person or Witness',
        LibraryInsightType.similarTimePeriod => 'Similar Time Period',
        LibraryInsightType.recurringEvidenceType => 'Recurring Evidence Type',
      };
}
