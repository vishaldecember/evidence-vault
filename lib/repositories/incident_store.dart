import '../domain/collection/evidence_collection.dart';
import '../domain/evidence/captured_evidence.dart';
import '../domain/evidence/supporting_evidence.dart';
import '../domain/incident/incident.dart';
import '../domain/organize/organize_context_anchor.dart';
import '../domain/participant/participant.dart';
import '../domain/reconstruction/narrative_event.dart';
import '../domain/reconstruction/reconstruction_note.dart';
import '../domain/relationship/relationship_group.dart';
import '../domain/relationship/relationship_suggestion.dart';
import '../domain/timeline/timeline_anchor.dart';
import '../models/evidence_relationship.dart';

/// In-memory backing store for a single active [Incident] aggregate.
class IncidentStore {
  IncidentStore({
    required this.incident,
    List<CapturedEvidence>? capturedEvidence,
    List<SupportingEvidence>? supportingEvidence,
    List<TimelineAnchor>? timelineAnchors,
    List<RelationshipGroup>? relationshipGroups,
    List<EvidenceRelationship>? relationships,
    List<ReconstructionNote>? reconstructionNotes,
    List<NarrativeEvent>? narrativeEvents,
    List<Participant>? participants,
    List<EvidenceCollection>? evidenceCollections,
    List<RelationshipSuggestion>? relationshipSuggestions,
    Set<String>? dismissedCollectionIds,
    List<OrganizeContextAnchor>? organizeContextAnchors,
    Set<String>? organizeCreatedEvidenceIds,
  })  : capturedEvidence = List<CapturedEvidence>.from(
          capturedEvidence ?? const [],
        ),
        supportingEvidence = List<SupportingEvidence>.from(
          supportingEvidence ?? const [],
        ),
        timelineAnchors = List<TimelineAnchor>.from(
          timelineAnchors ?? const [],
        ),
        relationshipGroups = List<RelationshipGroup>.from(
          relationshipGroups ?? const [],
        ),
        relationships = List<EvidenceRelationship>.from(
          relationships ?? const [],
        ),
        reconstructionNotes = List<ReconstructionNote>.from(
          reconstructionNotes ?? const [],
        ),
        narrativeEvents = List<NarrativeEvent>.from(
          narrativeEvents ?? const [],
        ),
        participants = List<Participant>.from(
          participants ?? const [],
        ),
        evidenceCollections = List<EvidenceCollection>.from(
          evidenceCollections ?? const [],
        ),
        relationshipSuggestions = List<RelationshipSuggestion>.from(
          relationshipSuggestions ?? const [],
        ),
        dismissedCollectionIds = Set<String>.from(
          dismissedCollectionIds ?? const {},
        ),
        organizeContextAnchors = List<OrganizeContextAnchor>.from(
          organizeContextAnchors ?? const [],
        ),
        organizeCreatedEvidenceIds = Set<String>.from(
          organizeCreatedEvidenceIds ?? const {},
        );

  Incident incident;
  final List<CapturedEvidence> capturedEvidence;
  final List<SupportingEvidence> supportingEvidence;
  final List<TimelineAnchor> timelineAnchors;
  final List<RelationshipGroup> relationshipGroups;
  final List<EvidenceRelationship> relationships;
  final List<ReconstructionNote> reconstructionNotes;
  final List<NarrativeEvent> narrativeEvents;
  final List<Participant> participants;

  /// Organize-stage Evidence Collections (Sprint 5B).
  final List<EvidenceCollection> evidenceCollections;

  /// Pending collection suggestion ids dismissed without deleting the row.
  final Set<String> dismissedCollectionIds;

  /// Explicit context→evidence relationships. Not chronology membership.
  /// Persisted locally per incident, not an evidence-record field.
  final List<OrganizeContextAnchor> organizeContextAnchors;

  /// Evidence ids created from the Organize Add-context toolbar.
  /// These are always floating context — never fixed-spine chronology.
  /// Persisted locally per incident — not an evidence-record field.
  final Set<String> organizeCreatedEvidenceIds;

  /// Pending / accepted relationship suggestions (Sprint 5C) — local first.
  final List<RelationshipSuggestion> relationshipSuggestions;
}
