import 'package:evidence_vault/models/evidence_artifact_model.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/evidence_record_screen.dart';
import 'package:evidence_vault/widgets/context/context_inline_composer.dart';
import 'package:evidence_vault/widgets/evidence_record/evidence_record_preview.dart';
import 'package:evidence_vault/widgets/linked_evidence/linked_evidence_section.dart';
import 'package:evidence_vault/widgets/linked_evidence/linked_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28, 14, 23),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

void main() {
  group('Evidence Record simplification (8.5.19)', () {
    test('preview height is type-adaptive and compact', () {
      expect(
        EvidenceRecordPreview.previewHeightFor(EvidenceArtifactType.photo),
        220,
      );
      expect(
        EvidenceRecordPreview.previewHeightFor(EvidenceArtifactType.note),
        140,
      );
      expect(
        EvidenceRecordPreview.previewHeightFor(EvidenceArtifactType.document),
        104,
      );
    });

    testWidgets('does not expose Link Existing Evidence actions', (tester) async {
      final photo = _item(id: 'photo');
      final video = _item(id: 'video', kind: WorkspaceEvidenceKind.video);

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceRecordScreen(
            evidenceId: 'photo',
            getItems: () => [photo, video],
            getRelationships: () => const [],
            onAddContext: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Link Existing Evidence'), findsNothing);
    });

    testWidgets('shows linked evidence as horizontal thumbnails', (tester) async {
      final photo = _item(id: 'photo');
      final video = _item(id: 'video', kind: WorkspaceEvidenceKind.video);
      final relationships = [
        EvidenceRelationship(
          id: 'rel-1',
          sourceEvidenceId: 'photo',
          targetEvidenceId: 'video',
          type: RelationshipType.relatedTo,
          createdAt: DateTime(2026, 7, 28),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceRecordScreen(
            evidenceId: 'photo',
            getItems: () => [photo, video],
            getRelationships: () => relationships,
            onAddContext: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinkedEvidenceSection), findsOneWidget);
      expect(find.byType(LinkedEvidenceThumbnail), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('context composer is always visible and editable', (tester) async {
      final photo = _item(id: 'photo');

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceRecordScreen(
            evidenceId: 'photo',
            getItems: () => [photo],
            getRelationships: () => const [],
            onAddContext: (_, _) {},
            onAddContextText: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(ContextInlineComposer.hintText), findsOneWidget);
    });

    testWidgets('verification section stays concise without metadata duplicates',
        (tester) async {
      final photo = _item(id: 'photo');

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceRecordScreen(
            evidenceId: 'photo',
            getItems: () => [photo],
            getRelationships: () => const [],
            onAddContext: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Integrity'), findsOneWidget);
      expect(find.text('Not performed'), findsOneWidget);
      expect(find.text('Original Preserved'), findsNothing);
      expect(find.text('Verified'), findsNothing);
      expect(find.text('Metadata'), findsNothing);
      expect(find.text('Moto G35 5G'), findsNothing);
      expect(find.text('4032 × 3024'), findsNothing);
      expect(find.text('248 KB'), findsNothing);
    });
  });
}
