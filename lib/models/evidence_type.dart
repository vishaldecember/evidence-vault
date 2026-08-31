enum EvidenceType {
  photo,
  video,
  audio,
  document;

  String get label => switch (this) {
        EvidenceType.photo => 'Photo',
        EvidenceType.video => 'Video',
        EvidenceType.audio => 'Audio Recording',
        EvidenceType.document => 'Document',
      };

  String get iconName => switch (this) {
        EvidenceType.photo => 'photo_camera_outlined',
        EvidenceType.video => 'videocam_outlined',
        EvidenceType.audio => 'mic_outlined',
        EvidenceType.document => 'description_outlined',
      };
}
