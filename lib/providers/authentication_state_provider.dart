import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/sprint6c_file_trace.dart';
import '../repositories/auth/auth_repository.dart';
import '../repositories/auth/firebase_auth_repository.dart';
import '../services/auth/firebase_bootstrap.dart';
import '../services/user_session_service.dart';

/// Observes authentication state and syncs [UserSessionService].
class AuthenticationStateProvider extends ChangeNotifier {
  AuthenticationStateProvider({
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository() {
    _listenToAuthChanges();
  }

  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authSubscription;

  bool _isReady = false;
  bool _isAuthenticated = false;

  bool get isReady => _isReady;
  bool get isAuthenticated => _isAuthenticated;
  bool get isFirebaseAvailable => FirebaseBootstrap.isAvailable;

  /// True when a freshly created account still needs a preferred name.
  ///
  /// Returning users enter [MainShellScreen] immediately even if Firebase
  /// `displayName` is empty — name collection is for first-time registration.
  bool get needsPreferredName {
    if (!_isAuthenticated || !FirebaseBootstrap.isAvailable) {
      return false;
    }

    final user = _authRepository.currentUser;
    if (user == null) return false;

    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return false;

    final createdAt = user.metadata.creationTime;
    final lastSignIn = user.metadata.lastSignInTime;
    if (createdAt == null || lastSignIn == null) {
      return true;
    }

    // Fresh registration: creation and first sign-in are nearly simultaneous.
    final isFreshRegistration =
        lastSignIn.difference(createdAt).abs() <= const Duration(minutes: 2);
    return isFreshRegistration;
  }

  AuthRepository get authRepository => _authRepository;

  void _listenToAuthChanges() {
    if (!FirebaseBootstrap.isAvailable) {
      _isReady = true;
      _isAuthenticated = UserSessionService.isSignedIn;
      notifyListeners();
      return;
    }

    _authSubscription = _authRepository.authStateChanges().listen((user) {
      Sprint6cFileTrace.auth(
        'authStateChanges uid=${user?.uid ?? 'NULL'} '
        'localBefore=${UserSessionService.isSignedIn}',
      );
      _applyUser(user);
      _isReady = true;
      notifyListeners();
    });

    // Immediate sync for restored Firebase session on cold start.
    _applyUser(_authRepository.currentUser);
    _isReady = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _applyUser(User? user) {
    if (user == null) {
      Sprint6cFileTrace.auth(
        '_applyUser(null) → isAuthenticated=false '
        '(UserSessionService NOT cleared) '
        'localSignedIn=${UserSessionService.isSignedIn}',
      );
      _isAuthenticated = false;
      // Do NOT clear [UserSessionService] here. Firebase can emit null during
      // Android SAF / file-picker activity resume; wiping the local session
      // would look like logout and bounce Capture Workspace to Home.
      // Explicit sign-out clears UserSessionService before refreshFromSession.
      return;
    }

    Sprint6cFileTrace.auth('_applyUser(uid=${user.uid}) → authenticated');
    _isAuthenticated = true;
    UserSessionService.establishSession(
      userId: user.uid,
      email: user.email ?? '',
      name: _displayNameFor(user),
    );
  }

  String _displayNameFor(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Investigator';
  }

  /// Called after bootstrap when Firebase was unavailable at startup.
  void refreshFromSession() {
    Sprint6cFileTrace.auth(
      'refreshFromSession localSignedIn=${UserSessionService.isSignedIn}',
    );
    _isAuthenticated = UserSessionService.isSignedIn;
    notifyListeners();
  }

  /// Re-sync session after profile fields (e.g. preferred name) change.
  void notifyProfileUpdated() {
    _applyUser(_authRepository.currentUser);
    notifyListeners();
  }

  @visibleForTesting
  void setAuthenticatedForTests(bool value) {
    _isAuthenticated = value;
    _isReady = true;
    notifyListeners();
  }
}
