import 'package:flutter/material.dart';

import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/living_evidence_preview.dart';

/// Finger-driven spatial thumbnail gallery for the Evidence Inspector.
///
/// Uses Flutter transforms only (perspective / scale / translate / opacity).
/// Does not mutate [items] or evidence/incident IDs.
class EvidenceSpatialCarousel extends StatefulWidget {
  const EvidenceSpatialCarousel({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<WorkspaceEvidenceItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Viewport height including scale/shadow breathing room.
  static const double viewportHeight = 88;

  @override
  State<EvidenceSpatialCarousel> createState() =>
      _EvidenceSpatialCarouselState();
}

class _EvidenceSpatialCarouselState extends State<EvidenceSpatialCarousel>
    with SingleTickerProviderStateMixin {
  /// Fractional drag offset in “item units” (negative = swipe left / next).
  double _drag = 0;
  late AnimationController _snapController;
  Animation<double>? _snapAnimation;

  /// Center-to-center spacing — keeps thumbs visually distinct.
  static const double _itemExtent = 84;
  static const double _cardSize = 72;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
    )..addListener(() {
        final anim = _snapAnimation;
        if (anim == null) {
          return;
        }
        setState(() => _drag = anim.value);
      });
  }

  @override
  void didUpdateWidget(EvidenceSpatialCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        !_snapController.isAnimating) {
      _drag = 0;
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double get _visualOffset => widget.selectedIndex + _drag;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Drag left → next (increase index).
      _drag -= details.delta.dx / (_itemExtent * 0.92);
      _drag = _drag.clamp(
        -widget.selectedIndex.toDouble() - 0.45,
        (widget.items.length - 1 - widget.selectedIndex).toDouble() + 0.45,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    var targetDelta = _drag.round();
    if (velocity.abs() > 420) {
      targetDelta += velocity < 0 ? 1 : -1;
    }
    final targetIndex = (widget.selectedIndex + targetDelta)
        .clamp(0, widget.items.length - 1);
    final remaining = (targetIndex - widget.selectedIndex) - _drag;

    _snapAnimation = Tween<double>(
      begin: _drag,
      end: _drag + remaining,
    ).animate(
      CurvedAnimation(parent: _snapController, curve: AppMotion.enter),
    );
    _snapController.forward(from: 0).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() => _drag = 0);
      if (targetIndex != widget.selectedIndex) {
        widget.onSelected(targetIndex);
      }
    });
  }

  void _onTapIndex(int index) {
    if (index == widget.selectedIndex) {
      return;
    }
    widget.onSelected(index);
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    if (items.length == 1) {
      return SizedBox(
        height: EvidenceSpatialCarousel.viewportHeight,
        child: Center(
          child: _CarouselThumb(
            item: items.first,
            size: _cardSize,
            emphasized: true,
            onTap: () {},
          ),
        ),
      );
    }

    return SizedBox(
      height: EvidenceSpatialCarousel.viewportHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final centerX = constraints.maxWidth / 2;
            final centerY = EvidenceSpatialCarousel.viewportHeight / 2;
            final entries = <({int index, double offset, Widget child})>[];

            for (var i = 0; i < items.length; i++) {
              final offset = i - _visualOffset;
              if (offset.abs() > 1.85) {
                continue;
              }
              final abs = offset.abs();
              final depth = (1 - (abs / 2.4)).clamp(0.0, 1.0);
              final scale = 0.84 + (0.16 * depth);
              final opacity = (0.48 + (0.52 * depth)).clamp(0.48, 1.0);
              final x = centerX + (offset * _itemExtent) - (_cardSize / 2);
              final y = centerY - (_cardSize / 2) + ((1 - depth) * 3);
              final rotateY = -offset * 0.11;
              final isActive = abs < 0.35;

              entries.add((
                index: i,
                offset: abs,
                child: Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0009)
                        ..rotateY(rotateY)
                        ..scaleByDouble(scale, scale, scale, 1),
                      child: _CarouselThumb(
                        item: items[i],
                        size: _cardSize,
                        emphasized: isActive,
                        onTap: () => _onTapIndex(i),
                      ),
                    ),
                  ),
                ),
              ));
            }

            entries.sort((a, b) => a.offset.compareTo(b.offset));

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final entry in entries) entry.child,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CarouselThumb extends StatelessWidget {
  const _CarouselThumb({
    required this.item,
    required this.size,
    required this.emphasized,
    required this.onTap,
  });

  final WorkspaceEvidenceItem item;
  final double size;
  final bool emphasized;
  final VoidCallback onTap;

  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: emphasized,
      label: item.kind.label,
      child: Material(
        key: Key('evidence_inspector_thumb_${item.id}'),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: AppColors.warning.withValues(
                  alpha: emphasized ? 0.9 : 0.55,
                ),
                width: emphasized ? 1.5 : 1,
              ),
              boxShadow: emphasized
                  ? [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.16),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ColoredBox(
              color: AppColors.card,
              child: LivingEvidencePreview(
                item: item,
                uniformThumbnailSize: true,
                suppressBorder: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Position chip: `2 / 5`.
class EvidenceInspectorPositionLabel extends StatelessWidget {
  const EvidenceInspectorPositionLabel({
    super.key,
    required this.index,
    required this.total,
    this.color = AppColors.navy,
  });

  final int index;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${index + 1} / $total',
      key: const Key('evidence_inspector_position'),
      textAlign: TextAlign.center,
      style: AppTextStyles.heading.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
        height: 1.15,
      ),
    );
  }
}

/// Chronological ascending order for Inspector carousel (story order).
///
/// When [incidentId] is set, only items that [WorkspaceEvidenceItem.belongsToIncident]
/// that id are kept. Blank item incidentIds fail closed.
List<WorkspaceEvidenceItem> evidenceInspectorOrder(
  Iterable<WorkspaceEvidenceItem> items, {
  String? incidentId,
}) {
  if (incidentId != null && incidentId.isEmpty) {
    return const [];
  }
  final ordered = List<WorkspaceEvidenceItem>.of(items);
  if (incidentId != null) {
    ordered.removeWhere((item) => !item.belongsToIncident(incidentId));
  }
  ordered.sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));
  return ordered;
}
