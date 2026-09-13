import 'dart:math' as math;
import 'dart:ui';

import 'package:intl/intl.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../domain/organize/organize_spine_classification.dart';
import '../../engines/evidence_semantics.dart';
import '../../models/workspace_evidence_item.dart';
import '../../utils/instant_codec.dart';
import '../relationship/relationship_engine.dart';

enum SpatialGraphNodeKind { moment, context, person, location, description }

enum SpatialGraphRouteKind {
  location,
  branch,
  hinge,
  related,
  chronology,
  person,
}

class SpatialGraphNode {
  const SpatialGraphNode({
    required this.id,
    required this.kind,
    required this.label,
    required this.position,
    this.timestamp,
    this.evidenceId,
    this.evidenceKind,
    this.subtitle,
    this.dateLabel,
    this.thumbnailPath,
    this.organizeContext = false,
    this.locationKey,
    this.locationUncertain = false,
  });

  final String id;
  final SpatialGraphNodeKind kind;
  final String label;
  final Offset position;
  final DateTime? timestamp;
  final String? evidenceId;
  final WorkspaceEvidenceKind? evidenceKind;
  final String? subtitle;
  final String? dateLabel;
  final String? thumbnailPath;
  final bool organizeContext;
  final String? locationKey;
  final bool locationUncertain;

  SpatialGraphNode copyWith({Offset? position}) {
    return SpatialGraphNode(
      id: id,
      kind: kind,
      label: label,
      position: position ?? this.position,
      timestamp: timestamp,
      evidenceId: evidenceId,
      evidenceKind: evidenceKind,
      subtitle: subtitle,
      dateLabel: dateLabel,
      thumbnailPath: thumbnailPath,
      organizeContext: organizeContext,
      locationKey: locationKey,
      locationUncertain: locationUncertain,
    );
  }
}

class SpatialGraphEdge {
  const SpatialGraphEdge({
    required this.fromId,
    required this.toId,
    this.route = SpatialGraphRouteKind.branch,
    this.points = const [],
  });

  final String fromId;
  final String toId;
  final SpatialGraphRouteKind route;
  final List<Offset> points;

  SpatialGraphEdge copyWith({List<Offset>? points}) {
    return SpatialGraphEdge(
      fromId: fromId,
      toId: toId,
      route: route,
      points: points ?? this.points,
    );
  }
}

/// Time gap between consecutive preserved moments. Not a missing-evidence marker.
class SpatialGraphGap {
  const SpatialGraphGap({
    required this.fromMomentId,
    required this.toMomentId,
    required this.label,
    required this.yStart,
    required this.yEnd,
    required this.x,
  });

  final String fromMomentId;
  final String toMomentId;
  final String label;
  final double yStart;
  final double yEnd;
  final double x;
}

class SpatialGraphTimeMark {
  const SpatialGraphTimeMark({
    required this.at,
    required this.x,
    required this.label,
  });

  final DateTime at;
  final double x;
  final String label;
}

class SpatialGraphLocationBand {
  const SpatialGraphLocationBand({
    required this.key,
    required this.label,
    required this.y,
  });

  final String key;
  final String label;
  final double y;
}

class SpatialGraphTick {
  const SpatialGraphTick({required this.from, required this.to});

  final Offset from;
  final Offset to;
}

class SpatialGraphLayout {
  const SpatialGraphLayout({
    required this.nodes,
    required this.edges,
    required this.size,
    required this.axisX,
    this.gaps = const [],
    this.origin = Offset.zero,
    this.axisXEnd = Offset.zero,
    this.axisYEnd = Offset.zero,
    this.timeMarks = const [],
    this.bands = const [],
    this.xTicks = const [],
    this.yTicks = const [],
  });

  final List<SpatialGraphNode> nodes;
  final List<SpatialGraphEdge> edges;
  final Size size;
  final double axisX;
  final List<SpatialGraphGap> gaps;
  final Offset origin;
  final Offset axisXEnd;
  final Offset axisYEnd;
  final List<SpatialGraphTimeMark> timeMarks;
  final List<SpatialGraphLocationBand> bands;
  final List<SpatialGraphTick> xTicks;
  final List<SpatialGraphTick> yTicks;

  static const double fingerGap = 48;

  /// Vertical chronology spine. Left of axis holds location + context tangents.
  static const double axisXDefault = 108;

  static const double timestampGap = fingerGap * 2;

  /// Location pin center, hinged immediately left of the evidence node.
  static const double locationInset = 44;

  /// People sit to the right of the evidence field.
  static const double peopleOffsetX = 86;
  static const double peopleLaneX = peopleOffsetX;
  static const double _personTrunkGap = 16;
  static const double _personLaneGap = 48;
  static const double _personPitch = 72;

  static const double momentRadius = 17;
  static const double personMarkSize = 28;
  static const double locationMarkSize = 18;
  static const double _personRowH = 44;
  static const double _contextPitch = 64;
  static const double _topPad = 28;
  static const double _bottomPad = 36;
  static const double _leftPad = 20;
  static const double _rightPad = 56;
  static const double _rowPitch = 78;
  static const double _significantGapExtra = 36;
  static const double _gapAxisClearance = 10;
  static const double _gapLabelWidth = 48;
  static const String unknownKey = 'unknown';

  static double fingerGapFor({double textScale = 1}) {
    return fingerGap * textScale.clamp(1.0, 1.35);
  }

