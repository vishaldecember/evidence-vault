import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JourneyEvidenceThumbnail', () {
    final item = WorkspaceEvidenceItem(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      title: 'Photo Evidence',
      lastPreservedAt: DateTime(2026, 7, 28, 9),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
    );

    testWidgets('selected state animates scale increase', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JourneyEvidenceThumbnail(
              item: item,
              isSelected: false,
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JourneyEvidenceThumbnail(
              item: item,
              isSelected: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(JourneyEvidenceThumbnail.selectionDuration);

      expect(find.byType(AnimatedScale), findsOneWidget);
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.04);
    });

    testWidgets('tap still invokes callback while selection is visual only',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JourneyEvidenceThumbnail(
              item: item,
              isSelected: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(JourneyEvidenceThumbnail));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
