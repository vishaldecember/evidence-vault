import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/relationship_group_confidence.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Read-only coaching indicator beneath a relationship group header.
class RelationshipGroupConfidenceIndicator extends StatelessWidget {
  const RelationshipGroupConfidenceIndicator({
    super.key,
    required this.confidence,
  });

  final RelationshipGroupConfidence confidence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🛡 Confidence',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${confidence.emoji} ${confidence.label}',
          style: AppTextStyles.caption.copyWith(
            color: _levelColor(confidence),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static Color _levelColor(RelationshipGroupConfidence confidence) {
    return switch (confidence) {
      RelationshipGroupConfidence.high => AppColors.success,
      RelationshipGroupConfidence.medium => AppColors.warning,
      RelationshipGroupConfidence.low => AppColors.danger,
    };
  }
}
