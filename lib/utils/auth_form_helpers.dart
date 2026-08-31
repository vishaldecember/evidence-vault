import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../navigation/auth_navigation.dart';
import '../widgets/auth/auth_feedback.dart';

abstract final class AuthFormHelpers {
  static void dismissKeyboard(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static void handleAuthError(
    BuildContext context,
    Object error, {
    VoidCallback? onRetry,
  }) {
    if (error is AuthException &&
        error.type == AuthErrorType.emailAlreadyInUse) {
      AuthFeedback.showAccountExists(
        context,
        onGoToSignIn: () => AuthNavigation.openLogin(context),
      );
      return;
    }

    if (error is AuthException &&
        error.type == AuthErrorType.networkUnavailable) {
      AuthFeedback.showNetworkError(
        context,
        error.message,
        onRetry: onRetry,
      );
      return;
    }

    if (error is AuthException) {
      AuthFeedback.showError(context, AuthService.messageFor(error));
      return;
    }

    AuthFeedback.showError(
      context,
      'Something went wrong. Please try again later.',
    );
  }
}
