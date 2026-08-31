import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/home_dashboard_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'activity_tile.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    super.key,
    required this.entries,
  });

  final List<RecentActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < entries.length; index++)
            ActivityTile(
              entry: entries[index],
              showDivider: index < entries.length - 1,
            ),
        ],
      ),
    );
  }
}
