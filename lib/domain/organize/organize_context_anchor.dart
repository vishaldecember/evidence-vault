/// User-declared Organize placement: contextual evidence beside a captured moment.
///
/// Directed and Organize-only. Not Evidence Chain support, not an Investigation
/// relationship, not a collection, and not chronology.
class OrganizeContextAnchor {
  const OrganizeContextAnchor({
    required this.contextEvidenceId,
    required this.capturedEvidenceId,
  });

  /// Voice / text note / file the user is placing.
  final String contextEvidenceId;

  /// Chronology-spine moment the user placed it beside.
  final String capturedEvidenceId;

  Map<String, String> toJson() => {
        'contextEvidenceId': contextEvidenceId,
        'capturedEvidenceId': capturedEvidenceId,
      };

  /// Returns null when the payload is missing, empty, or self-referential.
  /// Never infers a snap from layout or other evidence fields.
  static OrganizeContextAnchor? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final contextId = (map['contextEvidenceId'] as String?)?.trim() ?? '';
    final capturedId = (map['capturedEvidenceId'] as String?)?.trim() ?? '';
    if (contextId.isEmpty || capturedId.isEmpty || contextId == capturedId) {
      return null;
    }
    return OrganizeContextAnchor(
      contextEvidenceId: contextId,
      capturedEvidenceId: capturedId,
    );
  }
}
