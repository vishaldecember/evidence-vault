/// Independent trust status for preserved evidence.
///
/// Separate from integrity — verification answers how evidence can be
/// independently trusted, not whether it has remained unchanged.
enum VerificationStatus {
  notVerified,
  verified,
  verificationPending;

  String get label => switch (this) {
        VerificationStatus.notVerified => 'Not Verified',
        VerificationStatus.verified => 'Verified',
        VerificationStatus.verificationPending => 'Verification Pending',
      };
}
