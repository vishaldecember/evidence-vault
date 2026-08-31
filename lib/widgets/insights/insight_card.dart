import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/insight_model.dart';
import '../../models/insight_severity.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Calm informational card for one insight observation.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});

  final InsightModel insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _backgroundColor(insight.severity),
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(
          color: _borderColor(insight.severity),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            insight.title,
            style: AppTextStyles.emphasisLabel,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            insight.explanation,
            style: AppTextStyles.bodySmall.copyWith(height: 1.5),
          ),
          if (insight.suggestedAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              insight.suggestedAction!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _backgroundColor(InsightSeverity severity) => switch (severity) {
        InsightSeverity.positive =>
          AppColors.primary.withValues(alpha: 0.06),
        InsightSeverity.neutral => AppColors.surfaceMuted,
        InsightSeverity.informational => AppColors.background,
      };

  Color _borderColor(InsightSeverity severity) => switch (severity) {
        InsightSeverity.positive =>
          AppColors.primary.withValues(alpha: 0.2),
        InsightSeverity.neutral =>
          AppColors.border.withValues(alpha: 0.6),
        InsightSeverity.informational =>
          AppColors.border.withValues(alpha: 0.5),
      };
}
