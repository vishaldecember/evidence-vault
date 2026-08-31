/// User-declared relationship of one evidence item to the incident timeline.
///
/// Not an evidence type, relationship, collection, placement, or event-time.
/// Null / absent means undeclared — never infer from kind, origin, or anchors.
enum EvidenceTemporalIntent {
  chronological,
  context;

  static const String wireChronological = 'chronological';
  static const String wireContext = 'context';

  String get wireName => switch (this) {
        EvidenceTemporalIntent.chronological => wireChronological,
        EvidenceTemporalIntent.context => wireContext,
      };

  /// Missing, empty, or unknown values hydrate as null. Never invent intent.
  static EvidenceTemporalIntent? fromWire(Object? value) {
    if (value is! String) {
      return null;
    }
    switch (value.trim()) {
      case wireChronological:
        return EvidenceTemporalIntent.chronological;
      case wireContext:
        return EvidenceTemporalIntent.context;
      default:
        return null;
    }
  }
}
