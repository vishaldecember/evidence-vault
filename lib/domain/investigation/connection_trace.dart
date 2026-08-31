import 'dart:ui';

import '../../models/workspace_evidence_item.dart';

enum ConnectionTraceKind { moment, context, person, location }

/// Provenance of a Connections trace. Colors communicate this, not labels.
enum ConnectionTraceOrigin { systemGenerated, user }

class ConnectionTraceNode {
  const ConnectionTraceNode({
    required this.id,
    required this.kind,
    required this.label,
    required this.timestamp,
    required this.position,
    this.evidenceId,
    this.evidenceKind,
  });

  final String id;
  final ConnectionTraceKind kind;
  final String label;
  final DateTime timestamp;
  final Offset position;
  final String? evidenceId;
  final WorkspaceEvidenceKind? evidenceKind;

  ConnectionTraceNode copyWith({Offset? position}) {
    return ConnectionTraceNode(
      id: id,
      kind: kind,
      label: label,
      timestamp: timestamp,
      position: position ?? this.position,
      evidenceId: evidenceId,
      evidenceKind: evidenceKind,
    );
  }
}

class ConnectionTraceLink {
  const ConnectionTraceLink({
    required this.fromId,
    required this.toId,
    this.origin = ConnectionTraceOrigin.systemGenerated,
  });

  final String fromId;
  final String toId;
  final ConnectionTraceOrigin origin;
}

class ConnectionTraceSnapshot {
  const ConnectionTraceSnapshot({
    this.nodes = const [],
    this.links = const [],
    this.size = const Size(400, 280),
  });

  final List<ConnectionTraceNode> nodes;
  final List<ConnectionTraceLink> links;
  final Size size;

  ConnectionTraceSnapshot copyWith({
    List<ConnectionTraceNode>? nodes,
    List<ConnectionTraceLink>? links,
    Size? size,
  }) {
    return ConnectionTraceSnapshot(
      nodes: nodes ?? this.nodes,
      links: links ?? this.links,
      size: size ?? this.size,
    );
  }
}