  static double contextPitchFor({double textScale = 1}) {
    return _contextPitch * textScale.clamp(1.0, 1.35);
  }

  double get timestampX => axisX + timestampGap;

  SpatialGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  static Rect nodeBox(SpatialGraphNode node) => _box(node);

  static String personNodeId(String identityKey) => 'person::$identityKey';

  static double markRadius(SpatialGraphNode node) {
    return switch (node.kind) {
      SpatialGraphNodeKind.moment => momentRadius,
      SpatialGraphNodeKind.location => locationMarkSize / 2,
      _ => personMarkSize / 2,
    };
  }

  static Offset markCenter(SpatialGraphNode node) {
    final box = _box(node);
    return Offset(node.position.dx, box.top + markRadius(node));
  }

  static String locationNodeId(String momentId) => '$momentId::location';

  static SpatialGraphLayout fromGraph(
    InvestigationGraphView graph, {
    Set<String> organizeCreatedIds = const {},
    List<OrganizeContextAnchor> contextAnchors = const [],
    double textScale = 1,
  }) {
    final moments = _momentsOf(graph, organizeCreatedIds);
    if (moments.isEmpty) {
      return const SpatialGraphLayout(
        nodes: [],
        edges: [],
        size: Size(320, 240),
        axisX: axisXDefault,
        origin: Offset(axisXDefault, 200),
        axisXEnd: Offset(axisXDefault, 200),
        axisYEnd: Offset(axisXDefault, 28),
      );
    }

    final finger = fingerGapFor(textScale: textScale);
    final contextPitch = contextPitchFor(textScale: textScale);

    final pending = <_Pending>[];
    for (final moment in moments) {
      pending.addAll(_satellitesFor(graph, moment, organizeCreatedIds));
      pending.addAll(
        _organizeContextPending(
          graph: graph,
          moment: moment,
          contextAnchors: contextAnchors,
          alreadyUsed: {for (final node in pending) node.id},
        ),
      );
    }

    final locationOf = <String, _Loc>{};
    for (final moment in moments) {
      locationOf[moment.id] = _locationFor(moment, graph.collections);
    }

    final instants = [for (final moment in moments) _instant(moment)];
    final gapDurations = <Duration>[
      for (var i = 0; i < instants.length - 1; i++)
        instants[i + 1].difference(instants[i]),
    ];
    final significant = significantConsecutiveGapIndex(gapDurations);

    const axisX = axisXDefault;
    final momentNodes = <SpatialGraphNode>[];
    var y = _topPad + 30;
    for (var i = 0; i < moments.length; i++) {
      if (i > 0) {
        y += _rowPitch;
        if (significant != null && i - 1 == significant) {
          y += _significantGapExtra;
        }
      }
      final moment = moments[i];
      final loc = locationOf[moment.id]!;
      final at = instants[i];
      momentNodes.add(
        SpatialGraphNode(
          id: moment.id,
          kind: SpatialGraphNodeKind.moment,
          label: _shortLabel(moment.title, moment.kind.label),
          position: Offset(axisX, y),
          timestamp: at,
          evidenceId: moment.id,
          evidenceKind: moment.kind,
          subtitle: _clockLabel(at),
          dateLabel: _dateLabel(at),
          locationKey: loc.key,
        ),
      );
    }

    final byMoment = {for (final node in momentNodes) node.id: node};
    final nodes = [...momentNodes];
    final edges = <SpatialGraphEdge>[];

    for (final moment in moments) {
      final loc = locationOf[moment.id]!;
      if (loc.key == unknownKey) {
        continue;
      }
      final host = byMoment[moment.id]!;
      final hasContexts = pending.any(
        (node) =>
            node.momentId == moment.id &&
            (node.kind == SpatialGraphNodeKind.context ||
                node.kind == SpatialGraphNodeKind.description),
      );
      final pinY = _positionYForMarkCenter(
        SpatialGraphNodeKind.location,
        markCenter(host).dy - (hasContexts ? 52 : 0),
      );
      nodes.add(
        SpatialGraphNode(
          id: locationNodeId(moment.id),
          kind: SpatialGraphNodeKind.location,
          label: loc.label,
          position: Offset(axisX - locationInset, pinY),
          evidenceId: moment.id,
          locationKey: loc.key,
          locationUncertain: loc.uncertain,
        ),
      );
    }

    for (final moment in moments) {
      final host = byMoment[moment.id]!;
      final contexts = [
        for (final node in pending)
          if (node.momentId == moment.id &&
              (node.kind == SpatialGraphNodeKind.context ||
                  node.kind == SpatialGraphNodeKind.description))
            node,
      ];
      _placeLeftTangent(
        contexts,
        host,
        fingerGap: finger,
        pitch: contextPitch,
      );
      for (final node in contexts) {
        nodes.add(node.toNode());
      }
      if (contexts.isNotEmpty) {
        edges.add(
          SpatialGraphEdge(
            fromId: moment.id,
            toId: contexts.last.id,
            route: SpatialGraphRouteKind.hinge,
          ),
        );
      }
    }

    final peopleIndex = _personIndexOf(moments);
    _addPersonNodes(
      nodes: nodes,
      groups: peopleIndex.groups,
      orderByMoment: peopleIndex.orderByMoment,
      byMoment: byMoment,
    );

    _resolveOverlaps(nodes);

    SpatialGraphNode? byId(String id) {
      for (final node in nodes) {
        if (node.id == id) {
          return node;
        }
      }
      return null;
    }

    final liveMoments = {
      for (final node in nodes)
        if (node.kind == SpatialGraphNodeKind.moment) node.id: node,
    };

    final routed = [
      for (final edge in edges)
        edge.copyWith(
          points: _polylineFor(
            edge: edge,
            from: byId(edge.fromId),
            to: byId(edge.toId),
            nodes: nodes,
          ),
        ),
      ..._exclusivePersonRoutes(
        nodes: nodes,
        groups: peopleIndex.groups,
        orderByMoment: peopleIndex.orderByMoment,
        byMoment: liveMoments,
        axisX: axisX,
      ),
      ..._personRoutes(
        nodes: nodes,
        groups: [
          for (final group in peopleIndex.groups)
            if (group.momentIds.length > 1) group,
        ],
        byMoment: {for (final node in nodes) node.id: node},
        axisX: axisX,
      ),
      ..._locationStubs(nodes, liveMoments, axisX),
    ];

    final gaps = <SpatialGraphGap>[];
    if (significant != null) {
      final from = momentNodes[significant];
      final to = momentNodes[significant + 1];
      final label = formatTimeGap(from.timestamp!, to.timestamp!);
      if (label != null) {
        gaps.add(
          SpatialGraphGap(
            fromMomentId: from.id,
            toMomentId: to.id,
            label: label,
            yStart: markCenter(from).dy,
            yEnd: markCenter(to).dy,
            x: axisX - _gapAxisClearance - _gapLabelWidth,
          ),
        );
      }
    }

    return _finalize(
      nodes: nodes,
      edges: routed,
      gaps: gaps,
      axisX: axisX,
      momentNodes: [
        for (final node in nodes)
          if (node.kind == SpatialGraphNodeKind.moment) node,
      ],
    );
  }

