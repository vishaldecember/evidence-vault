import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/relationship_group.dart';
import '../../services/relationship_group_color_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';

/// Read-only awareness of committed relationship groups in the Workspace.
///
/// Data is sourced from [RelationshipRepository.groups] via the parent —
/// no duplicate relationship state.
class RelationshipGroupSummary extends StatelessWidget {
  const RelationshipGroupSummary({
    super.key,
    required this.relationshipGroups,
    this.onViewConnections,
  });

  final List<RelationshipGroup> relationshipGroups;
  final VoidCallback? onViewConnections;

  static String groupCountLabel(int count) {
    if (count == 1) {
      return '1 Group Created';
    }
    return '$count Groups Created';
  }

  @override
  Widget build(BuildContext context) {
    if (relationshipGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    final orderedGroups =
        RelationshipGroupColorService.orderedGroups(relationshipGroups);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: AppDecorations.card(
        backgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.55),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Relationship Groups',
                  style: AppTextStyles.emphasisLabel.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ViewConnectionsButton(onPressed: onViewConnections),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                groupCountLabel(orderedGroups.length),
                style: AppTextStyles.caption,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RelationshipGroupColorChips(groups: orderedGroups),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewConnectionsButton extends StatelessWidget {
  const _ViewConnectionsButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Connections →',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RelationshipGroupColorChips extends StatelessWidget {
  const _RelationshipGroupColorChips({required this.groups});

  final List<RelationshipGroup> groups;

  static const double _chipSize = 12;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        for (final group in groups)
          Semantics(
            label:
                RelationshipGroupColorService.displayName(group, groups),
            child: Container(
              width: _chipSize,
              height: _chipSize,
              decoration: BoxDecoration(
                color: RelationshipGroupColorService.colorForGroup(group),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
