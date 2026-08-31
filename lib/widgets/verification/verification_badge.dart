import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/verification_model.dart';
import '../../models/verification_status.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Subtle verification indicator — used sparingly on key surfaces only.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    super.key,
    required this.verification,
    this.compact = false,
  });

  final VerificationModel verification;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (verification.isNotVerified && compact) {
      return const SizedBox.shrink();
    }

    final colors = _colorsFor(verification.status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? 2 : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verification.isVerified) ...[
            Icon(
              Icons.verified_outlined,
              size: compact ? 12 : 14,
              color: colors.foreground,
            ),
            SizedBox(width: compact ? 4 : AppSpacing.xxs),
          ],
          Text(
            verification.statusLabel,
            style: AppTextStyles.caption.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _colorsFor(VerificationStatus status) => switch (status) {
        VerificationStatus.verified => _BadgeColors(
            background: AppColors.success.withValues(alpha: 0.08),
            border: AppColors.success.withValues(alpha: 0.2),
            foreground: AppColors.success,
          ),
        VerificationStatus.verificationPending => _BadgeColors(
            background: AppColors.primary.withValues(alpha: 0.06),
            border: AppColors.primary.withValues(alpha: 0.18),
            foreground: AppColors.primary,
          ),
        VerificationStatus.notVerified => _BadgeColors(
            background: AppColors.surfaceMuted.withValues(alpha: 0.6),
            border: AppColors.border.withValues(alpha: 0.45),
            foreground: AppColors.textMuted,
          ),
      };
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}
