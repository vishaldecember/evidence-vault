import 'package:flutter/material.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../models/evidence_relationship.dart';
import '../../models/workspace_evidence_item.dart';
import 'investigation_connections_canvas.dart';

/// Connections perspective — spatial traces, independent of Groups.
class ConnectionsWorkspace extends StatelessWidget {
  const ConnectionsWorkspace({
    super.key,
    required this.incidentId,
    required this.evidence,
    required this.relationships,
    required this.collections,
    this.onEvidenceTap,
  });

  final String incidentId;
  final List<WorkspaceEvidenceItem> evidence;
  final List<EvidenceRelationship> relationships;
  final List<EvidenceCollection> collections;
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceTap;

  static const scrollStorageKey = PageStorageKey<String>(
    'investigation_connections_workspace_scroll',
  );

  @override
  Widget build(BuildContext context) {
    return InvestigationConnectionsCanvas(
      key: scrollStorageKey,
      incidentId: incidentId,
      evidence: evidence,
      relationships: relationships,
      collections: collections,
      onEvidenceTap: onEvidenceTap,
    );
  }
}
