import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Consistent button hierarchy across Evidence Vault.
abstract final class AppButtonStyles {
  static ButtonStyle get primary => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        shadowColor: AppColors.primaryShadow,
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        textStyle: AppTextStyles.button,
      );

  static ButtonStyle get primaryCompact => primary.copyWith(
        minimumSize: WidgetStateProperty.all(
          const Size.fromHeight(AppSpacing.buttonHeight),
        ),
      );

  static ButtonStyle get secondaryOutlined => OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
      );

  static ButtonStyle get tertiaryOutlined => OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
        side: BorderSide(color: AppColors.navy.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
      );

  static ButtonStyle get inlineOutlined => OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(44),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        textStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
      );
}
