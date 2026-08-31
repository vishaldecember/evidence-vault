import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../models/relationship_group_confidence.dart';
import '../../../services/narrative_validation_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Validation summary beneath a narrative event title.
class NarrativeValidationSummary extends StatelessWidget {
  const NarrativeValidationSummary({
    super.key,
    required this.validation,
  });

  final NarrativeEventValidation validation;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (validation.status) {
      RelationshipGroupConfidence.high => AppColors.success,
      RelationshipGroupConfidence.medium => AppColors.warning,
      RelationshipGroupConfidence.low => AppColors.danger,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supported by',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        for (final line in validation.supportedByLines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        if (validation.recommendations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Recommendation',
            style: AppTextStyles.caption.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          for (final recommendation in validation.recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '⚠ $recommendation',
                style: AppTextStyles.caption.copyWith(
                  color: statusColor,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
