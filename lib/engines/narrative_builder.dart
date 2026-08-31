import '../domain/reconstruction/narrative_event.dart';
import '../engines/evidence_semantics.dart';
import '../engines/enrichment_engine.dart';
import '../models/connection_group_node.dart';
import '../models/reflection_model.dart';
import '../models/relationship_group.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';
import '../repositories/incident_store.dart';
import '../repositories/narrative_event_repository.dart';
import '../services/investigation_narrative_reference_resolver.dart';
import '../services/narrative_validation_service.dart';
import '../services/relationship_group_color_service.dart';

/// Read model for one structured narrative event in the builder UI.
class NarrativeEventViewModel {
  const NarrativeEventViewModel({
    required this.event,
    required this.anchorNode,
    required this.relationshipGroups,
    required this.reconstructionNotes,
    required this.supportingEvidence,
    required this.displayEvidence,
    required this.validation,
    this.hasMissingReferencedEvidence = false,
    this.referenceStatusMessage,
  });

  final NarrativeEvent event;
  final TimelineAnchorNode? anchorNode;
  final List<RelationshipGroup> relationshipGroups;
  final List<ReflectionModel> reconstructionNotes;
  final List<WorkspaceEvidenceItem> supportingEvidence;
  final List<WorkspaceEvidenceItem> displayEvidence;
  final NarrativeEventValidation validation;
  final bool hasMissingReferencedEvidence;
  final String? referenceStatusMessage;

  static const missingReferenceMessage = 'Referenced evidence removed.';

  bool get isInvestigatorAdded => event.isInvestigatorAdded;
}

/// Builds structured narrative projections from the incident aggregate.
abstract class NarrativeBuilder {
  List<NarrativeEventViewModel> build(NarrativeBuildContext context);
}

class NarrativeBuildContext {
  const NarrativeBuildContext({
    required this.store,
    required this.timelineNodes,
    required this.groupNodes,
    required this.notes,
    required this.items,
    required this.groups,
    required this.enrichmentContext,
  });

  final IncidentStore store;
  final List<TimelineAnchorNode> timelineNodes;
  final List<ConnectionGroupNode> groupNodes;
  final List<ReflectionModel> notes;
  final List<WorkspaceEvidenceItem> items;
  final List<RelationshipGroup> groups;
  final EnrichmentContext enrichmentContext;
}

class DefaultNarrativeBuilder implements NarrativeBuilder {
  const DefaultNarrativeBuilder();

  @override
  List<NarrativeEventViewModel> build(NarrativeBuildContext context) {
    final referencesByEventId = <String, NarrativeEventReferences>{};
    final viewModels = <NarrativeEventViewModel>[];

    final events = List<NarrativeEvent>.from(context.store.narrativeEvents)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final event in events) {
      final anchorNode = _anchorNodeFor(event.timelineAnchorEvidenceId, context);
      final relationshipGroups = anchorNode != null
          ? RelationshipGroupColorService.groupsForEvidence(
              event.timelineAnchorEvidenceId,
              context.groups,
            )
          : _groupsFromPersistedRefs(event, context.groups);
      final supportingEvidence = anchorNode != null
          ? _existingSupportingEvidence(
              anchorNode.supportingItems,
              context.items,
            )
          : _existingSupportingFromRefs(event, context.items);
      final reconstructionNotes = _notesForEvent(
        event: event,
        context: context,
        anchorNode: anchorNode,
        relationshipGroups: relationshipGroups,
      );

      final displayEvidence = <WorkspaceEvidenceItem>[
        if (anchorNode != null) anchorNode.capturedItem,
        ...supportingEvidence,
      ];

      referencesByEventId[event.id] = NarrativeEventReferences(
        relationshipGroupIds: relationshipGroups.map((group) => group.id).toList(),
        reconstructionNoteIds: reconstructionNotes.map((note) => note.id).toList(),
        supportingEvidenceIds: supportingEvidence.map((item) => item.id).toList(),
      );

      final missingReferencedEvidence =
          !event.isInvestigatorAdded && anchorNode == null;

      viewModels.add(
        NarrativeEventViewModel(
          event: event,
          anchorNode: anchorNode,
          relationshipGroups: relationshipGroups,
          reconstructionNotes: reconstructionNotes,
          supportingEvidence: supportingEvidence,
          displayEvidence: displayEvidence,
          validation: NarrativeValidationService.validateEvent(
            displayEvidence: displayEvidence,
            supportingEvidence: supportingEvidence,
            reconstructionNotes: reconstructionNotes,
            hasMissingReferencedEvidence: missingReferencedEvidence,
            enrichmentContext: context.enrichmentContext,
            eventSummary: event.summary,
            incidentPrimaryChronologyCount:
                EvidenceSemantics.primaryChronologyCount(context.items),
          ),
          hasMissingReferencedEvidence: missingReferencedEvidence,
          referenceStatusMessage: missingReferencedEvidence
              ? NarrativeEventViewModel.missingReferenceMessage
              : null,
        ),
      );
    }

