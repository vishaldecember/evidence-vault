enum EvidenceCategory {
  personal,
  legal,
  medical,
  property,
  work,
  other;

  String get label => switch (this) {
        EvidenceCategory.personal => 'Personal',
        EvidenceCategory.legal => 'Legal',
        EvidenceCategory.medical => 'Medical',
        EvidenceCategory.property => 'Property',
        EvidenceCategory.work => 'Work',
        EvidenceCategory.other => 'Other',
      };
}
