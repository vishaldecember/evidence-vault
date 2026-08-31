import 'package:flutter/material.dart';

import '../../theme/app_button_styles.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Opens the Trust Package preview for review before future sharing.
class PrepareTrustPackageAction extends StatelessWidget {
  const PrepareTrustPackageAction({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          Icons.verified_user_outlined,
          size: 20,
          color: enabled ? AppColors.navy : AppColors.textMuted,
        ),
        label: Text(
          'Prepare Trust Package',
          style: AppTextStyles.label.copyWith(
            color: enabled ? AppColors.navy : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: AppButtonStyles.tertiaryOutlined.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.textMuted
                : AppColors.navy,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: enabled
                  ? AppColors.navy.withValues(alpha: 0.35)
                  : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
