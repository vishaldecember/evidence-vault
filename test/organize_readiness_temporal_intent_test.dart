import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/evidence_temporal_intent.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/incident_workspace_entry.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _ev({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  EvidenceTemporalIntent? temporalIntent,
  String? contentHash,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    temporalIntent: temporalIntent,
    contentHash: contentHash,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

OrganizeReadiness _assess(
  List<WorkspaceEvidenceItem> evidence, {
  List<String>? capturedOrder,
}) {
  return OrganizeReadiness.assess(
    evidence: evidence,
    orderedCapturedEvidenceIds: capturedOrder ??
        [
          for (final item in evidence)
            if (item.kind.isPrimaryChronology) item.id,
        ],
  );
}

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-o16', title: 'Case'),
  );
}

List<String> _sequence(WorkspaceEvidenceController controller) {
  return [
    for (final anchor in controller.timelineRepository.anchors)
      '${anchor.id}:${anchor.capturedEvidenceId}:${anchor.sequenceOrder}:${anchor.anchoredAt.toIso8601String()}',
  ];
}

List<String> _timelineOrder(WorkspaceEvidenceController controller) {
  return [
    for (final item in controller.aggregate.store.capturedEvidence)
      '${item.id}:${item.timelineOrder}',
    for (final item in controller.aggregate.store.supportingEvidence)
      '${item.id}:${item.timelineOrder}',
  ];
}

Map<String, Object?> _frozen(
  WorkspaceEvidenceController controller,
  String id,
) {
  final captured = controller.evidenceRepository.capturedById(id);
  if (captured != null) {
    final projected = controller.currentIncident.evidenceById(id)!;
    return {
      'id': captured.id,
      'contentHash': captured.contentHash,
      'capturedAt': captured.capturedAt,
      'createdAt': captured.createdAt,
      'recordedAt': projected.recordedAt,
      'lastPreservedAt': projected.lastPreservedAt,
      'timelineOrder': captured.timelineOrder,
      'verification': captured.verification.status.name,
    };
  }
  final supporting = controller.evidenceRepository.supportingById(id)!;
  final projected = controller.currentIncident.evidenceById(id)!;
  return {
    'id': supporting.id,
    'contentHash': supporting.contentHash,
    'capturedAt': projected.capturedAt,
    'createdAt': supporting.createdAt,
    'recordedAt': projected.recordedAt,
    'lastPreservedAt': projected.lastPreservedAt,
    'timelineOrder': supporting.timelineOrder,
    'verification': supporting.verification.status.name,
  };
}

