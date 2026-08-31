import '../domain/organize/organize_context_anchor.dart';
import '../domain/relationship/relationship_group.dart';
import '../domain/timeline/timeline_anchor.dart';
import '../mappers/evidence_projection.dart';
import '../repositories/incident_store.dart';
import '../repositories/timeline_repository.dart';
import '../services/relationship_group_color_service.dart';
import '../models/connection_group_node.dart';
import '../models/timeline_anchor_node.dart';
import '../models/workspace_evidence_item.dart';

/// Read-only access to workspace evidence for presentation layers.
///
/// [WorkspaceEvidenceController] is the single source of truth; this repository
/// centralises derived reads so UI widgets do not apply competing filters.
abstract final class WorkspaceEvidenceRepository {
  WorkspaceEvidenceRepository._();

  /// Chronological capture sequence for the Incident Journey strip.
  ///
  /// Preserves capture order — never reorders. Primary and supporting items
  /// both appear; connector colour communicates chronology vs enrichment.
  static List<WorkspaceEvidenceItem> journeySequence(
    IncidentStore store,
    TimelineRepository timelineRepository,
  ) {
    final items = EvidenceProjection.toWorkspaceItems(store);
    final orderedPrimaryIds = timelineRepository.orderedCapturedEvidenceIds();
    final primaryOrder = <String, int>{
      for (var i = 0; i < orderedPrimaryIds.length; i++)
        orderedPrimaryIds[i]: i,
    };

    final sequence = List<WorkspaceEvidenceItem>.from(items)
      ..sort((a, b) {
        final byTime = a.lastPreservedAt.compareTo(b.lastPreservedAt);
        if (byTime != 0) {
          return byTime;
        }
        // Tie-break primaries by timeline order only when both are primary.
        final aOrder = primaryOrder[a.id];
        final bOrder = primaryOrder[b.id];
        if (aOrder != null && bOrder != null) {
          return aOrder.compareTo(bOrder);
        }
        return a.id.compareTo(b.id);
      });
    return List<WorkspaceEvidenceItem>.unmodifiable(
      _dedupeById(sequence),
    );
  }

  /// Helper for tests — chronological capture order including supporting items.
  static List<WorkspaceEvidenceItem> journeySequenceFromItems(
    List<WorkspaceEvidenceItem> items,
  ) {
    final sequence = List<WorkspaceEvidenceItem>.from(items)
      ..sort((a, b) {
        final byTime = a.lastPreservedAt.compareTo(b.lastPreservedAt);
        if (byTime != 0) {
          return byTime;
        }
        return a.id.compareTo(b.id);
      });
    return List<WorkspaceEvidenceItem>.unmodifiable(
      _dedupeById(sequence),
    );
  }

  /// Keeps the first occurrence of each evidence id — duplicate ids must never
  /// reach the Journey [Wrap] (duplicate [ValueKey]s crash the tree).
  static List<WorkspaceEvidenceItem> _dedupeById(
    List<WorkspaceEvidenceItem> items,
  ) {
    final seen = <String>{};
    final unique = <WorkspaceEvidenceItem>[];
    for (final item in items) {
      if (seen.add(item.id)) {
        unique.add(item);
      }
    }
    return unique;
  }

