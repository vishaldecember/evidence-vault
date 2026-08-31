import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/workspace_session.dart';
import '../../diagnostics/sprint6c_file_trace.dart';
import '../../navigation/app_navigator.dart';
import '../../providers/authentication_state_provider.dart';
import '../../screens/main_shell_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/welcome_name_screen.dart';
import '../../services/storage/file_attach_flow.dart';
import '../../services/storage/file_attach_recovery.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';

/// Routes users based on restored authentication state.
///
/// Once [MainShellScreen] has been shown, it stays mounted during session
/// restore / file-picker resume so Capture Workspace is never torn down to Home.
///
/// Cold-start File attach recovery keeps this gate's restore spinner until
/// the originating Workspace is on the navigator stack, so Home is not the
/// first visible route after Android recreates the process.
///
/// Native file pickers (SAF) can pause the activity long enough that a timed
/// "auth loss grace" would expire mid-pick. Tear-down happens only when the
/// local [UserSessionService] is cleared (explicit sign-out), never on a
/// transient Firebase `authStateChanges(null)` while the shell is latched.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authState,
  });

  final AuthenticationStateProvider authState;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _wasAuthenticated = false;

  /// After first MainShell paint, keep it through restore/picker resume.
  bool _mainShellReady = false;

  /// Session restore is not enough: pending File attach recovery must push
  /// Workspace before MainShell/Home is first painted.
  bool _attachRecoverySettled = false;
  bool _attachRecoveryScheduled = false;

  @override
  void initState() {
    super.initState();
    _wasAuthenticated = widget.authState.isAuthenticated;
    widget.authState.addListener(_onAuthStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kickOffRestoreIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authState != widget.authState) {
      oldWidget.authState.removeListener(_onAuthStateChanged);
      widget.authState.addListener(_onAuthStateChanged);
      _wasAuthenticated = widget.authState.isAuthenticated;
    }
  }

  @override
  void dispose() {
    Sprint6cFileTrace.auth('AuthGate DISPOSE latch=$_mainShellReady');
    widget.authState.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final isAuth = widget.authState.isAuthenticated;
    Sprint6cFileTrace.auth(
      'onAuth isAuth=$isAuth latch=$_mainShellReady '
      'wasAuth=$_wasAuthenticated localSignedIn=${UserSessionService.isSignedIn}',
    );

    if (isAuth) {
      // Real cold login only — never pop Capture routes after picker resume.
      if (!_wasAuthenticated && !_mainShellReady) {
        _clearAuthStackIfAuthenticated();
      }
      _kickOffRestoreIfNeeded();
      _wasAuthenticated = true;
      return;
    }

    // Unauthenticated emission from Firebase / provider.
    if (!widget.authState.isReady) {
      _wasAuthenticated = false;
      return;
    }

    if (_mainShellReady) {
      // File-picker / activity resume can emit null for minutes while the
      // user browses SAF. Local session still present ⇒ NOT a logout.
      if (UserSessionService.isSignedIn) {
        Sprint6cFileTrace.auth(
          'IGNORE transient unauth while shell latched (local session present)',
        );
        return;
      }

      // Explicit sign-out cleared [UserSessionService] before notifying.
      Sprint6cFileTrace.auth('CLEAR latch — local session gone (explicit sign-out)');
      setState(() {
        _mainShellReady = false;
        _attachRecoverySettled = false;
        _attachRecoveryScheduled = false;
        _wasAuthenticated = false;
      });
      // [AuthenticationService.signOut] already called onSignedOut().
      return;
    }

    _wasAuthenticated = false;
    WorkspaceSession.instance.onSignedOut();
  }

  void _kickOffRestoreIfNeeded() {
    if (!widget.authState.isReady || !widget.authState.isAuthenticated) {
      return;
    }
    if (widget.authState.needsPreferredName) {
      return;
    }
    if (WorkspaceSession.instance.isCloudRestored ||
        WorkspaceSession.instance.isRestoring) {
      return;
    }
    Sprint6cFileTrace.session('kickOff restoreForSignedInUser');
    WorkspaceSession.instance.restoreForSignedInUser();
  }

  void _scheduleAttachRecoveryGate() {
    if (_attachRecoverySettled || _attachRecoveryScheduled) {
      return;
    }
    _attachRecoveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_settleAttachRecovery());
    });
  }

  /// Holds the existing restore spinner until pending File attach recovery
  /// has pushed Workspace (or confirmed there is nothing to recover).
  Future<void> _settleAttachRecovery() async {
    var pending = false;
    FileAttachRecoveryOutcome? outcome;
    try {
      pending = await FileAttachRecovery.hasPendingRecoveryForCurrentUser();
      if (pending && mounted) {
        Sprint6cFileTrace.auth(
          'defer MainShell until attach recovery navigation',
        );
        outcome = await FileAttachRecovery.recoverIfNeeded();
      }
    } catch (error) {
      Sprint6cFileTrace.auth('attach recovery gate failed: $error');
      pending = false;
    }

    if (!mounted) {
      return;
    }

    final nav = appNavigatorKey.currentState;
    final workspaceReady = FileAttachFlow.workspaceRouteVisible ||
        (nav?.canPop() ?? false);
    final terminal = outcome == FileAttachRecoveryOutcome.none ||
        outcome == FileAttachRecoveryOutcome.abandoned ||
        outcome == FileAttachRecoveryOutcome.persistedFromNative ||
        outcome == FileAttachRecoveryOutcome.restoredReselectRequired;
    final mayReleaseHome = !pending || workspaceReady || terminal;

    if (!mayReleaseHome) {
      Sprint6cFileTrace.auth(
        'keep MainShell gated — pending recovery not terminal '
        'outcome=$outcome workspaceReady=$workspaceReady',
      );
      _attachRecoveryScheduled = false;
      return;
    }

    setState(() {
      _attachRecoverySettled = true;
      if (widget.authState.isAuthenticated &&
          UserSessionService.isSignedIn &&
          !widget.authState.needsPreferredName) {
        Sprint6cFileTrace.auth('latch → true (attach recovery settled)');
        _mainShellReady = true;
      }
    });
  }

  void _clearAuthStackIfAuthenticated() {
    if (!widget.authState.isAuthenticated || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.authState.isAuthenticated) return;
      // Never wipe Capture / Workspace routes once the shell is latched.
      if (_mainShellReady) return;
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      ScaffoldMessenger.maybeOf(context)?.clearMaterialBanners();
      final navigator = Navigator.maybeOf(context);
      if (navigator == null) return;
      if (navigator.canPop()) {
        Sprint6cFileTrace.nav(
          'AuthGate popUntil(isFirst) — WOULD SURFACE HOME if Workspace pushed',
        );
        navigator.popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.authState,
        WorkspaceSession.instance,
      ]),
      builder: (context, _) {
        // Latch wins: keep MainShell (and its Navigator stack) through
        // file-picker resume even if auth briefly reports signed-out.
        if (_mainShellReady) {
          return const MainShellScreen();
        }

        if (!widget.authState.isReady) {
          Sprint6cFileTrace.auth('build → loading (auth not ready)');
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (widget.authState.isAuthenticated) {
          if (widget.authState.needsPreferredName) {
            return const WelcomeNameScreen();
          }

          final restored = WorkspaceSession.instance.isCloudRestored;
          final restoring = WorkspaceSession.instance.isRestoring;
          if (!restored || restoring) {
            Sprint6cFileTrace.auth(
              'build → restore spinner restored=$restored restoring=$restoring',
            );
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (!_attachRecoverySettled) {
            _scheduleAttachRecoveryGate();
            Sprint6cFileTrace.auth('build → attach recovery gate spinner');
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // First settled paint of the shell — latch so picker resume is safe.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !_mainShellReady &&
                widget.authState.isAuthenticated) {
              Sprint6cFileTrace.auth('latch → true (first settled paint)');
              setState(() => _mainShellReady = true);
            }
          });
          return const MainShellScreen();
        }

        Sprint6cFileTrace.auth('build → SplashScreen (unauthenticated)');
        return const SplashScreen();
      },
    );
  }
}
