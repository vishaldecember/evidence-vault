import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/timeline_workspace_filter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Lightweight visibility filters for the Timeline Workspace.
class TimelineWorkspaceFilters extends StatelessWidget {
  const TimelineWorkspaceFilters({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final TimelineWorkspaceFilter selectedFilter;
  final ValueChanged<TimelineWorkspaceFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0;
                index < TimelineWorkspaceFilter.valuesInDisplayOrder.length;
                index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.xs),
              Builder(
                builder: (context) {
                  final filter =
                      TimelineWorkspaceFilter.valuesInDisplayOrder[index];
                  final isSelected = filter == selectedFilter;
                  return FilterChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    showCheckmark: false,
                    onSelected: (_) => onFilterSelected(filter),
                    labelStyle: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    selectedColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundColor: AppColors.card,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.45)
                          : AppColors.border.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
