import 'dart:math' as math;
import 'dart:ui';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/investigation/connection_trace.dart';
import '../../engines/evidence_semantics.dart';
import '../../models/evidence_relationship.dart';
import '../../models/workspace_evidence_item.dart';

/// Derives system-generated connection traces from persisted incident data.
///
/// Layout is spatial and relational — not chronological. Does not invent links.
abstract final class ConnectionTraceEngine {
  static const double scale = 1.1;
  static const double markSize = 31;
  static const double visualRadius = markSize / 2;
  static const double collisionRadius = 50;
  static const double minSeparation = 160;
  static const double _pad = 72;

  static ConnectionTraceSnapshot systemSnapshot({
    required List<WorkspaceEvidenceItem> evidence,
    required List<EvidenceRelationship> relationships,
    List<EvidenceCollection> collections = const [],
  }) {
    final items = [...evidence];
    final ids = {for (final item in items) item.id};
    final adj = <String, Set<String>>{
      for (final item in items) item.id: <String>{},
    };
    final links = <ConnectionTraceLink>[];

    void relate(
      String a,
      String b, {
      ConnectionTraceOrigin origin = ConnectionTraceOrigin.systemGenerated,
    }) {
      if (a == b || !ids.contains(a) || !ids.contains(b)) {
        return;
      }
      adj[a]!.add(b);
      adj[b]!.add(a);
      links.add(ConnectionTraceLink(fromId: a, toId: b, origin: origin));
    }

    for (final item in items) {
      final parent = item.parentEvidenceId?.trim() ?? '';
      if (parent.isNotEmpty) {
        relate(parent, item.id);
      }
    }
    for (final relationship in relationships) {
      relate(
        relationship.sourceEvidenceId,
        relationship.targetEvidenceId,
        origin: EvidenceSemantics.isExplicitUserRelationship(relationship)
            ? ConnectionTraceOrigin.user
            : ConnectionTraceOrigin.systemGenerated,
      );
    }

    final positions = _spatialPositions(ids: ids, adj: adj);

    var nodes = <ConnectionTraceNode>[
      for (final item in items)
        ConnectionTraceNode(
          id: item.id,
          kind: _kindFor(item),
          label: item.kind.label,
          timestamp: item.lastPreservedAt,
          position: positions[item.id] ?? const Offset(160, 160),
          evidenceId: item.id,
          evidenceKind: item.kind,
        ),
    ];

    final people = <String, _PersonAcc>{};
    for (final item in items) {
      for (final person in item.relatedPeople) {
        final name = person.displayName.trim();
        if (name.isEmpty) {
          continue;
        }
        final key = person.participantId.trim().isNotEmpty
            ? person.participantId
            : 'person:${name.toLowerCase()}';
        people
            .putIfAbsent(key, () => _PersonAcc(id: key, name: name))
            .evidenceIds
            .add(item.id);
      }
      final legacy = (item.relatedPersonName ?? '').trim();
      if (legacy.isNotEmpty && item.relatedPeople.isEmpty) {
        final key = item.participantId ?? 'person:${legacy.toLowerCase()}';
        people
            .putIfAbsent(key, () => _PersonAcc(id: key, name: legacy))
            .evidenceIds
            .add(item.id);
      }
    }

    final evidenceCluster = [for (final node in nodes) node.position];
    final personAccs = people.values.toList();
    for (var i = 0; i < personAccs.length; i++) {
      final person = personAccs[i];
      final related = [
        for (final node in nodes)
          if (person.evidenceIds.contains(node.id)) node.position,
      ];
      final relatedTimes = [
        for (final item in items)
          if (person.evidenceIds.contains(item.id)) item.lastPreservedAt,
      ]..sort();
      nodes.add(
        ConnectionTraceNode(
          id: person.id,
          kind: ConnectionTraceKind.person,
          label: person.name,
          timestamp: relatedTimes.isEmpty
              ? DateTime.fromMillisecondsSinceEpoch(0)
              : relatedTimes.first,
          position: _regionalHubPosition(
            related: related,
            cluster: evidenceCluster,
            kind: ConnectionTraceKind.person,
            index: i,
            count: personAccs.length,
          ),
        ),
      );
      for (final evidenceId in person.evidenceIds) {
        links.add(ConnectionTraceLink(fromId: evidenceId, toId: person.id));
      }
    }

    final locationHubs = <({EvidenceCollection collection, List<Offset> related})>[
      for (final collection in collections)
        if (collection.category == 'location' &&
            collection.name.trim().isNotEmpty)
          (
            collection: collection,
            related: [
              for (final node in nodes)
                if (node.evidenceId != null &&
                    collection.memberEvidenceIds.contains(node.id))
                  node.position,
            ],
          ),
    ].where((hub) => hub.related.isNotEmpty).toList();
    for (var i = 0; i < locationHubs.length; i++) {
      final hub = locationHubs[i];
      nodes.add(
        ConnectionTraceNode(
          id: hub.collection.id,
          kind: ConnectionTraceKind.location,
          label: hub.collection.name.trim(),
          timestamp: items.isEmpty
              ? DateTime.fromMillisecondsSinceEpoch(0)
              : items.first.lastPreservedAt,
          position: _regionalHubPosition(
            related: hub.related,
            cluster: evidenceCluster,
            kind: ConnectionTraceKind.location,
            index: i,
            count: locationHubs.length,
          ),
        ),
      );
      for (final id in hub.collection.memberEvidenceIds) {
        if (nodes.any((node) => node.id == id)) {
          links.add(ConnectionTraceLink(fromId: id, toId: hub.collection.id));
        }
      }
    }

    final uniqueLinks = _uniqueLinks(links);
    nodes = _refine(nodes, uniqueLinks);
    nodes = _normalize(nodes);

    var maxX = 360.0;
    var maxY = 280.0;
    for (final node in nodes) {
      maxX = math.max(maxX, node.position.dx);
      maxY = math.max(maxY, node.position.dy);
    }

    return ConnectionTraceSnapshot(
      nodes: nodes,
      links: uniqueLinks,
      size: Size(maxX + _pad, maxY + _pad),
    );
  }

