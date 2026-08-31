/// One person linked to a single evidence or context item.
///
/// Identity lives on [Participant]. This is the per-evidence membership row.
class RelatedPersonLink {
  const RelatedPersonLink({
    required this.participantId,
    required this.displayName,
    this.roleName,
  });

  final String participantId;
  final String displayName;
  final String? roleName;

  RelatedPersonLink copyWith({
    String? participantId,
    String? displayName,
    String? roleName,
  }) {
    return RelatedPersonLink(
      participantId: participantId ?? this.participantId,
      displayName: displayName ?? this.displayName,
      roleName: roleName ?? this.roleName,
    );
  }
}
