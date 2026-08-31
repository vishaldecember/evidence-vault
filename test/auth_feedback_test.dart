import 'package:evidence_vault/constants/app_notifications.dart';
import 'package:evidence_vault/services/auth/auth_exception.dart';
import 'package:evidence_vault/utils/auth_form_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('email already in use shows Go to Sign In action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  AuthFormHelpers.handleAuthError(
                    context,
                    const AuthException(
                      type: AuthErrorType.emailAlreadyInUse,
                      message:
                          'An account with this email already exists. Try signing in instead.',
                    ),
                  );
                },
                child: const Text('Trigger'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();

    expect(
      find.text('An account with this email already exists.'),
      findsOneWidget,
    );
    expect(find.text('Go to Sign In'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    // Drain the auto-hide Timer so the test binding has no pending timers.
    await tester.pump(AppNotifications.authBannerDuration);
    await tester.pumpAndSettle();
  });
}
