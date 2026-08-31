import 'package:evidence_vault/models/evidence_record_model.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/context/context_inline_composer.dart';
import 'package:evidence_vault/widgets/context/context_reminder_drawer.dart';
import 'package:evidence_vault/widgets/context/context_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _photo({required String id}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Photo Evidence',
    lastPreservedAt: DateTime(2026, 8, 1),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

WorkspaceEvidenceItem _contextItem({
  required String id,
  required String parentId,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.note,
    title: 'Context — Written Note',
    lastPreservedAt: DateTime(2026, 8, 1),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    isContextual: true,
    relatedEvidenceIds: {parentId},
    notePreview: 'Witness saw the incident.',
  );
}

EvidenceRecordModel _recordFor({
  required WorkspaceEvidenceItem evidence,
  required List<WorkspaceEvidenceItem> allItems,
  List<EvidenceRelationship> relationships = const [],
}) {
  return EvidenceRecordModel.fromWorkspace(
    evidence: evidence,
    allItems: allItems,
    relationships: relationships,
  );
}

void main() {
  Widget buildCard({
    required EvidenceRecordModel record,
    required List<WorkspaceEvidenceItem> items,
    List<EvidenceRelationship> relationships = const [],
    ValueChanged<String>? onContextTextSubmitted,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ContextSectionCard(
          record: record,
          allItems: items,
          relationships: relationships,
          onContextTextSubmitted:
              onContextTextSubmitted ?? (_) {},
        ),
      ),
    );
  }

  group('Context reminder UX', () {
    testWidgets('shows orange Add Context reminder when enrichment is missing',
        (tester) async {
      final photo = _photo(id: 'photo-1');
      final record = _recordFor(evidence: photo, allItems: [photo]);

      await tester.pumpWidget(buildCard(record: record, items: [photo]));
      await tester.pumpAndSettle();

      expect(find.text(ContextReminderDrawer.reminderLabel), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('expanding reminder focuses editable context field', (tester) async {
      final photo = _photo(id: 'photo-1');
      final record = _recordFor(evidence: photo, allItems: [photo]);

      await tester.pumpWidget(buildCard(record: record, items: [photo]));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ContextReminderDrawer.reminderLabel));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(ContextInlineComposer.hintText), findsOneWidget);
    });

    testWidgets('reminder remains visible when collapsed again', (tester) async {
      final photo = _photo(id: 'photo-1');
      final record = _recordFor(evidence: photo, allItems: [photo]);

      await tester.pumpWidget(buildCard(record: record, items: [photo]));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ContextReminderDrawer.reminderLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Collapse context section'));
      await tester.pumpAndSettle();

      expect(find.text(ContextReminderDrawer.reminderLabel), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('submitting context text removes reminder', (tester) async {
      final photo = _photo(id: 'photo-1');
      var items = <WorkspaceEvidenceItem>[photo];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            final record = _recordFor(evidence: photo, allItems: items);
            return MaterialApp(
              home: Scaffold(
                body: ContextSectionCard(
                  record: record,
                  allItems: items,
                  relationships: const [],
                  onContextTextSubmitted: (_) {
                    setState(() {
                      items = [
                        photo,
                        _contextItem(id: 'ctx-1', parentId: 'photo-1'),
                      ];
                    });
                  },
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(ContextReminderDrawer.reminderLabel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Important detail');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text(ContextReminderDrawer.reminderLabel), findsNothing);
      expect(find.text('Your observations'), findsOneWidget);
      expect(find.text('Context Enriched'), findsNothing);
    });

    testWidgets('reminder remains when only a RELATED link exists',
        (tester) async {
      final photo = _photo(id: 'photo-1');
      final file = WorkspaceEvidenceItem(
        id: 'file-1',
        kind: WorkspaceEvidenceKind.attachment,
        title: 'Attachment',
        lastPreservedAt: DateTime(2026, 8, 1),
        integrityVerified: true,
        verification: VerificationFactory.initial(),
      );
      final relationships = [
        EvidenceRelationship(
          id: 'rel-1',
          sourceEvidenceId: 'photo-1',
          targetEvidenceId: 'file-1',
          type: RelationshipType.relatedTo,
          createdAt: DateTime(2026, 8, 1),
        ),
      ];
      final items = [photo, file];
      final record = _recordFor(
        evidence: photo,
        allItems: items,
        relationships: relationships,
      );

      await tester.pumpWidget(
        buildCard(
          record: record,
          items: items,
          relationships: relationships,
        ),
      );
      await tester.pumpAndSettle();

      // RELATED is linkage, not recorded context (Step 4C / 6C).
      expect(find.text(ContextReminderDrawer.reminderLabel), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
