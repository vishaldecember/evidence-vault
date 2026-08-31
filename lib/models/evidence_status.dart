enum EvidenceStatus {
  draft,
  saved,
  discarded;

  String get label => switch (this) {
        EvidenceStatus.draft => 'Draft',
        EvidenceStatus.saved => 'Saved',
        EvidenceStatus.discarded => 'Discarded',
      };
}
