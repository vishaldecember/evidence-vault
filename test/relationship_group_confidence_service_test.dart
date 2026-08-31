import 'package:evidence_vault/engines/enrichment_engine.dart';
import 'package:evidence_vault/models/connection_group_node.dart';
import 'package:evidence_vault/models/relationship_group.dart';
import 'package:evidence_vault/models/relationship_group_confidence.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/relationship_group_confidence_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  bool isContextual = false,
  Set<String> relatedEvidenceIds = const {},
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    isContextual: isContextual,
    relatedEvidenceIds: relatedEvidenceIds,
  );
}

ConnectionGroupNode _node({
  required List<WorkspaceEvidenceItem> captured,
  List<WorkspaceEvidenceItem> supporting = const [],
}) {
  return ConnectionGroupNode(
    group: RelationshipGroup(
      id: 'group-1',
      evidenceIds: [
        ...captured.map((item) => item.id),
        ...supporting.map((item) => item.id),
      ],
      type: RelationshipType.relatedTo,
      createdAt: DateTime(2026, 7, 28),
      colorIndex: 0,
    ),
    capturedEntries: [
      for (final item in captured)
        ConnectionGroupCapturedEntry(
          captured: item,
          supportingItems: supporting
              .where(
                (support) => support.relatedEvidenceIds.contains(item.id),
              )
              .toList(),
        ),
    ],
    standaloneSupporting: supporting
        .where((support) => support.relatedEvidenceIds.isEmpty)
        .toList(),
  );
}

void main() {
  group('RelationshipGroupConfidenceService', () {
    test('single photo group is low confidence', () {
      final photo = _item(id: 'photo');
      final node = _node(captured: [photo]);
      final context = EnrichmentContext(items: [photo], relationships: const []);

      expect(
        RelationshipGroupConfidenceService.compute(node, context),
        RelationshipGroupConfidence.low,
      );
    });

    test('photo and video without context is low confidence', () {
      final photo = _item(id: 'photo');
      final video = _item(id: 'video', kind: WorkspaceEvidenceKind.video);
      final node = _node(captured: [photo, video]);
      final context = EnrichmentContext(
        items: [photo, video],
        relationships: const [],
      );

      expect(
        RelationshipGroupConfidenceService.compute(node, context),
        RelationshipGroupConfidence.low,
      );
    });

    test('three types with context and partial enrichment is medium', () {
      final photo = _item(id: 'photo');
      final video = _item(id: 'video', kind: WorkspaceEvidenceKind.video);
      final contextNote = _item(
        id: 'context',
        kind: WorkspaceEvidenceKind.note,
        isContextual: true,
        relatedEvidenceIds: {'photo'},
      );
      final node = _node(
        captured: [photo, video],
        supporting: [contextNote],
      );
      final enrichmentContext = EnrichmentContext(
        items: [photo, video, contextNote],
        relationships: const [],
      );

      expect(
        RelationshipGroupConfidenceService.compute(node, enrichmentContext),
        RelationshipGroupConfidence.medium,
      );
    });

    test('rich multi-type group with supporting evidence is high', () {
      final photo = _item(id: 'photo');
      final video = _item(id: 'video', kind: WorkspaceEvidenceKind.video);
      final voice = _item(id: 'voice', kind: WorkspaceEvidenceKind.voice);
      final contextNote = _item(
        id: 'context',
        kind: WorkspaceEvidenceKind.note,
        isContextual: true,
        relatedEvidenceIds: {'photo', 'video', 'voice'},
      );
      final witness = _item(
        id: 'witness',
        kind: WorkspaceEvidenceKind.witness,
        relatedEvidenceIds: {'photo'},
      );
      final document = _item(
        id: 'pdf',
        kind: WorkspaceEvidenceKind.attachment,
        relatedEvidenceIds: {'video'},
      );
      final node = _node(
        captured: [photo, video, voice],
        supporting: [contextNote, witness, document],
      );
      final enrichmentContext = EnrichmentContext(
        items: [photo, video, voice, contextNote, witness, document],
        relationships: const [],
      );

      expect(
        RelationshipGroupConfidenceService.compute(node, enrichmentContext),
        RelationshipGroupConfidence.high,
      );
    });
  });
}