  static SpatialGraphLayout _finalize({
    required List<SpatialGraphNode> nodes,
    required List<SpatialGraphEdge> edges,
    required List<SpatialGraphGap> gaps,
    required double axisX,
    required List<SpatialGraphNode> momentNodes,
  }) {
    var minX = axisX;
    var maxX = axisX + 160;
    var minY = _topPad.toDouble();
    var maxY = momentNodes.isEmpty ? 240.0 : momentNodes.last.position.dy;
    for (final node in nodes) {
      final box = _box(node);
      minX = math.min(minX, box.left);
      maxX = math.max(maxX, box.right);
      minY = math.min(minY, box.top);
      maxY = math.max(maxY, box.bottom);
    }
    for (final edge in edges) {
      for (final point in edge.points) {
        minX = math.min(minX, point.dx);
        maxX = math.max(maxX, point.dx);
        minY = math.min(minY, point.dy);
        maxY = math.max(maxY, point.dy);
      }
    }
    for (final gap in gaps) {
      minX = math.min(minX, gap.x);
    }

    final dx = minX < _leftPad ? _leftPad - minX : 0.0;
    final dy = minY < 12 ? 12 - minY : 0.0;
    final shift = Offset(dx, dy);
    final shiftedNodes = [
      for (final node in nodes) node.copyWith(position: node.position + shift),
    ];
    final shiftedEdges = [
      for (final edge in edges)
        edge.copyWith(points: [for (final point in edge.points) point + shift]),
    ];
    final shiftedGaps = [
      for (final gap in gaps)
        SpatialGraphGap(
          fromMomentId: gap.fromMomentId,
          toMomentId: gap.toMomentId,
          label: gap.label,
          yStart: gap.yStart + dy,
          yEnd: gap.yEnd + dy,
          x: gap.x + dx,
        ),
    ];
    final shiftedAxis = axisX + dx;
    SpatialGraphNode? firstMoment;
    SpatialGraphNode? lastMoment;
    for (final node in shiftedNodes) {
      if (node.kind != SpatialGraphNodeKind.moment) {
        continue;
      }
      firstMoment ??= node;
      lastMoment = node;
    }
    final firstMarkY = firstMoment == null
        ? 28.0
        : markCenter(firstMoment).dy;
    final lastMarkY = lastMoment == null ? 200.0 : markCenter(lastMoment).dy;
    final origin = Offset(shiftedAxis, lastMarkY + 28);
    final axisYEnd = Offset(shiftedAxis, math.max(12.0, firstMarkY - 24));
    var width = maxX + dx + _rightPad;
    var height = math.max(maxY + dy, origin.dy) + _bottomPad;
    return SpatialGraphLayout(
      nodes: shiftedNodes,
      edges: shiftedEdges,
      gaps: shiftedGaps,
      axisX: shiftedAxis,
      origin: origin,
      axisXEnd: origin,
      axisYEnd: axisYEnd,
      size: Size(width, height),
    );
  }

  static int? significantConsecutiveGapIndex(List<Duration> gaps) {
    if (gaps.length < 2) {
      return null;
    }
    final minutes = [for (final gap in gaps) gap.inMinutes];
    var maxMinutes = 0;
    for (final value in minutes) {
      if (value > maxMinutes) {
        maxMinutes = value;
      }
    }
    if (maxMinutes < 1) {
      return null;
    }

    final others = [
      for (final value in minutes)
        if (value != maxMinutes) value,
    ];
    if (others.isEmpty) {
      return null;
    }

    var otherMax = 0;
    for (final value in others) {
      if (value > otherMax) {
        otherMax = value;
      }
    }
    if (otherMax <= 0 || maxMinutes < otherMax * 2) {
      return null;
    }

    final sorted = [...others]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();
    if (median > 0 && maxMinutes < median * 3) {
      return null;
    }

    for (var i = 0; i < minutes.length; i++) {
      if (minutes[i] == maxMinutes) {
        return i;
      }
    }
    return null;
  }

