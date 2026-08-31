import '../domain/trust_package/trust_package.dart';

enum TrustPackageQualityRating {
  excellent('Excellent'),
  good('Good'),
  needsReview('Needs Review'),
  incomplete('Incomplete');

  const TrustPackageQualityRating(this.label);

  final String label;
}

class TrustPackageQualityIndicator {
  const TrustPackageQualityIndicator({
    required this.label,
    required this.isMet,
    required this.statusLabel,
  });

  final String label;
  final bool isMet;
  final String statusLabel;
}

class TrustPackageInvestigationQuality {
  const TrustPackageInvestigationQuality({
    required this.overallRating,
    required this.indicators,
  });

  final TrustPackageQualityRating overallRating;
  final List<TrustPackageQualityIndicator> indicators;
}

/// Derives investigation quality indicators from [TrustPackage] only.
abstract final class TrustPackageScorecardService {
  static const timelineReferencesLabel = 'Timeline references verified';
  static const narrativeReferencesLabel = 'Narrative references verified';

  /// Maps stored integrity tokens to user-facing referential language.
  static String integrityStatusLabel(String stored) {
    return switch (stored) {
      'Complete' => 'Verified',
      'Incomplete' => 'Unverified',
      _ => stored,
    };
  }

  static TrustPackageInvestigationQuality evaluate(TrustPackage package) {
    final summary = package.investigationSummary;
    final integrity = package.integritySummary;
    final distinctEvidenceTypes = package.evidenceAppendix.entries
        .map((entry) => entry.evidenceType)
        .toSet()
        .length;

    final timelineComplete = package.timelineSection.entries.isNotEmpty &&
        integrity.timelineIntegrity == 'Complete';
    final narrativeComplete = package.reconstructionSection.events.isNotEmpty &&
        package.reconstructionSection.events.every(
          (event) => !event.validationStatus.contains('Low'),
        );
    final groupsRecorded = package.relationshipGroupsSection.groups.isNotEmpty &&
        integrity.relationshipIntegrity == 'Complete';
    final contextCoverage = summary.contextEntryCount > 0;
    final evidenceDiversity = distinctEvidenceTypes >= 2;
    final validationHealthy = integrity.validationStatus == 'Excellent' ||
        integrity.validationStatus == 'Needs Review';

    final indicators = [
      TrustPackageQualityIndicator(
        label: timelineReferencesLabel,
        isMet: timelineComplete,
        statusLabel: timelineComplete ? 'Verified' : 'Unverified',
      ),
      TrustPackageQualityIndicator(
        label: narrativeReferencesLabel,
        isMet: narrativeComplete,
        statusLabel: narrativeComplete ? 'Verified' : 'Unverified',
      ),
      TrustPackageQualityIndicator(
        label: 'Relationship groups recorded',
        isMet: groupsRecorded,
        statusLabel: groupsRecorded ? 'Recorded' : 'None recorded',
      ),
      TrustPackageQualityIndicator(
        label: 'Context Coverage',
        isMet: contextCoverage,
        statusLabel: contextCoverage ? 'Present' : 'Missing',
      ),
      TrustPackageQualityIndicator(
        label: 'Evidence Diversity',
        isMet: evidenceDiversity,
        statusLabel: evidenceDiversity ? 'Diverse' : 'Limited',
      ),
      TrustPackageQualityIndicator(
        label: 'Validation Status',
        isMet: validationHealthy,
        statusLabel: integrity.validationStatus,
      ),
    ];

    final metCount = indicators.where((entry) => entry.isMet).length;
    final TrustPackageQualityRating overallRating;
    if (metCount == indicators.length &&
        integrity.validationStatus == 'Excellent') {
      overallRating = TrustPackageQualityRating.excellent;
    } else if (metCount >= 4 && validationHealthy) {
      overallRating = TrustPackageQualityRating.good;
    } else if (metCount >= 3) {
      overallRating = TrustPackageQualityRating.needsReview;
    } else {
      overallRating = TrustPackageQualityRating.incomplete;
    }

    return TrustPackageInvestigationQuality(
      overallRating: overallRating,
      indicators: indicators,
    );
  }
}
