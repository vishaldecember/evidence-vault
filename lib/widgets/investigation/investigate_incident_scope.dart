import 'package:flutter/foundation.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/incident/current_incident.dart';
import '../../domain/incident/incident_status.dart';
import '../../domain/relationship/relationship_suggestion.dart';
import '../../engines/narrative_builder.dart';
import '../../models/connection_group_node.dart';
import '../../models/evidence_relationship.dart';
import '../../models/journey_stage.dart';
import '../../models/relationship_group.dart';
import '../../models/timeline_anchor_node.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/relationship/relationship_engine.dart';

/// Presentation-only incident scope for Investigate lists.
///
/// Does not mutate stores. Foreign evidence is excluded, never reassigned.
abstract final class InvestigateIncidentScope {
  static bool owns(WorkspaceEvidenceItem item, String incidentId) {
    return item.belongsToIncident(incidentId);
  }

  /// Fail-closed write gate for a bound workspace.
  ///
  /// Blank bound or session identity never authorizes a write. A mismatched
  /// session must not remap the write onto either incident.
  static bool sessionMatchesBound(
    String boundIncidentId,
    String sessionIncidentId,
  ) {
    final bound = boundIncidentId.trim();
    return bound.isNotEmpty && sessionIncidentId == bound;
  }

  static void _logExcluded({
    required String expectedIncidentId,
    required String actualIncidentId,
    required String evidenceId,
  }) {
    debugPrint(
      '[Investigate] excluded foreign evidence\n'
      'EXPECTED INCIDENT:\n$expectedIncidentId\n\n'
      'ACTUAL INCIDENT:\n$actualIncidentId\n\n'
      'EXPECTED EVIDENCE:\n(owned by $expectedIncidentId)\n\n'
      'ACTUAL EVIDENCE:\n$evidenceId',
    );
  }

