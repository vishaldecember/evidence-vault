import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/investigation/connection_trace.dart';
import '../../models/evidence_relationship.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/investigation/connection_trace_engine.dart';
import '../../services/investigation/user_connection_overlay_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/instant_codec.dart';
import 'investigation_evidence_mark.dart';

/// Spatial Connections canvas — system (violet) and investigator (orange) traces.
class InvestigationConnectionsCanvas extends StatefulWidget {
  const InvestigationConnectionsCanvas({
    super.key,
    required this.incidentId,
    required this.evidence,
    required this.relationships,
    this.collections = const [],
    this.onEvidenceTap,
  });

  final String incidentId;
  final List<WorkspaceEvidenceItem> evidence;
  final List<EvidenceRelationship> relationships;
  final List<EvidenceCollection> collections;
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceTap;

  static const Key canvasKey = Key('investigation_connections_canvas');
  static const Key edgesKey = Key('investigation_connection_edges');
  static const double chipWidth = 80;

  static const Color systemLinkColor = AppColors.connectionSystem;
  static const Color mineLinkColor = AppColors.connectionMine;

  static Key nodeKey(String id) => Key('investigation_connection_node_$id');

  @override
  State<InvestigationConnectionsCanvas> createState() =>
      _InvestigationConnectionsCanvasState();
}

class _InvestigationConnectionsCanvasState
    extends State<InvestigationConnectionsCanvas> {
  @override
  void initState() {
    super.initState();
    UserConnectionOverlayStore.instance.hydrate(widget.incidentId);
  }

  @override
  void didUpdateWidget(covariant InvestigationConnectionsCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidentId != widget.incidentId) {
      UserConnectionOverlayStore.instance.hydrate(widget.incidentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserConnectionOverlayStore.instance,
      builder: (context, _) {
        final snapshot = ConnectionTraceEngine.mergeUserOverlay(
          system: ConnectionTraceEngine.systemSnapshot(
            evidence: widget.evidence,
            relationships: widget.relationships,
            collections: widget.collections,
          ),
          mine: UserConnectionOverlayStore.instance.snapshotFor(
            widget.incidentId,
          ),
        );
        return SizedBox.expand(
          key: InvestigationConnectionsCanvas.canvasKey,
          child: ClipRect(
            child: InteractiveViewer(
              key: ValueKey<String>(widget.incidentId),
              constrained: false,
              minScale: 0.75,
              maxScale: 2,
              boundaryMargin: const EdgeInsets.all(48),
              child: SizedBox(
                width: snapshot.size.width,
                height: snapshot.size.height,
                child: Stack(
                  children: [
                    CustomPaint(
                      key: InvestigationConnectionsCanvas.edgesKey,
                      size: snapshot.size,
                      painter: _ConnectionEdgePainter(snapshot: snapshot),
                    ),
                    for (final node in snapshot.nodes)
                      Positioned(
                        left:
                            node.position.dx -
                            InvestigationConnectionsCanvas.chipWidth / 2,
                        top:
                            node.position.dy -
                            ConnectionTraceEngine.markSize / 2,
                        width: InvestigationConnectionsCanvas.chipWidth,
                        child: _ConnectionIcon(
                          node: node,
                          onTap: () {
                            final evidenceId = node.evidenceId;
                            if (evidenceId == null) {
                              return;
                            }
                            for (final item in widget.evidence) {
                              if (item.id == evidenceId) {
                                widget.onEvidenceTap?.call(item);
                                return;
                              }
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionIcon extends StatelessWidget {
  const _ConnectionIcon({required this.node, required this.onTap});

  final ConnectionTraceNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (node.kind) {
      ConnectionTraceKind.moment => const Color(0xFFE8F1F8),
      ConnectionTraceKind.context => const Color(0xFF9BBAD1),
      ConnectionTraceKind.person => const Color(0xFFD4C4A8),
      ConnectionTraceKind.location => const Color(0xFFC5B8E0),
    };
    final time = node.timestamp.millisecondsSinceEpoch == 0
        ? node.label
        : DateFormat('h:mm a').format(InstantCodec.toLocal(node.timestamp));
    final mark = node.kind == ConnectionTraceKind.person
        ? Container(
            width: ConnectionTraceEngine.markSize,
            height: ConnectionTraceEngine.markSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
              border: Border.all(color: color),
            ),
            child: Icon(Icons.person_outline_rounded, size: 16, color: color),
          )
        : node.kind == ConnectionTraceKind.location
        ? Container(
            width: ConnectionTraceEngine.markSize,
            height: ConnectionTraceEngine.markSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
              border: Border.all(color: color),
            ),
            child: Icon(Icons.place_rounded, size: 16, color: color),
          )
        : InvestigationEvidenceMark(
            kind: node.evidenceKind,
            color: color,
            size: ConnectionTraceEngine.markSize,
          );

    return Semantics(
      button: node.evidenceId != null,
      label: '${node.label} $time',
      child: GestureDetector(
        key: InvestigationConnectionsCanvas.nodeKey(node.id),
        onTap: node.evidenceId == null ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            const SizedBox(height: 3),
            Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onCanvas,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionEdgePainter extends CustomPainter {
  const _ConnectionEdgePainter({required this.snapshot});

  final ConnectionTraceSnapshot snapshot;

  static const double _stroke = 1.5;
  static const double _head = 7.7;

  @override
  void paint(Canvas canvas, Size size) {
    final systemPaint = Paint()
      ..color = InvestigationConnectionsCanvas.systemLinkColor.withValues(
        alpha: 0.82,
      )
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final mineGlow = Paint()
      ..color = InvestigationConnectionsCanvas.mineLinkColor.withValues(
        alpha: 0.28,
      )
      ..strokeWidth = _stroke + 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.4);
    final minePaint = Paint()
      ..color = InvestigationConnectionsCanvas.mineLinkColor.withValues(
        alpha: 0.92,
      )
      ..strokeWidth = _stroke + 0.15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    ConnectionTraceNode? byId(String id) {
      for (final node in snapshot.nodes) {
        if (node.id == id) {
          return node;
        }
      }
      return null;
    }

    for (final link in snapshot.links) {
      final from = byId(link.fromId);
      final to = byId(link.toId);
      if (from == null || to == null) {
        continue;
      }
      final mine = link.origin == ConnectionTraceOrigin.user;
      if (mine) {
        _drawBidirectional(canvas, from.position, to.position, mineGlow);
      }
      _drawBidirectional(
        canvas,
        from.position,
        to.position,
        mine ? minePaint : systemPaint,
      );
    }
  }

  static void _drawBidirectional(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
  ) {
    final start = ConnectionTraceEngine.pointOnCircumference(from, to);
    final end = ConnectionTraceEngine.pointOnCircumference(to, from);
    if ((end - start).distance < 8) {
      return;
    }
    canvas.drawLine(start, end, paint);
    final direction = (end - start) / (end - start).distance;
    _arrowHead(canvas, end, direction, paint);
    _arrowHead(canvas, start, -direction, paint);
  }

  static void _arrowHead(
    Canvas canvas,
    Offset tip,
    Offset direction,
    Paint paint,
  ) {
    final normal = Offset(-direction.dy, direction.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - direction.dx * _head + normal.dx * 4.4,
        tip.dy - direction.dy * _head + normal.dy * 4.4,
      )
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - direction.dx * _head - normal.dx * 4.4,
        tip.dy - direction.dy * _head - normal.dy * 4.4,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectionEdgePainter oldDelegate) {
    return oldDelegate.snapshot != snapshot;
  }
}
