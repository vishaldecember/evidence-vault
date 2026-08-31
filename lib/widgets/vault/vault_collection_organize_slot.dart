import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import 'vault_organize_drag_data.dart';

/// Organize-mode drop target for an existing Collection.
///
/// Accepts an incident drag. Does not make the Collection itself draggable.
class VaultCollectionOrganizeSlot extends StatelessWidget {
  const VaultCollectionOrganizeSlot({
    super.key,
    required this.collectionId,
    required this.child,
    required this.onIncidentDropped,
  });

  final String collectionId;
  final Widget child;
  final void Function(String sourceIncidentId, String collectionId)
      onIncidentDropped;

  static Key targetKey(String collectionId) =>
      Key('vault_collection_target_$collectionId');

  @override
  Widget build(BuildContext context) {
    return DragTarget<VaultOrganizeDragData>(
      key: targetKey(collectionId),
      onWillAcceptWithDetails: (details) {
        return details.data.incidentId.trim().isNotEmpty;
      },
      onAcceptWithDetails: (details) {
        onIncidentDropped(details.data.incidentId, collectionId);
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
            child: child,
          ),
        );
      },
    );
  }
}
