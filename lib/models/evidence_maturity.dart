/// Evidence maturity lane for the Evidence Maturity Engine.
///
/// Single source of truth for which lane an evidence item belongs to.
/// Promotion between lanes is intentionally deferred (Sprint 4G.2+).
enum EvidenceMaturity {
  /// Captured — primary chronology evidence.
  capture,

  /// Strengthening — supporting enrichment.
  building,

  /// Investigation Ready — mature, investigation-ready evidence.
  rich;

  /// User-facing lane title.
  String get laneLabel => switch (this) {
        EvidenceMaturity.capture => 'Captured',
        EvidenceMaturity.building => 'Strengthening',
        EvidenceMaturity.rich => 'Investigation Ready',
      };

  /// Foundation default for journey lane membership.
  ///
  /// Primary media → [capture]. Standalone capture-bar notes/attachments also
  /// belong in [capture] so they appear as chronological thumbnails. Parent-
  /// linked supporting context stays in [building].
  static EvidenceMaturity forJourneyItem({
    required bool isPrimaryChronology,
    required bool isStandaloneCaptureBarEvidence,
  }) {
    if (isPrimaryChronology || isStandaloneCaptureBarEvidence) {
      return EvidenceMaturity.capture;
    }
    return EvidenceMaturity.building;
  }

  /// Legacy helper — prefer [forJourneyItem].
  static EvidenceMaturity forPrimaryChronology(bool isPrimaryChronology) {
    return forJourneyItem(
      isPrimaryChronology: isPrimaryChronology,
      isStandaloneCaptureBarEvidence: false,
    );
  }
}
