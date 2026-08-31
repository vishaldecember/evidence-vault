/// User-facing authentication errors — never expose raw Firebase messages.
enum AuthErrorType {
  invalidEmail,
  emailAlreadyInUse,
  wrongPassword,
  weakPassword,
  userNotFound,
  tooManyRequests,
  networkUnavailable,
  userDisabled,
  operationNotAllowed,
  requiresRecentLogin,
  appleSignInUnavailable,
  googleSignInCancelled,
  firebaseUnavailable,
  unknown,
}

class AuthException implements Exception {
  const AuthException({
    required this.type,
    required this.message,
  });

  final AuthErrorType type;
  final String message;

  @override
  String toString() => message;
}
