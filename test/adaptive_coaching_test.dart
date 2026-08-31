import 'package:evidence_vault/controllers/investigation_coaching_controller.dart';
import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/risk/incident_risk_assessment.dart';
import 'package:evidence_vault/engines/adaptive_coaching.dart';
import 'package:evidence_vault/engines/evidence_semantics.dart';
import 'package:evidence_vault/engines/investigation_coaching_engine.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:evidence_vault/services/trust_package_scorecard_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  DateTime? lastPreservedAt,
  String? parentEvidenceId,
  String? notePreview,
  double? latitude,
  double? longitude,
  String incidentId = 'inc-A',
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: lastPreservedAt ?? DateTime(2026, 8, 1, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
    notePreview: notePreview,
    latitude: latitude,
    longitude: longitude,
    incidentId: incidentId,
  );
}

void main() {
  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('Adaptive coaching', () {
    test('Photo + Video + Voice is not only-one-primary behavior', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo', kind: WorkspaceEvidenceKind.image),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
            _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
          ],
        ),
      );

      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      final blob = items
          .map((item) => '${item.observation} ${item.suggestedAction}')
          .join(' ')
          .toLowerCase();

      expect(blob, isNot(contains('only one primary')));
      expect(blob, isNot(contains('capture additional evidence')));
      expect(blob, isNot(contains('only one source')));
      expect(
        items.any(
          (item) => item.observation.contains('parent-linked supporting evidence'),
        ),
        isTrue,
      );
      expect(items.length, lessThanOrEqualTo(3));
      expect(
        items.where(
          (item) => item.fingerprint.startsWith('timeline:no_support:'),
        ),
        hasLength(1),
      );
      expect(
        items.any(
          (item) => item.fingerprint.startsWith('narrative:single_source:'),
        ),
        isFalse,
      );
      expect(
        items.any(
          (item) => item.observation.toLowerCase().contains('corroborat'),
        ),
        isFalse,
      );
    });

    test('adding parent-linked supporting document satisfies no-support coaching',
        () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
        ),
      );

      final before = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        before.any(
          (item) => item.fingerprint.startsWith('timeline:no_support:'),
        ),
        isTrue,
      );

      controller.addContextEvidence(
        parentEvidenceId: 'photo',
        mode: WorkspaceCaptureMode.file,
      );
      controller.addContextEvidence(
        parentEvidenceId: 'video',
        mode: WorkspaceCaptureMode.file,
      );

      final after = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        after.any(
          (item) => item.fingerprint.startsWith('timeline:no_support:'),
        ),
        isFalse,
      );
    });

    test('first evaluation does not describe existing evidence as newly captured',
        () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo',
              lastPreservedAt: DateTime(2026, 8, 1),
            ),
            _item(
              id: 'video',
              kind: WorkspaceEvidenceKind.video,
              lastPreservedAt: DateTime(2026, 8, 4),
            ),
          ],
        ),
      );

      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        items.any(
          (item) => item.fingerprint.startsWith('incident:development'),
        ),
        isFalse,
      );
      expect(
        items.any(
          (item) => item.observation.toLowerCase().contains('new evidence was captured'),
        ),
        isFalse,
      );
    });

    test('new evidence after a significant gap is a development fact, not causality',
        () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo',
              lastPreservedAt: DateTime(2026, 8, 1, 10),
            ),
            _item(
              id: 'video',
              kind: WorkspaceEvidenceKind.video,
              lastPreservedAt: DateTime(2026, 8, 1, 10, 5),
            ),
            _item(
              id: 'later',
              lastPreservedAt: DateTime(2026, 8, 4, 10),
            ),
          ],
        ),
      );

      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          controller,
          previouslySeenEvidenceIds: {'photo', 'video'},
        ),
      );
      final development = items.where(
        (item) => item.fingerprint.startsWith('incident:development'),
      );
      expect(development, hasLength(1));
      expect(
        development.first.observation,
        contains('New evidence was added after a'),
      );
      expect(development.first.observation, contains('gap'));
      expect(
        development.first.observation.toLowerCase(),
        isNot(contains('continuation')),
      );
      expect(
        development.first.suggestedAction,
        contains('relates to the earlier record'),
      );
      expect(
        development.first.suggestedAction.toLowerCase(),
        isNot(contains('this is a continuation')),
      );
      expect(
        items.where((item) => item.fingerprint.startsWith('timeline:time_gap:')),
        isEmpty,
      );
    });

    test('repeating the same snapshot does not re-emit development', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo', lastPreservedAt: DateTime(2026, 8, 1)),
            _item(
              id: 'later',
              lastPreservedAt: DateTime(2026, 8, 4),
            ),
          ],
        ),
      );

      final first = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          controller,
          previouslySeenEvidenceIds: {'photo'},
        ),
      );
      expect(
        first.any((item) => item.fingerprint.startsWith('incident:development')),
        isTrue,
      );

      final second = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          controller,
          previouslySeenEvidenceIds: {'photo', 'later'},
        ),
      );
      expect(
        second.any((item) => item.fingerprint.startsWith('incident:development')),
        isFalse,
      );
    });

    test('session controller first look is a baseline even when a time gap exists',
        () {
      final evidence = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo', lastPreservedAt: DateTime(2026, 7, 1)),
            _item(
              id: 'video',
              kind: WorkspaceEvidenceKind.video,
              lastPreservedAt: DateTime(2026, 7, 4),
            ),
          ],
        ),
      );
      final coaching = InvestigationCoachingController(controller: evidence);

      expect(
        coaching.visibleItems.any(
          (item) => item.fingerprint.startsWith('incident:development'),
        ),
        isFalse,
      );
      expect(
        coaching.visibleItems.any(
          (item) => item.observation.contains('New evidence was added'),
        ),
        isFalse,
      );
    });

    test('event-level reconstruction copy is not used as an incident shortage', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
            _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
          ],
        ),
      );
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        items.any(
          (item) => item.fingerprint.startsWith('narrative:single_source:'),
        ),
        isFalse,
      );
    });

    test('metadata RELATED is not treated as supporting or corroboration', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
          relationships: [
            EvidenceRelationship(
              id: 'rel-1',
              sourceEvidenceId: 'photo',
              targetEvidenceId: 'video',
              type: RelationshipType.relatedTo,
              createdAt: DateTime(2026, 8, 1),
              source: 'metadata',
              reason: 'Related because these were captured 12 seconds apart.',
            ),
          ],
        ),
      );
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        items.any(
          (item) => item.fingerprint == 'timeline:no_support:incident',
        ),
        isTrue,
      );
      final blob = items
          .map((item) => '${item.observation} ${item.suggestedAction}')
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('corroborat')));
      expect(blob, isNot(contains('caused')));
    });

    test('duplicate missing-context warnings collapse to one', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo-1'),
            _item(id: 'photo-2'),
            _item(id: 'photo-3'),
          ],
        ),
      );
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        items.where(
          (item) =>
              item.fingerprint == 'evidence_completeness:photos_no_observations',
        ),
        hasLength(1),
      );
      expect(
        items.where(
          (item) => item.fingerprint == 'narrative:document_relevance',
        ),
        isEmpty,
      );
    });

    test('coaching covering no-support suppresses duplicate risk types', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
        ),
      );
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      final covered = AdaptiveCoaching.riskTypesCoveredBy(items);
      expect(covered, contains(RiskType.documentationGap));
      expect(covered, contains(RiskType.missingEvidence));
    });

    test('foreign incident evidence stays excluded', () {
      final mixed = [
        _item(id: 'photo-a', incidentId: 'inc-A'),
        _item(id: 'photo-b', incidentId: 'inc-B'),
      ];
      final scoped = EvidenceSemantics.incidentScopedItems(mixed, 'inc-A');
      expect(scoped.map((item) => item.id), isNot(contains('photo-b')));

      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext(
          incidentId: 'inc-A',
          items: scoped,
          timelineNodes: const [],
          narrativeEvents: const [],
          relationships: const [],
          groupMemberEvidenceIds: const {},
          primaryEvidenceCount: EvidenceSemantics.primaryChronologyCount(scoped),
          enrichedEvidenceCount: 0,
          trustPackageQuality: const TrustPackageInvestigationQuality(
            overallRating: TrustPackageQualityRating.incomplete,
            indicators: [],
          ),
        ),
      );
      for (final item in items) {
        expect(item.targetEvidenceId, isNot('photo-b'));
        expect(item.targetAnchorId, isNot('photo-b'));
      }
    });

    test('coaching does not mutate evidence identity', () {
      final photo = _item(
        id: 'photo',
        lastPreservedAt: DateTime(2026, 8, 1, 12, 30, 5),
      );
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [photo]),
      );
      final before = controller.currentIncident.evidence.single;
      InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      final after = controller.currentIncident.evidence.single;
      expect(after.id, before.id);
      expect(after.incidentId, before.incidentId);
      expect(after.lastPreservedAt, before.lastPreservedAt);
      expect(after.parentEvidenceId, before.parentEvidenceId);
    });

    test('documented-rich incident drops optional witness nag', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo',
              notePreview: 'Front door.',
              latitude: 27.7,
              longitude: 85.3,
            ),
            _item(
              id: 'video',
              kind: WorkspaceEvidenceKind.video,
              notePreview: 'Lobby.',
              latitude: 27.7,
              longitude: 85.3,
            ),
            _item(
              id: 'note-photo',
              kind: WorkspaceEvidenceKind.note,
              parentEvidenceId: 'photo',
              notePreview: 'Attached observation.',
            ),
            _item(
              id: 'note-video',
              kind: WorkspaceEvidenceKind.note,
              parentEvidenceId: 'video',
              notePreview: 'Video observation.',
            ),
          ],
        ),
      );
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        items.any(
          (item) => item.fingerprint == 'evidence_completeness:no_witness',
        ),
        isFalse,
      );
      expect(
        items.any(
          (item) => item.fingerprint.startsWith('timeline:no_support:'),
        ),
        isFalse,
      );
      expect(
        items.any((item) => item.fingerprint == 'incident:well_documented'),
        isTrue,
      );
      expect(items, hasLength(1));
    });
  });
}
