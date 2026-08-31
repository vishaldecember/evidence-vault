/// Methodology stages shown in the Investigation Journey header.
///
/// These are workspace orientation markers — not completion or progress states.
/// Together they represent the Incident Status lifecycle:
/// Capture → Organize → Investigation → Trust Package.
enum InvestigationMethodologyStage {
  capture,
  evidence,
  investigation,
  trustPackage;

  static const List<InvestigationMethodologyStage> journeyOrder = [
    InvestigationMethodologyStage.capture,
    InvestigationMethodologyStage.evidence,
    InvestigationMethodologyStage.investigation,
    InvestigationMethodologyStage.trustPackage,
  ];
}

extension InvestigationMethodologyStageLabels on InvestigationMethodologyStage {
  /// User-facing stage name in primary workflow navigation.
  String get label => switch (this) {
        InvestigationMethodologyStage.capture => 'Capture',
        InvestigationMethodologyStage.evidence => 'Organize',
        InvestigationMethodologyStage.investigation => 'Investigate',
        InvestigationMethodologyStage.trustPackage => 'Trust Package',
      };

  /// Short workflow purpose line — identical voice across all stages.
  String get subtitle => switch (this) {
        InvestigationMethodologyStage.capture =>
          'Capture what happened clearly',
        InvestigationMethodologyStage.evidence =>
          'Organize and enrich your records',
        InvestigationMethodologyStage.investigation =>
          'Understand chronology and relationships',
        InvestigationMethodologyStage.trustPackage =>
          'Generate a professional evidence package',
      };
}
