import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/investigation/connection_trace.dart';
import '../../models/workspace_evidence_item.dart';

/// Persists the user's Connections arrangement independently of evidence.
///
/// Never writes Timeline, Groups, people, locations, or evidence metadata.
class UserConnectionOverlayStore extends ChangeNotifier {
  UserConnectionOverlayStore._();

  static final UserConnectionOverlayStore instance =
      UserConnectionOverlayStore._();

  final Map<String, ConnectionTraceSnapshot> _mine = {};

  ConnectionTraceSnapshot? snapshotFor(String incidentId) => _mine[incidentId];

  bool hasUserArrangement(String incidentId) => _mine.containsKey(incidentId);

  @visibleForTesting
  void resetForTests() {
    _mine.clear();
  }

  Future<void> removeForIncident(String incidentId) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    _mine.remove(id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(id));
    } catch (_) {}
  }

  Future<void> hydrate(String incidentId) async {
    if (_mine.containsKey(incidentId)) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(incidentId));
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      _mine[incidentId] = _fromJson(Map<String, dynamic>.from(decoded));
      notifyListeners();
    } catch (_) {
      // Overlay is visualization-only; a failed restore leaves System Generated.
    }
  }

  Future<void> save({
    required String incidentId,
    required ConnectionTraceSnapshot snapshot,
  }) async {
    _mine[incidentId] = snapshot;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(incidentId), jsonEncode(_toJson(snapshot)));
    } catch (_) {}
  }

  ConnectionTraceSnapshot cloneSystem(ConnectionTraceSnapshot system) {
    return ConnectionTraceSnapshot(
      nodes: [
        for (final node in system.nodes)
          node.copyWith(position: Offset(node.position.dx, node.position.dy)),
      ],
      links: [
        for (final link in system.links)
          ConnectionTraceLink(
            fromId: link.fromId,
            toId: link.toId,
            origin: link.origin,
          ),
      ],
      size: system.size,
    );
  }

  static String _key(String incidentId) =>
      'investigation_my_connections_$incidentId';

  static Map<String, Object?> _toJson(ConnectionTraceSnapshot snapshot) {
    return {
      'size': {'w': snapshot.size.width, 'h': snapshot.size.height},
      'nodes': [
        for (final node in snapshot.nodes)
          {
            'id': node.id,
            'kind': node.kind.name,
            'label': node.label,
            'timestamp': node.timestamp.toIso8601String(),
            'x': node.position.dx,
            'y': node.position.dy,
            'evidenceId': node.evidenceId,
            if (node.evidenceKind != null) 'evidenceKind': node.evidenceKind!.name,
          },
      ],
      'links': [
        for (final link in snapshot.links)
          {
            'from': link.fromId,
            'to': link.toId,
            'origin': link.origin.name,
          },
      ],
    };
  }

  static ConnectionTraceSnapshot _fromJson(Map<String, dynamic> json) {
    final sizeRaw = json['size'];
    final size = sizeRaw is Map
        ? Size(
            (sizeRaw['w'] as num?)?.toDouble() ?? 400,
            (sizeRaw['h'] as num?)?.toDouble() ?? 280,
          )
        : const Size(400, 280);
    final nodesRaw = json['nodes'];
    final linksRaw = json['links'];
    return ConnectionTraceSnapshot(
      size: size,
      nodes: [
        if (nodesRaw is List)
          for (final raw in nodesRaw)
            if (raw is Map)
              ConnectionTraceNode(
                id: '${raw['id']}',
                kind: ConnectionTraceKind.values.firstWhere(
                  (value) => value.name == raw['kind'],
                  orElse: () => ConnectionTraceKind.moment,
                ),
                label: '${raw['label'] ?? ''}',
                timestamp:
                    DateTime.tryParse('${raw['timestamp']}') ??
                    DateTime.fromMillisecondsSinceEpoch(0),
                position: Offset(
                  (raw['x'] as num?)?.toDouble() ?? 0,
                  (raw['y'] as num?)?.toDouble() ?? 0,
                ),
                evidenceId: raw['evidenceId'] as String?,
                evidenceKind: _kindFromJson(raw['evidenceKind']),
              ),
      ],
      links: [
        if (linksRaw is List)
          for (final raw in linksRaw)
            if (raw is Map)
              ConnectionTraceLink(
                fromId: '${raw['from']}',
                toId: '${raw['to']}',
                origin: ConnectionTraceOrigin.values.firstWhere(
                  (value) => value.name == raw['origin'],
                  orElse: () => ConnectionTraceOrigin.user,
                ),
              ),
      ],
    );
  }

  static WorkspaceEvidenceKind? _kindFromJson(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    for (final value in WorkspaceEvidenceKind.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}
