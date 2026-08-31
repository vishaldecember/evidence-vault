import 'package:evidence_vault/services/auth/auth_error_mapper.dart';
import 'package:evidence_vault/services/auth/auth_exception.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthErrorMapper', () {
    test('maps email-already-in-use to friendly message', () {
      final error = AuthErrorMapper.fromFirebaseAuthException(
        FirebaseAuthException(code: 'email-already-in-use'),
      );

      expect(error.type, AuthErrorType.emailAlreadyInUse);
      expect(error.message, contains('already exists'));
      expect(error.message, isNot(contains('email-already-in-use')));
    });

    test('maps wrong-password to friendly message', () {
      final error = AuthErrorMapper.fromFirebaseAuthException(
        FirebaseAuthException(code: 'wrong-password'),
      );

      expect(error.type, AuthErrorType.wrongPassword);
      expect(error.message, contains('Incorrect email or password'));
    });

    test('maps weak-password to friendly message', () {
      final error = AuthErrorMapper.fromFirebaseAuthException(
        FirebaseAuthException(code: 'weak-password'),
      );

      expect(error.type, AuthErrorType.weakPassword);
      expect(error.message, contains('stronger password'));
    });

    test('maps network-request-failed to offline guidance', () {
      final error = AuthErrorMapper.fromFirebaseAuthException(
        FirebaseAuthException(code: 'network-request-failed'),
      );

      expect(error.type, AuthErrorType.networkUnavailable);
      expect(error.message, contains('You’re offline'));
      expect(error.message, contains('Airplane Mode'));
    });

    test('maps too-many-requests to friendly message', () {
      final error = AuthErrorMapper.fromFirebaseAuthException(
        FirebaseAuthException(code: 'too-many-requests'),
      );

      expect(error.type, AuthErrorType.tooManyRequests);
      expect(error.message, contains('Too many attempts'));
    });

    test('preserves AuthException instances', () {
      const original = AuthException(
        type: AuthErrorType.googleSignInCancelled,
        message: 'Google sign-in was cancelled.',
      );

      expect(AuthErrorMapper.fromObject(original), same(original));
    });
  });
}
