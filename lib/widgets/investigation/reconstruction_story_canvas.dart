import 'package:flutter/material.dart';

import '../../models/workspace_evidence_item.dart';
import '../../services/investigation/connection_trace_engine.dart';
import '../../services/investigation/reconstruction_canvas_layout.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'investigation_evidence_mark.dart';

/// Two-dimensional Reconstruct canvas: X = when, Y = where.
class ReconstructionStoryCanvas extends StatelessWidget {
  const ReconstructionStoryCanvas({
    super.key,
    required this.plot,
    required this.onEvidenceTap,
    required this.onEditLocation,
  });

  final ReconstructionPlot plot;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceTap;
  final void Function(ReconstructionLocationBand band) onEditLocation;

  static const Key canvasKey = Key('reconstruction_story_canvas');
  static const Key axesKey = Key('reconstruction_story_axes');
  static const Key whenAxisKey = Key('reconstruction_axis_when');
  static const Key whereAxisKey = Key('reconstruction_axis_where');
  static const Color locationRed = Color(0xFFE53935);
  static const Color evidenceColor = Color(0xFFE8F1F8);
  static const Color contextColor = Color(0xFF8FCBB3);

  static Key nodeKey(String id) => Key('reconstruction_evidence_$id');
  static Key locationBandKey(String key) =>
      Key('reconstruction_location_band_$key');
  static Key timeMarkKey(DateTime at) =>
      Key('reconstruction_time_${at.millisecondsSinceEpoch}');

  @override
  Widget build(BuildContext context) {
    if (plot.nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          'Preserve moments to reconstruct what happened.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.onCanvasSecondary,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: ClipRect(
        child: InteractiveViewer(
          constrained: false,
          minScale: 0.8,
          maxScale: 2.2,
          boundaryMargin: const EdgeInsets.all(48),
          child: SizedBox(
            key: canvasKey,
            width: plot.size.width,
            height: plot.size.height,
            child: Stack(
              children: [
                CustomPaint(
                  key: axesKey,
                  size: plot.size,
                  painter: _ReconstructionAxesPainter(plot: plot),
                ),
                Positioned(
                  key: whenAxisKey,
                  left: plot.axisXEnd.dx - 36,
                  top: plot.origin.dy + 28,
                  child: Text(
                    'WHEN',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onCanvasSecondary,
                      fontSize: 8,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final band in plot.bands)
                  Positioned(
                    key: locationBandKey(band.key),
                    left: 4,
                    top: band.y - 22,
                    width: plot.origin.dx - 8,
                    child: _LocationBandLabel(
                      band: band,
                      onEdit: band.editable ? () => onEditLocation(band) : null,
                    ),
                  ),
                for (final mark in plot.timeMarks)
                  Positioned(
                    key: timeMarkKey(mark.at),
                    left: mark.x - (plot.origin.dx * 0.45).clamp(22.0, 28.0),
                    top: plot.origin.dy + 6,
                    width: (plot.origin.dx).clamp(40.0, 56.0),
                    child: Column(
                      children: [
                        Text(
                          mark.dateLabel,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.onCanvasSecondary,
                            fontSize: 8,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          mark.timeLabel,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.timelineChronology,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final node in plot.nodes)
                  Positioned(
                    key: nodeKey(node.id),
                    left: node.position.dx - ConnectionTraceEngine.markSize / 2,
                    top: node.position.dy - ConnectionTraceEngine.markSize / 2,
                    width: ConnectionTraceEngine.markSize,
                    height: ConnectionTraceEngine.markSize,
                    child: Semantics(
                      button: true,
                      label: node.item.kind.label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onEvidenceTap(node.item),
                        child: InvestigationEvidenceMark(
                          kind: node.item.kind,
                          color: node.kind == ReconstructionPlotKind.context
                              ? contextColor
                              : evidenceColor,
                          size: ConnectionTraceEngine.markSize,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationBandLabel extends StatelessWidget {
  const _LocationBandLabel({required this.band, this.onEdit});

  final ReconstructionLocationBand band;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final addLocation =
        band.label == ReconstructionCanvasLayout.addLocationLabel;
    final child = Semantics(
      button: onEdit != null,
      label: 'Location ${band.label}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.place_rounded,
            size: 16,
            color: ReconstructionStoryCanvas.locationRed,
          ),
          const SizedBox(height: 2),
          Text(
            _twoLineLocation(band.label),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: addLocation
                  ? AppColors.onCanvasSecondary
                  : AppColors.onCanvas,
              fontSize: addLocation ? 8 : 9,
              fontWeight: addLocation ? FontWeight.w500 : FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
    if (onEdit == null) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: child,
    );
  }

  static String _twoLineLocation(String label) {
    final comma = label.indexOf(',');
    if (comma <= 0 || comma >= label.length - 1) {
      return label;
    }
    return '${label.substring(0, comma).trim()}\n${label.substring(comma + 1).trim()}';
  }
}

class _ReconstructionAxesPainter extends CustomPainter {
  const _ReconstructionAxesPainter({required this.plot});

  final ReconstructionPlot plot;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = const Color(0x55D4E4F2)
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(plot.origin, plot.axisXEnd, axis);
    canvas.drawLine(plot.origin, plot.axisYEnd, axis);

    final lane = Paint()
      ..color = const Color(0x14D4E4F2)
      ..strokeWidth = 1;
    for (final band in plot.bands) {
      canvas.drawLine(
        Offset(plot.origin.dx, band.y),
        Offset(plot.axisXEnd.dx, band.y),
        lane,
      );
    }

    if (plot.storyPath.length >= 2) {
      final story = Paint()
        ..color = const Color(0x33C4A882)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(plot.storyPath.first.dx, plot.storyPath.first.dy);
      for (var i = 1; i < plot.storyPath.length; i++) {
        path.lineTo(plot.storyPath[i].dx, plot.storyPath[i].dy);
      }
      canvas.drawPath(path, story);
    }
  }

  @override
  bool shouldRepaint(covariant _ReconstructionAxesPainter oldDelegate) {
    return oldDelegate.plot != plot;
  }
}
