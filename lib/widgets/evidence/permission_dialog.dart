import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

class PermissionDialog extends StatelessWidget {
  const PermissionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.permanentlyDenied,
  });

  final String title;
  final String message;
  final bool permanentlyDenied;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required bool permanentlyDenied,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.navy.withValues(alpha: 0.28),
      transitionDuration: AppMotion.page,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: PermissionDialog(
            title: title,
            message: message,
            permanentlyDenied: permanentlyDenied,
          ),
        );
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
      title: Text(title, style: AppTextStyles.heading),
      content: Text(message, style: AppTextStyles.bodySmall),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now', style: AppTextStyles.link),
        ),
        if (permanentlyDenied)
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open settings', style: AppTextStyles.link),
          ),
      ],
    );
  }
}
