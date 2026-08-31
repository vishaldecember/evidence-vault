import '../domain/participant/participant.dart';
import '../domain/participant/participant_role.dart';

/// Owns [Participant] persistence within an incident.
abstract class ParticipantRepository {
  List<Participant> getByIncident();

  Participant? getById(String id);

  Participant create({
    required String displayName,
    required ParticipantRole role,
    String? contactInformation,
    String? organisation,
    String notes,
  });

  /// Reuses an existing participant when [displayName] matches case-insensitively.
  Participant findOrCreateByDisplayName({
    required String displayName,
    required ParticipantRole role,
  });

  Participant? update({
    required String participantId,
    String? displayName,
    ParticipantRole? role,
    String? contactInformation,
    String? organisation,
    String? notes,
    bool clearContactInformation = false,
    bool clearOrganisation = false,
  });

  bool delete(String participantId);
}
