import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evidence_vault/screens/main_shell_screen.dart';

void main() {
  testWidgets('Home capture buttons expose accessible button semantics', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    final photoSemantics = tester.getSemantics(find.text('Photo'));
    expect(photoSemantics.label, 'Capture photo evidence');
    expect(photoSemantics.flagsCollection.isButton, isTrue);

    final voiceSemantics = tester.getSemantics(find.text('Voice'));
    expect(voiceSemantics.label, 'Record voice evidence');
    expect(voiceSemantics.flagsCollection.isButton, isTrue);
  });
}