    return viewModels;
  }

  static List<RelationshipGroup> _groupsFromPersistedRefs(
    NarrativeEvent event,
    List<RelationshipGroup> groups,
  ) {
    return groups
        .where((group) => event.relationshipGroupIds.contains(group.id))
        .toList(growable: false);
  }

  static List<WorkspaceEvidenceItem> _existingSupportingEvidence(
    List<WorkspaceEvidenceItem> supportingItems,
    List<WorkspaceEvidenceItem> items,
  ) {
    final itemIds = items.map((item) => item.id).toSet();
    return supportingItems
        .where((item) => itemIds.contains(item.id))
        .toList(growable: false);
  }

  static List<WorkspaceEvidenceItem> _existingSupportingFromRefs(
    NarrativeEvent event,
    List<WorkspaceEvidenceItem> items,
  ) {
    return items
        .where((item) => event.supportingEvidenceIds.contains(item.id))
        .toList(growable: false);
  }

  static Map<String, NarrativeEventReferences> resolveReferences(
    NarrativeBuildContext context,
  ) {
    return {
      for (final viewModel in const DefaultNarrativeBuilder().build(context))
        viewModel.event.id: NarrativeEventReferences(
          relationshipGroupIds:
              viewModel.relationshipGroups.map((group) => group.id).toList(),
          reconstructionNoteIds:
              viewModel.reconstructionNotes.map((note) => note.id).toList(),
          supportingEvidenceIds:
              viewModel.supportingEvidence.map((item) => item.id).toList(),
        ),
    };
  }

  static TimelineAnchorNode? _anchorNodeFor(
    String evidenceId,
    NarrativeBuildContext context,
  ) {
    for (final node in context.timelineNodes) {
      if (node.capturedItem.id == evidenceId) {
        return node;
      }
    }
    return null;
  }

  static List<ReflectionModel> _notesForEvent({
    required NarrativeEvent event,
    required NarrativeBuildContext context,
    required TimelineAnchorNode? anchorNode,
    required List<RelationshipGroup> relationshipGroups,
  }) {
    final matches = <String, ReflectionModel>{};

    for (final note in context.notes) {
      final references = InvestigationNarrativeReferenceResolver.resolve(
        note: note,
        items: context.items,
        groups: context.groups,
        timelineNodes: context.timelineNodes,
      );

      if (references.anchorIds.contains(event.timelineAnchorEvidenceId) ||
          references.groupIds.any(
            (groupId) => relationshipGroups.any((group) => group.id == groupId),
          )) {
        matches[note.id] = note;
      }
    }

    for (final noteId in event.reconstructionNoteIds) {
      for (final note in context.notes) {
        if (note.id == noteId) {
          matches[note.id] = note;
        }
      }
    }

    if (anchorNode != null) {
      for (final note in context.notes) {
        if (InvestigationNarrativeReferenceResolver.narrativeSectionsForEvidence(
          evidenceId: anchorNode.capturedItem.id,
          notes: [note],
          items: context.items,
          groups: context.groups,
          timelineNodes: context.timelineNodes,
        ).contains(note.id)) {
          matches[note.id] = note;
        }
      }
    }

    return matches.values.toList();
  }
}
