import 'package:firebase_auth/firebase_auth.dart';

import 'auth/auth_exception.dart';
import 'auth/authentication_service.dart';

export 'auth/auth_exception.dart';

/// Authentication facade for UI and session consumers.
///
/// Delegates to [AuthenticationService]. Isolated from investigation logic.
/// No Firestore — identity only (MVP-0.9.3.3A).
abstract final class AuthService {
  static AuthenticationService get _auth => AuthenticationService.instance;

  /// Creates a new email/password account.
  static Future<void> register({
    String name = '',
    required String email,
    required String password,
  }) =>
      _auth.register(name: name, email: email, password: password);

  /// Backward-compatible alias for [register].
  static Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) =>
      register(name: name, email: email, password: password);

  static Future<void> signIn({
    required String email,
    required String password,
  }) =>
      _auth.signIn(email: email, password: password);

  static Future<void> reauthenticate({
    required String email,
    required String password,
  }) =>
      _auth.reauthenticate(email: email, password: password);

  static Future<void> signOut() => _auth.signOut();

  static Future<void> sendPasswordResetEmail({
    required String email,
  }) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Optional — Google Sign-In remains available but is not required for MVP-0.9.3.3A.
  static Future<void> signInWithGoogle() => _auth.signInWithGoogle();

  static Future<void> signInWithApple() => _auth.signInWithApple();

  static Future<void> updatePreferredName(String name) =>
      _auth.updatePreferredName(name);

  /// Currently signed-in Firebase user, or null.
  static User? get currentUser => _auth.currentUser;

  /// Emits on sign-in, sign-out, and restored sessions.
  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static String messageFor(AuthException error) => error.message;
}
