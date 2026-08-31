/// Explicit content facts about one evidence item.
///
/// These are not inferred from files. A future extractor may populate them.
/// Empty, absent, or generic tokens must not produce Matter suggestions.
/// Filenames, titles, timestamps, and GPS are not Matter.
class MatterContentSignal {
  const MatterContentSignal({
    required this.evidenceId,
    this.objectLabels = const [],
    this.namedEntities = const [],
    this.topics = const [],
    this.placeMentions = const [],
    this.similarityGroupId,
  });

  final String evidenceId;

  /// Visible / mentioned objects supplied by a future extractor.
  final List<String> objectLabels;

  /// Named people, organizations, or other entities — not witness role.
  final List<String> namedEntities;

  /// Topics or document subjects.
  final List<String> topics;

  /// Places named *in content* — not capture GPS.
  final List<String> placeMentions;

  /// Caller-supplied similarity bucket. Same id means similar content.
  final String? similarityGroupId;
}
