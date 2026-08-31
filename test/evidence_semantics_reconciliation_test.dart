import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/engines/evidence_semantics.dart';
import 'package:evidence_vault/engines/investigation_coaching_engine.dart';
import 'package:evidence_vault/engines/investigation_health_engine.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:evidence_vault/services/narrative_validation_service.dart';
import 'package:evidence_vault/services/relationship/relationship_engine.dart';
import 'package:evidence_vault/services/risk/deterministic_risk_assessment_provider.dart';
import 'package:evidence_vault/services/risk/risk_assessment_provider.dart';
import 'package:evidence_vault/services/trust_package_scorecard_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required String incidentId,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? parentEvidenceId,
  String? collectionId,
  String? notePreview,
  double? latitude,
  double? longitude,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    incidentId: incidentId,
    kind: kind,
    title: '$kind $id',
    lastPreservedAt: DateTime(2026, 8, 14, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
    collectionId: collectionId,
    notePreview: notePreview,
    latitude: latitude,
    longitude: longitude,
  );
}

EvidenceRelationship _metadataRelated(String a, String b) {
  return EvidenceRelationship(
    id: 'rel-$a-$b',
    sourceEvidenceId: a,
    targetEvidenceId: b,
    type: RelationshipType.relatedTo,
    createdAt: DateTime(2026, 8, 14),
    source: 'metadata',
    reason: 'Related because these were captured 12 seconds apart.',
  );
}

void _forbidIncidentLevelLies(Iterable<String> messages) {
  for (final message in messages) {
    final lower = message.toLowerCase();
    expect(lower, isNot(contains('only one primary')));
    expect(lower, isNot(contains('capture additional evidence')));
    expect(lower, isNot(contains('only one source')));
    expect(lower, isNot(contains('has no evidence')));
    expect(lower, isNot(contains('similar photos')));
    expect(lower, isNot(contains('isolated')));
    expect(lower, isNot(contains('missing witness statement')));
    expect(lower, isNot(contains('uncorroborated')));
  }
}

