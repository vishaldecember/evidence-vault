import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/investigation/spatial_graph_layout.dart';
import '../../services/relationship/relationship_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'investigation_evidence_mark.dart';

/// Graph-owned evidence label colors. Independent of Organize typography.
abstract final class GraphEvidenceTypography {
  static const Color timestamp = Color(0xFFFFFFFF);
  static const Color date = Color(0xFFFFFFFF);
  static const Color participant = Color(0xFFFFFFFF);
}

/// Spatial relationship graph — chronological spine with horizontal meaning.
class InvestigationGraphWorkspace extends StatefulWidget {
  const InvestigationGraphWorkspace({
    super.key,
    required this.graph,
    required this.onEvidenceTap,
    this.organizeCreatedIds = const {},
    this.contextAnchors = const [],
  });

  final InvestigationGraphView graph;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceTap;
  final Set<String> organizeCreatedIds;
  final List<OrganizeContextAnchor> contextAnchors;

  static const Key workspaceKey = Key('investigation_graph_workspace');
  static const Key edgesKey = Key('investigation_graph_edges');
  static const Key spineKey = Key('investigation_graph_spine');
  static const Key timeAxisKey = Key('investigation_graph_time_axis');
  static Key nodeKey(String id) => Key('investigation_graph_node_$id');
  static Key nodeMarkKey(String id) => Key('investigation_graph_node_mark_$id');
  static Key timestampKey(String momentId) =>
      Key('investigation_graph_timestamp_$momentId');
  static Key timeMarkKey(DateTime at) =>
      Key('investigation_graph_time_${at.millisecondsSinceEpoch}');
  static Key gapKey(String fromId, String label) =>
      Key('investigation_graph_gap_${fromId}_$label');
  static Key locationUncertainKey(String id) =>
      Key('investigation_graph_location_uncertain_$id');

  static const Color chronologyColor = AppColors.timelineChronology;
  static const Color locationPinColor = Color(0xFFE53935);
  static const Color axisColor = Color(0x66D4E4F2);
  static const double spineStrokeWidth = 1.35;

  static const scrollStorageKey = PageStorageKey<String>(
    'investigation_graph_workspace_scroll',
  );

  static IconData iconFor(WorkspaceEvidenceKind? kind) {
    return InvestigationEvidenceMark.iconFor(kind);
  }

  @override
  State<InvestigationGraphWorkspace> createState() =>
      _InvestigationGraphWorkspaceState();
}

