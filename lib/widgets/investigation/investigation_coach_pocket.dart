import 'package:flutter/material.dart';

import '../../constants/app_accessibility.dart';
import '../../constants/app_spacing.dart';
import '../../controllers/investigation_coaching_controller.dart';
import '../../models/investigation_coaching_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';

/// Thin right-side holder for dismissed Investigation Coach suggestions.
class InvestigationCoachPocket extends StatelessWidget {
  const InvestigationCoachPocket({
    super.key,
    required this.controller,
    required this.onRestore,
  });

  final InvestigationCoachingController controller;
  final ValueChanged<InvestigationCoachingItem> onRestore;

  static const double width = 48;

  /// Flies a compact file-like stand-in from the card into the pocket.
  static void flyToPocket({
    required BuildContext fromContext,
    required BuildContext pocketContext,
    required VoidCallback onArrived,
  }) {
    final overlayState = Overlay.maybeOf(fromContext, rootOverlay: true);
    final fromBox = fromContext.findRenderObject();
    final pocketBox = pocketContext.findRenderObject();
    if (overlayState == null ||
        fromBox is! RenderBox ||
        pocketBox is! RenderBox ||
        !fromBox.hasSize ||
        !pocketBox.hasSize) {
      onArrived();
      return;
    }

    final fromRect = fromBox.localToGlobal(Offset.zero) & fromBox.size;
    final pocketRect = pocketBox.localToGlobal(Offset.zero) & pocketBox.size;
    final toRect = Rect.fromCenter(
      center: pocketRect.center,
      width: 24,
      height: 32,
    );

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return _CoachPocketFlight(
          from: fromRect,
          to: toRect,
          onComplete: () {
            entry.remove();
            onArrived();
          },
        );
      },
    );
    overlayState.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.pocketedItems;
        return SizedBox(
          width: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.journeyTabCapture.withValues(alpha: 0.52),
              border: Border(
                left: BorderSide(
                  color: AppColors.cardHalo.withValues(alpha: 0.40),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: 6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_copy_outlined,
                    size: 20,
                    color: AppColors.onCanvasSecondary.withValues(alpha: 0.72),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    for (var index = 0; index < items.length; index++) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.xs),
                      _PocketFile(
                        key: Key('coach_pocket_${items[index].fingerprint}'),
                        item: items[index],
                        onTap: () => onRestore(items[index]),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PocketFile extends StatelessWidget {
  const _PocketFile({
    super.key,
    required this.item,
    required this.onTap,
  });

  final InvestigationCoachingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.category.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppAccessibility.minTouchTarget,
              minHeight: AppAccessibility.minTouchTarget,
            ),
            child: Center(
              child: Opacity(
                opacity: 0.62,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.journeyTabOrganize.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                    border: Border(
                      left: BorderSide(
                        color: AppColors.onCanvas.withValues(alpha: 0.42),
                        width: 2,
                      ),
                    ),
                  ),
                  child: const SizedBox(
                    height: 34,
                    width: 28,
                    child: Icon(
                      Icons.insert_drive_file_outlined,
                      size: 16,
                      color: AppColors.onCanvas,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachPocketFlight extends StatefulWidget {
  const _CoachPocketFlight({
    required this.from,
    required this.to,
    required this.onComplete,
  });

  final Rect from;
  final Rect to;
  final VoidCallback onComplete;

  @override
  State<_CoachPocketFlight> createState() => _CoachPocketFlightState();
}

class _CoachPocketFlightState extends State<_CoachPocketFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Rect?> _rect;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.sheet,
    );
    _rect = RectTween(begin: widget.from, end: widget.to).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.enter),
    );
    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rect,
      builder: (context, _) {
        final rect = _rect.value ?? widget.from;
        return Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.journeyTabOrganize,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.canvasHaloCore.withValues(alpha: 0.28),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.insert_drive_file_outlined,
                size: 16,
                color: AppColors.onCanvas,
              ),
            ),
          ),
        );
      },
    );
  }
}
