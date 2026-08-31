import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import 'vault_organize_drag_data.dart';

/// Organize-mode drag source and incident drop target.
///
/// Phase 3 accepts incident → incident only. Collection targets come later.
class VaultIncidentOrganizeSlot extends StatelessWidget {
  const VaultIncidentOrganizeSlot({
    super.key,
    required this.incidentId,
    required this.child,
    required this.onDroppedOn,
  });

  final String incidentId;
  final Widget child;
  final void Function(String sourceIncidentId, String targetIncidentId)
      onDroppedOn;

  static Key dragKey(String incidentId) =>
      Key('vault_incident_drag_$incidentId');

  static Key targetKey(String incidentId) =>
      Key('vault_incident_target_$incidentId');

  @override
  Widget build(BuildContext context) {
    return DragTarget<VaultOrganizeDragData>(
      key: targetKey(incidentId),
      onWillAcceptWithDetails: (details) {
        return details.data.incidentId != incidentId;
      },
      onAcceptWithDetails: (details) {
        onDroppedOn(details.data.incidentId, incidentId);
      },
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return AnimatedScale(
          scale: highlighted ? 1.02 : 1,
          duration: AppMotion.fast,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: highlighted
                  ? Border.all(color: AppColors.navy.withValues(alpha: 0.35))
                  : Border.all(color: Colors.transparent),
            ),
            child: LongPressDraggable<VaultOrganizeDragData>(
              key: dragKey(incidentId),
              data: VaultOrganizeDragData.incident(incidentId),
              dragAnchorStrategy: childDragAnchorStrategy,
              feedback: _LiftedFeedback(child: child),
              childWhenDragging: Opacity(opacity: 0.35, child: child),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _LiftedFeedback extends StatelessWidget {
  const _LiftedFeedback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      shadowColor: AppColors.navy.withValues(alpha: 0.18),
      child: Opacity(
        opacity: 0.92,
        child: Transform.scale(
          scale: 1.04,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 48,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
