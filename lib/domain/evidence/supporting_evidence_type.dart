/// Flexible supporting material — relationship editing applies here.
enum SupportingEvidenceType {
  note,
  pdf,
  document,
  attachment,
  witnessStatement;

  String get label => switch (this) {
        SupportingEvidenceType.note => 'Note',
        SupportingEvidenceType.pdf => 'PDF',
        SupportingEvidenceType.document => 'Document',
        SupportingEvidenceType.attachment => 'Attachment',
        SupportingEvidenceType.witnessStatement => 'Witness Statement',
      };
}
