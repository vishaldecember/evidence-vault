import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/investigation_coaching_item.dart';
import '../../models/investigation_coaching_priority.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// One coaching insight card — professional assistant tone, not conversational.
class InvestigationCoachingCard extends StatelessWidget {
  const InvestigationCoachingCard({
    super.key,
    required this.item,
    required this.onReview,
    required this.onDismiss,
  });

  final InvestigationCoachingItem item;
  final VoidCallback onReview;
  final VoidCallback onDismiss;

  /// Soft warm notebook-paper surface — unsaturated coffee beige.
  static const Color notebookBackground = Color(0xFFFAF6F0);

  /// Darker charcoal border — clearer card edge, not pure black.
  static const Color notebookBorder = Color(0xFF4A4D55);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: notebookBackground,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(
          color: notebookBorder.withValues(alpha: 0.78),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.category.label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  softWrap: true,
                ),
              ),
              _PriorityBadge(priority: item.priority),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.observation,
            style: AppTextStyles.bodySmall.copyWith(height: 1.4),
            maxLines: 5,
            softWrap: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Suggested Action',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.suggestedAction,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            maxLines: 4,
            softWrap: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              TextButton(
                onPressed: onReview,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Review'),
              ),
              const SizedBox(width: AppSpacing.xs),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final InvestigationCoachingPriority priority;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (priority) {
      InvestigationCoachingPriority.high => (
          AppColors.danger.withValues(alpha: 0.12),
          AppColors.danger,
        ),
      InvestigationCoachingPriority.medium => (
          AppColors.warning.withValues(alpha: 0.14),
          AppColors.warning,
        ),
      InvestigationCoachingPriority.low => (
          AppColors.border.withValues(alpha: 0.35),
          AppColors.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        priority.label,
        style: AppTextStyles.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
