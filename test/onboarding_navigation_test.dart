import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) => pumpEvidenceVaultApp(tester);

  testWidgets('Splash shows onboarding actions', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(
      find.textContaining('Have you ever wished you had'),
      findsOneWidget,
    );
  });

  testWidgets('Create Account navigates from Splash', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your vault'), findsOneWidget);
    expect(find.text('Capture. Organize. Protect.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Full name'), findsNothing);
    expect(find.text('Missing:'), findsNothing);
  });

  testWidgets('Login navigates from Splash', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('Login screen links to Create Vault', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create Vault'));
    await tester.tap(find.text('Create Vault'));
    await tester.pumpAndSettle();

    expect(find.text('Create your vault'), findsOneWidget);
  });

  testWidgets('Login screen opens Forgot Password', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);
  });

  testWidgets('Forgot Password validates email before submit',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
  });
}
