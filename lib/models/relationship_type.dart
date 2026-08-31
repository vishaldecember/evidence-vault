/// Canonical relationship types for Linked Evidence.
///
/// Only these four types are supported in Sprint 4.1.
/// Future types (witness, location, AI-suggested) extend via enum values
/// without changing existing presentation code.
enum RelationshipType {
  supports,
  explains,
  references,
  relatedTo;

  String get label => switch (this) {
        RelationshipType.supports => 'Supports',
        RelationshipType.explains => 'Explains',
        RelationshipType.references => 'References',
        RelationshipType.relatedTo => 'Related To',
      };

  static const List<RelationshipType> canonical = [
    RelationshipType.supports,
    RelationshipType.explains,
    RelationshipType.references,
    RelationshipType.relatedTo,
  ];
}
