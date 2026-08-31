import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_accessibility.dart';
import '../../theme/app_colors.dart';

/// Vault-only organize chrome around an existing incident tile.
///
/// Transform-only motion. Does not change incident data or layout of the
/// underlying tile contents.
class VaultOrganizeModule extends StatelessWidget {
  const VaultOrganizeModule({
    super.key,
    required this.incidentId,
    required this.organizing,
    required this.child,
    this.animation,
    this.phase = 0,
    this.onRemove,
  });

  final String incidentId;
  final bool organizing;
  final Widget child;
  final Animation<double>? animation;
  final double phase;
  final VoidCallback? onRemove;

  static Key moduleKey(String incidentId) =>
      Key('vault_organize_module_$incidentId');

  static Key removeKey(String incidentId) =>
      Key('vault_organize_remove_$incidentId');

  static const double _maxAngle = 0.02;

  @override
  Widget build(BuildContext context) {
    Widget tile = child;
    if (organizing) {
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      final animation = this.animation;
      if (!reduceMotion && animation != null) {
        tile = AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final angle =
                _maxAngle * math.sin((animation.value * 2 * math.pi) + phase);
            return Transform.rotate(
              angle: angle,
              filterQuality: FilterQuality.low,
              child: child,
            );
          },
          child: child,
        );
      }
      tile = Stack(
        key: moduleKey(incidentId),
        clipBehavior: Clip.none,
        children: [
          tile,
          Positioned(
            left: -6,
            top: -6,
            child: _OrganizeRemoveAffordance(
              incidentId: incidentId,
              onPressed: onRemove,
            ),
          ),
        ],
      );
    }
    return tile;
  }
}

class _OrganizeRemoveAffordance extends StatelessWidget {
  const _OrganizeRemoveAffordance({
    required this.incidentId,
    required this.onPressed,
  });

  final String incidentId;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Remove not available yet',
      hint: 'Does not delete or archive this incident',
      child: SizedBox(
        width: AppAccessibility.minTouchTarget,
        height: AppAccessibility.minTouchTarget,
        child: IconButton(
          key: VaultOrganizeModule.removeKey(incidentId),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          tooltip: 'Remove not available yet',
          icon: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.navy.withValues(alpha: 0.35)),
            ),
            child: const SizedBox(
              width: 22,
              height: 22,
              child: Icon(
                Icons.remove,
                size: 14,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