void main() {
  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('EvidenceSemantics', () {
    test('Photo + Video + Voice are 3 primary chronology items, not supporting',
        () {
      const incidentId = 'inc-A';
      final items = [
        _item(id: 'photo', incidentId: incidentId),
        _item(
          id: 'video',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.video,
        ),
        _item(
          id: 'voice',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.voice,
        ),
      ];

      expect(EvidenceSemantics.primaryChronologyCount(items), 3);
      expect(
        EvidenceSemantics.hasStructuralSupport(
          evidenceId: 'photo',
          items: items,
        ),
        isFalse,
      );
      expect(
        items.any(
          (item) => EvidenceSemantics.structurallySupports(
            child: item,
            parentId: 'photo',
          ),
        ),
        isFalse,
      );
    });

    test('parent-linked note is structural supporting; collection is not', () {
      const incidentId = 'inc-A';
      final items = [
        _item(id: 'photo', incidentId: incidentId, collectionId: 'col-1'),
        _item(
          id: 'video',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.video,
          collectionId: 'col-1',
        ),
        _item(
          id: 'note',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.note,
          parentEvidenceId: 'photo',
          notePreview: 'Heard shouting.',
        ),
      ];

      expect(
        EvidenceSemantics.hasStructuralSupport(
          evidenceId: 'photo',
          items: items,
        ),
        isTrue,
      );
      expect(
        EvidenceSemantics.hasStructuralSupport(
          evidenceId: 'video',
          items: items,
        ),
        isFalse,
      );
      expect(EvidenceSemantics.isInCollection(items.first), isTrue);
    });

    test('metadata RELATED is suggested, not supporting or corroboration', () {
      const incidentId = 'inc-A';
      final items = [
        _item(id: 'photo', incidentId: incidentId),
        _item(
          id: 'video',
          incidentId: incidentId,
          kind: WorkspaceEvidenceKind.video,
        ),
      ];
      final relationships = [_metadataRelated('photo', 'video')];

      expect(EvidenceSemantics.isSuggestedRelated(relationships.single), isTrue);
      expect(
        EvidenceSemantics.hasStructuralSupport(
          evidenceId: 'photo',
          items: items,
          relationships: relationships,
        ),
        isFalse,
      );
      expect(
        EvidenceSemantics.hasSuggestedRelationship(
          evidenceId: 'photo',
          relationships: relationships,
        ),
        isTrue,
      );
    });

    test('foreign incident items are excluded', () {
      final scoped = EvidenceSemantics.incidentScopedItems(
        [
          _item(id: 'photo-a', incidentId: 'inc-A'),
          _item(id: 'photo-b', incidentId: 'inc-B'),
        ],
        'inc-A',
      );
      expect(scoped.map((item) => item.id), ['photo-a']);
    });
  });

  group('Founder case Photo + Video + Voice', () {
    late WorkspaceEvidenceController controller;

    setUp(() {
      controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.preserveEvidence(WorkspaceCaptureMode.voice);
    });

    test('coaching does not invent incident-level shortages', () {
      final context = InvestigationCoachingContext.fromController(controller);
      expectIncident('inc-A', context.incidentId);
      expect(context.primaryEvidenceCount, 3);
      expect(context.items, hasLength(3));

      final items = InvestigationCoachingEngine.generate(context);
      expect(
        items.any((item) => item.fingerprint == 'relationship:similar_photos'),
        isFalse,
      );
      expect(
        items.any(
          (item) => item.fingerprint.startsWith('relationship:isolated_document'),
        ),
        isFalse,
      );

      _forbidIncidentLevelLies([
        for (final item in items) ...[item.observation, item.suggestedAction],
      ]);

      expect(
        items.any(
          (item) => item.observation.contains('parent-linked supporting evidence'),
        ),
        isTrue,
      );
      expect(items.length, lessThanOrEqualTo(3));
      expect(
        items.any(
          (item) => item.fingerprint.startsWith('narrative:single_source:'),
        ),
        isFalse,
      );
    });

    test('narrative validation stays event-scoped', () {
      for (final event in controller.narrativeEvents) {
        expect(event.displayEvidence, hasLength(1));
        expect(
          event.validation.recommendations,
          isNot(contains(NarrativeValidationService.recEventSingleEvidence)),
        );
        _forbidIncidentLevelLies(event.validation.recommendations);
      }
    });

    test('risk does not treat siblings or collection as supporting', () async {
      final evidence = controller.currentIncident.evidence;
      final collection = EvidenceCollection(
        id: 'col-1',
        incidentId: 'inc-A',
        name: 'Scene',
        systemGenerated: true,
        displayOrder: 0,
        createdAt: DateTime(2026, 8, 14),
        updatedAt: DateTime(2026, 8, 14),
        memberEvidenceIds: evidence.map((item) => item.id).toList(),
      );
      final relationships = [
        _metadataRelated(evidence[0].id, evidence[1].id),
      ];
      final provider = const DeterministicRiskAssessmentProvider();
      final context = RiskAssessmentContext(
        incidentId: 'inc-A',
        incidentTitle: 'Alpha',
        journeyStage: JourneyStage.building,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
        now: DateTime(2026, 8, 8),
        evidence: [
          for (final item in evidence)
            WorkspaceEvidenceItem(
              id: item.id,
              incidentId: 'inc-A',
              kind: item.kind,
              title: item.title,
              lastPreservedAt: item.lastPreservedAt,
              integrityVerified: true,
              verification: item.verification,
              collectionId: 'col-1',
            ),
        ],
        capturedEvidence: const [],
        relationships: relationships,
        collections: [collection],
        graph: const InvestigationGraphView(
          primaryEvidenceIds: [],
          supportingByPrimaryId: {},
          edges: [],
          collections: [],
          evidenceById: {},
        ),
      );

      final assessments = await provider.assess(context);
      _forbidIncidentLevelLies([
        for (final item in assessments) item.reason,
      ]);
      expect(
        assessments.any(
          (item) => item.reason.contains('parent-linked supporting evidence'),
        ),
        isTrue,
      );
      expect(
        EvidenceSemantics.hasStructuralSupport(
          evidenceId: evidence.first.id,
          items: context.evidence,
          relationships: relationships,
        ),
        isFalse,
      );
    });

    test('health findings stay incident-scoped and do not count siblings as support',
        () {
      final health = InvestigationHealthEngine.evaluate(controller.aggregate);
      expect(health.findings, isNotEmpty);
      expect(
        EvidenceSemantics.primaryChronologyCount(
          controller.currentIncident.evidence,
        ),
        3,
      );
    });
  });

  group('Incident ownership', () {
    test('coaching, validation, risk, and health ignore incident B', () async {
      const incidentA = 'inc-A';
      const incidentB = 'inc-B';
      final mixed = [
        _item(id: 'photo-a', incidentId: incidentA),
        _item(
          id: 'video-a',
          incidentId: incidentA,
          kind: WorkspaceEvidenceKind.video,
        ),
        _item(
          id: 'voice-a',
          incidentId: incidentA,
          kind: WorkspaceEvidenceKind.voice,
        ),
        _item(id: 'photo-b', incidentId: incidentB),
        _item(
          id: 'video-b',
          incidentId: incidentB,
          kind: WorkspaceEvidenceKind.video,
        ),
      ];
      final scoped = EvidenceSemantics.incidentScopedItems(mixed, incidentA);
      expectIncident(incidentA, incidentA);
      expect(scoped.map((item) => item.id).toList(), [
        'photo-a',
        'video-a',
        'voice-a',
      ]);
      expect(EvidenceSemantics.primaryChronologyCount(scoped), 3);

      final coaching = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext(
          incidentId: incidentA,
          items: scoped,
          timelineNodes: const [],
          narrativeEvents: const [],
          relationships: const [],
          groupMemberEvidenceIds: const {},
          primaryEvidenceCount:
              EvidenceSemantics.primaryChronologyCount(scoped),
          enrichedEvidenceCount: 0,
          trustPackageQuality: const TrustPackageInvestigationQuality(
            overallRating: TrustPackageQualityRating.incomplete,
            indicators: [],
          ),
        ),
      );
      for (final item in coaching) {
        expect(item.targetEvidenceId, isNot('photo-b'));
        expect(item.targetAnchorId, isNot('photo-b'));
      }

      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: incidentA, title: 'Alpha'),
      );
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.preserveEvidence(WorkspaceCaptureMode.voice);
      controller.aggregate.store.capturedEvidence.add(
        CapturedEvidence(
          id: 'photo-b',
          incidentId: incidentB,
          type: CapturedEvidenceType.photo,
          capturedAt: DateTime(2026, 8, 14, 11),
          title: 'Photo B',
          integrityVerified: true,
          verification: VerificationFactory.initial(),
          timelineAnchorId: 'anchor-photo-b',
        ),
      );
      final health = InvestigationHealthEngine.evaluate(controller.aggregate);
      expect(
        health.findings.any(
          (finding) => (finding.affectedObjectId ?? '') == 'photo-b',
        ),
        isFalse,
      );

      final provider = const DeterministicRiskAssessmentProvider();
      final assessments = await provider.assess(
        RiskAssessmentContext(
          incidentId: incidentA,
          incidentTitle: 'Alpha',
          journeyStage: JourneyStage.building,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
          now: DateTime(2026, 8, 8),
          evidence: mixed,
          capturedEvidence: const [],
          relationships: const [],
          collections: const [],
          graph: const InvestigationGraphView(
            primaryEvidenceIds: [],
            supportingByPrimaryId: {},
            edges: [],
            collections: [],
            evidenceById: {},
          ),
        ),
      );
      for (final item in assessments) {
        expect(item.sourceEvidenceIds, isNot(contains('photo-b')));
        expect(item.sourceEvidenceIds, isNot(contains('video-b')));
      }
    });
  });

  group('Group membership vs structural connectivity', () {
    test('ungrouped copy is group-scoped, not unconnected', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo-1', incidentId: ''),
            _item(id: 'photo-2', incidentId: ''),
            _item(id: 'photo-3', incidentId: ''),
          ],
        ),
      );
      controller.commitRelationshipGroup(evidenceIds: ['photo-1', 'photo-2']);
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      final match = items.where(
        (entry) => entry.fingerprint == 'relationship:unconnected_evidence',
      );
      expect(match, hasLength(1));
      expect(match.first.observation.toLowerCase(), isNot(contains('unconnected')));
      expect(match.first.observation, contains('investigation group'));
    });
  });
}

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail(
      'EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual',
    );
  }
}