  static Offset pointOnCircumference(Offset from, Offset to) {
    final delta = to - from;
    final length = delta.distance;
    if (length < 1) {
      return from;
    }
    return from + delta / length * visualRadius;
  }

  static bool nodesOverlap(Offset a, Offset b) {
    return (a - b).distance < minSeparation - 0.5;
  }

  static bool edgeHitsNode({
    required Offset from,
    required Offset to,
    required Offset other,
  }) {
    return _distanceToSegment(other, from, to) < collisionRadius;
  }

  static bool edgesCross(Offset a1, Offset a2, Offset b1, Offset b2) {
    if (_sharesEndpoint(a1, a2, b1, b2)) {
      return false;
    }
    return _segmentsCross(a1, a2, b1, b2);
  }

  static Map<String, Offset> _spatialPositions({
    required Set<String> ids,
    required Map<String, Set<String>> adj,
  }) {
    final positions = <String, Offset>{};
    final components = _components(ids, adj);
    final isolated = [
      for (final component in components)
        if (component.length == 1) component.single,
    ];
    final connected = [
      for (final component in components)
        if (component.length > 1) component,
    ];
    var origin = const Offset(168, 176);
    for (final component in connected) {
      positions.addAll(_placeComponent(component, adj, origin));
      origin = Offset(origin.dx + 220 + component.length * 16, origin.dy);
      if (origin.dx > 540) {
        origin = Offset(168, origin.dy + 230);
      }
    }
    if (connected.isEmpty) {
      origin = const Offset(168, 176);
    }
    for (var i = 0; i < isolated.length; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      positions[isolated[i]] = Offset(
        origin.dx + col * minSeparation,
        origin.dy + row * (minSeparation + 16),
      );
    }
    return positions;
  }

