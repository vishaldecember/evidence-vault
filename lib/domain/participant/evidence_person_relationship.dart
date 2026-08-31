import 'participant_role.dart';

/// Relationship options when linking evidence to a person inline.
enum EvidencePersonRelationship {
  witness,
  personInvolved,
  friend,
  colleague,
  family,
  other;

  String get label => switch (this) {
        EvidencePersonRelationship.witness => 'Witness',
        EvidencePersonRelationship.personInvolved => 'Person Involved',
        EvidencePersonRelationship.friend => 'Friend',
        EvidencePersonRelationship.colleague => 'Colleague',
        EvidencePersonRelationship.family => 'Family',
        EvidencePersonRelationship.other => 'Other',
      };

  ParticipantRole get participantRole => switch (this) {
        EvidencePersonRelationship.witness => ParticipantRole.witness,
        EvidencePersonRelationship.personInvolved => ParticipantRole.subject,
        EvidencePersonRelationship.friend => ParticipantRole.friend,
        EvidencePersonRelationship.colleague => ParticipantRole.colleague,
        EvidencePersonRelationship.family => ParticipantRole.family,
        EvidencePersonRelationship.other => ParticipantRole.other,
      };

  static EvidencePersonRelationship? fromParticipantRole(ParticipantRole role) =>
      switch (role) {
        ParticipantRole.witness => EvidencePersonRelationship.witness,
        ParticipantRole.subject => EvidencePersonRelationship.personInvolved,
        ParticipantRole.friend => EvidencePersonRelationship.friend,
        ParticipantRole.colleague => EvidencePersonRelationship.colleague,
        ParticipantRole.family => EvidencePersonRelationship.family,
        ParticipantRole.other => EvidencePersonRelationship.other,
        _ => null,
      };
}
