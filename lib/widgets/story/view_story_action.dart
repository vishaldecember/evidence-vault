import 'package:flutter/material.dart';

import '../../theme/app_button_styles.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Opens the assembled incident story in a dedicated reading view.
class ViewStoryAction extends StatelessWidget {
  const ViewStoryAction({
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
          Icons.menu_book_outlined,
          size: 20,
          color: enabled ? AppColors.primary : AppColors.textMuted,
        ),
        label: Text(
          'View Story',
          style: AppTextStyles.label.copyWith(
            color: enabled ? AppColors.primary : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: AppButtonStyles.secondaryOutlined.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.textMuted
                : AppColors.primary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
