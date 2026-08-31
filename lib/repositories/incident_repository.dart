import 'package:uuid/uuid.dart';

import '../domain/incident/incident.dart';
import '../domain/incident/incident_status.dart';
import 'incident_store.dart';

/// Owns [Incident] lifecycle for the active truth record.
abstract class IncidentRepository {
  Incident get currentIncident;

  void updateTitle(String title);

  void markManuallyComplete();

  /// Sets or clears the presentation cover pointer. Does not mutate Evidence.
  void setCoverEvidenceId(String? evidenceId);
}

/// In-memory [IncidentRepository] backed by [IncidentStore].
class InMemoryIncidentRepository implements IncidentRepository {
  InMemoryIncidentRepository(this._store);

  static const _uuid = Uuid();

  final IncidentStore _store;

  @override
  Incident get currentIncident => _store.incident;

  @override
  void updateTitle(String title) {
    _store.incident = _store.incident.copyWith(
      title: title,
      updatedAt: DateTime.now(),
    );
  }

  @override
  void markManuallyComplete() {
    _store.incident = _store.incident.copyWith(
      manuallyComplete: true,
      updatedAt: DateTime.now(),
    );
  }

  @override
  void setCoverEvidenceId(String? evidenceId) {
    final id = Incident.normalizeCoverEvidenceId(evidenceId);
    if (id != null) {
      final incidentId = _store.incident.id.trim();
      for (final item in _store.capturedEvidence) {
        if (item.id == id && item.incidentId.trim() != incidentId) {
          return;
        }
      }
      for (final item in _store.supportingEvidence) {
        if (item.id == id && item.incidentId.trim() != incidentId) {
          return;
        }
      }
    }
    final current = _store.incident;
    _store.incident = Incident(
      id: current.id,
      title: current.title,
      status: current.status,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      manuallyComplete: current.manuallyComplete,
      coverEvidenceId: id,
    );
  }

  /// Fresh immutable id for every new incident (Capture Now / empty draft).
  static String newIncidentId() => 'incident-${_uuid.v4()}';

  static IncidentStore createDefaultStore({Incident? incident}) {
    final now = DateTime.now();
    return IncidentStore(
      incident: incident ??
          Incident(
            // UUID — never reuse a previous incident id after Vault clear.
            id: newIncidentId(),
            title: '',
            status: IncidentStatus.draft,
            createdAt: now,
            updatedAt: now,
          ),
    );
  }
}
