import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Investigation-specific workspace chrome shown below the global journey.
class InvestigationStageHeader extends StatelessWidget {
  const InvestigationStageHeader({
    super.key,
    this.trailing,
  });

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Investigation Workspace',
              style: AppTextStyles.label.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onCanvas,
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              softWrap: true,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
