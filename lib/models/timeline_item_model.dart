import '../domain/incident/incident_aggregate.dart';
import '../mappers/evidence_projection.dart';
import 'evidence_artifact_model.dart';
import 'timeline_event_type.dart';
import 'workspace_evidence_item.dart';

/// Read-only view of one chronological incident event.
///
/// Aggregated from existing workspace data — never duplicates storage.
/// Extension points reserved for relationship, reflection, witness,
/// verification, AI, and export events.
class TimelineItemModel {
  const TimelineItemModel({
    required this.evidenceId,
    required this.eventType,
    required this.title,
    required this.description,
    required this.occurredAt,
    this.artifactType,
  });

  /// Opens the corresponding [EvidenceRecordScreen].
  final String evidenceId;
  final TimelineEventType eventType;
  final String title;
  final String description;
  final DateTime occurredAt;
  final EvidenceArtifactType? artifactType;

  /// Builds timeline events from workspace artifacts and context items.
  ///
  /// [newestFirst] defaults to true; architecture supports oldest-first later.
  static List<TimelineItemModel> fromWorkspace({
    required List<WorkspaceEvidenceItem> items,
    bool newestFirst = true,
  }) {
    final events = items.map((item) {
      final artifactType =
          EvidenceArtifactType.fromWorkspaceKind(item.kind);

      if (item.isContextual) {
        return TimelineItemModel(
          evidenceId: item.id,
          eventType: TimelineEventType.contextAdded,
          title: TimelineEventType.contextAdded.label,
          description: artifactType.label,
          occurredAt: item.lastPreservedAt,
          artifactType: artifactType,
        );
      }

      return TimelineItemModel(
        evidenceId: item.id,
        eventType: TimelineEventType.evidencePreserved,
        title: TimelineEventType.evidencePreserved.label,
        description: artifactType.label,
        occurredAt: item.lastPreservedAt,
        artifactType: artifactType,
      );
    }).toList();

    events.sort(
      (a, b) => newestFirst
          ? b.occurredAt.compareTo(a.occurredAt)
          : a.occurredAt.compareTo(b.occurredAt),
    );

    return events;
  }

  /// Builds timeline events from immutable [TimelineAnchor] order.
  static List<TimelineItemModel> fromIncidentAggregate(
    IncidentAggregate aggregate, {
    bool newestFirst = true,
  }) {
    final items = EvidenceProjection.toWorkspaceItems(aggregate.store);
    final itemById = {for (final item in items) item.id: item};
    final events = <TimelineItemModel>[];

    for (final anchor
        in aggregate.timelineRepository.orderedCapturedEvidenceIds()) {
      final item = itemById[anchor];
      if (item == null) {
        continue;
      }
      final artifactType =
          EvidenceArtifactType.fromWorkspaceKind(item.kind);
      events.add(
        TimelineItemModel(
          evidenceId: item.id,
          eventType: TimelineEventType.evidencePreserved,
          title: TimelineEventType.evidencePreserved.label,
          description: artifactType.label,
          occurredAt: item.lastPreservedAt,
          artifactType: artifactType,
        ),
      );
    }

    for (final item in items.where((entry) => entry.isContextual)) {
      final artifactType =
          EvidenceArtifactType.fromWorkspaceKind(item.kind);
      events.add(
        TimelineItemModel(
          evidenceId: item.id,
          eventType: TimelineEventType.contextAdded,
          title: TimelineEventType.contextAdded.label,
          description: artifactType.label,
          occurredAt: item.lastPreservedAt,
          artifactType: artifactType,
        ),
      );
    }

    if (newestFirst) {
      return events.reversed.toList();
    }
    return events;
  }
}
