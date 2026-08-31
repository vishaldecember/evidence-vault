import 'package:flutter/foundation.dart';

import '../domain/collection/evidence_collection.dart';
import 'connection_group_node.dart';
import 'workspace_evidence_item.dart';

/// How a Connections pair was derived — presentation only, not persisted.
enum ConnectionsPairKind {
  supporting,
  linked,
  suggested,
}

/// One structural or suggested evidence pair in Connections.
class ConnectionsPairView {
  const ConnectionsPairView({
    required this.from,
    required this.to,
    required this.kind,
    required this.label,
    this.detail,
    this.confidence,
  });

  final WorkspaceEvidenceItem from;
  final WorkspaceEvidenceItem to;
  final ConnectionsPairKind kind;
  final String label;
  final String? detail;
  final double? confidence;

  bool get isSuggested => kind == ConnectionsPairKind.suggested;

  String get pairId {
    final a = from.id;
    final b = to.id;
    return a.compareTo(b) <= 0 ? '${a}__$b' : '${b}__$a';
  }
}

/// Collection membership shown as grouping context, never as causality.
class ConnectionsCollectionView {
  const ConnectionsCollectionView({
    required this.collection,
    required this.members,
  });

  final EvidenceCollection collection;
  final List<WorkspaceEvidenceItem> members;

  String get name {
    final trimmed = collection.name.trim();
    return trimmed.isEmpty ? 'Collection' : trimmed;
  }
}

/// Incident-scoped Connections presentation.
///
/// Structural = persisted parent/child, explicit links, collections, groups.
/// Suggested = heuristic RELATED — never shown as established fact.
class ConnectionsPresentation {
  const ConnectionsPresentation({
    required this.incidentId,
    required this.supporting,
    required this.linked,
    required this.collections,
    required this.groupNodes,
    required this.suggested,
  });

  final String incidentId;
  final List<ConnectionsPairView> supporting;
  final List<ConnectionsPairView> linked;
  final List<ConnectionsCollectionView> collections;
  final List<ConnectionGroupNode> groupNodes;
  final List<ConnectionsPairView> suggested;

  bool get hasStructural =>
      supporting.isNotEmpty ||
      linked.isNotEmpty ||
      collections.isNotEmpty ||
      groupNodes.any((node) => node.evidenceCount > 0);

  bool get hasSuggested => suggested.isNotEmpty;

  bool get isEmpty => !hasStructural && !hasSuggested;

  static const Key structuralSectionKey = Key('connections_structural_section');
  static const Key suggestedSectionKey = Key('connections_suggested_section');
  static const Key emptyStructuralKey = Key('connections_empty_structural');
  static const Key editGroupsKey = Key('connections_edit_groups');

  static Key pairKey(ConnectionsPairView pair) =>
      Key('connections_pair_${pair.pairId}');

  static Key suggestedKey(ConnectionsPairView pair) =>
      Key('connections_suggested_${pair.pairId}');

  static Key collectionKey(String collectionId) =>
      Key('connections_collection_$collectionId');
}
