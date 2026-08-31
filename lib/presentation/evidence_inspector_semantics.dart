import '../models/verification_status.dart';
import '../models/workspace_evidence_item.dart';
import '../utils/workspace_evidence_formatters.dart';

/// One Inspector clock with a truthful role. Presentation-only.
class EvidenceInstantRow {
  const EvidenceInstantRow({
    required this.label,
    required this.instant,
  });

  /// `Captured` or `Recorded`. Never `Timestamp` / `Capture date`.
  final String label;
  final DateTime instant;

  String get formatted =>
      WorkspaceEvidenceFormatters.inspectorTimestamp(instant);
}

/// Presentation mapping for Inspector / Complete Record.
///
/// Does not invent chronology, hashes, or verification. Does not mutate Evidence.
abstract final class EvidenceInspectorSemantics {
  static const capturedLabel = 'Captured';
  static const recordedLabel = 'Recorded';

  static const observationLabel = 'Your observation';
  static const observationPlaceholder = 'Add your observation…';
  static const observationsHeader = 'Your observations';
  static const observationComposerHint = 'Add your observation…';

  static const integrityNotVerified = 'Not performed';
  static const integrityPending = 'Verification pending';
  static const integrityVerified = 'Independently verified';
  static const verifiedLabel = 'Verified';

  static const completeRecordIntegrityTitle = 'Integrity';

  static const evidenceHeader = 'Evidence';
  static const factsHeader = 'Facts';
  static const provenanceHeader = 'Provenance';
  static const verificationHeader = 'Verification';
  static const independentVerificationLabel = 'Independent verification';
  static const originalLabel = 'Original';
  static const originalPreserved = 'Preserved';
  static const fingerprintLabel = 'Fingerprint';
  static const fingerprintRecorded = 'SHA-256 recorded';
  static const fingerprintNotRecorded = 'Not recorded';
  static const captureModalityLabel = 'Capture modality';
  static const sourceLabel = 'Device';
  static const locationLabel = 'Location';
  static const locationUnavailable = 'Unavailable';
  static const locationRecorded = 'Recorded at capture';
  static const typeLabel = 'Type';
  static const chronologyHeader = 'Chronology';
  static const integrityHeader = 'Integrity';
  static const relationshipsHeader = 'Relationships';
  static const timelineRoleHeader = 'Timeline role';
  static const timelineRoleChronological = 'Chronological';
  static const timelineRoleChronologicalCaption =
      'Part of the event timeline';
  static const timelineRoleContext = 'Context';
  static const timelineRoleContextCaption =
      'Supporting context, not a timeline event';
  static const timelineRoleUnspecified = 'Not specified';
  static const timelineRoleVoicePrompt =
      'How should this recording be treated?';
  static const timelineRoleNotePrompt = 'How should this note be treated?';
  static const timelineRoleSkip = 'Skip';
  static const addObservationAffordance = 'Add your observation';
  static const hashLabel = 'Content hash';
  static const hashStatusLabel = 'Hash';
  static const chronologyUnsupported =
      'Not placed on the incident chronology';
  static const relationshipsCaption =
      'Connected records you or the system already linked.';

  /// Capture vs record instants from projected fields, then kind fallback.
  ///
  /// Primary kinds: [WorkspaceEvidenceItem.lastPreservedAt] is domain
  /// `capturedAt`. Supporting kinds: it is domain `createdAt`.
  /// [WorkspaceEvidenceItem.updatedAt] is never used as capture or record time.
  static List<EvidenceInstantRow> instants(WorkspaceEvidenceItem item) {
    final captured = item.capturedAt;
    final recorded = item.recordedAt;
    final rows = <EvidenceInstantRow>[];

    if (captured != null) {
      rows.add(EvidenceInstantRow(label: capturedLabel, instant: captured));
    }
    if (recorded != null &&
        (captured == null || !_sameInstant(captured, recorded))) {
      rows.add(EvidenceInstantRow(label: recordedLabel, instant: recorded));
    }
    if (rows.isNotEmpty) {
      return rows;
    }

    // Legacy presentation items: only lastPreservedAt is populated.
    if (item.kind.isPrimaryChronology) {
      return [
        EvidenceInstantRow(
          label: capturedLabel,
          instant: item.lastPreservedAt,
        ),
      ];
    }
    return [
      EvidenceInstantRow(
        label: recordedLabel,
        instant: item.lastPreservedAt,
      ),
    ];
  }

