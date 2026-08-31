import '../../mappers/current_incident_projection.dart';
import '../../mappers/evidence_projection.dart';
import '../../migration/workspace_state_migration.dart';
import '../../models/evidence_relationship.dart';
import '../../repositories/evidence_repository.dart';
import '../../repositories/incident_repository.dart';
import '../../repositories/incident_store.dart';
import '../../repositories/in_memory_evidence_repository.dart';
import '../../repositories/in_memory_participant_repository.dart';
import '../../repositories/in_memory_relationship_repository.dart';
import '../../repositories/narrative_event_repository.dart';
import '../../repositories/participant_repository.dart';
import '../../repositories/reconstruction_repository.dart';
import '../../repositories/relationship_repository.dart';
import '../../repositories/timeline_repository.dart';
import 'current_incident.dart';
import 'incident.dart';
import 'incident_status.dart';

/// Facade for the Sprint 9 incident aggregate and its repositories.
///
/// Owns the single active investigation. Screens read [sharedIncident] —
/// never a local Incident copy.
class IncidentAggregate {
  IncidentAggregate._({
    required this.store,
    required this.incidentRepository,
    required this.timelineRepository,
    required this.evidenceRepository,
    required this.reconstructionRepository,
    required this.narrativeEventRepository,
    required this.relationshipRepository,
    required this.participantRepository,
  });

  final IncidentStore store;
  final IncidentRepository incidentRepository;
  final TimelineRepository timelineRepository;
  final EvidenceRepository evidenceRepository;
  final ReconstructionRepository reconstructionRepository;
  final NarrativeEventRepository narrativeEventRepository;
  final RelationshipRepository relationshipRepository;
  final ParticipantRepository participantRepository;

  Incident get incident => store.incident;

  /// Shared [CurrentIncident] projection — repository-owned single source of truth.
  CurrentIncident get sharedIncident =>
      CurrentIncidentProjection.fromAggregate(this);

  /// Projects the aggregate to legacy [WorkspaceEvidenceState] for UI compatibility.
  WorkspaceEvidenceState get projectedState =>
      EvidenceProjection.toWorkspaceState(store);

  factory IncidentAggregate.fromLegacyState(WorkspaceEvidenceState legacy) {
    return IncidentAggregate._create(WorkspaceStateMigration.migrate(legacy));
  }

  factory IncidentAggregate.empty() {
    return IncidentAggregate._create(
      InMemoryIncidentRepository.createDefaultStore(),
    );
  }

  /// Local-first shell for a known [id] when cloud hydrate is unavailable.
  ///
  /// Opens Workspace on the correct incident identity immediately; evidence
  /// may arrive via a later restore / sync.
  factory IncidentAggregate.shell({
    required String id,
    String title = '',
  }) {
    final now = DateTime.now();
    return IncidentAggregate.fromStore(
      IncidentStore(
        incident: Incident(
          id: id,
          title: title,
          status: IncidentStatus.draft,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
  }

  /// Hydrate from a pre-built store (Firestore restore — Sprint 4B).
  factory IncidentAggregate.fromStore(IncidentStore store) {
    return IncidentAggregate._create(store);
  }

  static IncidentAggregate _create(IncidentStore store) {
    final timelineRepository = InMemoryTimelineRepository(store);
    return IncidentAggregate._(
      store: store,
      incidentRepository: InMemoryIncidentRepository(store),
      timelineRepository: timelineRepository,
      evidenceRepository: InMemoryEvidenceRepository(
        store,
        timelineRepository,
      ),
      reconstructionRepository: InMemoryReconstructionRepository(store),
      narrativeEventRepository: InMemoryNarrativeEventRepository(store),
      relationshipRepository: InMemoryRelationshipRepository(store),
      participantRepository: InMemoryParticipantRepository(store),
    );
  }
}