  static String? formatTimeGap(DateTime earlier, DateTime later) {
    final delta = later.difference(earlier);
    if (delta.isNegative || delta.inMinutes < 1) {
      return null;
    }
    final days = delta.inDays;
    final hours = delta.inHours.remainder(24);
    final minutes = delta.inMinutes.remainder(60);
    if (days > 0) {
      if (hours > 0) {
        return '+ ${days}d ${hours}h';
      }
      return days == 1 ? '+ 1 day' : '+ $days days';
    }
    if (delta.inHours >= 1) {
      if (minutes > 0) {
        return '+ ${delta.inHours}h ${minutes}m';
      }
      return '+ ${delta.inHours}h';
    }
    return '+ ${delta.inMinutes}m';
  }

  static DateTime _instant(WorkspaceEvidenceItem item) {
    return item.capturedAt ?? item.recordedAt ?? item.lastPreservedAt;
  }

  static String _clockLabel(DateTime at) {
    return DateFormat('HH:mm').format(InstantCodec.toLocal(at));
  }

  static String _dateLabel(DateTime at) {
    return DateFormat('d MMM yyyy').format(InstantCodec.toLocal(at));
  }

  static List<WorkspaceEvidenceItem> _momentsOf(
    InvestigationGraphView graph,
    Set<String> organizeCreatedIds,
  ) {
    final moments = <WorkspaceEvidenceItem>[];
    final seen = <String>{};
    void consider(WorkspaceEvidenceItem item) {
      if (!seen.add(item.id)) {
        return;
      }
      if (OrganizeSpineClassification.isToolbarCreated(
        item.id,
        organizeCreatedIds: organizeCreatedIds,
      )) {
        return;
      }
      final parent = item.parentEvidenceId?.trim() ?? '';
      if (parent.isNotEmpty) {
        return;
      }
      moments.add(item);
    }

    for (final item in graph.evidenceById.values) {
      consider(item);
    }
    if (moments.isEmpty) {
      for (final item in graph.primaryEvidence) {
        consider(item);
      }
    }
    moments.sort((a, b) {
      final byTime = _instant(a).compareTo(_instant(b));
      if (byTime != 0) {
        return byTime;
      }
      return a.id.compareTo(b.id);
    });
    return moments;
  }

  static _Loc _locationFor(
    WorkspaceEvidenceItem item,
    List<EvidenceCollection> collections,
  ) {
    final established = EvidenceSemantics.hasLocation(item);
    for (final collection in collections) {
      if (collection.category != 'location') {
        continue;
      }
      final name = collection.name.trim();
      if (name.isEmpty) {
        continue;
      }
      if (!collection.memberEvidenceIds.contains(item.id)) {
        continue;
      }
      return _Loc(
        key: 'loc:${collection.id}',
        label: _shortLabel(name, ''),
        uncertain:
            !established && (collection.systemGenerated || collection.pending),
      );
    }
    if (established) {
      final lat = item.latitude!;
      final lng = item.longitude!;
      return _Loc(
        key: 'geo:${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}',
        label: '${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°',
      );
    }
    return const _Loc(key: unknownKey, label: '');
  }

  static List<_Pending> _satellitesFor(
    InvestigationGraphView graph,
    WorkspaceEvidenceItem moment,
    Set<String> organizeCreatedIds,
  ) {
    final pending = <_Pending>[];
    final usedIds = <String>{moment.id};

    if (EvidenceSemantics.hasWrittenDescription(moment) &&
        moment.kind != WorkspaceEvidenceKind.note) {
      pending.add(
        _Pending(
          id: '${moment.id}::description',
          momentId: moment.id,
          kind: SpatialGraphNodeKind.description,
          label: _shortLabel(moment.notePreview!.trim(), 'Description'),
        ),
      );
    }

    for (final item in graph.supportingFor(moment.id)) {
      if (item.id == moment.id) {
        continue;
      }
      if (OrganizeSpineClassification.isToolbarCreated(
        item.id,
        organizeCreatedIds: organizeCreatedIds,
      )) {
        continue;
      }
      if (!usedIds.add(item.id)) {
        continue;
      }
      pending.add(
        _Pending(
          id: item.id,
          momentId: moment.id,
          kind: SpatialGraphNodeKind.context,
          label: _shortLabel(item.title, item.kind.label),
          evidenceId: item.id,
          evidenceKind: item.kind,
          timestamp: _instant(item),
          subtitle: _clockLabel(_instant(item)),
        ),
      );
    }

    return pending;
  }

