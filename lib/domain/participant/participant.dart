import 'participant_role.dart';

/// A person involved in an investigation — independent of evidence.
///
/// Participants may own evidence, statements, and relationships. They are
/// not evidence themselves.
class Participant {
  const Participant({
    required this.id,
    required this.incidentId,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.contactInformation,
    this.organisation,
    this.notes = '',
  });

  final String id;
  final String incidentId;
  final String displayName;
  final ParticipantRole role;
  final String? contactInformation;
  final String? organisation;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Participant copyWith({
    String? displayName,
    ParticipantRole? role,
    String? contactInformation,
    String? organisation,
    String? notes,
    DateTime? updatedAt,
    bool clearContactInformation = false,
    bool clearOrganisation = false,
  }) {
    return Participant(
      id: id,
      incidentId: incidentId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      contactInformation: clearContactInformation
          ? null
          : (contactInformation ?? this.contactInformation),
      organisation:
          clearOrganisation ? null : (organisation ?? this.organisation),
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
