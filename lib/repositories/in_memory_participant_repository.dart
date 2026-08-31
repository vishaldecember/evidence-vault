import '../domain/participant/participant.dart';
import '../domain/participant/participant_role.dart';
import '../domain/participant/related_person_metadata.dart';
import '../models/workspace_evidence_factory.dart';
import 'incident_store.dart';
import 'participant_repository.dart';

/// In-memory [ParticipantRepository] backed by [IncidentStore].
class InMemoryParticipantRepository implements ParticipantRepository {
  InMemoryParticipantRepository(this._store);

  final IncidentStore _store;

  @override
  List<Participant> getByIncident() =>
      List<Participant>.unmodifiable(_store.participants);

  @override
  Participant? getById(String id) {
    for (final participant in _store.participants) {
      if (participant.id == id) {
        return participant;
      }
    }
    return null;
  }

  @override
  Participant create({
    required String displayName,
    required ParticipantRole role,
    String? contactInformation,
    String? organisation,
    String notes = '',
  }) {
    final now = DateTime.now();
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'cannot be empty');
    }

    final participant = Participant(
      id: WorkspaceEvidenceFactory.nextParticipantId(),
      incidentId: _store.incident.id,
      displayName: trimmedName,
      role: role,
      contactInformation: _trimOrNull(contactInformation),
      organisation: _trimOrNull(organisation),
      notes: notes.trim(),
      createdAt: now,
      updatedAt: now,
    );

    _store.participants.insert(0, participant);
    _touchIncident(now);
    return participant;
  }

  @override
  Participant findOrCreateByDisplayName({
    required String displayName,
    required ParticipantRole role,
  }) {
    final normalized = displayName.trim().toLowerCase();
    for (final participant in _store.participants) {
      if (participant.displayName.trim().toLowerCase() == normalized) {
        return participant;
      }
    }

    return create(displayName: displayName, role: role);
  }

  @override
  Participant? update({
    required String participantId,
    String? displayName,
    ParticipantRole? role,
    String? contactInformation,
    String? organisation,
    String? notes,
    bool clearContactInformation = false,
    bool clearOrganisation = false,
  }) {
    final index = _store.participants.indexWhere(
      (participant) => participant.id == participantId,
    );
    if (index == -1) {
      return null;
    }

    final existing = _store.participants[index];
    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'cannot be empty');
    }

    final updated = existing.copyWith(
      displayName: trimmedName,
      role: role,
      contactInformation: clearContactInformation
          ? null
          : _trimOrNull(contactInformation),
      organisation: clearOrganisation ? null : _trimOrNull(organisation),
      notes: notes?.trim(),
      updatedAt: DateTime.now(),
      clearContactInformation: clearContactInformation,
      clearOrganisation: clearOrganisation,
    );
    _store.participants[index] = updated;
    _touchIncident(updated.updatedAt);
    return updated;
  }

  @override
  bool delete(String participantId) {
    final index = _store.participants.indexWhere(
      (participant) => participant.id == participantId,
    );
    if (index == -1) {
      return false;
    }

    if (_evidenceReferencesParticipant(participantId)) {
      return false;
    }

    _store.participants.removeAt(index);
    _touchIncident(DateTime.now());
    return true;
  }

  bool _evidenceReferencesParticipant(String participantId) {
    for (final evidence in _store.capturedEvidence) {
      if (evidence.participantId == participantId) {
        return true;
      }
      if (RelatedPersonMetadata.peopleOf(evidence.metadata)
          .any((person) => person.participantId == participantId)) {
        return true;
      }
    }
    for (final evidence in _store.supportingEvidence) {
      if (evidence.participantId == participantId) {
        return true;
      }
      if (RelatedPersonMetadata.peopleOf(evidence.metadata)
          .any((person) => person.participantId == participantId)) {
        return true;
      }
    }
    return false;
  }

  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  void _touchIncident(DateTime updatedAt) {
    _store.incident = _store.incident.copyWith(updatedAt: updatedAt);
  }
}
