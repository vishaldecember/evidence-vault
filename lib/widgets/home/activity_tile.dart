import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/home_dashboard_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.entry,
    this.showDivider = true,
  });

  final RecentActivityEntry entry;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  entry.icon,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: AppTextStyles.label),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      entry.relativeTimestamp,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            color: AppColors.divider,
          ),
      ],
    );
  }
}
