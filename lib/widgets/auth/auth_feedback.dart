import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_notifications.dart';
import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/success_confirmation.dart';

/// Premium Material 3 authentication feedback surfaces.
abstract final class AuthFeedback {
  static Timer? _autoHideTimer;

  static void showSuccess(BuildContext context, String message) {
    SuccessConfirmation.show(context, message: message);
  }

  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showBanner(
      context,
      message: message,
      tone: _AuthFeedbackTone.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showNetworkError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    _showBanner(
      context,
      message: message,
      tone: _AuthFeedbackTone.error,
      icon: Icons.wifi_off_rounded,
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    );
  }

  /// Account-already-exists guidance with navigation to Sign In.
  static void showAccountExists(
    BuildContext context, {
    required VoidCallback onGoToSignIn,
  }) {
    _showBanner(
      context,
      message: 'An account with this email already exists.',
      tone: _AuthFeedbackTone.warning,
      actionLabel: 'Go to Sign In',
      onAction: onGoToSignIn,
      duration: AppNotifications.authBannerDuration,
    );
  }

  static void _dismiss(ScaffoldMessengerState messenger) {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    messenger.hideCurrentMaterialBanner();
  }

  static void _showBanner(
    BuildContext context, {
    required String message,
    required _AuthFeedbackTone tone,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    _autoHideTimer?.cancel();
    messenger.hideCurrentMaterialBanner();
    messenger.clearSnackBars();

    final colors = _colorsFor(tone);
    final resolvedIcon = icon ??
        (tone == _AuthFeedbackTone.warning
            ? Icons.info_outline_rounded
            : Icons.error_outline_rounded);

    messenger.showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        leadingPadding: const EdgeInsets.only(right: AppSpacing.sm),
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.shadow,
        elevation: 2,
        leading: Icon(resolvedIcon, color: colors.foreground, size: 22),
        content: Text(
          message,
          style: AppTextStyles.label.copyWith(
            color: colors.foreground,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
        actions: [
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                _dismiss(messenger);
                onAction();
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.foreground,
                textStyle: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              child: Text(actionLabel),
            ),
          TextButton(
            onPressed: () => _dismiss(messenger),
            style: TextButton.styleFrom(
              foregroundColor: colors.foreground.withValues(alpha: 0.85),
              textStyle: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.foreground.withValues(alpha: 0.85),
              ),
            ),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    final autoHide = duration ?? AppNotifications.authBannerDuration;
    _autoHideTimer = Timer(autoHide, () {
      if (messenger.mounted) {
        messenger.hideCurrentMaterialBanner();
      }
      _autoHideTimer = null;
    });
  }

  static _AuthFeedbackColors _colorsFor(_AuthFeedbackTone tone) {
    return switch (tone) {
      _AuthFeedbackTone.error => const _AuthFeedbackColors(
          background: Color(0xFFFEF2F2),
          foreground: Color(0xFF991B1B),
        ),
      _AuthFeedbackTone.warning => const _AuthFeedbackColors(
          background: Color(0xFFFFFBEB),
          foreground: Color(0xFF92400E),
        ),
    };
  }
}

enum _AuthFeedbackTone { error, warning }

class _AuthFeedbackColors {
  const _AuthFeedbackColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
