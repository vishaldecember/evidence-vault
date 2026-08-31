/// Role of a person involved in an investigation.
enum ParticipantRole {
  reporter,
  witness,
  subject,
  investigator,
  friend,
  colleague,
  family,
  other;

  String get label => switch (this) {
        ParticipantRole.reporter => 'Reporter',
        ParticipantRole.witness => 'Witness',
        ParticipantRole.subject => 'Person Involved',
        ParticipantRole.investigator => 'Investigator',
        ParticipantRole.friend => 'Friend',
        ParticipantRole.colleague => 'Colleague',
        ParticipantRole.family => 'Family',
        ParticipantRole.other => 'Other',
      };
}
