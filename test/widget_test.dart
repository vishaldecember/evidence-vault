import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('EvidenceVaultApp renders splash screen', (WidgetTester tester) async {
    await pumpEvidenceVaultApp(tester);

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}