  static List<WorkspaceEvidenceItem> evidence(
    Iterable<WorkspaceEvidenceItem> items,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    final owned = <WorkspaceEvidenceItem>[];
    for (final item in items) {
      if (owns(item, incidentId)) {
        owned.add(item);
      } else {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: item.incidentId,
          evidenceId: item.id,
        );
      }
    }
    return owned;
  }

  /// Capture chronology (`sequenceOrder`) — does not sort by lastPreservedAt.
  static List<TimelineAnchorNode> timeline(
    Iterable<TimelineAnchorNode> nodes,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    final scoped = <TimelineAnchorNode>[];
    for (final node in nodes) {
      if (!owns(node.capturedItem, incidentId)) {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: node.capturedItem.incidentId,
          evidenceId: node.capturedItem.id,
        );
        continue;
      }
      if (node.anchor.incidentId.isNotEmpty &&
          node.anchor.incidentId != incidentId) {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: node.anchor.incidentId,
          evidenceId: node.capturedItem.id,
        );
        continue;
      }
      scoped.add(
        TimelineAnchorNode(
          anchor: node.anchor,
          capturedItem: node.capturedItem,
          supportingItems: evidence(node.supportingItems, incidentId),
        ),
      );
    }
    return scoped;
  }

  static List<ConnectionGroupNode> connections(
    Iterable<ConnectionGroupNode> nodes,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    return [
      for (final node in nodes)
        ConnectionGroupNode(
          group: node.group,
          capturedEntries: [
            for (final entry in node.capturedEntries)
              if (owns(entry.captured, incidentId))
                ConnectionGroupCapturedEntry(
                  captured: entry.captured,
                  supportingItems: evidence(entry.supportingItems, incidentId),
                ),
          ],
          standaloneSupporting: evidence(node.standaloneSupporting, incidentId),
        ),
    ];
  }

  /// Keeps a relationship only when both ends belong to [incidentId].
  static List<EvidenceRelationship> relationships(
    Iterable<EvidenceRelationship> relationships,
    Iterable<WorkspaceEvidenceItem> items,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    final ownedIds = {
      for (final item in evidence(items, incidentId)) item.id,
    };
    final byId = {for (final item in items) item.id: item};
    final scoped = <EvidenceRelationship>[];
    for (final relationship in relationships) {
      final source = byId[relationship.sourceEvidenceId];
      final target = byId[relationship.targetEvidenceId];
      final sourceOwned = ownedIds.contains(relationship.sourceEvidenceId);
      final targetOwned = ownedIds.contains(relationship.targetEvidenceId);
      if (sourceOwned && targetOwned) {
        scoped.add(relationship);
        continue;
      }
      final foreign = (source != null && !owns(source, incidentId))
          ? source
          : (target != null && !owns(target, incidentId) ? target : null);
      if (foreign != null) {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: foreign.incidentId,
          evidenceId: foreign.id,
        );
      }
    }
    return scoped;
  }

  static List<RelationshipGroup> relationshipGroups(
    Iterable<RelationshipGroup> groups,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    return [
      for (final group in groups)
        if (group.incidentId.isNotEmpty && group.incidentId == incidentId)
          group,
    ];
  }

  static List<EvidenceCollection> collections(
    Iterable<EvidenceCollection> collections,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    return [
      for (final collection in collections)
        if (collection.incidentId.isNotEmpty &&
            collection.incidentId == incidentId)
          collection,
    ];
  }

  static List<RelationshipSuggestion> suggestions(
    Iterable<RelationshipSuggestion> suggestions,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    return [
      for (final suggestion in suggestions)
        if (suggestion.incidentId.isNotEmpty &&
            suggestion.incidentId == incidentId)
          suggestion,
    ];
  }

  static InvestigationGraphView graph(
    InvestigationGraphView view,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const InvestigationGraphView(
        primaryEvidenceIds: [],
        supportingByPrimaryId: {},
        edges: [],
        collections: [],
        evidenceById: {},
      );
    }
    final ownedById = {
      for (final item in evidence(view.evidenceById.values, incidentId))
        item.id: item,
    };
    final ownedIds = ownedById.keys.toSet();
    return InvestigationGraphView(
      primaryEvidenceIds: [
        for (final id in view.primaryEvidenceIds)
          if (ownedIds.contains(id)) id,
      ],
      supportingByPrimaryId: {
        for (final entry in view.supportingByPrimaryId.entries)
          if (ownedIds.contains(entry.key))
            entry.key: [
              for (final id in entry.value)
                if (ownedIds.contains(id)) id,
            ],
      },
      edges: [
        for (final edge in view.edges)
          if (ownedIds.contains(edge.sourceEvidenceId) &&
              ownedIds.contains(edge.targetEvidenceId))
            edge,
      ],
      collections: [
        for (final collection in view.collections)
          if (collection.incidentId.isNotEmpty &&
              collection.incidentId == incidentId)
            collection,
      ],
      evidenceById: ownedById,
    );
  }

  static List<NarrativeEventViewModel> reconstruction(
    Iterable<NarrativeEventViewModel> events,
    String incidentId,
  ) {
    if (incidentId.isEmpty) {
      return const [];
    }
    final scoped = <NarrativeEventViewModel>[];
    for (final event in events) {
      final eventIncidentId = event.event.incidentId;
      if (eventIncidentId.isEmpty || eventIncidentId != incidentId) {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: eventIncidentId,
          evidenceId: event.event.id,
        );
        continue;
      }
      final captured = event.anchorNode?.capturedItem;
      if (captured != null && !owns(captured, incidentId)) {
        _logExcluded(
          expectedIncidentId: incidentId,
          actualIncidentId: captured.incidentId,
          evidenceId: captured.id,
        );
        continue;
      }
      final display = evidence(event.displayEvidence, incidentId);
      if (captured == null &&
          event.displayEvidence.isNotEmpty &&
          display.isEmpty) {
        continue;
      }
      final scopedAnchors = event.anchorNode == null
          ? const <TimelineAnchorNode>[]
          : timeline([event.anchorNode!], incidentId);
      scoped.add(
        NarrativeEventViewModel(
          event: event.event,
          anchorNode: scopedAnchors.isEmpty ? null : scopedAnchors.first,
          relationshipGroups: event.relationshipGroups,
          reconstructionNotes: event.reconstructionNotes,
          supportingEvidence: evidence(event.supportingEvidence, incidentId),
          displayEvidence: display,
          validation: event.validation,
          hasMissingReferencedEvidence: event.hasMissingReferencedEvidence,
          referenceStatusMessage: event.referenceStatusMessage,
        ),
      );
    }
    return scoped;
  }

  /// Presentation slice for Capture / Organize / Trust under [boundIncidentId].
  ///
  /// If the session working set is a different incident, returns an empty
  /// slice keyed to the bound id — never the foreign incident's evidence.
  static CurrentIncident presentation(
    CurrentIncident current,
    String boundIncidentId,
  ) {
    final bound = boundIncidentId.trim();
    if (bound.isEmpty || current.id.trim() != bound) {
      debugPrint(
        '[Workspace] presentation empty — bound=$bound '
        'session=${current.id} sessionEvidence=${current.evidence.length}',
      );
      return CurrentIncident(
        id: bound,
        title: '',
        status: IncidentStatus.draft,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        manuallyComplete: false,
        journeyStage: JourneyStage.empty,
        captureProgressPercent: 0,
        timelineAnchorCount: 0,
        relationshipGroupCount: 0,
        narrativeEventCount: 0,
        evidence: const [],
        journeyEvidence: const [],
        relationshipGroups: const [],
        evidenceCollections: const [],
        trustPackageReady: false,
        trustPackageProgressPercent: 0,
      );
    }
    final scopedEvidence = evidence(current.evidence, bound);
    final scopedJourney = evidence(current.journeyEvidence, bound);
    if (current.evidence.length != scopedEvidence.length ||
        current.journeyEvidence.length != scopedJourney.length) {
      debugPrint(
        '[Workspace] presentation filtered bound=$bound '
        'sessionEvidence=${current.evidence.length} '
        'presented=${scopedEvidence.length} '
        'sessionIds=${[
          for (final item in current.evidence) '${item.id}:${item.incidentId}',
        ]} '
        'presentedIds=${[for (final item in scopedEvidence) item.id]}',
      );
    }
    return CurrentIncident(
      id: current.id,
      title: current.title,
      status: current.status,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      manuallyComplete: current.manuallyComplete,
      journeyStage: current.journeyStage,
      captureProgressPercent: current.captureProgressPercent,
      timelineAnchorCount: current.timelineAnchorCount,
      relationshipGroupCount: current.relationshipGroupCount,
      narrativeEventCount: current.narrativeEventCount,
      evidence: scopedEvidence,
      journeyEvidence: scopedJourney,
      relationshipGroups: relationshipGroups(
        current.relationshipGroups,
        bound,
      ),
      evidenceCollections: collections(current.evidenceCollections, bound),
      trustPackageReady: current.trustPackageReady,
      trustPackageProgressPercent: current.trustPackageProgressPercent,
      coverEvidenceId: current.coverEvidenceId,
    );
  }
}
