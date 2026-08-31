import 'package:evidence_vault/providers/authentication_state_provider.dart';
import 'package:evidence_vault/services/auth/authentication_service.dart';
import 'package:evidence_vault/services/auth/firebase_bootstrap.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/services/storage/file_attach_recovery.dart';
import 'package:evidence_vault/widgets/auth/auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';

void main() {
  setUp(() {
    FirebaseBootstrap.resetForTests();
    UserSessionService.resetForTests();
    SharedPreferences.setMockInitialValues({});
    FileAttachRecovery.debugReset();
  });

  tearDown(() {
    UserSessionService.resetForTests();
    FirebaseBootstrap.resetForTests();
  });

  group('AuthService API (MVP-0.9.3.3A)', () {
    test('exposes register, signIn, signOut, currentUser, authStateChanges', () {
      final repository = FakeAuthRepository();
      AuthenticationService.configure(authRepository: repository);
      final auth = AuthenticationService.instance;

      expect(auth.currentUser, isNull);
      expect(auth.authStateChanges(), isA<Stream<User?>>());
      // Method surface — callable without Firebase when unavailable throws AuthException.
      expect(auth.register, isA<Function>());
      expect(auth.signIn, isA<Function>());
      expect(auth.signOut, isA<Function>());
    });

    test('signOut clears local session for AuthGate', () async {
      final repository = FakeAuthRepository();
      final provider = AuthenticationStateProvider(authRepository: repository);
      addTearDown(provider.dispose);

      AuthenticationService.configure(
        stateProvider: provider,
        authRepository: repository,
      );

      UserSessionService.establishSession(
        userId: 'uid-test',
        email: 'session@example.com',
        name: 'Session User',
      );
      provider.refreshFromSession();
      expect(provider.isAuthenticated, isTrue);

      await AuthenticationService.instance.signOut();
      expect(UserSessionService.isSignedIn, isFalse);
      expect(provider.isAuthenticated, isFalse);
    });
  });

  group('AuthGate session routing', () {
    testWidgets('shows authentication entry when signed out', (tester) async {
      final authState = AuthenticationStateProvider(
        authRepository: FakeAuthRepository(),
      );
      addTearDown(authState.dispose);
      authState.setAuthenticatedForTests(false);

      await tester.pumpWidget(
        MaterialApp(home: AuthGate(authState: authState)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
    });

    testWidgets('enters main investigation shell when authenticated',
        (tester) async {
      final authState = AuthenticationStateProvider(
        authRepository: FakeAuthRepository(),
      );
      addTearDown(authState.dispose);
      UserSessionService.establishSession(
        userId: 'uid-1',
        email: 'user@example.com',
        name: 'User',
      );
      authState.setAuthenticatedForTests(true);

      await tester.pumpWidget(
        MaterialApp(home: AuthGate(authState: authState)),
      );
      await tester.pumpAndSettle();

      // MainShellScreen bottom destinations.
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Create Account'), findsNothing);
    });

    testWidgets('sign-out returns to authentication entry', (tester) async {
      final repository = FakeAuthRepository();
      final authState = AuthenticationStateProvider(authRepository: repository);
      addTearDown(authState.dispose);

      AuthenticationService.configure(
        stateProvider: authState,
        authRepository: repository,
      );

      UserSessionService.establishSession(
        userId: 'uid-1',
        email: 'user@example.com',
        name: 'User',
      );
      authState.setAuthenticatedForTests(true);

      await tester.pumpWidget(
        MaterialApp(home: AuthGate(authState: authState)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create Account'), findsNothing);

      await tester.runAsync(() async {
        await AuthenticationService.instance.signOut();
      });
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
    });
  });
}
