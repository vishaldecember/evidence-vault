import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../navigation/app_navigation.dart';
import '../../services/vault_reset_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

class VaultClearedDialog extends StatelessWidget {
  const VaultClearedDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.navy.withValues(alpha: 0.28),
      transitionDuration: AppMotion.page,
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Center(child: VaultClearedDialog());
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      title: const Text('Your vault is now empty.', style: AppTextStyles.heading),
      content: Text(
        'Every investigation has been permanently removed. Your account and '
        'settings remain intact.',
        style: AppTextStyles.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: () {
            VaultResetService.acknowledgeVaultCleared();
            Navigator.pop(context);
          },
          child: const Text('Close', style: AppTextStyles.link),
        ),
        FilledButton(
          onPressed: () {
            VaultResetService.acknowledgeVaultCleared();
            Navigator.pop(context);
            AppNavigation.openEvidenceWorkspace(
              context,
              captureInitiated: true,
            );
          },
          child: const Text('Create First Incident'),
        ),
      ],
    );
  }
}
