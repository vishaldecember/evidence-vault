import 'package:evidence_vault/controllers/investigation_coaching_controller.dart';
import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/risk/incident_risk_assessment.dart';
import 'package:evidence_vault/engines/adaptive_coaching.dart';
import 'package:evidence_vault/engines/incident_coaching_maturity.dart';
import 'package:evidence_vault/engines/investigation_coaching_engine.dart';
import 'package:evidence_vault/models/coaching_statement_kind.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  DateTime? lastPreservedAt,
  String? parentEvidenceId,
  String? notePreview,
  double? latitude,
  double? longitude,
  String? collectionId,
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
    collectionId: collectionId,
    incidentId: 'inc-A',
  );
}

void main() {
  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('Incident coaching maturity', () {
    test('A EARLY incident receives basic documentation coaching', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
      );
      final context = InvestigationCoachingContext.fromController(controller);
      expect(
        IncidentCoachingMaturityEval.evaluate(
          items: context.items,
          relationships: context.relationships,
        ),
        IncidentCoachingMaturity.early,
      );
      final items = InvestigationCoachingEngine.generate(context);
      expect(
        items.any((item) => item.fingerprint == 'incident:early_start'),
        isTrue,
      );
      expect(items.first.kind, CoachingStatementKind.suggestion);
      expect(
        items.any((item) => item.fingerprint == 'evidence_completeness:no_witness'),
        isFalse,
      );
      expect(
        items.any((item) => item.fingerprint.startsWith('timeline:no_support:')),
        isFalse,
      );
      expect(items.length, lessThanOrEqualTo(3));
    });

    test('B EARLY to DEVELOPING changes coaching focus', () {
      final early = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          WorkspaceEvidenceController(
            initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
          ),
        ),
      );
      expect(
        early.any((item) => item.fingerprint == 'incident:early_start'),
        isTrue,
      );

      final developing = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          WorkspaceEvidenceController(
            initialState: WorkspaceEvidenceState(
              items: [
                _item(id: 'photo'),
                _item(id: 'video', kind: WorkspaceEvidenceKind.video),
              ],
            ),
          ),
        ),
      );
      expect(
        developing.any((item) => item.fingerprint == 'incident:early_start'),
        isFalse,
      );
      expect(
        developing.any(
          (item) => item.observation.contains('parent-linked supporting evidence'),
        ),
        isTrue,
      );
    });

    test('C DEVELOPING to DOCUMENTED quiets generic capture warnings', () {
      final documented = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          WorkspaceEvidenceController(
            initialState: WorkspaceEvidenceState(
              items: [
                _item(id: 'photo', notePreview: 'Door.', collectionId: 'col-1'),
                _item(
                  id: 'video',
                  kind: WorkspaceEvidenceKind.video,
                  collectionId: 'col-1',
                ),
                _item(
                  id: 'note',
                  kind: WorkspaceEvidenceKind.note,
                  parentEvidenceId: 'photo',
                  notePreview: 'Linked note.',
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        IncidentCoachingMaturityEval.evaluate(
          items: [
            _item(id: 'photo', notePreview: 'Door.', collectionId: 'col-1'),
            _item(
              id: 'video',
              kind: WorkspaceEvidenceKind.video,
              collectionId: 'col-1',
            ),
            _item(
              id: 'note',
              kind: WorkspaceEvidenceKind.note,
              parentEvidenceId: 'photo',
              notePreview: 'Linked note.',
            ),
          ],
          relationships: const [],
        ),
        IncidentCoachingMaturity.documented,
      );
      expect(
        documented.any(
          (item) =>
              item.fingerprint == 'evidence_completeness:photos_no_observations',
        ),
        isFalse,
      );
      expect(
        documented.any(
          (item) => item.fingerprint == 'evidence_completeness:no_witness',
        ),
        isFalse,
      );
    });

    test('D DOCUMENTED to RICH generic warnings disappear', () {
      final items = [
        _item(
          id: 'photo',
          notePreview: 'Door.',
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
          notePreview: 'Support.',
        ),
        _item(
          id: 'note-video',
          kind: WorkspaceEvidenceKind.note,
          parentEvidenceId: 'video',
          notePreview: 'Support.',
        ),
      ];
      expect(
        IncidentCoachingMaturityEval.evaluate(
          items: items,
          relationships: const [],
        ),
        IncidentCoachingMaturity.rich,
      );
      final coaching = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          WorkspaceEvidenceController(
            initialState: WorkspaceEvidenceState(items: items),
          ),
        ),
      );
      expect(coaching, hasLength(1));
      expect(coaching.single.fingerprint, 'incident:well_documented');
      expect(coaching.single.kind, CoachingStatementKind.fact);
      expect(
        coaching.single.observation.toLowerCase(),
        isNot(contains('complete')),
      );
      expect(
        coaching.single.observation.toLowerCase(),
        isNot(contains('legally')),
      );
    });

    test('E-F development after 24h is a fact, not causality', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo', lastPreservedAt: DateTime(2026, 8, 1)),
            _item(id: 'later', lastPreservedAt: DateTime(2026, 8, 3)),
          ],
        ),
      );
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          controller,
          previouslySeenEvidenceIds: {'photo'},
        ),
      );
      final development = items.singleWhere(
        (item) => item.fingerprint.startsWith('incident:development'),
      );
      expect(development.kind, CoachingStatementKind.fact);
      expect(development.observation, contains('New evidence was added after a'));
      expect(development.observation.toLowerCase(), isNot(contains('continuation')));
      expect(development.observation.toLowerCase(), isNot(contains('same event')));
      expect(
        development.suggestedAction,
        contains('relates to the earlier record'),
      );
    });

    test('G-H Photo + Video + Voice is not one-primary and siblings are not supporting',
        () {
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
      final blob = items
          .map((item) => '${item.observation} ${item.suggestedAction}')
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('only one primary')));
      expect(blob, isNot(contains('capture additional evidence')));
      expect(blob, isNot(contains('corroborat')));
      expect(items.length, lessThanOrEqualTo(3));
      expect(
        items.any((item) => item.observation.contains('parent-linked')),
        isTrue,
      );
    });

    test('I suggested RELATED is not supporting', () {
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
        items.any((item) => item.fingerprint == 'timeline:no_support:incident'),
        isTrue,
      );
    });

    test('J satisfied warning disappears when supporting is added', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
      );
      expect(
        InvestigationCoachingEngine.generate(
          InvestigationCoachingContext.fromController(controller),
        ).any((item) => item.fingerprint == 'incident:early_start'),
        isTrue,
      );
      controller.addContextEvidence(
        parentEvidenceId: 'photo',
        mode: WorkspaceCaptureMode.note,
      );
      final after = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(
        after.any((item) => item.fingerprint == 'incident:early_start'),
        isFalse,
      );
      expect(
        after.any((item) => item.fingerprint.startsWith('timeline:no_support:')),
        isFalse,
      );
    });

    test('K-L session cache does not replay; new condition can appear', () async {
      final evidence = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
            _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
          ],
        ),
      );
      final coaching = InvestigationCoachingController(controller: evidence);
      final first = coaching.visibleItems.map((item) => item.fingerprint).toList();
      final second = coaching.visibleItems.map((item) => item.fingerprint).toList();
      expect(second, first);
      expect(
        first.contains('relationship:unconnected_evidence'),
        isFalse,
      );

      final grouped = evidence.commitRelationshipGroup(
        evidenceIds: ['photo', 'video'],
      );
      expect(grouped, isNotNull);
      await Future<void>.delayed(Duration.zero);

      final after = coaching.visibleItems.map((item) => item.fingerprint).toList();
      expect(after, isNot(first));
      expect(after, contains('relationship:unconnected_evidence'));
    });

    test('M Risk Coach documentation types are covered by Investigation Coach', () {
      final covered = AdaptiveCoaching.riskTypesCoveredBy(
        const [],
        maturity: IncidentCoachingMaturity.developing,
      );
      expect(covered, contains(RiskType.documentationGap));
      expect(covered, contains(RiskType.missingEvidence));
    });

    test('N reconstruction one-anchor is not an incident shortage', () {
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(
          WorkspaceEvidenceController(
            initialState: WorkspaceEvidenceState(
              items: [
                _item(id: 'photo'),
                _item(id: 'video', kind: WorkspaceEvidenceKind.video),
                _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
              ],
            ),
          ),
        ),
      );
      expect(
        items.any(
          (item) => item.fingerprint.startsWith('narrative:single_source:'),
        ),
        isFalse,
      );
    });

    test('O-P coaching does not create incidents or change bound id', () {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      final incidentId = controller.currentIncident.id;
      InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(controller.currentIncident.id, incidentId);
      expect(controller.currentIncident.id, 'inc-A');
    });
  });
}
