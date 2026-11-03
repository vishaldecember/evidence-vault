import 'package:flutter/material.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../models/evidence_relationship.dart';
import '../../models/workspace_evidence_item.dart';
import 'connections_tree_view.dart';

/// Connections perspective — structured relationship trees.
class ConnectionsWorkspace extends StatelessWidget {
  const ConnectionsWorkspace({
    super.key,
    required this.incidentId,
    required this.evidence,
    required this.relationships,
    this.collections = const [],
    this.contextAnchors = const [],
    this.onEvidenceTap,
  });

  final String incidentId;
  final List<WorkspaceEvidenceItem> evidence;
  final List<EvidenceRelationship> relationships;
  final List<EvidenceCollection> collections;
  final List<OrganizeContextAnchor> contextAnchors;
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceTap;

  static const scrollStorageKey = PageStorageKey<String>(
    'investigation_connections_workspace_scroll',
  );

  @override
  Widget build(BuildContext context) {
    return ConnectionsTreeView(
      key: scrollStorageKey,
      incidentId: incidentId,
      evidence: evidence,
      relationships: relationships,
      collections: collections,
      contextAnchors: contextAnchors,
      onEvidenceTap: onEvidenceTap,
    );
  }
}