  static _PersonIndex _personIndexOf(List<WorkspaceEvidenceItem> moments) {
    final groups = <String, _PersonGroup>{};
    final orderByMoment = <String, List<String>>{};
    void add({
      required String momentId,
      required String key,
      required String name,
    }) {
      if (key.isEmpty || name.trim().isEmpty) {
        return;
      }
      final group = groups.putIfAbsent(
        key,
        () => _PersonGroup(key: key, label: _shortLabel(name, 'Person')),
      );
      if (!group.momentIds.contains(momentId)) {
        group.momentIds.add(momentId);
      }
      final order = orderByMoment.putIfAbsent(momentId, () => <String>[]);
      if (!order.contains(key)) {
        order.add(key);
      }
    }

    for (final moment in moments) {
      for (final person in moment.relatedPeople) {
        final name = person.displayName.trim();
        if (name.isEmpty) {
          continue;
        }
        final id = person.participantId.trim();
        add(
          momentId: moment.id,
          key: id.isNotEmpty ? id : 'name:${name.toLowerCase()}',
          name: name,
        );
      }
      final legacy = (moment.relatedPersonName ?? '').trim();
      if (legacy.isNotEmpty && moment.relatedPeople.isEmpty) {
        add(
          momentId: moment.id,
          key: (moment.participantId ?? '').trim().isNotEmpty
              ? moment.participantId!.trim()
              : 'name:${legacy.toLowerCase()}',
          name: legacy,
        );
      }
    }
    return _PersonIndex(
      groups: groups.values.toList(),
      orderByMoment: orderByMoment,
    );
  }

  static void _addPersonNodes({
    required List<SpatialGraphNode> nodes,
    required List<_PersonGroup> groups,
    required Map<String, List<String>> orderByMoment,
    required Map<String, SpatialGraphNode> byMoment,
  }) {
    if (groups.isEmpty) {
      return;
    }
    final byKey = {for (final group in groups) group.key: group};

    for (final moment in byMoment.values) {
      final exclusive = [
        for (final key in orderByMoment[moment.id] ?? const <String>[])
          if (byKey[key] != null && byKey[key]!.momentIds.length == 1)
            byKey[key]!,
      ];
      if (exclusive.isEmpty) {
        continue;
      }
      var startX = markCenter(moment).dx + markRadius(moment) + 28;
      for (final node in nodes) {
        if (node.kind == SpatialGraphNodeKind.location ||
            node.kind == SpatialGraphNodeKind.moment) {
          continue;
        }
        if ((markCenter(node).dy - markCenter(moment).dy).abs() < 36) {
          startX = math.max(startX, _box(node).right + 18);
        }
      }
      final markY = markCenter(moment).dy;
      var x = startX + 22;
      for (final group in exclusive) {
        nodes.add(
          SpatialGraphNode(
            id: personNodeId(group.key),
            kind: SpatialGraphNodeKind.person,
            label: group.label,
            position: Offset(
              x,
              _positionYForMarkCenter(SpatialGraphNodeKind.person, markY),
            ),
          ),
        );
        x += _personPitch;
      }
    }

    final shared = [
      for (final group in groups)
        if (group.momentIds.length > 1) group,
    ];
    if (shared.isEmpty) {
      return;
    }
    var fieldRight = axisXDefault;
    for (final node in nodes) {
      if (node.kind == SpatialGraphNodeKind.location) {
        continue;
      }
      fieldRight = math.max(fieldRight, _box(node).right);
    }
    final personX = fieldRight + _personLaneGap;
    shared.sort((a, b) {
      double yOf(_PersonGroup group) {
        final ys = [
          for (final id in group.momentIds)
            if (byMoment[id] != null) markCenter(byMoment[id]!).dy,
        ];
        if (ys.isEmpty) {
          return 0.0;
        }
        return ys.reduce((left, right) => left + right) / ys.length;
      }

      return yOf(a).compareTo(yOf(b));
    });

    final placed = <SpatialGraphNode>[];
    for (final group in shared) {
      final hosts = [
        for (final id in group.momentIds)
          if (byMoment[id] != null) byMoment[id]!,
      ];
      if (hosts.isEmpty) {
        continue;
      }
      final markY =
          hosts.map((host) => markCenter(host).dy).reduce((a, b) => a + b) /
          hosts.length;
      var y = _positionYForMarkCenter(SpatialGraphNodeKind.person, markY);
      var x = personX;
      var guard = 0;
      var node = SpatialGraphNode(
        id: personNodeId(group.key),
        kind: SpatialGraphNodeKind.person,
        label: group.label,
        position: Offset(x, y),
      );
      while (guard < 24) {
        guard += 1;
        var blocked = false;
        for (final other in [...nodes, ...placed]) {
          if (_box(other).overlaps(_box(node).inflate(8))) {
            blocked = true;
            break;
          }
        }
        if (!blocked) {
          break;
        }
        y += _personRowH / 2;
        if (guard == 8 || guard == 16) {
          x += 72;
          y = _positionYForMarkCenter(SpatialGraphNodeKind.person, markY);
        }
        node = node.copyWith(position: Offset(x, y));
      }
      placed.add(node);
      nodes.add(node);
    }
  }

  static double _positionYForMarkCenter(
    SpatialGraphNodeKind kind,
    double markY,
  ) {
    final height = switch (kind) {
      SpatialGraphNodeKind.moment => 64.0,
      SpatialGraphNodeKind.location => 44.0,
      SpatialGraphNodeKind.person => 44.0,
      SpatialGraphNodeKind.description => 52.0,
      SpatialGraphNodeKind.context => 58.0,
    };
    final radius = switch (kind) {
      SpatialGraphNodeKind.moment => momentRadius,
      SpatialGraphNodeKind.location => locationMarkSize / 2,
      _ => personMarkSize / 2,
    };
    return markY - radius + height / 2;
  }

