import 'verification_event.dart';
import 'verification_status.dart';

/// Presentation model for independent evidence verification.
///
/// Adds confidence without altering evidence. Complements integrity.
/// Extension points reserved for digital signatures, hash verification,
/// blockchain anchoring, witness verification, third-party verification,
/// chain of custody verification, and QR verification.
class VerificationModel {
  const VerificationModel({
    required this.status,
    this.verifiedAt,
    this.method,
    this.notes,
    this.events = const [],
  });

  final VerificationStatus status;
  final DateTime? verifiedAt;
  final String? method;
  final String? notes;
  final List<VerificationEvent> events;

  bool get isVerified => status == VerificationStatus.verified;

  bool get isPending => status == VerificationStatus.verificationPending;

  bool get isNotVerified => status == VerificationStatus.notVerified;

  String get statusLabel => status.label;

  /// Placeholder for evidence without an assigned verification workflow.
  static const notVerified = VerificationModel(
    status: VerificationStatus.notVerified,
    method: 'Not yet assigned',
    notes: 'No verification notes recorded.',
  );

  /// Placeholder for evidence awaiting independent verification.
  static VerificationModel pending({DateTime? requestedAt}) => VerificationModel(
        status: VerificationStatus.verificationPending,
        verifiedAt: requestedAt,
        method: 'Not yet assigned',
        notes: 'Verification has not yet been completed.',
      );

  /// Placeholder for independently verified evidence.
  static VerificationModel verified({
    required DateTime verifiedAt,
    String? method,
    String? notes,
    List<VerificationEvent> events = const [],
  }) =>
      VerificationModel(
        status: VerificationStatus.verified,
        verifiedAt: verifiedAt,
        method: method ?? 'Not yet assigned',
        notes: notes ?? 'No verification notes recorded.',
        events: events,
      );
}
