import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/auth/auth_error_mapper.dart';
import '../../services/auth/auth_exception.dart';
import 'auth_repository.dart';

/// Firebase-backed [AuthRepository] implementation.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  bool get isSignedIn => currentUser != null;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _guard(() => _firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ));
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _guard(() => _firebaseAuth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ));
  }

  static const _googleScopes = ['email', 'profile'];

  @override
  Future<UserCredential> signInWithGoogle() async {
    return _guard(() async {
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate(
          scopeHint: _googleScopes,
        );
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) {
          throw const AuthException(
            type: AuthErrorType.googleSignInCancelled,
            message: 'Google sign-in was cancelled.',
          );
        }
        rethrow;
      }

      final googleAuth = googleUser.authentication;
      String? accessToken = (await googleUser.authorizationClient
              .authorizationForScopes(_googleScopes))
          ?.accessToken;

      accessToken ??= (await googleUser.authorizationClient
              .authorizeScopes(_googleScopes))
          .accessToken;

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      return _firebaseAuth.signInWithCredential(credential);
    });
  }

  @override
  Future<UserCredential> signInWithApple() async {
    throw const AuthException(
      type: AuthErrorType.appleSignInUnavailable,
      message: 'Sign in with Apple is coming soon.',
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _guard(() => _firebaseAuth.sendPasswordResetEmail(
          email: email.trim(),
        ));
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException(
        type: AuthErrorType.unknown,
        message: 'No signed-in account to verify.',
      );
    }

    await _guard(user.sendEmailVerification);
  }

  @override
  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException(
        type: AuthErrorType.unknown,
        message: 'No signed-in account to verify.',
      );
    }

    await _guard(() async {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    });
  }

  @override
  Future<void> signOut() async {
    await _guard(() async {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
    });
  }

  @override
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    await _guard(() async {
      await user.delete();
      await _googleSignIn.signOut();
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthErrorMapper.fromFirebaseAuthException(error);
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }
}