class _InvestigationGraphWorkspaceState
    extends State<InvestigationGraphWorkspace> {
  final TransformationController _transform = TransformationController();
  String? _centeredSignature;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _centerOnAxis(SpatialGraphLayout layout, Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) {
      return;
    }
    final signature =
        '${layout.axisX.toStringAsFixed(1)}:${layout.size.width.toStringAsFixed(1)}:'
        '${layout.nodes.length}:${viewport.width.toStringAsFixed(1)}';
    if (_centeredSignature == signature) {
      return;
    }
    _centeredSignature = signature;
    final dx = viewport.width / 2 - layout.axisX;
    final matrix = Matrix4.identity();
    matrix.setTranslationRaw(dx, 0, 0);
    _transform.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final layout = SpatialGraphLayout.fromGraph(
      widget.graph,
      organizeCreatedIds: widget.organizeCreatedIds,
      contextAnchors: widget.contextAnchors,
      textScale: textScale,
    );
    if (layout.nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Text(
          'Preserve moments to see how they relate.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.onCanvasSecondary,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 390,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 640,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _centerOnAxis(layout, viewport);
        });
        return ClipRect(
          child: InteractiveViewer(
            key: InvestigationGraphWorkspace.scrollStorageKey,
            transformationController: _transform,
            constrained: false,
            minScale: 0.85,
            maxScale: 2.2,
            boundaryMargin: EdgeInsets.symmetric(
              horizontal: math.max(48, viewport.width / 2),
              vertical: 48,
            ),
            child: SizedBox(
              key: InvestigationGraphWorkspace.workspaceKey,
              width: layout.size.width,
              height: layout.size.height,
              child: Stack(
                children: [
                  CustomPaint(
                    key: InvestigationGraphWorkspace.edgesKey,
                    size: layout.size,
                    painter: _SpatialGraphScenePainter(layout: layout),
                  ),
                  Positioned(
                    key: InvestigationGraphWorkspace.spineKey,
                    left:
                        layout.axisX -
                        InvestigationGraphWorkspace.spineStrokeWidth / 2,
                    top: layout.axisYEnd.dy,
                    width: InvestigationGraphWorkspace.spineStrokeWidth,
                    height: (layout.origin.dy - layout.axisYEnd.dy) < 8
                        ? 8
                        : layout.origin.dy - layout.axisYEnd.dy,
                    child: const SizedBox.expand(),
                  ),
                  for (final gap in layout.gaps)
                    Positioned(
                      key: InvestigationGraphWorkspace.gapKey(
                        gap.fromMomentId,
                        gap.label,
                      ),
                      left: gap.x,
                      top: (gap.yStart + gap.yEnd) / 2 - 8,
                      width: math.max(36, layout.axisX - gap.x - 8),
                      child: Text(
                        gap.label,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onCanvasSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  for (final node in layout.nodes)
                    Positioned(
                      key: InvestigationGraphWorkspace.nodeKey(node.id),
                      left: SpatialGraphLayout.nodeBox(node).left,
                      top: SpatialGraphLayout.nodeBox(node).top,
                      width: SpatialGraphLayout.nodeBox(node).width,
                      child: _GraphNodeChip(
                        node: node,
                        onTap: () {
                          final evidenceId = node.evidenceId;
                          if (evidenceId == null) {
                            return;
                          }
                          final item = widget.graph.evidenceById[evidenceId];
                          if (item != null) {
                            widget.onEvidenceTap(item);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GraphNodeChip extends StatelessWidget {
  const _GraphNodeChip({required this.node, required this.onTap});

  final SpatialGraphNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMoment = node.kind == SpatialGraphNodeKind.moment;
    final isOrganizeContext = node.organizeContext;
    final isLocation = node.kind == SpatialGraphNodeKind.location;
    final color = switch (node.kind) {
      SpatialGraphNodeKind.moment => const Color(0xFFE8F1F8),
      SpatialGraphNodeKind.context when isOrganizeContext => Colors.white,
      SpatialGraphNodeKind.context => const Color(0xFF8FCBB3),
      SpatialGraphNodeKind.description => const Color(0xFFB8D4C8),
      SpatialGraphNodeKind.person => const Color(0xFFD4C4A8),
      SpatialGraphNodeKind.location =>
        InvestigationGraphWorkspace.locationPinColor,
    };
    final markSize = isMoment
        ? 34.0
        : isLocation
        ? 18.0
        : 28.0;
    if (isLocation) {
      return Semantics(
        label: node.locationUncertain && node.label.isNotEmpty
            ? '${node.label} uncertain'
            : node.locationUncertain
            ? 'Uncertain location'
            : node.label,
        child: SizedBox(
          width: SpatialGraphLayout.nodeBox(node).width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: markSize + 8,
                height: markSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.place_rounded,
                      key: InvestigationGraphWorkspace.nodeMarkKey(node.id),
                      size: markSize,
                      color: InvestigationGraphWorkspace.locationPinColor,
                    ),
                    if (node.locationUncertain)
                      Positioned(
                        right: -1,
                        top: -2,
                        child: Text(
                          '?',
                          key: InvestigationGraphWorkspace.locationUncertainKey(
                            node.id,
                          ),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.onCanvasSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (node.label.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  node.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onCanvas,
                    fontWeight: FontWeight.w600,
                    fontSize: 8,
                    height: 1.05,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final mark =
        node.kind == SpatialGraphNodeKind.moment ||
            node.kind == SpatialGraphNodeKind.context
        ? InvestigationEvidenceMark(
            markKey: InvestigationGraphWorkspace.nodeMarkKey(node.id),
            kind: node.evidenceKind,
            color: color,
            size: markSize,
            filled: isOrganizeContext,
          )
        : Container(
            key: InvestigationGraphWorkspace.nodeMarkKey(node.id),
            width: markSize,
            height: markSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Icon(
              switch (node.kind) {
                SpatialGraphNodeKind.description => Icons.subject_rounded,
                SpatialGraphNodeKind.person => Icons.person_outline_rounded,
                SpatialGraphNodeKind.location => Icons.place_rounded,
                _ => Icons.circle_outlined,
              },
              size: 14,
              color: color,
            ),
          );

    return Semantics(
      button: node.evidenceId != null,
      label: node.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: node.evidenceId == null ? null : onTap,
        child: SizedBox(
          width: SpatialGraphLayout.nodeBox(node).width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              if (isMoment && node.subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  node.subtitle!,
                  key: InvestigationGraphWorkspace.timestampKey(node.id),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: GraphEvidenceTypography.timestamp,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                if (node.dateLabel != null)
                  Text(
                    node.dateLabel!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: GraphEvidenceTypography.date,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      height: 1.05,
                    ),
                  ),
              ] else if (node.kind == SpatialGraphNodeKind.context) ...[
                if (node.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    node.subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onCanvasSecondary,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      height: 1.05,
                    ),
                  ),
                ],
              ] else if (node.kind == SpatialGraphNodeKind.person) ...[
                const SizedBox(height: 3),
                Text(
                  node.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: GraphEvidenceTypography.participant,
                    fontWeight: FontWeight.w500,
                    fontSize: 9,
                    height: 1.1,
                  ),
                ),
              ] else if (!isMoment) ...[
                const SizedBox(height: 3),
                Text(
                  node.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: isOrganizeContext
                        ? AppColors.onCanvas
                        : AppColors.onCanvasSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 9,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SpatialGraphScenePainter extends CustomPainter {
  const _SpatialGraphScenePainter({required this.layout});

  final SpatialGraphLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final spine = Paint()
      ..color = InvestigationGraphWorkspace.chronologyColor
      ..strokeWidth = InvestigationGraphWorkspace.spineStrokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(layout.axisYEnd, layout.origin, spine);

    final hinge = Paint()
      ..color = const Color(0x66A8C0D4)
      ..strokeWidth = 1.05
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final person = Paint()
      ..color = const Color(0x88C4B49A)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final location = Paint()
      ..color = InvestigationGraphWorkspace.locationPinColor.withValues(
        alpha: 0.35,
      )
      ..strokeWidth = 1.05
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in layout.edges) {
      final points = edge.points;
      if (points.length < 2) {
        continue;
      }
      _drawSchematic(canvas, switch (edge.route) {
        SpatialGraphRouteKind.person => person,
        SpatialGraphRouteKind.location => location,
        SpatialGraphRouteKind.chronology => spine,
        _ => hinge,
      }, points);
    }
  }

  static void _drawSchematic(Canvas canvas, Paint paint, List<Offset> pts) {
    const radius = 7.0;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final prev = pts[i - 1];
      final corner = pts[i];
      final next = pts[i + 1];
      final incoming = corner - prev;
      final outgoing = next - corner;
      final len1 = incoming.distance;
      final len2 = outgoing.distance;
      if (len1 < 1 || len2 < 1) {
        path.lineTo(corner.dx, corner.dy);
        continue;
      }
      final inset = radius < len1 / 2 && radius < len2 / 2
          ? radius
          : (len1 < len2 ? len1 : len2) / 2;
      final p1 = corner - incoming / len1 * inset;
      final p2 = corner + outgoing / len2 * inset;
      path.lineTo(p1.dx, p1.dy);
      path.quadraticBezierTo(corner.dx, corner.dy, p2.dx, p2.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpatialGraphScenePainter oldDelegate) {
    return oldDelegate.layout != layout;
  }
}