  static List<SpatialGraphEdge> _exclusivePersonRoutes({
    required List<SpatialGraphNode> nodes,
    required List<_PersonGroup> groups,
    required Map<String, List<String>> orderByMoment,
    required Map<String, SpatialGraphNode> byMoment,
    required double axisX,
  }) {
    final byKey = {for (final group in groups) group.key: group};
    SpatialGraphNode? personOf(String key) {
      final id = personNodeId(key);
      for (final node in nodes) {
        if (node.id == id) {
          return node;
        }
      }
      return null;
    }

    final edges = <SpatialGraphEdge>[];
    for (final moment in byMoment.values) {
      final exclusive = [
        for (final key in orderByMoment[moment.id] ?? const <String>[])
          if (byKey[key] != null &&
              byKey[key]!.momentIds.length == 1 &&
              personOf(key) != null)
            personOf(key)!,
      ];
      if (exclusive.isEmpty) {
        continue;
      }
      final last = exclusive.last;
      final start = Offset(
        markCenter(moment).dx + markRadius(moment),
        markCenter(moment).dy,
      );
      final end = Offset(markCenter(last).dx - markRadius(last), start.dy);
      edges.add(
        SpatialGraphEdge(
          fromId: moment.id,
          toId: last.id,
          route: SpatialGraphRouteKind.person,
          points: _keepRightOfAxis([start, end], axisX),
        ),
      );
    }
    return edges;
  }

  static List<SpatialGraphEdge> _personRoutes({
    required List<SpatialGraphNode> nodes,
    required List<_PersonGroup> groups,
    required Map<String, SpatialGraphNode> byMoment,
    required double axisX,
  }) {
    final edges = <SpatialGraphEdge>[];
    SpatialGraphNode? personOf(String key) {
      final id = personNodeId(key);
      for (final node in nodes) {
        if (node.id == id) {
          return node;
        }
      }
      return null;
    }

    for (final group in groups) {
      final person = personOf(group.key);
      if (person == null) {
        continue;
      }
      final hosts = [
        for (final id in group.momentIds)
          if (byMoment[id] != null) byMoment[id]!,
      ];
      if (hosts.isEmpty) {
        continue;
      }
      edges.addAll(_dRoutesForPerson(person: person, hosts: hosts, axisX: axisX));
    }
    return edges;
  }

  static List<SpatialGraphEdge> _dRoutesForPerson({
    required SpatialGraphNode person,
    required List<SpatialGraphNode> hosts,
    required double axisX,
  }) {
    final personCenter = markCenter(person);
    final personEnd = Offset(
      personCenter.dx - markRadius(person),
      personCenter.dy,
    );
    var trunkX = personEnd.dx - _personTrunkGap;
    for (final host in hosts) {
      final right = markCenter(host).dx + markRadius(host) + 12;
      if (right > trunkX) {
        trunkX = right;
      }
    }
    if (trunkX > personEnd.dx - 8) {
      trunkX = personEnd.dx - 8;
    }
    trunkX = math.max(trunkX, axisX);

    final sorted = [...hosts]
      ..sort((a, b) => markCenter(a).dy.compareTo(markCenter(b).dy));
    final edges = <SpatialGraphEdge>[];
    final ys = [for (final host in sorted) markCenter(host).dy];

    if (sorted.length == 1 && (ys.first - personCenter.dy).abs() < 1.5) {
      final start = Offset(
        markCenter(sorted.first).dx + markRadius(sorted.first),
        ys.first,
      );
      edges.add(
        SpatialGraphEdge(
          fromId: sorted.first.id,
          toId: person.id,
          route: SpatialGraphRouteKind.person,
          points: _keepRightOfAxis([start, personEnd], axisX),
        ),
      );
      return edges;
    }

    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    for (final host in sorted) {
      final y = markCenter(host).dy;
      final start = Offset(markCenter(host).dx + markRadius(host), y);
      edges.add(
        SpatialGraphEdge(
          fromId: host.id,
          toId: person.id,
          route: SpatialGraphRouteKind.person,
          points: _keepRightOfAxis([start, Offset(trunkX, y)], axisX),
        ),
      );
    }
    edges.add(
      SpatialGraphEdge(
        fromId: sorted.first.id,
        toId: person.id,
        route: SpatialGraphRouteKind.person,
        points: _keepRightOfAxis([Offset(trunkX, minY), Offset(trunkX, maxY)], axisX),
      ),
    );
    edges.add(
      SpatialGraphEdge(
        fromId: sorted.first.id,
        toId: person.id,
        route: SpatialGraphRouteKind.person,
        points: _keepRightOfAxis(
          [Offset(trunkX, personCenter.dy), personEnd],
          axisX,
        ),
      ),
    );
    return edges;
  }

