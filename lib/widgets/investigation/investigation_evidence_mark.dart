import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';

/// Shared V3R evidence mark — Graph chronology and Connections spatial map.
class InvestigationEvidenceMark extends StatelessWidget {
  const InvestigationEvidenceMark({
    super.key,
    required this.kind,
    required this.color,
    this.size = 28,
    this.iconSize,
    this.filled = false,
    this.highlighted = false,
    this.markKey,
  });

  final WorkspaceEvidenceKind? kind;
  final Color color;
  final double size;
  final double? iconSize;
  final bool filled;
  final bool highlighted;
  final Key? markKey;

  static IconData iconFor(WorkspaceEvidenceKind? kind) {
    return switch (kind) {
      WorkspaceEvidenceKind.image => Icons.photo_outlined,
      WorkspaceEvidenceKind.video => Icons.videocam_outlined,
      WorkspaceEvidenceKind.voice => Icons.mic_none_rounded,
      WorkspaceEvidenceKind.note => Icons.notes_rounded,
      WorkspaceEvidenceKind.attachment => Icons.insert_drive_file_outlined,
      WorkspaceEvidenceKind.witness => Icons.record_voice_over_outlined,
      null => Icons.circle_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final highlight = highlighted ? AppColors.connectionMine : color;
    return Container(
      key: markKey,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? Colors.white
            : highlight.withValues(alpha: highlighted ? 0.35 : 0.22),
        border: Border.all(
          color: filled ? Colors.white : highlight,
          width: highlighted || filled ? 1.4 : 1,
        ),
      ),
      child: Icon(
        iconFor(kind),
        size: iconSize ?? (size >= 32 ? 16 : 14),
        color: filled ? AppColors.navy : highlight,
      ),
    );
  }
}

/// Press-and-hold wobble used by Connections (same language as Organize).
class InvestigationNodeWobble extends StatefulWidget {
  const InvestigationNodeWobble({
    super.key,
    required this.active,
    required this.child,
    this.maxAngle = 0.045,
  });

  final bool active;
  final Widget child;
  final double maxAngle;

  static const Duration cycle = Duration(milliseconds: 640);

  @override
  State<InvestigationNodeWobble> createState() =>
      _InvestigationNodeWobbleState();
}

class _InvestigationNodeWobbleState extends State<InvestigationNodeWobble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: InvestigationNodeWobble.cycle,
    );
    _sync();
  }

  @override
  void didUpdateWidget(InvestigationNodeWobble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!widget.active) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.active || reduceMotion) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle =
            widget.maxAngle * math.sin(_controller.value * 2 * math.pi);
        return Transform.rotate(
          angle: angle,
          filterQuality: FilterQuality.low,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
