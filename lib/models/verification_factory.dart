import 'verification_model.dart';
import 'verification_status.dart';
import 'workspace_evidence_item.dart';

/// Resolves verification presentation from preserved evidence.
abstract final class VerificationFactory {
  static const _placeholderMethod = 'Not yet assigned';
  static const _placeholderNotes = 'No verification notes recorded.';

  /// Returns the verification state stored on the evidence item.
  static VerificationModel forWorkspaceItem(WorkspaceEvidenceItem item) {
    return item.verification;
  }

  /// Initial verification state for newly preserved evidence.
  static VerificationModel initial() => VerificationModel.notVerified;

  /// Aggregates verification across multiple artifacts for package-level display.
  static VerificationModel forArtifacts(Iterable<WorkspaceEvidenceItem> items) {
    final artifacts = items.where((item) => !item.isContextual).toList();
    if (artifacts.isEmpty) {
      return VerificationModel.notVerified;
    }

    final statuses = artifacts.map((item) => item.verification.status).toSet();

    if (statuses.length == 1 &&
        statuses.first == VerificationStatus.verified) {
      final latest = artifacts
          .map((item) => item.verification.verifiedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (latest, date) =>
                latest == null || date.isAfter(latest) ? date : latest,
          );

      return VerificationModel.verified(
        verifiedAt: latest ?? DateTime.now(),
        method: _placeholderMethod,
        notes: _placeholderNotes,
      );
    }

    if (statuses.contains(VerificationStatus.verificationPending)) {
      return VerificationModel.pending();
    }

    return VerificationModel.notVerified;
  }
}