  /// Status from [WorkspaceEvidenceItem.verification] only.
  ///
  /// Ignores [WorkspaceEvidenceItem.integrityVerified] — Firestore hydrate
  /// currently forces that flag true, so it is not proof of verification.
  static String integrityStatus(WorkspaceEvidenceItem item) {
    return switch (item.verification.status) {
      VerificationStatus.verified => integrityVerified,
      VerificationStatus.verificationPending => integrityPending,
      VerificationStatus.notVerified => integrityNotVerified,
    };
  }

  /// Canonical content hash when the domain already stored one.
  ///
  /// Does not compute, verify, or invent a hash.
  static String? contentHash(WorkspaceEvidenceItem item) {
    final hash = item.contentHash?.trim();
    if (hash == null || hash.isEmpty) {
      return null;
    }
    return hash;
  }

  static String fingerprintStatus(WorkspaceEvidenceItem item) {
    return contentHash(item) == null
        ? fingerprintNotRecorded
        : fingerprintRecorded;
  }

  /// Photo, video, or audio captured in Evidence Vault — not an import.
  static bool isVaultCapturedMedia(WorkspaceEvidenceItem item) {
    return item.kind == WorkspaceEvidenceKind.image ||
        item.kind == WorkspaceEvidenceKind.video ||
        item.kind == WorkspaceEvidenceKind.voice;
  }

  /// How the evidence entered Evidence Vault. Derived from capture kind.
  static String captureModality(WorkspaceEvidenceItem item) {
    return switch (item.kind) {
      WorkspaceEvidenceKind.image ||
      WorkspaceEvidenceKind.video =>
        'Device Camera',
      WorkspaceEvidenceKind.voice => 'Device Microphone',
      WorkspaceEvidenceKind.note => 'Text Entry',
      WorkspaceEvidenceKind.attachment => 'File Import / Attachment',
      WorkspaceEvidenceKind.witness => 'Text Entry',
    };
  }

  static String sourceLabelValue(WorkspaceEvidenceItem item) {
    final device = item.deviceModel?.trim() ?? '';
    if (device.isEmpty) {
      return 'Unavailable';
    }
    return device;
  }

  /// Human-readable capture location. Does not invent a place name.
  static String locationLabelValue(WorkspaceEvidenceItem item) {
    if (item.latitude == null || item.longitude == null) {
      return locationUnavailable;
    }
    return locationRecorded;
  }

  static String hashPreview(String hash) {
    if (hash.length <= 16) {
      return hash;
    }
    return '${hash.substring(0, 8)}…${hash.substring(hash.length - 6)}';
  }

  /// Incident chronology from existing [sequenceOrder] ordering.
  ///
  /// [orderedCapturedEvidenceIds] must already be sequenceOrder-sorted.
  /// Returns null when this item is not a chronology anchor — do not invent
  /// "N of M" for supporting notes.
  static EvidenceChronologyPosition? chronologyPosition({
    required String evidenceId,
    required List<String> orderedCapturedEvidenceIds,
  }) {
    if (orderedCapturedEvidenceIds.isEmpty) {
      return null;
    }
    final index = orderedCapturedEvidenceIds.indexOf(evidenceId);
    if (index < 0) {
      return null;
    }
    return EvidenceChronologyPosition(
      index: index,
      total: orderedCapturedEvidenceIds.length,
    );
  }

  static DateTime? verifiedAt(WorkspaceEvidenceItem item) {
    if (!item.verification.isVerified) {
      return null;
    }
    return item.verification.verifiedAt;
  }

  static bool _sameInstant(DateTime a, DateTime b) {
    return a.toUtc().isAtSameMomentAs(b.toUtc());
  }
}

/// Safe Inspector presentation of existing `sequenceOrder` chronology.
class EvidenceChronologyPosition {
  const EvidenceChronologyPosition({
    required this.index,
    required this.total,
  });

  /// Zero-based index in `TimelineRepository.orderedCapturedEvidenceIds()`.
  final int index;
  final int total;

  /// One-based position for display. Never invented.
  int get ordinal => index + 1;

  String get headline => 'Evidence $ordinal of $total';

  String get positionLine => 'Position $ordinal in this incident';
}
