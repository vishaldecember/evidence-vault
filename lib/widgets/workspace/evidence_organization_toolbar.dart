import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'connect_evidence_action.dart';

/// Evidence-stage toolbar for relationship group creation.
class EvidenceOrganizationToolbar extends StatelessWidget {
  const EvidenceOrganizationToolbar({
    super.key,
    required this.onConnectPressed,
    this.onCancelConnect,
    this.connectModeActive = false,
    this.connectPendingColorIndex = 0,
    this.showConnectAction = false,
    this.embedded = false,
  });

  final VoidCallback onConnectPressed;
  final VoidCallback? onCancelConnect;
  final bool connectModeActive;
  final int connectPendingColorIndex;
  final bool showConnectAction;

  /// When true, renders inside Organize Records (no outer card spacing).
  final bool embedded;

  static const String helperText =
      'Connect evidence already inside this record.';

  static const String connectModeHelperText =
      'Select evidence in Organize Records, then tap Done.';

  @override
  Widget build(BuildContext context) {
    if (!showConnectAction && !embedded) {
      return const SizedBox.shrink();
    }

    if (!showConnectAction && embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Organize Evidence',
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Add at least two pieces of evidence to connect them.',
            style: AppTextStyles.caption.copyWith(height: 1.45),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Organize Evidence',
                style: embedded
                    ? AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      )
                    : AppTextStyles.heading,
              ),
            ),
            ConnectEvidencesPill(
              onPressed: onConnectPressed,
              isActive: connectModeActive,
              accentColorIndex: connectPendingColorIndex,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          connectModeActive ? connectModeHelperText : helperText,
          style: AppTextStyles.caption.copyWith(height: 1.45),
        ),
        if (connectModeActive && onCancelConnect != null) ...[
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
    );
  }
}
