import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/engines/adaptive_coaching.dart';
import 'package:evidence_vault/engines/enrichment_engine.dart';
import 'package:evidence_vault/engines/evidence_semantics.dart';
import 'package:evidence_vault/engines/investigation_coaching_engine.dart';
import 'package:evidence_vault/mappers/connections_presentation_mapper.dart';
import 'package:evidence_vault/models/connections_presentation.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/relationship_group_confidence.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:evidence_vault/services/narrative_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required String incidentId,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? parentEvidenceId,
  String? notePreview,
  double? latitude,
  double? longitude,
  String? relatedPersonName,
  String? relatedPersonRole,
  String? participantId,
  DateTime? lastPreservedAt,
  bool isContextual = false,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    incidentId: incidentId,
    kind: kind,
    title: '$kind $id',
    lastPreservedAt: lastPreservedAt ?? DateTime(2026, 8, 14, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
    notePreview: notePreview,
    latitude: latitude,
    longitude: longitude,
    relatedPersonName: relatedPersonName,
    relatedPersonRole: relatedPersonRole,
    participantId: participantId,
    isContextual: isContextual,
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

void _forbidContractViolations(Iterable<String> messages) {
  for (final message in messages) {
    final lower = message.toLowerCase();
    expect(lower, isNot(contains('only one primary')));
    expect(lower, isNot(contains('missing primary')));
    expect(lower, isNot(contains('no evidence')));
    expect(lower, isNot(contains('capture additional evidence')));
    expect(lower, isNot(contains('only one source')));
    expect(lower, isNot(contains('uncorroborated')));
    expect(lower, isNot(contains('corroborat')));
    expect(lower, isNot(contains('missing witness statement')));
    expect(lower, isNot(contains('your incident is missing supporting')));
    expect(lower, isNot(contains('isolated')));
  }
}

void main() {
  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('Test 1 — Photo + Video + Voice', () {
    test('three chronology items are primary and coaching stays honest', () {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.preserveEvidence(WorkspaceCaptureMode.voice);

      final items = controller.currentIncident.evidence;
      expect(EvidenceSemantics.primaryChronologyCount(items), 3);
      expect(
        items.where((item) => item.isSupportingEvidence),
        isEmpty,
      );

      final coaching = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );

      expect(
        coaching.any(
          (item) => item.fingerprint == 'relationship:similar_photos',
        ),
        isFalse,
      );
      _forbidContractViolations([
        for (final item in coaching) ...[item.observation, item.suggestedAction],
      ]);
      expect(
        coaching.any(
          (item) => item.observation.contains('3 primary chronology items'),
        ),
        isTrue,
      );
    });
  });

  group('Test 2 — Structural support', () {
    test('parent-linked note is structural supporting; kind is not', () {
      const incidentId = 'inc-A';
      final photo = _item(id: 'photo', incidentId: incidentId);
      final note = _item(
        id: 'note',
        incidentId: incidentId,
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
        notePreview: 'Heard shouting.',
      );
      final standalone = _item(
        id: 'loose-file',
        incidentId: incidentId,
        kind: WorkspaceEvidenceKind.attachment,
      );

      expect(note.isSupportingEvidence, isTrue);
      expect(
        EvidenceSemantics.structurallySupports(child: note, parentId: 'photo'),
        isTrue,
      );
      expect(
        EvidenceSemantics.structurallySupports(
          child: standalone,
          parentId: 'photo',
        ),
        isFalse,
      );
      expect(
        EvidenceSemantics.hasStructuralSupport(
          evidenceId: photo.id,
          items: [photo, note, standalone],
        ),
        isTrue,
      );
    });
  });

  group('Test 3 — Suggested RELATED', () {
    test('metadata RELATED is suggested, not supporting, not enrichment', () {
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

      final snapshot = EnrichmentEngine.compute(
        EnrichmentContext(items: items, relationships: relationships),
      );
      expect(snapshot.enrichedEvidenceCount, 0);
      expect(snapshot.journeyStage, isNot(JourneyStage.rich));

      final presentation = ConnectionsPresentationMapper.build(
        incidentId: incidentId,
        items: items,
        relationships: relationships,
        collections: const [],
        groupNodes: const [],
        suggestions: const [],
      );
      expect(presentation.suggested, isNotEmpty);
      expect(
        presentation.suggested.single.kind,
        ConnectionsPairKind.suggested,
      );
      expect(presentation.supporting, isEmpty);
    });
  });

  group('Test 4 — Context dimensions', () {
    test('timestamp, GPS, and written notes are distinct', () {
      const incidentId = 'inc-A';
      final timeOnly = _item(id: 'photo', incidentId: incidentId);
      final withGps = _item(
        id: 'video',
        incidentId: incidentId,
        kind: WorkspaceEvidenceKind.video,
        latitude: 27.7,
        longitude: 85.3,
      );
      final withNote = _item(
        id: 'voice',
        incidentId: incidentId,
        kind: WorkspaceEvidenceKind.voice,
        notePreview: 'Shouting outside.',
      );

      expect(EvidenceSemantics.hasLocation(timeOnly), isFalse);
      expect(EvidenceSemantics.hasWrittenDescription(timeOnly), isFalse);
      expect(EvidenceSemantics.hasRecordedContext(timeOnly), isFalse);

      expect(EvidenceSemantics.hasLocation(withGps), isTrue);
      expect(EvidenceSemantics.hasWrittenDescription(withGps), isFalse);
      expect(EvidenceSemantics.hasRecordedContext(withGps), isTrue);

      expect(EvidenceSemantics.hasLocation(withNote), isFalse);
      expect(EvidenceSemantics.hasWrittenDescription(withNote), isTrue);
      expect(EvidenceSemantics.hasRecordedContext(withNote), isTrue);
    });
  });

  group('Test 5 — Witness', () {
    test('only witness-kind evidence satisfies witness semantics', () {
      const incidentId = 'inc-A';
      final relatedPerson = _item(
        id: 'photo',
        incidentId: incidentId,
        relatedPersonName: 'Alex',
        relatedPersonRole: 'witness',
      );
      final participantOnly = _item(
        id: 'video',
        incidentId: incidentId,
        kind: WorkspaceEvidenceKind.video,
        participantId: 'part-1',
      );
      final witness = _item(
        id: 'wit',
        incidentId: incidentId,
        kind: WorkspaceEvidenceKind.witness,
      );

      expect(EvidenceSemantics.hasWitnessKind([relatedPerson]), isFalse);
      expect(EvidenceSemantics.hasWitnessKind([participantOnly]), isFalse);
      expect(EvidenceSemantics.hasWitnessKind([witness]), isTrue);
    });
  });

  group('Test 6 — Reconstruction', () {
    test('default one-anchor events are not incident-level missing evidence', () {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.preserveEvidence(WorkspaceCaptureMode.voice);

      expect(controller.narrativeEvents, hasLength(3));
      for (final event in controller.narrativeEvents) {
        expect(event.displayEvidence, hasLength(1));
        expect(
          event.validation.status,
          isNot(RelationshipGroupConfidence.low),
        );
        expect(
          event.validation.recommendations,
          isNot(contains(NarrativeValidationService.recEventSingleEvidence)),
        );
        _forbidContractViolations(event.validation.recommendations);
      }

      final coaching = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        coaching.any(
          (item) => item.fingerprint.startsWith('narrative:single_source:'),
        ),
        isFalse,
      );
      _forbidContractViolations([
        for (final item in coaching) ...[item.observation, item.suggestedAction],
      ]);
    });
  });

  group('Test 7 — Adaptive coaching', () {
    test('baseline, 24h development, satisfied rules, no duplicates', () {
      final early = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          WorkspaceEvidenceController(
            initialState: WorkspaceEvidenceState(
              items: [_item(id: 'photo', incidentId: 'inc-A')],
            ),
          ),
        ),
      );
      expect(
        early.any((item) => item.fingerprint == 'incident:early_start'),
        isTrue,
      );

      final later = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo',
              incidentId: 'inc-A',
              lastPreservedAt: DateTime(2026, 8, 1),
            ),
            _item(
              id: 'video',
              incidentId: 'inc-A',
              kind: WorkspaceEvidenceKind.video,
              lastPreservedAt: DateTime(2026, 8, 3),
            ),
          ],
        ),
      );
      final developed = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          later,
          previouslySeenEvidenceIds: {'photo'},
        ),
      );
      expect(
        developed.any(
          (item) => item.fingerprint.startsWith('incident:development'),
        ),
        isTrue,
      );

      final supported = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          WorkspaceEvidenceController(
            initialState: WorkspaceEvidenceState(
              items: [
                _item(
                  id: 'photo',
                  incidentId: 'inc-A',
                  notePreview: 'Door.',
                ),
                _item(
                  id: 'video',
                  incidentId: 'inc-A',
                  kind: WorkspaceEvidenceKind.video,
                  notePreview: 'Lobby.',
                ),
                _item(
                  id: 'note-photo',
                  incidentId: 'inc-A',
                  kind: WorkspaceEvidenceKind.note,
                  parentEvidenceId: 'photo',
                  notePreview: 'Support.',
                ),
                _item(
                  id: 'note-video',
                  incidentId: 'inc-A',
                  kind: WorkspaceEvidenceKind.note,
                  parentEvidenceId: 'video',
                  notePreview: 'Support.',
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        supported.any(
          (item) => item.fingerprint.startsWith('timeline:no_support:'),
        ),
        isFalse,
      );

      expect(AdaptiveCoaching.developmentGap, const Duration(hours: 24));
      expect(early.length, lessThanOrEqualTo(3));
    });
  });

  group('Test 8 — Incident identity', () {
    test('coaching does not mutate incident id, evidence ids, or timestamps', () {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);

      final incidentId = controller.currentIncident.id;
      final evidence = [
        for (final item in controller.currentIncident.evidence)
          (item.id, item.lastPreservedAt, item.incidentId),
      ];
      final sequence = [
        for (final node in controller.anchoredTimeline) node.anchor.sequenceOrder,
      ];

      InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );

      expect(controller.currentIncident.id, incidentId);
      expect(
        [
          for (final item in controller.currentIncident.evidence)
            (item.id, item.lastPreservedAt, item.incidentId),
        ],
        evidence,
      );
      expect(
        [
          for (final node in controller.anchoredTimeline) node.anchor.sequenceOrder,
        ],
        sequence,
      );
    });
  });

  group('Graph primary role vs persisted flag', () {
    test('chronology role wins over CapturedEvidence.isPrimaryEvidence=false', () {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      final photoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.setPrimaryEvidence(evidenceId: photoId, isPrimary: false);

      expect(
        controller.aggregate.store.capturedEvidence
            .firstWhere((item) => item.id == photoId)
            .isPrimaryEvidence,
        isFalse,
      );
      expect(
        EvidenceSemantics.primaryChronologyCount(
          controller.currentIncident.evidence,
        ),
        2,
      );
      expect(controller.investigationGraph.primaryEvidenceIds, contains(photoId));
    });
  });
}