  static Map<String, Offset> _placeComponent(
    List<String> component,
    Map<String, Set<String>> adj,
    Offset origin,
  ) {
    final placed = <String, Offset>{};
    if (component.length == 1) {
      placed[component.single] = origin;
      return placed;
    }
    if (component.length == 2) {
      placed[component[0]] = Offset(origin.dx - minSeparation / 2, origin.dy);
      placed[component[1]] = Offset(origin.dx + minSeparation / 2, origin.dy);
      return placed;
    }

    final ordered = _circleOrder(component, adj);
    final n = ordered.length;
    final radius = math.max(
      minSeparation / (2 * math.sin(math.pi / n)) * 1.12,
      88.0,
    );
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      placed[ordered[i]] = Offset(
        origin.dx + radius * math.cos(angle),
        origin.dy + radius * math.sin(angle),
      );
    }
    return placed;
  }

  /// Place higher-degree nodes first, then neighbors, to keep related items adjacent.
  static List<String> _circleOrder(
    List<String> component,
    Map<String, Set<String>> adj,
  ) {
    if (component.length <= 3) {
      return component;
    }
    final remaining = {...component};
    final start = component.reduce((a, b) {
      final da = adj[a]?.length ?? 0;
      final db = adj[b]?.length ?? 0;
      if (da != db) {
        return da > db ? a : b;
      }
      return a.compareTo(b) < 0 ? a : b;
    });
    final ordered = <String>[start];
    remaining.remove(start);
    while (remaining.isNotEmpty) {
      String? next;
      var best = -1;
      for (final candidate in remaining) {
        var score = 0;
        for (final neighbor in adj[candidate] ?? const <String>{}) {
          if (ordered.contains(neighbor)) {
            score += 1;
          }
        }
        if (score > best ||
            (score == best &&
                (next == null || candidate.compareTo(next) < 0))) {
          best = score;
          next = candidate;
        }
      }
      ordered.add(next!);
      remaining.remove(next);
    }
    return ordered;
  }

  static List<ConnectionTraceNode> _refine(
    List<ConnectionTraceNode> input,
    List<ConnectionTraceLink> links,
  ) {
    var nodes = [...input];
    for (var iter = 0; iter < 28; iter++) {
      var moved = false;
      final byId = {for (final node in nodes) node.id: node};

      for (var i = 0; i < nodes.length; i++) {
        for (var j = i + 1; j < nodes.length; j++) {
          final a = nodes[i];
          final b = nodes[j];
          final delta = b.position - a.position;
          final distance = delta.distance;
          if (distance >= minSeparation) {
            continue;
          }
          final push = (minSeparation - math.max(distance, 1)) / 2 + 1;
          final dir = distance < 1 ? const Offset(1, 0) : delta / distance;
          nodes[i] = a.copyWith(position: a.position - dir * push);
          nodes[j] = b.copyWith(position: b.position + dir * push);
          moved = true;
        }
      }

      for (final link in links) {
        final from = byId[link.fromId];
        final to = byId[link.toId];
        if (from == null || to == null) {
          continue;
        }
        for (var i = 0; i < nodes.length; i++) {
          final other = nodes[i];
          if (other.id == from.id || other.id == to.id) {
            continue;
          }
          final clearance = _distanceToSegment(
            other.position,
            from.position,
            to.position,
          );
          if (clearance >= collisionRadius) {
            continue;
          }
          final axis = to.position - from.position;
          final length = axis.distance;
          if (length < 1) {
            continue;
          }
          var normal = Offset(-axis.dy, axis.dx) / length;
          final mid = Offset(
            (from.position.dx + to.position.dx) / 2,
            (from.position.dy + to.position.dy) / 2,
          );
          final side = other.position - mid;
          if (side.dx * normal.dx + side.dy * normal.dy < 0) {
            normal = -normal;
          }
          nodes[i] = other.copyWith(
            position:
                other.position + normal * (collisionRadius - clearance + 6),
          );
          moved = true;
        }
      }

      if (iter % 4 == 3) {
        final swapped = _uncrossBySwap(nodes, links);
        if (swapped != null) {
          nodes = swapped;
          moved = true;
        }
      }

      if (!moved) {
        break;
      }
    }
    return nodes;
  }

  static List<ConnectionTraceNode>? _uncrossBySwap(
    List<ConnectionTraceNode> nodes,
    List<ConnectionTraceLink> links,
  ) {
    final byId = {for (final node in nodes) node.id: node};
    Offset? pos(String id) => byId[id]?.position;
    var crossings = _countCrossings(links, pos);
    if (crossings == 0) {
      return null;
    }
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        if (nodes[i].kind != nodes[j].kind) {
          continue;
        }
        final trial = [...nodes];
        trial[i] = nodes[i].copyWith(position: nodes[j].position);
        trial[j] = nodes[j].copyWith(position: nodes[i].position);
        final trialById = {for (final node in trial) node.id: node};
        final next = _countCrossings(links, (id) => trialById[id]?.position);
        if (next < crossings) {
          return trial;
        }
      }
    }
    return null;
  }

  static int _countCrossings(
    List<ConnectionTraceLink> links,
    Offset? Function(String id) pos,
  ) {
    var count = 0;
    for (var i = 0; i < links.length; i++) {
      for (var j = i + 1; j < links.length; j++) {
        final a1 = pos(links[i].fromId);
        final a2 = pos(links[i].toId);
        final b1 = pos(links[j].fromId);
        final b2 = pos(links[j].toId);
        if (a1 == null || a2 == null || b1 == null || b2 == null) {
          continue;
        }
        if (edgesCross(a1, a2, b1, b2)) {
          count += 1;
        }
      }
    }
    return count;
  }

  static List<ConnectionTraceNode> _normalize(List<ConnectionTraceNode> nodes) {
    if (nodes.isEmpty) {
      return nodes;
    }
    var minX = nodes.first.position.dx;
    var minY = nodes.first.position.dy;
    for (final node in nodes) {
      minX = math.min(minX, node.position.dx);
      minY = math.min(minY, node.position.dy);
    }
    final dx = _pad - minX;
    final dy = _pad - minY;
    if (dx.abs() < 1 && dy.abs() < 1) {
      return nodes;
    }
    return [
      for (final node in nodes)
        node.copyWith(position: node.position + Offset(dx, dy)),
    ];
  }

  static List<List<String>> _components(
    Set<String> ids,
    Map<String, Set<String>> adj,
  ) {
    final seen = <String>{};
    final components = <List<String>>[];
    final ordered = [...ids]..sort();
    for (final id in ordered) {
      if (!seen.add(id)) {
        continue;
      }
      final stack = [id];
      final component = <String>[];
      while (stack.isNotEmpty) {
        final current = stack.removeLast();
        component.add(current);
        for (final next in adj[current] ?? const <String>{}) {
          if (seen.add(next)) {
            stack.add(next);
          }
        }
      }
      component.sort();
      components.add(component);
    }
    return components;
  }

  /// Person hubs sit to the right of related evidence; location hubs to the left.
  /// Layout-only — does not change membership, endpoints, or chronology.
  static Offset _regionalHubPosition({
    required List<Offset> related,
    required List<Offset> cluster,
    required ConnectionTraceKind kind,
    required int index,
    required int count,
  }) {
    final anchor = _centroid(related);
    final bounds = cluster.isEmpty ? related : cluster;
    var minX = anchor.dx;
    var maxX = anchor.dx;
    for (final point in bounds) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
    }
    final spread = count <= 1
        ? 0.0
        : (index - (count - 1) / 2) * (minSeparation * 0.7);
    final x = kind == ConnectionTraceKind.location
        ? minX - minSeparation
        : maxX + minSeparation;
    return Offset(x, anchor.dy + spread);
  }

  static Offset _centroid(List<Offset> points) {
    if (points.isEmpty) {
      return const Offset(180, 180);
    }
    var x = 0.0;
    var y = 0.0;
    for (final point in points) {
      x += point.dx;
      y += point.dy;
    }
    return Offset(x / points.length, y / points.length);
  }

  static double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 < 1) {
      return (point - a).distance;
    }
    var t = ((point.dx - a.dx) * ab.dx + (point.dy - a.dy) * ab.dy) / length2;
    t = t.clamp(0.0, 1.0);
    final projected = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (point - projected).distance;
  }

  static bool _sharesEndpoint(Offset a1, Offset a2, Offset b1, Offset b2) {
    bool same(Offset x, Offset y) => (x - y).distance < 0.5;
    return same(a1, b1) || same(a1, b2) || same(a2, b1) || same(a2, b2);
  }

  static bool _segmentsCross(Offset a, Offset b, Offset c, Offset d) {
    final d1 = _direction(c, d, a);
    final d2 = _direction(c, d, b);
    final d3 = _direction(a, b, c);
    final d4 = _direction(a, b, d);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  static double _direction(Offset a, Offset b, Offset c) {
    return (c.dx - a.dx) * (b.dy - a.dy) - (c.dy - a.dy) * (b.dx - a.dx);
  }

  static ConnectionTraceKind _kindFor(WorkspaceEvidenceItem item) {
    if (item.kind.isPrimaryChronology && !item.isContextual) {
      return ConnectionTraceKind.moment;
    }
    return ConnectionTraceKind.context;
  }

  static List<ConnectionTraceLink> _uniqueLinks(
    List<ConnectionTraceLink> links,
  ) {
    final seen = <String, int>{};
    final unique = <ConnectionTraceLink>[];
    for (final link in links) {
      final a = link.fromId.compareTo(link.toId) <= 0 ? link.fromId : link.toId;
      final b = link.fromId.compareTo(link.toId) <= 0 ? link.toId : link.fromId;
      final key = '$a::$b';
      final existing = seen[key];
      if (existing == null) {
        seen[key] = unique.length;
        unique.add(link);
        continue;
      }
      if (link.origin == ConnectionTraceOrigin.user &&
          unique[existing].origin != ConnectionTraceOrigin.user) {
        unique[existing] = ConnectionTraceLink(
          fromId: unique[existing].fromId,
          toId: unique[existing].toId,
          origin: ConnectionTraceOrigin.user,
        );
      }
    }
    return unique;
  }

  /// Overlay-only traces join the system map as My Connections (orange).
  static ConnectionTraceSnapshot mergeUserOverlay({
    required ConnectionTraceSnapshot system,
    ConnectionTraceSnapshot? mine,
  }) {
    if (mine == null || mine.links.isEmpty) {
      return system;
    }
    final nodeIds = {for (final node in system.nodes) node.id};
    final extras = <ConnectionTraceLink>[];
    for (final link in mine.links) {
      if (!nodeIds.contains(link.fromId) || !nodeIds.contains(link.toId)) {
        continue;
      }
      extras.add(
        ConnectionTraceLink(
          fromId: link.fromId,
          toId: link.toId,
          origin: ConnectionTraceOrigin.user,
        ),
      );
    }
    if (extras.isEmpty) {
      return system;
    }
    return system.copyWith(links: _uniqueLinks([...system.links, ...extras]));
  }
}

class _PersonAcc {
  _PersonAcc({required this.id, required this.name});

  final String id;
  final String name;
  final Set<String> evidenceIds = {};
}
