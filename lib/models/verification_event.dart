/// One recorded verification event in the verification history.
///
/// Extension points reserved for digital signatures, hash verification,
/// blockchain anchoring, witness verification, third-party verification,
/// chain of custody verification, and QR verification.
class VerificationEvent {
  const VerificationEvent({
    required this.id,
    required this.occurredAt,
    this.method,
    this.notes,
  });

  final String id;
  final DateTime occurredAt;
  final String? method;
  final String? notes;
}