void main() {
  setUp(WorkspaceEvidenceFactory.resetForTests);
  tearDown(WorkspaceEvidenceFactory.useProductionIds);

  final t0 = DateTime.utc(2026, 8, 24, 8);
  final t1 = DateTime.utc(2026, 8, 24, 10);
  final t2 = DateTime.utc(2026, 8, 24, 12);

  test('A chronological Voice contributes to videoVoice', () {
    final readiness = _assess([
      _ev(id: 'vid', kind: WorkspaceEvidenceKind.video, at: t0),
      _ev(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t1,
        temporalIntent: EvidenceTemporalIntent.chronological,
      ),
    ]);
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.videoVoice);
    expect(readiness.composition.voices, 1);
  });

  test('B chronological Text contributes to videoText', () {
    final readiness = _assess(
      [
        _ev(id: 'vid', kind: WorkspaceEvidenceKind.video, at: t0),
        _ev(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          at: t1,
          temporalIntent: EvidenceTemporalIntent.chronological,
        ),
      ],
      capturedOrder: ['vid'],
    );
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.videoText);
    expect(readiness.composition.texts, 1);
    expect(readiness.structureSummary, 'Video → Text');
  });

  test('A/B chronological Voice/Text can frame Photo for photoVoiceText', () {
    final readiness = _assess(
      [
        _ev(
          id: 'voice',
          kind: WorkspaceEvidenceKind.voice,
          at: t0,
          temporalIntent: EvidenceTemporalIntent.chronological,
        ),
        _ev(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t1),
        _ev(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          at: t2,
          temporalIntent: EvidenceTemporalIntent.chronological,
        ),
      ],
      capturedOrder: ['voice', 'photo'],
    );
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.photoVoiceText);
    expect(readiness.structureSummary, 'Voice → Photo → Text');
  });

  test('C context Voice does not satisfy chronological voice requirements', () {
    final readiness = _assess([
      _ev(id: 'vid', kind: WorkspaceEvidenceKind.video, at: t0),
      _ev(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t1,
        temporalIntent: EvidenceTemporalIntent.context,
      ),
    ]);
    expect(readiness.isReady, isFalse);
    expect(readiness.matchedPattern, isNull);
    expect(readiness.composition.voices, 0);
    expect(readiness.composition.videos, 1);
    expect(readiness.structureSummary, 'Video');
  });

  test('D context Text does not satisfy chronological text requirements', () {
    final readiness = _assess(
      [
        _ev(id: 'vid', kind: WorkspaceEvidenceKind.video, at: t0),
        _ev(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          at: t1,
          temporalIntent: EvidenceTemporalIntent.context,
        ),
      ],
      capturedOrder: ['vid'],
    );
    expect(readiness.isReady, isFalse);
    expect(readiness.matchedPattern, isNull);
    expect(readiness.composition.texts, 0);
    expect(readiness.structureSummary, 'Video');
  });

  test('C context Voice in sequenceOrder is still excluded from chronology', () {
    final readiness = _assess(
      [
        _ev(
          id: 'voice',
          kind: WorkspaceEvidenceKind.voice,
          at: t0,
          temporalIntent: EvidenceTemporalIntent.context,
        ),
        _ev(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t1),
      ],
      capturedOrder: ['voice', 'photo'],
    );
    expect(readiness.composition.voices, 0);
    expect(readiness.structureSummary, 'Photo');
    expect(readiness.isReady, isFalse);
  });

  test('E null temporalIntent is not inferred from kind or timestamps', () {
    final note = _ev(id: 'note', kind: WorkspaceEvidenceKind.note, at: t0);
    expect(note.temporalIntent, isNull);
    expect(note.kind, WorkspaceEvidenceKind.note);
    final asNote = _assess([
      _ev(id: 'vid', kind: WorkspaceEvidenceKind.video, at: t0),
      note,
    ], capturedOrder: ['vid']);
    expect(asNote.composition.texts, 1);
    expect(asNote.matchedPattern, OrganizeReadinessPattern.videoText);

    final asVoiceKind = _ev(
      id: 'voice',
      kind: WorkspaceEvidenceKind.voice,
      at: t0,
    );
    expect(asVoiceKind.temporalIntent, isNull);
    final voiceOnly = _assess([
      _ev(id: 'vid', kind: WorkspaceEvidenceKind.video, at: t1),
      asVoiceKind,
    ]);
    expect(voiceOnly.composition.voices, 1);
    expect(voiceOnly.matchedPattern, OrganizeReadinessPattern.videoVoice);
  });

  test('F null Voice/Text retain legacy composition and structure', () {
    final evidence = [
      _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t0),
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t1),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t2),
    ];
    final readiness = _assess(evidence, capturedOrder: ['v1', 'p1']);
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.photoVoiceText);
    expect(readiness.structureSummary, 'Voice → Photo → Text');
    expect(readiness.composition.voices, 1);
    expect(readiness.composition.texts, 1);
  });

  test('R Organize origin does not invent chronological intent', () {
    final videoAndOrgNote = _assess(
      [
        _ev(id: 'vid', kind: WorkspaceEvidenceKind.video, at: t0),
        _ev(
          id: 'org-note',
          kind: WorkspaceEvidenceKind.note,
          at: t1,
          temporalIntent: EvidenceTemporalIntent.context,
        ),
      ],
      capturedOrder: ['vid'],
    );
    expect(videoAndOrgNote.isReady, isFalse);
    expect(videoAndOrgNote.composition.texts, 0);

    final videoAndUndeclaredOrgNote = _assess(
      [
        _ev(id: 'vid', kind: WorkspaceEvidenceKind.video, at: t0),
        _ev(id: 'org-note', kind: WorkspaceEvidenceKind.note, at: t1),
      ],
      capturedOrder: ['vid'],
    );
    expect(videoAndUndeclaredOrgNote.isReady, isTrue);
    expect(
      videoAndUndeclaredOrgNote.matchedPattern,
      OrganizeReadinessPattern.videoText,
    );
  });

  test('P readiness results are deterministic', () {
    final evidence = [
      _ev(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
      ),
      _ev(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t1),
      _ev(
        id: 'note2',
        kind: WorkspaceEvidenceKind.note,
        at: t2,
        temporalIntent: EvidenceTemporalIntent.chronological,
      ),
    ];
    final first = _assess(evidence, capturedOrder: ['photo']);
    final second = _assess(evidence, capturedOrder: ['photo']);
    expect(first.status, second.status);
    expect(first.matchedPattern, second.matchedPattern);
    expect(first.structureSummary, second.structureSummary);
    expect(first.composition.texts, second.composition.texts);
    expect(first.nextUsefulMaterial, second.nextUsefulMaterial);
  });

  test('Q existing patterns and thresholds remain unchanged', () {
    expect(OrganizeReadiness.examples, hasLength(10));
    expect(
      OrganizeReadinessPattern.values,
      [
        OrganizeReadinessPattern.photoVoiceText,
        OrganizeReadinessPattern.twoPhotosText,
        OrganizeReadinessPattern.photoWitness,
        OrganizeReadinessPattern.videoText,
        OrganizeReadinessPattern.videoVoice,
        OrganizeReadinessPattern.videoWitness,
        OrganizeReadinessPattern.twoVideosText,
        OrganizeReadinessPattern.twoVideosVoice,
        OrganizeReadinessPattern.photoTwoVoice,
        OrganizeReadinessPattern.photoTwoText,
      ],
    );
    expect(
      _assess([
        _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
        _ev(id: 'p2', kind: WorkspaceEvidenceKind.image, at: t1),
        _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t2),
      ]).matchedPattern,
      OrganizeReadinessPattern.twoPhotosText,
    );
    expect(
      _assess([
        _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      ]).isReady,
      isFalse,
    );
    expect(
      _assess([
        _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t1),
        _ev(
          id: 'n1',
          kind: WorkspaceEvidenceKind.note,
          at: t0,
          temporalIntent: EvidenceTemporalIntent.chronological,
        ),
        _ev(
          id: 'n2',
          kind: WorkspaceEvidenceKind.note,
          at: t2,
          temporalIntent: EvidenceTemporalIntent.chronological,
        ),
      ], capturedOrder: ['p1']).matchedPattern,
      OrganizeReadinessPattern.photoTwoText,
    );
  });

  test('O Phase 3E still routes from OrganizeReadiness.assess', () {
    final controller = _controller();
    final video = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final note = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    controller.setTemporalIntent(
      evidenceId: note,
      intent: EvidenceTemporalIntent.chronological,
    );

    final assessed = OrganizeReadiness.assess(
      evidence: controller.currentIncident.evidence,
      orderedCapturedEvidenceIds:
          controller.timelineRepository.orderedCapturedEvidenceIds(),
    );
    expect(controller.organizeReadiness.matchedPattern, assessed.matchedPattern);
    expect(IncidentWorkspaceEntry.tryAssess(controller)?.matchedPattern,
        assessed.matchedPattern);
    expect(
      IncidentWorkspaceEntry.stageFor(assessed),
      InvestigationMethodologyStage.evidence,
    );
    expect(assessed.matchedPattern, OrganizeReadinessPattern.videoText);
    expect(video, isNotEmpty);
  });

  group('G–N / S assess does not mutate working-set identity', () {
    test('changing temporalIntent updates readiness without mutating evidence',
        () {
      final controller = _controller();
      final video = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      final voice = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.voice,
      );
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setOrganizeContextAnchor(
        contextEvidenceId: note,
        capturedEvidenceId: video,
      );
      final collection = controller.createUserEvidenceCollection(
        evidenceIds: [video, note],
      );
      expect(collection, isNotNull);
      controller.commitRelationshipGroup(
        evidenceIds: [video, voice],
        type: RelationshipType.relatedTo,
      );

      final frozenVideo = _frozen(controller, video);
      final frozenVoice = _frozen(controller, voice);
      final frozenNote = _frozen(controller, note);
      final sequenceBefore = _sequence(controller);
      final timelineBefore = _timelineOrder(controller);
      final anchorsBefore = List.of(controller.timelineRepository.anchors);
      final collectionsBefore = [
        for (final item in controller.evidenceCollections)
          '${item.id}:${item.memberEvidenceIds.join(',')}',
      ];
      final groupsBefore = [
        for (final group in controller.aggregate.store.relationshipGroups)
          '${group.id}:${group.memberEvidenceIds.join(',')}',
      ];
      final relationshipsBefore = [
        for (final rel in controller.relationshipRepository.all)
          '${rel.id}:${rel.sourceEvidenceId}:${rel.targetEvidenceId}:${rel.type.name}',
      ];
      final organizeAnchorsBefore = [
        for (final anchor in controller.organizeContextAnchors)
          '${anchor.contextEvidenceId}:${anchor.capturedEvidenceId}',
      ];
      final inspectorBefore = [
        for (final item in evidenceInspectorOrder(
          controller.journeyEvidenceItems,
          incidentId: controller.currentIncident.id,
        ))
          item.id,
      ];

      expect(
        _assess(
          controller.currentIncident.evidence,
          capturedOrder:
              controller.timelineRepository.orderedCapturedEvidenceIds(),
        ).matchedPattern,
        OrganizeReadinessPattern.videoText,
      );

      controller.setTemporalIntent(
        evidenceId: note,
        intent: EvidenceTemporalIntent.context,
      );
      expect(
        OrganizeReadiness.assess(
          evidence: controller.currentIncident.evidence,
          orderedCapturedEvidenceIds:
              controller.timelineRepository.orderedCapturedEvidenceIds(),
        ).matchedPattern,
        OrganizeReadinessPattern.videoVoice,
      );

      controller.setTemporalIntent(
        evidenceId: voice,
        intent: EvidenceTemporalIntent.context,
      );
      controller.setTemporalIntent(
        evidenceId: note,
        intent: EvidenceTemporalIntent.chronological,
      );

      final after = OrganizeReadiness.assess(
        evidence: controller.currentIncident.evidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
      );
      expect(after.matchedPattern, OrganizeReadinessPattern.videoText);
      expect(after.composition.voices, 0);
      expect(after.composition.texts, 1);

      expect(_frozen(controller, video), frozenVideo);
      expect(_frozen(controller, voice), frozenVoice);
      expect(_frozen(controller, note), frozenNote);
      expect(_sequence(controller), sequenceBefore);
      expect(_timelineOrder(controller), timelineBefore);
      expect(controller.timelineRepository.anchors, anchorsBefore);
      expect(
        [
          for (final item in controller.evidenceCollections)
            '${item.id}:${item.memberEvidenceIds.join(',')}',
        ],
        collectionsBefore,
      );
      expect(
        [
          for (final group in controller.aggregate.store.relationshipGroups)
            '${group.id}:${group.memberEvidenceIds.join(',')}',
        ],
        groupsBefore,
      );
      expect(
        [
          for (final rel in controller.relationshipRepository.all)
            '${rel.id}:${rel.sourceEvidenceId}:${rel.targetEvidenceId}:${rel.type.name}',
        ],
        relationshipsBefore,
      );
      expect(
        [
          for (final anchor in controller.organizeContextAnchors)
            '${anchor.contextEvidenceId}:${anchor.capturedEvidenceId}',
        ],
        organizeAnchorsBefore,
      );
      expect(
        [
          for (final item in evidenceInspectorOrder(
            controller.journeyEvidenceItems,
            incidentId: controller.currentIncident.id,
          ))
            item.id,
        ],
        inspectorBefore,
      );
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == note,
        ),
        isFalse,
      );
    });
  });
}
