import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Subtle person chip for evidence cards — name only, no role.
class EvidenceParticipantChip extends StatelessWidget {
  const EvidenceParticipantChip({
    super.key,
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Related person $displayName',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.65),
          ),
        ),
        child: Text(
          '👤 $displayName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            height: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
