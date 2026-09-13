import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../controllers/workspace_session.dart';
import '../../diagnostics/sprint6c_file_trace.dart';
import '../../providers/authentication_state_provider.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../repositories/auth/firebase_auth_repository.dart';
import '../../services/auth/auth_error_mapper.dart';
import '../../services/auth/auth_exception.dart';
import '../../services/auth/firebase_bootstrap.dart';
import '../../services/storage/durable_attach_intent_store.dart';
import '../../services/storage/saf_staging_bridge.dart';
import '../../services/user_session_service.dart';

/// High-level authentication API — isolated from UI screens.
class AuthenticationService {
  AuthenticationService({
    AuthRepository? authRepository,
    this._stateProvider,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository();

  static AuthenticationService _instance = AuthenticationService();

  static AuthenticationService get instance => _instance;

  /// Wires session refresh into [AuthenticationStateProvider] after bootstrap.
  static void configure({
    AuthenticationStateProvider? stateProvider,
    AuthRepository? authRepository,
  }) {
    _instance = AuthenticationService(
      stateProvider: stateProvider,
      authRepository:
          authRepository ?? stateProvider?.authRepository,
    );
  }

  final AuthRepository _authRepository;
  final AuthenticationStateProvider? _stateProvider;

  AuthRepository get repository => _authRepository;

  /// Currently signed-in Firebase user, or null.
  User? get currentUser => _authRepository.currentUser;

  /// Emits on sign-in, sign-out, and restored sessions.
  Stream<User?> authStateChanges() => _authRepository.authStateChanges();

  void _ensureFirebaseAvailable() {
    if (!FirebaseBootstrap.isAvailable) {
      throw const AuthException(
        type: AuthErrorType.firebaseUnavailable,
        message:
            'Authentication is temporarily unavailable. Please try again later.',
      );
    }
  }

  /// Registers a new email/password account.
  /// Preferred name is collected after authentication on [WelcomeNameScreen].
  Future<void> register({
    String name = '',
    required String email,
    required String password,
  }) =>
      createAccount(name: name, email: email, password: password);

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    _ensureFirebaseAvailable();

    try {
      final credential = await _authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        final trimmedName = name.trim();
        if (trimmedName.isNotEmpty) {
          await user.updateDisplayName(trimmedName);
          await user.reload();
        }
        await _authRepository.sendEmailVerification();
      }

      _syncSessionFromFirebaseUser(_authRepository.currentUser);
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }

  /// Saves preferred name to Firebase Auth profile + local session.
  Future<void> updatePreferredName(String name) async {
    _ensureFirebaseAvailable();

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AuthException(
        type: AuthErrorType.unknown,
        message: 'Please enter your name',
      );
    }

    try {
      final user = _authRepository.currentUser;
      if (user == null) {
        throw const AuthException(
          type: AuthErrorType.unknown,
          message: 'No signed-in account to update.',
        );
      }

      await user.updateDisplayName(trimmed);
      await user.reload();
      _syncSessionFromFirebaseUser(_authRepository.currentUser);
      _stateProvider?.notifyProfileUpdated();
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _ensureFirebaseAvailable();

    try {
      await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _syncSessionFromFirebaseUser(_authRepository.currentUser);
      // Ensure AuthGate rebuilds even if authStateChanges is briefly delayed.
      _stateProvider?.notifyProfileUpdated();
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }

  Future<void> reauthenticate({
    required String email,
    required String password,
  }) async {
    _ensureFirebaseAvailable();

    try {
      await _authRepository.reauthenticateWithPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    _ensureFirebaseAvailable();

    try {
      await _authRepository.sendPasswordResetEmail(email: email);
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }

  Future<void> signInWithGoogle() async {
    _ensureFirebaseAvailable();

    try {
      await _authRepository.signInWithGoogle();
      _syncSessionFromFirebaseUser(_authRepository.currentUser);
      _stateProvider?.notifyProfileUpdated();
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }

  Future<void> signInWithApple() async {
    _ensureFirebaseAvailable();

    try {
      await _authRepository.signInWithApple();
      _syncSessionFromFirebaseUser(_authRepository.currentUser);
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }

  Future<void> signOut() async {
    Sprint6cFileTrace.auth('AuthenticationService.signOut START');
    // Sign-out policy: clear session, attach intent, and SAF staging.
    // Do NOT delete evidence_cache / incident library — the same user may
    // sign back in on this device. Destructive wipe is Clear Vault / Delete
    // Account only.
    // Remember incident + flush cloud while auth credentials still valid.
    try {
      await WorkspaceSession.instance.flushBeforeSignOut();
    } catch (error) {
      debugPrint('[Auth] pre-sign-out flush failed: $error');
    }

    if (FirebaseBootstrap.isAvailable) {
      try {
        await _authRepository.signOut();
      } catch (error) {
        throw AuthErrorMapper.fromObject(error);
      }
    }

    final userId = UserSessionService.account?.userId ?? '';
    if (userId.isNotEmpty) {
      await DurableAttachIntentStore.clearPendingIntent(
        userId: userId,
        reason: 'sign_out',
      );
    }
    await SafStagingBridge.discardAll();
    UserSessionService.signOut();
    WorkspaceSession.instance.onSignedOut();
    _stateProvider?.refreshFromSession();
    Sprint6cFileTrace.auth('AuthenticationService.signOut DONE');
  }

  /// Deletes the Firebase Auth user when available.
  ///
  /// Firestore/Storage wipe is attempted earlier by
  /// [InvestigationDataDeletionService]. Auth deletion does not by itself
  /// cascade Cloud data.
  Future<void> deleteFirebaseAccount() async {
    if (!FirebaseBootstrap.isAvailable) {
      return;
    }

    try {
      await _authRepository.deleteAccount();
    } catch (error) {
      throw AuthErrorMapper.fromObject(error);
    }
  }

  void _syncSessionFromFirebaseUser(User? user) {
    if (user == null) {
      UserSessionService.signOut();
      return;
    }

    UserSessionService.establishSession(
      userId: user.uid,
      email: user.email ?? '',
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Investigator'),
    );
  }
}
