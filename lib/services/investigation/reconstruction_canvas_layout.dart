import 'dart:math' as math;
import 'dart:ui';

import 'package:intl/intl.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../domain/organize/organize_spine_classification.dart';
import '../../engines/evidence_semantics.dart';
import '../../models/workspace_evidence_item.dart';
import '../../utils/instant_codec.dart';
import 'connection_trace_engine.dart';

enum ReconstructionPlotKind { evidence, context }

class ReconstructionLocationBand {
  const ReconstructionLocationBand({
    required this.key,
    required this.label,
    required this.y,
    this.latitude,
    this.longitude,
  });

  final String key;
  final String label;
  final double y;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}

class ReconstructionTimeMark {
  const ReconstructionTimeMark({
    required this.at,
    required this.x,
    required this.dateLabel,
    required this.timeLabel,
  });

  final DateTime at;
  final double x;
  final String dateLabel;
  final String timeLabel;
}

class ReconstructionPlotNode {
  const ReconstructionPlotNode({
    required this.id,
    required this.kind,
    required this.position,
    required this.item,
    required this.locationKey,
    this.cluster = '',
  });

  final String id;
  final ReconstructionPlotKind kind;
  final Offset position;
  final WorkspaceEvidenceItem item;
  final String locationKey;
  final String cluster;

  ReconstructionPlotNode copyWith({Offset? position}) {
    return ReconstructionPlotNode(
      id: id,
      kind: kind,
      position: position ?? this.position,
      item: item,
      locationKey: locationKey,
      cluster: cluster,
    );
  }
}

class ReconstructionPlot {
  const ReconstructionPlot({
    required this.nodes,
    required this.bands,
    required this.timeMarks,
    required this.storyPath,
    required this.size,
    required this.origin,
    required this.axisXEnd,
    required this.axisYEnd,
  });

  final List<ReconstructionPlotNode> nodes;
  final List<ReconstructionLocationBand> bands;
  final List<ReconstructionTimeMark> timeMarks;
  final List<Offset> storyPath;
  final Size size;
  final Offset origin;
  final Offset axisXEnd;
  final Offset axisYEnd;

  ReconstructionPlotNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }
}

/// Space × time layout for Reconstruct. Presentation only.
/// X/Y are ordered UX dimensions — not elapsed-time or geographic scales.
abstract final class ReconstructionCanvasLayout {
  static const double markSize = ConnectionTraceEngine.markSize;
  static const double leftGutter = 56;
  static const double bottomGutter = 56;
  static const double topPad = 24;
  static const double rightPad = 40;
  static const double rowPitch = 48;
  static const double minNodeGap = 38;
  static const String unknownKey = 'unknown';
  static const String locationUnavailableLabel = 'Location unavailable';
  static const Size defaultViewport = Size(390, 844);

  static double fingerGapFor(Size viewport) {
    final width = viewport.width.isFinite && viewport.width > 0
        ? viewport.width
        : defaultViewport.width;
    final height = viewport.height.isFinite && viewport.height > 0
        ? viewport.height
        : defaultViewport.height;
    final shortest = math.min(width, height);
    return (shortest * 0.12).clamp(40.0, 56.0);
  }

