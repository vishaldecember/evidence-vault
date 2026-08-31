import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Capture card toolbar — primary title with optional Connect action on the right.
class CaptureSectionHeader extends StatelessWidget {
  const CaptureSectionHeader({
    super.key,
    this.trailing,
    this.connectModeActive = false,
    this.onCancelConnect,
  });

  /// Connect pill aligned with the Capture title.
  final Widget? trailing;
  final bool connectModeActive;
  final VoidCallback? onCancelConnect;

  static const String connectModeHelperText =
      'Select evidence in Evidence Maturity, then tap Done.';

  /// Shared Capture card title typography — used by Connect for visual parity.
  static TextStyle get titleStyle =>
      AppTextStyles.heading.copyWith(fontSize: 17);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Capture',
                style: titleStyle,
              ),
            ),
            ?trailing,
          ],
        ),
        if (connectModeActive) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            connectModeHelperText,
            style: AppTextStyles.caption.copyWith(height: 1.35, fontSize: 12),
          ),
          if (onCancelConnect != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancelConnect,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
