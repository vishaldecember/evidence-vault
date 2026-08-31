import 'relationship_group.dart';
import 'relationship_type.dart';
import 'reflection_model.dart';
import 'workspace_evidence_item.dart';

/// Connects two preserved Evidence Artifacts without duplicating or modifying either.
///
/// Extension points reserved for bidirectional links, witness relationships,
/// location relationships, AI suggestions, and graph visualization.
class EvidenceRelationship {
  const EvidenceRelationship({
    required this.id,
    required this.sourceEvidenceId,
    required this.targetEvidenceId,
    required this.type,
    required this.createdAt,
    this.reason,
    this.source,
  });

  final String id;
  final String sourceEvidenceId;
  final String targetEvidenceId;
  final RelationshipType type;
  final DateTime createdAt;

  /// Human-readable explanation when system-generated (Sprint 5C).
  final String? reason;

  /// metadata | user | ai
  final String? source;
}

/// In-memory workspace state for the Evidence Map presentation layer.
class WorkspaceEvidenceState {
  const WorkspaceEvidenceState({
    this.items = const [],
    this.relationships = const [],
    this.relationshipGroups = const [],
    this.reflections = const [],
    this.incidentName = '',
    this.incidentManuallyComplete = false,
  });

  final List<WorkspaceEvidenceItem> items;
  final List<EvidenceRelationship> relationships;
  final List<RelationshipGroup> relationshipGroups;
  final List<ReflectionModel> reflections;
  final String incidentName;
  final bool incidentManuallyComplete;

  bool get isEmpty => items.isEmpty;

  /// Latest evidence first.
  List<WorkspaceEvidenceItem> get sortedItems {
    final sorted = List<WorkspaceEvidenceItem>.from(items)
      ..sort((a, b) => b.lastPreservedAt.compareTo(a.lastPreservedAt));
    return sorted;
  }

  /// Latest reflection first.
  List<ReflectionModel> get sortedReflections {
    final sorted = List<ReflectionModel>.from(reflections)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  WorkspaceEvidenceState copyWith({
    List<WorkspaceEvidenceItem>? items,
    List<EvidenceRelationship>? relationships,
    List<RelationshipGroup>? relationshipGroups,
    List<ReflectionModel>? reflections,
    String? incidentName,
    bool? incidentManuallyComplete,
  }) {
    return WorkspaceEvidenceState(
      items: items ?? this.items,
      relationships: relationships ?? this.relationships,
      relationshipGroups: relationshipGroups ?? this.relationshipGroups,
      reflections: reflections ?? this.reflections,
      incidentName: incidentName ?? this.incidentName,
      incidentManuallyComplete:
          incidentManuallyComplete ?? this.incidentManuallyComplete,
    );
  }
}