  static ReconstructionPlot fromEvidence({
    required List<WorkspaceEvidenceItem> evidence,
    List<EvidenceCollection> collections = const [],
    Set<String> organizeCreatedIds = const {},
    List<OrganizeContextAnchor> contextAnchors = const [],
    Size viewport = defaultViewport,
  }) {
    final finger = fingerGapFor(viewport);
    final left = finger;
    final bottom = finger;
    final top = math.max(16.0, finger * 0.45);
    final row = finger * 3;
    final column = finger;
    final clusterGap = markSize + 8;
    final fieldGap = finger;
    final axisClearance = 8.0;
    final fieldInset = markSize / 2 + axisClearance;

    final byId = {for (final item in evidence) item.id: item};
    final moments = _momentsOf(evidence, organizeCreatedIds);
    if (moments.isEmpty) {
      final height = math.max(
        240.0,
        viewport.height.isFinite ? viewport.height : 240.0,
      );
      return ReconstructionPlot(
        nodes: const [],
        bands: const [],
        timeMarks: const [],
        storyPath: const [],
        size: Size(
          math.max(360.0, viewport.width.isFinite ? viewport.width : 360.0),
          height,
        ),
        origin: Offset(left, height - bottom),
        axisXEnd: Offset(math.max(320.0, left + 200), height - bottom),
        axisYEnd: Offset(left, top),
      );
    }

    final locationOf = <String, _Loc>{};
    for (final moment in moments) {
      locationOf[moment.id] = _locationFor(
        moment,
        collections: collections,
      );
    }

    final contextItems = <WorkspaceEvidenceItem, WorkspaceEvidenceItem>{};
    for (final anchor in contextAnchors) {
      final context = byId[anchor.contextEvidenceId];
      final captured = byId[anchor.capturedEvidenceId];
      if (context == null || captured == null) {
        continue;
      }
      if (moments.any((item) => item.id == captured.id)) {
        contextItems[context] = captured;
      }
    }
    for (final item in evidence) {
      if (contextItems.containsKey(item)) {
        continue;
      }
      if (OrganizeSpineClassification.isToolbarCreated(
        item.id,
        organizeCreatedIds: organizeCreatedIds,
      )) {
        continue;
      }
      final parent = item.parentEvidenceId?.trim() ?? '';
      if (parent.isEmpty) {
        continue;
      }
      WorkspaceEvidenceItem? host;
      for (final moment in moments) {
        if (moment.id == parent) {
          host = moment;
          break;
        }
      }
      if (host != null) {
        contextItems[item] = host;
      }
    }

    final bandKeys = <String>[];
    void considerBand(String key) {
      if (!bandKeys.contains(key)) {
        bandKeys.add(key);
      }
    }

    final firstAt = <String, DateTime>{};
    for (final moment in moments) {
      final loc = locationOf[moment.id]!;
      considerBand(loc.key);
      final at = _instant(moment);
      final existing = firstAt[loc.key];
      if (existing == null || at.isBefore(existing)) {
        firstAt[loc.key] = at;
      }
    }
    bandKeys.sort((a, b) {
      if (a == unknownKey && b != unknownKey) {
        return 1;
      }
      if (b == unknownKey && a != unknownKey) {
        return -1;
      }
      return (firstAt[a] ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        firstAt[b] ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    final times = moments.map(_instant).toList()..sort();
    final uniqueTimes = <DateTime>[];
    for (final at in times) {
      if (uniqueTimes.isEmpty ||
          uniqueTimes.last.millisecondsSinceEpoch !=
              at.millisecondsSinceEpoch) {
        uniqueTimes.add(at);
      }
    }

    final plotWidth = math.max(
      math.max(column, viewport.width.isFinite ? viewport.width - left : 0),
      column + uniqueTimes.length * column,
    );
    final plotHeight = math.max(row, bandKeys.length * row);
    final canvasHeight = math.max(
      viewport.height.isFinite && viewport.height > 0
          ? viewport.height
          : top + plotHeight + bottom,
      top + plotHeight + bottom,
    );
    final origin = Offset(left, canvasHeight - bottom);
    final axisXEnd = Offset(left + plotWidth, origin.dy);
    final axisYEnd = Offset(left, top);

    double xFor(DateTime at) {
      final index = uniqueTimes.indexWhere(
        (time) => time.millisecondsSinceEpoch == at.millisecondsSinceEpoch,
      );
      final i = index < 0 ? 0 : index;
      return left + fieldInset + i * column;
    }

    double yFor(String key) {
      final index = bandKeys.indexOf(key);
      final fromBottom = index < 0 ? 0 : index;
      return origin.dy - (fromBottom + 0.5) * row;
    }

    final clusters = <String, List<_Pending>>{};
    void addPending(_Pending pending) {
      clusters.putIfAbsent(pending.cluster, () => []).add(pending);
    }

    for (final moment in moments) {
      final loc = locationOf[moment.id]!;
      final at = _instant(moment);
      addPending(
        _Pending(
          id: moment.id,
          kind: ReconstructionPlotKind.evidence,
          item: moment,
          locationKey: loc.key,
          cluster: '${loc.key}::${at.millisecondsSinceEpoch}',
          x: xFor(at),
          y: yFor(loc.key),
        ),
      );
    }
    for (final entry in contextItems.entries) {
      final host = entry.value;
      final loc = locationOf[host.id]!;
      final at = _instant(host);
      addPending(
        _Pending(
          id: entry.key.id,
          kind: ReconstructionPlotKind.context,
          item: entry.key,
          locationKey: loc.key,
          cluster: '${loc.key}::${at.millisecondsSinceEpoch}',
          x: xFor(at),
          y: yFor(loc.key),
        ),
      );
    }

    final nodes = <ReconstructionPlotNode>[];
    for (final group in clusters.values) {
      nodes.addAll(_spread(group, clusterGap));
    }
    final separated = _clearOfAxes(
      _resolveOverlaps(nodes, fieldGap, clusterGap),
      origin: origin,
      axisYEnd: axisYEnd,
      clearance: axisClearance,
    );

    final bands = [
      for (final key in bandKeys)
        ReconstructionLocationBand(
          key: key,
          label: _bandLabel(key, locationOf),
          y: yFor(key),
          latitude: _bandSource(key, locationOf, moments)?.latitude,
          longitude: _bandSource(key, locationOf, moments)?.longitude,
        ),
    ];

    final timeMarks = [
      for (final at in uniqueTimes)
        ReconstructionTimeMark(
          at: at,
          x: xFor(at),
          dateLabel: _dateLabel(at),
          timeLabel: _timeLabel(at),
        ),
    ];

    final story = <Offset>[];
    for (final moment in moments) {
      for (final node in separated) {
        if (node.id == moment.id) {
          story.add(node.position);
          break;
        }
      }
    }

    return ReconstructionPlot(
      nodes: separated,
      bands: bands,
      timeMarks: timeMarks,
      storyPath: story,
      size: Size(
        math.max(
          left + plotWidth + rightPad,
          viewport.width.isFinite ? viewport.width : left + plotWidth,
        ),
        canvasHeight,
      ),
      origin: origin,
      axisXEnd: axisXEnd,
      axisYEnd: axisYEnd,
    );
  }

  static DateTime instantOf(WorkspaceEvidenceItem item) => _instant(item);

  static String formatDate(DateTime at) => _dateLabel(at);

  static String formatTime(DateTime at) => _timeLabel(at);

  static String coordinateLabel(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(4)}°, ${longitude.toStringAsFixed(4)}°';
  }

  static List<WorkspaceEvidenceItem> _momentsOf(
    List<WorkspaceEvidenceItem> evidence,
    Set<String> organizeCreatedIds,
  ) {
    final moments = <WorkspaceEvidenceItem>[];
    final seen = <String>{};
    for (final item in evidence) {
      if (!seen.add(item.id)) {
        continue;
      }
      if (OrganizeSpineClassification.isToolbarCreated(
        item.id,
        organizeCreatedIds: organizeCreatedIds,
      )) {
        continue;
      }
      final parent = item.parentEvidenceId?.trim() ?? '';
      if (parent.isNotEmpty) {
        continue;
      }
      moments.add(item);
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
    WorkspaceEvidenceItem item, {
    required List<EvidenceCollection> collections,
  }) {
    if (EvidenceSemantics.hasLocation(item)) {
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
        return _Loc(key: 'loc:${collection.id}', label: name);
      }
      final lat = item.latitude!;
      final lng = item.longitude!;
      return _Loc(
        key: 'geo:${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}',
        label: coordinateLabel(lat, lng),
      );
    }
    return const _Loc(
      key: unknownKey,
      label: locationUnavailableLabel,
    );
  }

  static WorkspaceEvidenceItem? _bandSource(
    String key,
    Map<String, _Loc> locationOf,
    List<WorkspaceEvidenceItem> moments,
  ) {
    for (final moment in moments) {
      final loc = locationOf[moment.id];
      if (loc == null || loc.key != key) {
        continue;
      }
      if (EvidenceSemantics.hasLocation(moment)) {
        return moment;
      }
    }
    return null;
  }

  static String _bandLabel(String key, Map<String, _Loc> locationOf) {
    for (final loc in locationOf.values) {
      if (loc.key == key) {
        return loc.label;
      }
    }
    if (key == unknownKey) {
      return locationUnavailableLabel;
    }
    return key;
  }

  static List<ReconstructionPlotNode> _spread(
    List<_Pending> group,
    double clusterGap,
  ) {
    final cx =
        group.map((node) => node.x).reduce((a, b) => a + b) / group.length;
    final cy =
        group.map((node) => node.y).reduce((a, b) => a + b) / group.length;
    if (group.length == 1) {
      final node = group.single;
      return [
        ReconstructionPlotNode(
          id: node.id,
          kind: node.kind,
          position: Offset(cx, cy),
          item: node.item,
          locationKey: node.locationKey,
          cluster: node.cluster,
        ),
      ];
    }
    final n = group.length;
    final radius = math.max(
      clusterGap * 0.55,
      (n - 1) * clusterGap / (2 * math.pi),
    );
    return [
      for (var i = 0; i < n; i++)
        ReconstructionPlotNode(
          id: group[i].id,
          kind: group[i].kind,
          position: Offset(
            cx + radius * math.cos(-math.pi / 2 + 2 * math.pi * i / n),
            cy + radius * math.sin(-math.pi / 2 + 2 * math.pi * i / n),
          ),
          item: group[i].item,
          locationKey: group[i].locationKey,
          cluster: group[i].cluster,
        ),
    ];
  }

  static List<ReconstructionPlotNode> _resolveOverlaps(
    List<ReconstructionPlotNode> nodes,
    double fieldGap,
    double clusterGap,
  ) {
    final result = [...nodes];
    var guard = 0;
    while (guard < 64) {
      guard += 1;
      var moved = false;
      for (var i = 0; i < result.length; i++) {
        for (var j = i + 1; j < result.length; j++) {
          final a = result[i];
          final b = result[j];
          final minGap = a.cluster == b.cluster && a.cluster.isNotEmpty
              ? clusterGap
              : fieldGap;
          final delta = b.position - a.position;
          if (delta.distance >= minGap) {
            continue;
          }
          final later = a.position.dx <= b.position.dx ? j : i;
          final node = result[later];
          final push = minGap - delta.distance + 2;
          result[later] = node.copyWith(
            position: Offset(node.position.dx + push, node.position.dy),
          );
          moved = true;
        }
      }
      if (!moved) {
        break;
      }
    }
    return result;
  }

  static List<ReconstructionPlotNode> _clearOfAxes(
    List<ReconstructionPlotNode> nodes, {
    required Offset origin,
    required Offset axisYEnd,
    required double clearance,
  }) {
    final radius = markSize / 2;
    final minX = origin.dx + radius + clearance;
    final maxY = origin.dy - radius - clearance;
    final minY = axisYEnd.dy + radius + clearance;
    return [
      for (final node in nodes)
        node.copyWith(
          position: Offset(
            math.max(node.position.dx, minX),
            node.position.dy.clamp(minY, maxY),
          ),
        ),
    ];
  }

  static DateTime _instant(WorkspaceEvidenceItem item) {
    return item.capturedAt ?? item.recordedAt ?? item.lastPreservedAt;
  }

  static String _dateLabel(DateTime at) {
    return DateFormat('MMM d').format(InstantCodec.toLocal(at));
  }

  static String _timeLabel(DateTime at) {
    return DateFormat('HH:mm:ss').format(InstantCodec.toLocal(at));
  }
}

class _Loc {
  const _Loc({required this.key, required this.label});

  final String key;
  final String label;
}

class _Pending {
  const _Pending({
    required this.id,
    required this.kind,
    required this.item,
    required this.locationKey,
    required this.cluster,
    required this.x,
    required this.y,
  });

  final String id;
  final ReconstructionPlotKind kind;
  final WorkspaceEvidenceItem item;
  final String locationKey;
  final String cluster;
  final double x;
  final double y;
}