  /// Anchor-ordered reconstruction tree for the Timeline Workspace.
  ///
  /// Captured evidence follows immutable [TimelineAnchor] order.
  /// Supporting evidence attaches beneath its parent anchor only.
  static List<TimelineAnchorNode> anchoredTree(
    IncidentStore store,
    TimelineRepository timelineRepository,
  ) {
    final items = EvidenceProjection.toWorkspaceItems(store);
    final itemById = {for (final item in items) item.id: item};
    final anchorByCapturedId = {
      for (final anchor in store.timelineAnchors) anchor.capturedEvidenceId: anchor,
    };
    final capturedById = {
      for (final captured in store.capturedEvidence) captured.id: captured,
    };

    final nodes = <TimelineAnchorNode>[];

    for (final capturedId in timelineRepository.orderedCapturedEvidenceIds()) {
      final capturedItem = itemById[capturedId];
      if (capturedItem == null) {
        continue;
      }

      final anchor = anchorByCapturedId[capturedId] ??
          _fallbackAnchor(
            store: store,
            capturedId: capturedId,
            capturedAt: capturedById[capturedId]?.capturedAt,
            sequenceOrder: nodes.length,
          );

      nodes.add(
        TimelineAnchorNode(
          anchor: anchor,
          capturedItem: capturedItem,
          supportingItems: _supportingForParent(
            items,
            capturedId,
            organizeAnchors: store.organizeContextAnchors,
          ),
        ),
      );
    }

    final nestedIds = <String>{
      for (final node in nodes) node.capturedItem.id,
      for (final node in nodes)
        for (final supporting in node.supportingItems) supporting.id,
    };
    final standalone = [
      for (final item in items)
        if (!nestedIds.contains(item.id) && _isTimelineStandalone(item)) item,
    ]..sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));

    for (final item in standalone) {
      final node = TimelineAnchorNode(
        anchor: _fallbackAnchor(
          store: store,
          capturedId: item.id,
          capturedAt: item.lastPreservedAt,
          sequenceOrder: nodes.length,
        ),
        capturedItem: item,
        supportingItems: const [],
      );
      var insertAt = nodes.length;
      for (var i = 0; i < nodes.length; i++) {
        if (item.lastPreservedAt.isBefore(
          nodes[i].capturedItem.lastPreservedAt,
        )) {
          insertAt = i;
          break;
        }
      }
      nodes.insert(insertAt, node);
    }

    return List<TimelineAnchorNode>.unmodifiable(nodes);
  }

  static bool _isTimelineStandalone(WorkspaceEvidenceItem item) {
    return item.kind == WorkspaceEvidenceKind.note ||
        item.kind == WorkspaceEvidenceKind.attachment ||
        item.kind == WorkspaceEvidenceKind.witness ||
        item.isSupportingEvidence ||
        item.isContextual;
  }

  /// Builds presentation nodes for each [RelationshipGroup].
  static List<ConnectionGroupNode> connectionGroupNodes(
    IncidentStore store,
    TimelineRepository timelineRepository,
  ) {
    final items = EvidenceProjection.toWorkspaceItems(store);
    final itemById = {for (final item in items) item.id: item};
    final orderedGroups =
        RelationshipGroupColorService.orderedGroups(store.relationshipGroups);

    return [
      for (final group in orderedGroups)
        _connectionGroupNode(
          store: store,
          timelineRepository: timelineRepository,
          group: group,
          itemById: itemById,
          items: items,
        ),
    ];
  }

  static ConnectionGroupNode _connectionGroupNode({
    required IncidentStore store,
    required TimelineRepository timelineRepository,
    required RelationshipGroup group,
    required Map<String, WorkspaceEvidenceItem> itemById,
    required List<WorkspaceEvidenceItem> items,
  }) {
    final memberSet = group.memberEvidenceIds.toSet();
    final capturedEntries = <ConnectionGroupCapturedEntry>[];

    for (final capturedId
        in timelineRepository.orderedCapturedEvidenceIds()) {
      if (!memberSet.contains(capturedId)) {
        continue;
      }

      final captured = itemById[capturedId];
      if (captured == null) {
        continue;
      }

      capturedEntries.add(
        ConnectionGroupCapturedEntry(
          captured: captured,
          supportingItems: _supportingForParent(items, capturedId)
              .where((item) => memberSet.contains(item.id))
              .toList(),
        ),
      );
    }

    final nestedSupportingIds = capturedEntries
        .expand((entry) => entry.supportingItems)
        .map((item) => item.id)
        .toSet();

    final standaloneSupporting = items
        .where(
          (item) =>
              memberSet.contains(item.id) &&
              !nestedSupportingIds.contains(item.id) &&
              !capturedEntries.any((entry) => entry.captured.id == item.id),
        )
        .toList()
      ..sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));

    return ConnectionGroupNode(
      group: group,
      capturedEntries: capturedEntries,
      standaloneSupporting: standaloneSupporting,
    );
  }

  static List<WorkspaceEvidenceItem> _supportingForParent(
    List<WorkspaceEvidenceItem> items,
    String parentCapturedId, {
    List<OrganizeContextAnchor> organizeAnchors = const [],
  }) {
    final organizedIds = {
      for (final anchor in organizeAnchors)
        if (anchor.capturedEvidenceId == parentCapturedId)
          anchor.contextEvidenceId,
    };
    // Timeline nest uses the legacy supporting-*kind* getter plus parent/related
    // ids. Coaching/risk must not treat this kind filter as the definition of
    // structural support (see EvidenceSemantics.hasStructuralSupport).
    return items
        .where(
          (item) =>
              item.isSupportingEvidence &&
              (item.parentEvidenceId == parentCapturedId ||
                  item.relatedEvidenceIds.contains(parentCapturedId) ||
                  organizedIds.contains(item.id)),
        )
        .toList()
      ..sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));
  }

  static TimelineAnchor _fallbackAnchor({
    required IncidentStore store,
    required String capturedId,
    required DateTime? capturedAt,
    required int sequenceOrder,
  }) {
    return TimelineAnchor(
      id: 'timeline-anchor-fallback-$capturedId',
      incidentId: store.incident.id,
      capturedEvidenceId: capturedId,
      anchoredAt: capturedAt ?? DateTime.now(),
      sequenceOrder: sequenceOrder,
    );
  }
}
