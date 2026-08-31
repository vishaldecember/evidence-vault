import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/library_insight_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Calm informational card for one library insight observation.
///
/// Encourages exploration — never demands action or implies judgment.
class LibraryInsightCard extends StatelessWidget {
  const LibraryInsightCard({super.key, required this.insight});

  final LibraryInsightModel insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Observed',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            insight.message,
            style: AppTextStyles.bodySmall.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}
