import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication persistence boundary — no UI concerns.
abstract class AuthRepository {
  Stream<User?> authStateChanges();

  User? get currentUser;

  bool get isSignedIn;

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<UserCredential> signInWithGoogle();

  Future<UserCredential> signInWithApple();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> sendEmailVerification();

  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> deleteAccount();
}