  static List<SpatialGraphEdge> _locationStubs(
    List<SpatialGraphNode> nodes,
    Map<String, SpatialGraphNode> byMoment,
    double axisX,
  ) {
    final stubs = <SpatialGraphEdge>[];
    for (final node in nodes) {
      if (node.kind != SpatialGraphNodeKind.location) {
        continue;
      }
      final momentId = node.id.endsWith('::location')
          ? node.id.substring(0, node.id.length - '::location'.length)
          : '';
      final host = byMoment[momentId];
      final fromCenter = markCenter(node);
      final fromR = markRadius(node);
      if (host == null) {
        continue;
      }
      final hostMark = markCenter(host);
      final hostR = markRadius(host);
      final from = Offset(fromCenter.dx + fromR, fromCenter.dy);
      final to = Offset(hostMark.dx - hostR, hostMark.dy);
      final points = (from.dy - to.dy).abs() < 1.5
          ? [from, to]
          : [from, Offset(from.dx, to.dy), to];
      if ((to - from).distance < 2) {
        continue;
      }
      stubs.add(
        SpatialGraphEdge(
          fromId: node.id,
          toId: host.id,
          route: SpatialGraphRouteKind.location,
          points: [
            for (final point in points)
              Offset(math.min(point.dx, axisX - 1), point.dy),
          ],
        ),
      );
    }
    return stubs;
  }

  static List<Offset> _keepRightOfAxis(List<Offset> points, double axisX) {
    return [
      for (final point in points) Offset(math.max(point.dx, axisX), point.dy),
    ];
  }

  static List<_Pending> _organizeContextPending({
    required InvestigationGraphView graph,
    required WorkspaceEvidenceItem moment,
    required List<OrganizeContextAnchor> contextAnchors,
    required Set<String> alreadyUsed,
  }) {
    final pending = <_Pending>[];
    final used = {...alreadyUsed};
    for (final anchor in contextAnchors) {
      if (anchor.capturedEvidenceId != moment.id) {
        continue;
      }
      final item = graph.evidenceById[anchor.contextEvidenceId];
      if (item == null) {
        continue;
      }
      if (!used.add(item.id)) {
        continue;
      }
      pending.add(
        _Pending(
          id: item.id,
          momentId: moment.id,
          kind: SpatialGraphNodeKind.context,
          label: _shortLabel(item.title, item.kind.label),
          evidenceId: item.id,
          evidenceKind: item.kind,
          timestamp: _instant(item),
          subtitle: _clockLabel(_instant(item)),
          organizeContext: true,
        ),
      );
    }
    return pending;
  }

