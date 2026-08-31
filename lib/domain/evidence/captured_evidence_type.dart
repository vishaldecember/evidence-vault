/// Immutable capture types — each creates a [TimelineAnchor].
enum CapturedEvidenceType {
  photo,
  video,
  voice;

  String get label => switch (this) {
        CapturedEvidenceType.photo => 'Photo',
        CapturedEvidenceType.video => 'Video',
        CapturedEvidenceType.voice => 'Voice',
      };
}
