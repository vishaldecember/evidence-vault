import 'package:firebase_auth/firebase_auth.dart';

import 'auth_exception.dart';

/// Maps Firebase [FirebaseAuthException] codes to calm, user-facing messages.
abstract final class AuthErrorMapper {
  static AuthException fromFirebaseAuthException(FirebaseAuthException error) {
    final type = _typeForCode(error.code);
    return AuthException(type: type, message: _messageFor(type, error));
  }

  static AuthException fromObject(Object error) {
    if (error is AuthException) {
      return error;
    }

    if (error is FirebaseAuthException) {
      return fromFirebaseAuthException(error);
    }

    final message = error.toString().toLowerCase();
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection')) {
      return const AuthException(
        type: AuthErrorType.networkUnavailable,
        message:
            'You’re offline. Turn off Airplane Mode or reconnect to continue.',
      );
    }

    return const AuthException(
      type: AuthErrorType.unknown,
      message: 'Something went wrong. Please try again later.',
    );
  }

  static AuthErrorType _typeForCode(String code) {
    return switch (code) {
      'invalid-email' => AuthErrorType.invalidEmail,
      'email-already-in-use' => AuthErrorType.emailAlreadyInUse,
      'wrong-password' => AuthErrorType.wrongPassword,
      'invalid-credential' => AuthErrorType.wrongPassword,
      'weak-password' => AuthErrorType.weakPassword,
      'user-not-found' => AuthErrorType.userNotFound,
      'too-many-requests' => AuthErrorType.tooManyRequests,
      'network-request-failed' => AuthErrorType.networkUnavailable,
      'user-disabled' => AuthErrorType.userDisabled,
      'operation-not-allowed' => AuthErrorType.operationNotAllowed,
      'requires-recent-login' => AuthErrorType.requiresRecentLogin,
      _ => AuthErrorType.unknown,
    };
  }

  static String _messageFor(AuthErrorType type, FirebaseAuthException error) {
    return switch (type) {
      AuthErrorType.invalidEmail =>
        'Please enter a valid email address.',
      AuthErrorType.emailAlreadyInUse =>
        'An account with this email already exists. Try signing in instead.',
      AuthErrorType.wrongPassword =>
        'Incorrect email or password. Please try again.',
      AuthErrorType.weakPassword =>
        'Choose a stronger password that meets all requirements.',
      AuthErrorType.userNotFound =>
        'No account found with this email address.',
      AuthErrorType.tooManyRequests =>
        'Too many attempts. Please wait a moment and try again.',
      AuthErrorType.networkUnavailable =>
        'You’re offline. Turn off Airplane Mode or reconnect to continue.',
      AuthErrorType.userDisabled =>
        'This account has been disabled. Contact support for help.',
      AuthErrorType.operationNotAllowed =>
        'This sign-in method is not available yet. Enable it in Firebase Console, or try email instead.',
      AuthErrorType.requiresRecentLogin =>
        'For your security, please sign in again to continue.',
      AuthErrorType.appleSignInUnavailable =>
        'Sign in with Apple is coming soon.',
      AuthErrorType.googleSignInCancelled =>
        'Google sign-in was cancelled.',
      AuthErrorType.firebaseUnavailable =>
        'Authentication is temporarily unavailable. Please try again later.',
      AuthErrorType.unknown =>
        'Something went wrong. Please try again later.',
    };
  }
}
