import 'package:flutter/material.dart';

import '../../constants/app_accessibility.dart';
import '../../constants/app_spacing.dart';
import '../../domain/collection/evidence_collection.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';

/// Thin right-edge holder for dismissed Organize collection suggestions.
///
/// Visual language follows [InvestigationCoachPocket] (width, translucency,
/// file chip, flight). State is Organize-only — no coaching controller.
class OrganizeSuggestionRail extends StatelessWidget {
  const OrganizeSuggestionRail({
    super.key,
    required this.collections,
    required this.onRestore,
  });

  final List<EvidenceCollection> collections;
  final void Function(EvidenceCollection collection, BuildContext chipContext)
      onRestore;

  static const double width = 48;

  static const Key railKey = Key('organize_suggestion_rail');

  static Key chipKey(String collectionId) =>
      Key('organize_suggestion_chip_$collectionId');

  /// Flies a compact file stand-in from a suggestion card into the rail.
  static void flyToRail({
    required BuildContext fromContext,
    required BuildContext railContext,
    required VoidCallback onArrived,
  }) {
    _fly(
      fromContext: fromContext,
      toContext: railContext,
      onArrived: onArrived,
      contractToChip: true,
    );
  }

  /// Expands a rail chip back toward the workspace suggestion slot.
  static void flyFromRail({
    required BuildContext fromContext,
    required BuildContext toContext,
    required VoidCallback onArrived,
  }) {
    _fly(
      fromContext: fromContext,
      toContext: toContext,
      onArrived: onArrived,
      contractToChip: false,
    );
  }

  static void _fly({
    required BuildContext fromContext,
    required BuildContext toContext,
    required VoidCallback onArrived,
    required bool contractToChip,
  }) {
    final overlayState = Overlay.maybeOf(fromContext, rootOverlay: true);
    final fromBox = fromContext.findRenderObject();
    final toBox = toContext.findRenderObject();
    if (overlayState == null ||
        fromBox is! RenderBox ||
        toBox is! RenderBox ||
        !fromBox.hasSize ||
        !toBox.hasSize) {
      onArrived();
      return;
    }

    final fromRect = fromBox.localToGlobal(Offset.zero) & fromBox.size;
    final destRect = toBox.localToGlobal(Offset.zero) & toBox.size;
    final chipRect = Rect.fromCenter(
      center: destRect.center,
      width: 24,
      height: 32,
    );
    final cardRect = Rect.fromLTWH(
      destRect.left,
      destRect.top,
      destRect.width.clamp(160.0, 320.0),
      destRect.height.clamp(72.0, 160.0),
    );

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return _OrganizeRailFlight(
          from: contractToChip ? fromRect : fromRect,
          to: contractToChip ? chipRect : cardRect,
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
    if (collections.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxRailHeight = MediaQuery.sizeOf(context).height * 0.62;

    return SizedBox(
      key: railKey,
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
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxRailHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_copy_outlined,
                    size: 20,
                    color: AppColors.onCanvasSecondary.withValues(alpha: 0.72),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (var index = 0; index < collections.length; index++) ...[
                    if (index > 0) const SizedBox(height: AppSpacing.xs),
                    Builder(
                      builder: (chipContext) {
                        return _RailFile(
                          key: chipKey(collections[index].id),
                          collection: collections[index],
                          onTap: () =>
                              onRestore(collections[index], chipContext),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailFile extends StatelessWidget {
  const _RailFile({
    super.key,
    required this.collection,
    required this.onTap,
  });

  final EvidenceCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collection.name,
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
                  child: SizedBox(
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

class _OrganizeRailFlight extends StatefulWidget {
  const _OrganizeRailFlight({
    required this.from,
    required this.to,
    required this.onComplete,
  });

  final Rect from;
  final Rect to;
  final VoidCallback onComplete;

  @override
  State<_OrganizeRailFlight> createState() => _OrganizeRailFlightState();
}

class _OrganizeRailFlightState extends State<_OrganizeRailFlight>
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