  static void _placeLeftTangent(
    List<_Pending> contexts,
    SpatialGraphNode host, {
    required double fingerGap,
    required double pitch,
  }) {
    if (contexts.isEmpty) {
      return;
    }
    contexts.sort((a, b) {
      final at = a.timestamp;
      final bt = b.timestamp;
      if (at != null && bt != null) {
        final compared = at.compareTo(bt);
        if (compared != 0) {
          return compared;
        }
      } else if (at != null) {
        return -1;
      } else if (bt != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });
    final hostMark = markCenter(host);
    final contextR = personMarkSize / 2;
    var x = hostMark.dx - markRadius(host) - fingerGap - contextR;
    for (var i = 0; i < contexts.length; i++) {
      final kind = contexts[i].kind;
      contexts[i].position = Offset(
        x,
        _positionYForMarkCenter(kind, hostMark.dy),
      );
      x -= pitch;
    }
  }

  static void _resolveOverlaps(List<SpatialGraphNode> nodes) {
    var guard = 0;
    while (guard < 64) {
      guard += 1;
      var moved = false;
      for (var i = 0; i < nodes.length; i++) {
        for (var j = i + 1; j < nodes.length; j++) {
          final a = nodes[i];
          final b = nodes[j];
          if (a.kind == SpatialGraphNodeKind.moment &&
              b.kind == SpatialGraphNodeKind.moment) {
            continue;
          }
          if (!_box(a).overlaps(_box(b))) {
            continue;
          }

          SpatialGraphNode satellite;
          var satelliteIndex = j;
          if (a.kind == SpatialGraphNodeKind.moment) {
            satellite = b;
            satelliteIndex = j;
          } else if (b.kind == SpatialGraphNodeKind.moment) {
            satellite = a;
            satelliteIndex = i;
          } else if (_isContextLike(a) && !_isContextLike(b)) {
            satellite = b;
            satelliteIndex = j;
          } else if (_isContextLike(b) && !_isContextLike(a)) {
            satellite = a;
            satelliteIndex = i;
          } else if (a.kind == SpatialGraphNodeKind.location) {
            satellite = a;
            satelliteIndex = i;
          } else {
            satellite = b;
            satelliteIndex = j;
          }

          if (satellite.kind == SpatialGraphNodeKind.moment) {
            continue;
          }

          if (_isContextLike(satellite)) {
            nodes[satelliteIndex] = satellite.copyWith(
              position: Offset(satellite.position.dx - 12, satellite.position.dy),
            );
          } else if (satellite.kind == SpatialGraphNodeKind.location) {
            nodes[satelliteIndex] = satellite.copyWith(
              position: Offset(
                satellite.position.dx,
                satellite.position.dy - 14,
              ),
            );
          } else {
            nodes[satelliteIndex] = satellite.copyWith(
              position: Offset(satellite.position.dx + 16, satellite.position.dy),
            );
          }
          moved = true;
        }
      }
      if (!moved) {
        break;
      }
    }
  }

  static bool _isContextLike(SpatialGraphNode node) {
    return node.kind == SpatialGraphNodeKind.context ||
        node.kind == SpatialGraphNodeKind.description;
  }

  static Rect _box(SpatialGraphNode node) {
    final size = switch (node.kind) {
      SpatialGraphNodeKind.moment => const Size(48, 64),
      SpatialGraphNodeKind.location => const Size(40, 44),
      SpatialGraphNodeKind.person => Size(
        (node.label.length * 7.0).clamp(64.0, 128.0),
        44,
      ),
      SpatialGraphNodeKind.description => const Size(56, 52),
      SpatialGraphNodeKind.context => const Size(56, 58),
    };
    return Rect.fromCenter(
      center: node.position,
      width: size.width,
      height: size.height,
    );
  }

  static List<Offset> _polylineFor({
    required SpatialGraphEdge edge,
    required SpatialGraphNode? from,
    required SpatialGraphNode? to,
    required List<SpatialGraphNode> nodes,
  }) {
    if (from == null || to == null) {
      return const [];
    }
    final obstacles = [
      for (final node in nodes)
        if (node.id != from.id && node.id != to.id) _box(node).inflate(6),
    ];
    switch (edge.route) {
      case SpatialGraphRouteKind.chronology:
        return const [];
      case SpatialGraphRouteKind.hinge:
        final fromC = markCenter(from);
        final fromR = markRadius(from);
        final toC = markCenter(to);
        final toR = markRadius(to);
        final y = fromC.dy;
        final start = Offset(fromC.dx - fromR, y);
        final end = Offset(toC.dx + toR, y);
        return [start, end];
      case SpatialGraphRouteKind.person:
      case SpatialGraphRouteKind.location:
        return const [];
      case SpatialGraphRouteKind.related:
      case SpatialGraphRouteKind.branch:
        final fromC = markCenter(from);
        final fromR = markRadius(from);
        final toC = markCenter(to);
        final toR = markRadius(to);
        final start = Offset(fromC.dx + fromR, fromC.dy);
        final end = Offset(toC.dx - toR, toC.dy);
        if ((start.dy - end.dy).abs() < 1) {
          return _avoiding([start, end], obstacles);
        }
        return _avoiding([start, Offset(start.dx, end.dy), end], obstacles);
    }
  }

  static List<Offset> _avoiding(List<Offset> points, List<Rect> obstacles) {
    if (!_polylineHits(points, obstacles)) {
      return points;
    }
    if (points.length >= 2) {
      final shifted = [
        for (var i = 0; i < points.length; i++)
          i == 0 || i == points.length - 1
              ? points[i]
              : Offset(points[i].dx, points[i].dy + 12),
      ];
      if (!_polylineHits(shifted, obstacles)) {
        return shifted;
      }
    }
    return points;
  }

  static bool _polylineHits(List<Offset> points, List<Rect> obstacles) {
    for (var i = 0; i < points.length - 1; i++) {
      if (_openSegmentHits(points[i], points[i + 1], obstacles)) {
        return true;
      }
    }
    return false;
  }

  static bool _openSegmentHits(Offset a, Offset b, List<Rect> boxes) {
    for (final rect in boxes) {
      if (_segmentIntersectsRect(a, b, rect)) {
        return true;
      }
    }
    return false;
  }

  static bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
    if (rect.contains(a) || rect.contains(b)) {
      return true;
    }
    return _segmentsCross(a, b, rect.topLeft, rect.topRight) ||
        _segmentsCross(a, b, rect.topRight, rect.bottomRight) ||
        _segmentsCross(a, b, rect.bottomRight, rect.bottomLeft) ||
        _segmentsCross(a, b, rect.bottomLeft, rect.topLeft);
  }

  static bool _segmentsCross(Offset a, Offset b, Offset c, Offset d) {
    final d1 = _direction(c, d, a);
    final d2 = _direction(c, d, b);
    final d3 = _direction(a, b, c);
    final d4 = _direction(a, b, d);
    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  static double _direction(Offset a, Offset b, Offset c) {
    return (c.dx - a.dx) * (b.dy - a.dy) - (c.dy - a.dy) * (b.dx - a.dx);
  }

  static String _shortLabel(String title, String fallback) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    if (trimmed.length <= 18) {
      return trimmed;
    }
    return '${trimmed.substring(0, 16)}…';
  }
}

class _Loc {
  const _Loc({required this.key, required this.label, this.uncertain = false});

  final String key;
  final String label;
  final bool uncertain;
}

class _PersonGroup {
  _PersonGroup({required this.key, required this.label});

  final String key;
  final String label;
  final List<String> momentIds = [];
}

class _Pending {
  _Pending({
    required this.id,
    required this.momentId,
    required this.kind,
    required this.label,
    this.evidenceId,
    this.evidenceKind,
    this.timestamp,
    this.subtitle,
    this.organizeContext = false,
  });

  final String id;
  final String momentId;
  final SpatialGraphNodeKind kind;
  final String label;
  final String? evidenceId;
  final WorkspaceEvidenceKind? evidenceKind;
  final DateTime? timestamp;
  final String? subtitle;
  final bool organizeContext;
  Offset position = Offset.zero;

  SpatialGraphNode toNode() {
    return SpatialGraphNode(
      id: id,
      kind: kind,
      label: label,
      position: position,
      timestamp: timestamp,
      evidenceId: evidenceId,
      evidenceKind: evidenceKind,
      subtitle: subtitle,
      organizeContext: organizeContext,
    );
  }
}

class _PersonIndex {
  const _PersonIndex({required this.groups, required this.orderByMoment});

  final List<_PersonGroup> groups;
  final Map<String, List<String>> orderByMoment;
}
