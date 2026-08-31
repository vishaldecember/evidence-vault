/// Digital integrity + provenance projection for the Trust Pack.
///
/// Does not claim real-world authenticity, legal admissibility,
/// AI-generation detection, or independent review.
library;

enum TrustPackIntegrityState {
  verified,
  recorded,
  mismatch,
  fingerprintUnavailable,
}

abstract final class TrustPackIntegrityLabels {
  static const sectionTitle = 'Integrity & Provenance';
  static const verified = '✓ Integrity verified';
  static const recorded = 'Integrity recorded';
  static const mismatch = 'Integrity mismatch';
  static const fingerprintUnavailable = 'Integrity fingerprint unavailable';
  static const originalPreserved = 'Original preserved';
  static const originalNotAvailable = 'Original not currently available';
  static const captured = 'Captured';
  static const preserved = 'Preserved';
  static const source = 'Source';
  static const captureModality = 'Capture modality';
  static const location = 'Location';
  static const locationUnavailable = 'Unavailable';
  static const evidenceHistory = 'Evidence history';
  static const integrityDetails = 'Integrity details';
  static const sha256Fingerprint = 'SHA-256 fingerprint';
  static const independentVerification = 'Independent verification';
  static const independentNotPerformed = 'Not performed';
  static const recordedExplanation =
      'Original evidence is not currently available for re-verification.';
  static const mismatchExplanation =
      'The available evidence no longer matches the fingerprint recorded '
      'when it was preserved.';
  static const verifiedExplanation =
      'The currently available evidence matches the fingerprint recorded '
      'when it was preserved.';
  static const unavailableExplanation =
      'No integrity fingerprint was recorded for this evidence.';
  static const eventCaptured = 'Captured';
  static const eventPreserved = 'Preserved';
  static const eventContextAdded = 'Context added';

  static String ofNVerified(int verified, int total) =>
      '$verified of $total verified';

  static String singleScope = 'This status applies to this evidence.';

  static String allItemsScope(int count) =>
      'This status applies to all $count evidence items.';

  static const mixedScope =
      'Status is shown for each evidence item.';
}

class TrustPackageIntegrityHistoryEvent {
  const TrustPackageIntegrityHistoryEvent({
    required this.at,
    required this.label,
  });

  final DateTime at;
  final String label;
}

class TrustPackageIntegrityProvenanceEntry {
  const TrustPackageIntegrityProvenanceEntry({
    required this.evidenceId,
    required this.title,
    required this.state,
    required this.originalPreserved,
    this.capturedAt,
    this.preservedAt,
    this.source,
    this.captureModality,
    required this.location,
    this.locationUncertain = false,
    required this.history,
    this.contentHash,
    required this.independentVerification,
  });

  final String evidenceId;
  final String title;
  final TrustPackIntegrityState state;
  final bool originalPreserved;
  final DateTime? capturedAt;
  final DateTime? preservedAt;
  final String? source;
  final String? captureModality;
  final String location;
  final bool locationUncertain;
  final List<TrustPackageIntegrityHistoryEvent> history;
  final String? contentHash;
  final String independentVerification;

  String get statusLabel => switch (state) {
        TrustPackIntegrityState.verified => TrustPackIntegrityLabels.verified,
        TrustPackIntegrityState.recorded => TrustPackIntegrityLabels.recorded,
        TrustPackIntegrityState.mismatch => TrustPackIntegrityLabels.mismatch,
        TrustPackIntegrityState.fingerprintUnavailable =>
          TrustPackIntegrityLabels.fingerprintUnavailable,
      };

  String get statusExplanation => switch (state) {
        TrustPackIntegrityState.verified =>
          TrustPackIntegrityLabels.verifiedExplanation,
        TrustPackIntegrityState.recorded =>
          TrustPackIntegrityLabels.recordedExplanation,
        TrustPackIntegrityState.mismatch =>
          TrustPackIntegrityLabels.mismatchExplanation,
        TrustPackIntegrityState.fingerprintUnavailable =>
          TrustPackIntegrityLabels.unavailableExplanation,
      };

  String get originalPreservationLabel => originalPreserved
      ? TrustPackIntegrityLabels.originalPreserved
      : TrustPackIntegrityLabels.originalNotAvailable;

  String get locationDisplay {
    if (location == TrustPackIntegrityLabels.locationUnavailable) {
      return location;
    }
    if (locationUncertain) {
      return '📍? $location';
    }
    return location;
  }
}

class TrustPackageIntegrityProvenanceSection {
  const TrustPackageIntegrityProvenanceSection({
    this.entries = const [],
  });

  static const empty = TrustPackageIntegrityProvenanceSection();

  final List<TrustPackageIntegrityProvenanceEntry> entries;

  int get verifiedCount => entries
      .where((entry) => entry.state == TrustPackIntegrityState.verified)
      .length;

  int get recordedCount => entries
      .where((entry) => entry.state == TrustPackIntegrityState.recorded)
      .length;

  int get mismatchCount => entries
      .where((entry) => entry.state == TrustPackIntegrityState.mismatch)
      .length;

  bool get statesUniform {
    if (entries.length <= 1) {
      return true;
    }
    final first = entries.first.state;
    return entries.every((entry) => entry.state == first);
  }

  /// Conservative pack-level status. A mismatch is never hidden by a match.
  String get packStatusLabel {
    if (entries.isEmpty) {
      return TrustPackIntegrityLabels.fingerprintUnavailable;
    }
    if (mismatchCount > 0) {
      return TrustPackIntegrityLabels.mismatch;
    }
    if (statesUniform) {
      return entries.first.statusLabel;
    }
    if (verifiedCount > 0) {
      return TrustPackIntegrityLabels.ofNVerified(verifiedCount, entries.length);
    }
    if (recordedCount > 0) {
      return TrustPackIntegrityLabels.recorded;
    }
    return TrustPackIntegrityLabels.fingerprintUnavailable;
  }

  String? get packStatusSecondary {
    if (entries.length <= 1) {
      return null;
    }
    if (mismatchCount > 0) {
      return TrustPackIntegrityLabels.ofNVerified(verifiedCount, entries.length);
    }
    return null;
  }

  String get packStatusExplanation {
    if (entries.isEmpty) {
      return TrustPackIntegrityLabels.unavailableExplanation;
    }
    if (mismatchCount > 0) {
      return TrustPackIntegrityLabels.mismatchExplanation;
    }
    if (statesUniform) {
      return entries.first.statusExplanation;
    }
    if (verifiedCount > 0) {
      return 'Integrity states differ across evidence in this Trust Pack.';
    }
    if (recordedCount > 0) {
      return TrustPackIntegrityLabels.recordedExplanation;
    }
    return TrustPackIntegrityLabels.unavailableExplanation;
  }

  String get scopeCaption {
    if (entries.length <= 1) {
      return TrustPackIntegrityLabels.singleScope;
    }
    if (statesUniform && mismatchCount == 0) {
      return TrustPackIntegrityLabels.allItemsScope(entries.length);
    }
    return TrustPackIntegrityLabels.mixedScope;
  }

  bool get reportsEntirePackVerified =>
      entries.isNotEmpty &&
      verifiedCount == entries.length &&
      mismatchCount == 0;
}
