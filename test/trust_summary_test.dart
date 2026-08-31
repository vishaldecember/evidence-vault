import 'package:evidence_vault/models/evidence_record_model.dart';
import 'package:evidence_vault/models/trust_summary_model.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/trust/trust_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrustSummaryModel', () {
    test('includes only trust-focused rows', () {
      final evidence = WorkspaceEvidenceItem(
        id: 'photo-1',
        kind: WorkspaceEvidenceKind.image,
        title: 'Photo Evidence',
        lastPreservedAt: DateTime(2026, 7, 18, 14, 23, 41),
        integrityVerified: true,
        verification: VerificationFactory.initial(),
      );
      final record = EvidenceRecordModel.fromWorkspace(
        evidence: evidence,
        allItems: [evidence],
        relationships: const [],
      );

      final summary = TrustSummaryModel.fromRecord(record);

      expect(summary.entries.map((entry) => entry.label), [
        'Independent verification',
      ]);
      expect(summary.entries.single.value, 'Not performed');
    });
  });

  group('TrustSummarySection', () {
    testWidgets('shows simplified trust summary without editable fields',
        (tester) async {
      final evidence = WorkspaceEvidenceItem(
        id: 'photo-1',
        kind: WorkspaceEvidenceKind.image,
        title: 'Photo Evidence',
        lastPreservedAt: DateTime(2026, 7, 18, 14, 23, 41),
        integrityVerified: true,
        verification: VerificationFactory.initial(),
      );
      final record = EvidenceRecordModel.fromWorkspace(
        evidence: evidence,
        allItems: [evidence],
        relationships: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrustSummarySection(record: record),
          ),
        ),
      );

      expect(find.text('Integrity'), findsOneWidget);
      expect(find.text('Independent verification'), findsOneWidget);
      expect(find.text('Not performed'), findsOneWidget);
      expect(find.text('Original Preserved'), findsNothing);
      expect(find.text('Verified'), findsNothing);
      expect(find.text('Verified At'), findsNothing);
      expect(find.text('18 Jul 2026 • 14:23:41'), findsNothing);
      expect(find.text('Captured On'), findsNothing);
      expect(find.text('Location'), findsNothing);
      expect(find.text('Verification Method'), findsNothing);
      expect(find.text('Verification Notes'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
