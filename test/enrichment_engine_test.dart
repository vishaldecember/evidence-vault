import 'package:evidence_vault/engines/enrichment_engine.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/services/workspace_coaching_service.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:flutter_test/flutter_test.dart';

EnrichmentContext _context({
  required List<WorkspaceEvidenceItem> items,
  List<EvidenceRelationship> relationships = const [],
  Map<String, EvidenceEnrichmentSignals> signalsByEvidenceId = const {},
  int? richBaselinePrimaryCount,
}) {
  return EnrichmentContext(
    items: items,
    relationships: relationships,
    signalsByEvidenceId: signalsByEvidenceId,
    richBaselinePrimaryCount: richBaselinePrimaryCount,
  );
}

WorkspaceEvidenceItem _primary({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

WorkspaceEvidenceItem _attached({
  required String id,
  required String parentId,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.note,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Context',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    isContextual: true,
    relatedEvidenceIds: {parentId},
  );
}

EvidenceRelationship _relationship({
  required String id,
  required String sourceId,
  required String targetId,
}) {
  return EvidenceRelationship(
    id: id,
    sourceEvidenceId: sourceId,
    targetEvidenceId: targetId,
    type: RelationshipType.relatedTo,
    createdAt: DateTime(2026, 7, 28),
  );
}

EnrichmentSnapshot _compute(
  List<WorkspaceEvidenceItem> items, {
  List<EvidenceRelationship> relationships = const [],
}) {
  return EnrichmentEngine.compute(
    _context(items: items, relationships: relationships),
  );
}

void _expectSnapshot(
  EnrichmentSnapshot snapshot, {
  required int primary,
  required int enriched,
  required int percentage,
  required JourneyStage stage,
}) {
  expect(snapshot.primaryEvidenceCount, primary);
  expect(snapshot.enrichedEvidenceCount, enriched);
  expect(snapshot.enrichmentPercentage, percentage);
  expect(snapshot.journeyStage, stage);
}

void main() {
  group('EnrichmentEngine maturity values', () {
    test('supporting evidence does not increase primaryEvidenceCount', () {
      final snapshot = _compute([
        _primary(id: 'photo'),
        _attached(id: 'voice', parentId: 'photo', kind: WorkspaceEvidenceKind.voice),
        _primary(id: 'voice-capture', kind: WorkspaceEvidenceKind.voice),
        _primary(id: 'note-capture', kind: WorkspaceEvidenceKind.note),
      ]);

      expect(snapshot.primaryEvidenceCount, 2);
    });

    test('zero primary evidence returns 0% EMPTY', () {
      _expectSnapshot(
        _compute([
          _primary(id: 'note-capture', kind: WorkspaceEvidenceKind.note),
          _primary(id: 'file', kind: WorkspaceEvidenceKind.attachment),
        ]),
        primary: 0,
        enriched: 0,
        percentage: 0,
        stage: JourneyStage.empty,
      );
    });

    test('metadata RELATED does not count as enrichment', () {
      final snapshot = _compute(
        [
          _primary(id: 'photo'),
          _primary(id: 'video', kind: WorkspaceEvidenceKind.video),
        ],
        relationships: [
          _relationship(id: 'rel-1', sourceId: 'photo', targetId: 'video'),
        ],
      );

      _expectSnapshot(
        snapshot,
        primary: 2,
        enriched: 0,
        percentage: 0,
        stage: JourneyStage.empty,
      );
    });

    test('future AI enrichment counts toward enrichedEvidenceCount', () {
      final snapshot = EnrichmentEngine.compute(
        _context(
          items: [_primary(id: 'photo')],
          signalsByEvidenceId: const {
            'photo': EvidenceEnrichmentSignals(hasAiEnrichment: true),
          },
        ),
      );

      _expectSnapshot(
        snapshot,
        primary: 1,
        enriched: 1,
        percentage: 100,
        stage: JourneyStage.rich,
      );
    });
  });

  group('EnrichmentEngine acceptance tests', () {
    test('photo only', () {
      _expectSnapshot(
        _compute([_primary(id: 'photo')]),
        primary: 1,
        enriched: 0,
        percentage: 0,
        stage: JourneyStage.empty,
      );
    });

    test('photo + context', () {
      _expectSnapshot(
        _compute([
          _primary(id: 'photo'),
          _attached(id: 'ctx', parentId: 'photo'),
        ]),
        primary: 1,
        enriched: 1,
        percentage: 100,
        stage: JourneyStage.rich,
      );
    });

    test('photo + voice note', () {
      _expectSnapshot(
        _compute([
          _primary(id: 'photo'),
          _attached(
            id: 'voice',
            parentId: 'photo',
            kind: WorkspaceEvidenceKind.voice,
          ),
        ]),
        primary: 1,
        enriched: 1,
        percentage: 100,
        stage: JourneyStage.rich,
      );
    });

    test('photo + context, file', () {
      _expectSnapshot(
        _compute([
          _primary(id: 'photo'),
          _attached(id: 'ctx-photo', parentId: 'photo'),
          _primary(id: 'file', kind: WorkspaceEvidenceKind.attachment),
        ]),
        primary: 1,
        enriched: 1,
        percentage: 100,
        stage: JourneyStage.rich,
      );
    });

    test('photo + context, file + text note', () {
      _expectSnapshot(
        _compute([
          _primary(id: 'photo'),
          _attached(id: 'ctx-photo', parentId: 'photo'),
          _primary(id: 'file', kind: WorkspaceEvidenceKind.attachment),
          _attached(
            id: 'note-file',
            parentId: 'file',
            kind: WorkspaceEvidenceKind.note,
          ),
        ]),
        primary: 1,
        enriched: 1,
        percentage: 100,
        stage: JourneyStage.rich,
      );
    });

    test(
      'photo + context, video + voice note, file + linked evidence, witness + context',
      () {
        _expectSnapshot(
          _compute(
            [
              _primary(id: 'photo'),
              _attached(id: 'ctx-photo', parentId: 'photo'),
              _primary(id: 'video', kind: WorkspaceEvidenceKind.video),
              _attached(
                id: 'voice-video',
                parentId: 'video',
                kind: WorkspaceEvidenceKind.voice,
              ),
              _primary(id: 'file', kind: WorkspaceEvidenceKind.attachment),
              _primary(id: 'witness', kind: WorkspaceEvidenceKind.witness),
              _attached(id: 'ctx-witness', parentId: 'witness'),
            ],
            relationships: [
              _relationship(id: 'rel-1', sourceId: 'file', targetId: 'photo'),
            ],
          ),
          primary: 2,
          enriched: 2,
          percentage: 100,
          stage: JourneyStage.rich,
        );
      },
    );
  });

  group('EnrichmentEngine coaching messages', () {
    test('EMPTY coaching message', () {
      final snapshot = _compute([_primary(id: 'photo')]);
      expect(snapshot.coaching.journeyStatus, 'BUILDING');
      expect(
        snapshot.coaching.coachingMessage,
        contains('remaining 1 primary chronology items'),
      );
    });

    test('BUILDING coaching message', () {
      final snapshot = _compute([
        _primary(id: 'photo'),
        _attached(id: 'ctx-photo', parentId: 'photo'),
        _primary(id: 'video', kind: WorkspaceEvidenceKind.video),
      ]);
      expect(snapshot.journeyStage, JourneyStage.building);
      expect(snapshot.coaching.progressMessage, '1 of 2 primary chronology items have recorded context.');
      expect(
        snapshot.coaching.coachingMessage,
        contains('remaining 1 primary chronology items'),
      );
    });

    test('RICH coaching message', () {
      final snapshot = _compute([
        _primary(id: 'photo'),
        _attached(id: 'ctx-photo', parentId: 'photo'),
      ]);
      expect(snapshot.journeyStage, JourneyStage.rich);
      expect(snapshot.coaching.journeyStatus, 'RICH');
      expect(snapshot.coaching.coachingMessage, WorkspaceCoachingService.richCoaching);
    });

    test('BUILDING after new primary evidence uses quantitative coaching', () {
      final snapshot = EnrichmentEngine.compute(
        _context(
          items: [
            _primary(id: 'photo'),
            _attached(id: 'ctx-photo', parentId: 'photo'),
            _primary(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
          richBaselinePrimaryCount: 1,
        ),
      );

      expect(snapshot.journeyStage, JourneyStage.building);
      expect(snapshot.coaching.progressMessage, '1 of 2 primary chronology items have recorded context.');
      expect(
        snapshot.coaching.coachingMessage,
        contains('remaining 1 primary chronology items'),
      );
    });

    test('progressive BUILDING keeps quantitative coaching copy', () {
      final snapshot = _compute([
        _primary(id: 'photo'),
        _primary(id: 'video', kind: WorkspaceEvidenceKind.video),
        _attached(id: 'ctx-video', parentId: 'video'),
      ]);

      expect(snapshot.journeyStage, JourneyStage.building);
      expect(snapshot.coaching.progressMessage, '1 of 2 primary chronology items have recorded context.');
      expect(
        snapshot.coaching.coachingMessage,
        contains('remaining 1 primary chronology items'),
      );
    });
  });
}
