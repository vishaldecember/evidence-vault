import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/evidence_temporal_intent.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/organize/organize_chronology_eligibility.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/domain/organize/organize_spine_classification.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/incident_workspace_entry.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  DateTime? capturedAt,
  DateTime? recordedAt,
  DateTime? lastPreservedAt,
  EvidenceTemporalIntent? temporalIntent,
  String? contentHash,
  String incidentId = 'inc-elig',
}) {
  final preserved = lastPreservedAt ?? at;
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: preserved,
    capturedAt: capturedAt ?? (kind.isPrimaryChronology ? at : null),
    recordedAt: recordedAt ?? (kind.isPrimaryChronology ? null : at),
    temporalIntent: temporalIntent,
    contentHash: contentHash,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
  );
}

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-elig', title: 'Case'),
  );
}

OrganizeChronologyEligibility _classify(
  WorkspaceEvidenceItem item, {
  List<String> ordered = const [],
  Set<String> organizeCreatedIds = const {},
}) {
  return OrganizeChronologyEligibilityPolicy.classify(
    item: item,
    orderedCapturedEvidenceIds: ordered,
    organizeCreatedIds: organizeCreatedIds,
  );
}

List<String> _order({
  required List<WorkspaceEvidenceItem> items,
  required List<String> orderedCapturedEvidenceIds,
  Set<String> organizeCreatedIds = const {},
}) {
  return [
    for (final item in OrganizeChronologyCanvas.displayOrder(
      items: items,
      orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
      organizeCreatedIds: organizeCreatedIds,
      incidentId: 'inc-elig',
    ))
      item.id,
  ];
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
  };
}

void main() {
  setUp(WorkspaceEvidenceFactory.resetForTests);
  tearDown(WorkspaceEvidenceFactory.useProductionIds);

  final t0 = DateTime(2026, 8, 24, 8);
  final tEvent = DateTime(2026, 8, 24, 10);

  group('A–C canonical sequence', () {
    test('A canonical Photo stays in sequenceOrder', () {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: tEvent,
        contentHash: 'hash-photo',
      );
      expect(
        _classify(photo, ordered: const ['photo']),
        OrganizeChronologyEligibility.canonical,
      );
      expect(
        _order(items: [photo], orderedCapturedEvidenceIds: const ['photo']),
        ['photo'],
      );
    });

    test('B canonical Voice stays in sequenceOrder', () {
      final voice = _item(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: tEvent,
      );
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      expect(
        _classify(voice, ordered: const ['photo', 'voice']),
        OrganizeChronologyEligibility.canonical,
      );
      expect(
        _order(
          items: [voice, photo],
          orderedCapturedEvidenceIds: const ['photo', 'voice'],
        ),
        ['photo', 'voice'],
      );
    });

    test('C canonical Video stays in sequenceOrder', () {
      final video = _item(
        id: 'video',
        kind: WorkspaceEvidenceKind.video,
        at: tEvent,
      );
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      expect(
        _order(
          items: [video, photo],
          orderedCapturedEvidenceIds: const ['video', 'photo'],
        ),
        ['video', 'photo'],
      );
    });
  });

  group('D–G uncanonical chronological eligibility', () {
    test('D chronological Text without TimelineAnchor is eligible', () {
      final text = _item(
        id: 'text',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      expect(
        _classify(text, ordered: const ['photo']),
        OrganizeChronologyEligibility.uncanonicalChronological,
      );
      expect(
        OrganizeChronologyEligibilityPolicy.isChronologyEligible(
          item: text,
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        isTrue,
      );
      expect(
        OrganizeSpineClassification.isChronologicalSpine(item: text),
        isTrue,
      );
    });

    test('E chronological Voice without TimelineAnchor is eligible', () {
      final voice = _item(
        id: 'voice-free',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      expect(
        _classify(voice, ordered: const ['photo']),
        OrganizeChronologyEligibility.uncanonicalChronological,
      );
      expect(
        OrganizeChronologyEligibilityPolicy.isChronologyEligible(
          item: voice,
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        isTrue,
      );
    });

    test('F chronological Text does not receive a TimelineAnchor', () {
      final controller = _controller();
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setTemporalIntent(
        evidenceId: note,
        intent: EvidenceTemporalIntent.chronological,
      );
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == note,
        ),
        isFalse,
      );
      final projected = controller.currentIncident.evidenceById(note)!;
      expect(
        _classify(
          projected,
          ordered: controller.timelineRepository.orderedCapturedEvidenceIds(),
          organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        ),
        OrganizeChronologyEligibility.context,
      );
    });

    test('G chronological Voice without an anchor does not receive one', () {
      final controller = _controller();
      final voice = _item(
        id: 'voice-free',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final anchorsBefore = List.of(controller.timelineRepository.anchors);
      final ordered = OrganizeChronologyCanvas.displayOrder(
        items: [
          voice,
          controller.currentIncident.evidenceById(photo)!,
        ],
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
        incidentId: controller.currentIncident.id,
      );
      expect(
        ordered.map((item) => item.id),
        [photo, 'voice-free'],
      );
      expect(controller.timelineRepository.anchors, anchorsBefore);
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == 'voice-free',
        ),
        isFalse,
      );
    });
  });

  group('H–L ordering and fallback', () {
    test('K fallback prefers capturedAt then recordedAt then lastPreservedAt',
        () {
      final captured = _item(
        id: 'a',
        kind: WorkspaceEvidenceKind.note,
        at: DateTime(2026, 8, 24, 12),
        capturedAt: DateTime(2026, 8, 24, 8),
        recordedAt: DateTime(2026, 8, 24, 9),
        lastPreservedAt: DateTime(2026, 8, 24, 10),
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      expect(
        OrganizeChronologyEligibilityPolicy.fallbackInstant(captured),
        DateTime(2026, 8, 24, 8),
      );

      final recorded = _item(
        id: 'b',
        kind: WorkspaceEvidenceKind.note,
        at: DateTime(2026, 8, 24, 12),
        capturedAt: null,
        recordedAt: DateTime(2026, 8, 24, 9),
        lastPreservedAt: DateTime(2026, 8, 24, 10),
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      expect(
        OrganizeChronologyEligibilityPolicy.fallbackInstant(recorded),
        DateTime(2026, 8, 24, 9),
      );

      final preserved = WorkspaceEvidenceItem(
        id: 'c',
        kind: WorkspaceEvidenceKind.note,
        title: 'Note',
        lastPreservedAt: DateTime(2026, 8, 24, 10),
        temporalIntent: EvidenceTemporalIntent.chronological,
        integrityVerified: true,
        verification: VerificationFactory.initial(),
        incidentId: 'inc-elig',
      );
      expect(
        OrganizeChronologyEligibilityPolicy.fallbackInstant(preserved),
        DateTime(2026, 8, 24, 10),
      );
    });

    test('L fallback is deterministic including id tie-break', () {
      final t = DateTime(2026, 8, 24, 8);
      final early = _item(
        id: 'z-early',
        kind: WorkspaceEvidenceKind.note,
        at: t,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      final late = _item(
        id: 'a-late',
        kind: WorkspaceEvidenceKind.note,
        at: t.add(const Duration(minutes: 5)),
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: tEvent,
      );
      expect(
        _order(
          items: [late, early, photo],
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        ['photo', 'z-early', 'a-late'],
      );

      final sameA = _item(
        id: 'note-a',
        kind: WorkspaceEvidenceKind.note,
        at: t,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      final sameB = _item(
        id: 'note-b',
        kind: WorkspaceEvidenceKind.note,
        at: t,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      expect(
        _order(
          items: [sameB, sameA, photo],
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        ['photo', 'note-a', 'note-b'],
      );
    });
  });

  group('M–P null and context', () {
    test('M null temporalIntent retains O-14 origin behavior', () {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: tEvent,
      );
      final orgNote = _item(
        id: 'org-note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
      );
      const origin = {'org-note'};
      expect(
        _classify(
          orgNote,
          ordered: const ['photo', 'org-note'],
          organizeCreatedIds: origin,
        ),
        OrganizeChronologyEligibility.context,
      );
      expect(
        _order(
          items: [orgNote, photo],
          orderedCapturedEvidenceIds: const ['photo', 'org-note'],
          organizeCreatedIds: origin,
        ),
        ['photo', 'org-note'],
      );
    });

    test('N Capture-origin context intent stays chronology-eligible', () {
      final note = _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.context,
      );
      expect(
        OrganizeChronologyEligibilityPolicy.isChronologyEligible(
          item: note,
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        isTrue,
      );
      expect(
        _classify(note, ordered: const ['photo']),
        OrganizeChronologyEligibility.legacyFixed,
      );
    });

    test('O context with TimelineAnchor id remains context', () {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: tEvent,
      );
      final voice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.context,
      );
      const origin = {'org-voice'};
      expect(
        _classify(
          voice,
          ordered: const ['photo', 'org-voice'],
          organizeCreatedIds: origin,
        ),
        OrganizeChronologyEligibility.context,
      );
      expect(
        _order(
          items: [voice, photo],
          orderedCapturedEvidenceIds: const ['photo', 'org-voice'],
          organizeCreatedIds: origin,
        ),
        ['photo', 'org-voice'],
      );
    });
  });

  group('anticipation scenario', () {
    test('earlier chronological Text is eligible without fake sequenceOrder',
        () {
      final text = _item(
        id: 'warn',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
        contentHash: 'hash-warn',
      );
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: tEvent,
        contentHash: 'hash-photo',
      );
      expect(
        OrganizeChronologyEligibilityPolicy.isChronologyEligible(
          item: text,
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        isTrue,
      );
      expect(
        OrganizeChronologyEligibilityPolicy.isChronologyEligible(
          item: photo,
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        isTrue,
      );
      expect(
        _order(
          items: [photo, text],
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        containsAll(['warn', 'photo']),
      );
      expect(_classify(text, ordered: const ['photo']),
          OrganizeChronologyEligibility.uncanonicalChronological);
      expect(_classify(photo, ordered: const ['photo']),
          OrganizeChronologyEligibility.canonical);
      expect(text.contentHash, 'hash-warn');
      expect(photo.contentHash, 'hash-photo');
      expect(text.lastPreservedAt, t0);
      expect(photo.capturedAt, tEvent);
    });

    test('uncanonical chronological items sort by fallback, not origin', () {
      final laterText = _item(
        id: 'later-text',
        kind: WorkspaceEvidenceKind.note,
        at: tEvent.add(const Duration(hours: 1)),
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      final earlierText = _item(
        id: 'earlier-text',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: tEvent,
      );
      expect(
        _order(
          items: [laterText, earlierText, photo],
          orderedCapturedEvidenceIds: const ['photo'],
          organizeCreatedIds: const {'later-text', 'earlier-text'},
        ),
        ['photo', 'earlier-text', 'later-text'],
      );
    });

    test('explicit chronological precedes legacy leftovers', () {
      final chronoText = _item(
        id: 'chrono-text',
        kind: WorkspaceEvidenceKind.note,
        at: tEvent.add(const Duration(hours: 2)),
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      final legacyNote = _item(
        id: 'legacy-note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
      );
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: tEvent,
      );
      expect(
        _order(
          items: [legacyNote, chronoText, photo],
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        ['photo', 'chrono-text', 'legacy-note'],
      );
    });
  });

  group('H–AA controller integrity', () {
    test('H–AA presentation policy does not mutate chronology or graph', () {
      final controller = _controller();
      final warning = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setTemporalIntent(
        evidenceId: warning,
        intent: EvidenceTemporalIntent.chronological,
      );
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final orgVoice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      controller.setTemporalIntent(
        evidenceId: orgVoice,
        intent: EvidenceTemporalIntent.context,
      );
      controller.setOrganizeContextAnchor(
        contextEvidenceId: orgVoice,
        capturedEvidenceId: photo,
      );
      final collection = controller.createUserEvidenceCollection(
        evidenceIds: [photo, warning],
      );
      expect(collection, isNotNull);

      final frozenWarning = _frozen(controller, warning);
      final frozenPhoto = _frozen(controller, photo);
      final frozenVoice = _frozen(controller, orgVoice);
      final sequenceBefore = _sequence(controller);
      final timelineBefore = _timelineOrder(controller);
      final anchorsBefore = List.of(controller.timelineRepository.anchors);
      final organizeAnchorsBefore = [
        for (final anchor in controller.organizeContextAnchors)
          '${anchor.contextEvidenceId}:${anchor.capturedEvidenceId}',
      ];
      final collectionsBefore = [
        for (final item in controller.evidenceCollections)
          '${item.id}:${item.memberEvidenceIds.join(',')}',
      ];
      final readinessBefore = OrganizeReadiness.assess(
        evidence: controller.currentIncident.evidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
      );
      final stageBefore = IncidentWorkspaceEntry.stageFor(readinessBefore);
      final inspectorBefore = [
        for (final item in evidenceInspectorOrder(
          controller.journeyEvidenceItems,
          incidentId: controller.currentIncident.id,
        ))
          item.id,
      ];

      final ordered = OrganizeChronologyCanvas.displayOrder(
        items: controller.currentIncident.journeyEvidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
        organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        incidentId: controller.currentIncident.id,
      );
      final ids = [for (final item in ordered) item.id];
      expect(ids, containsAll([warning, photo, orgVoice]));
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: controller.currentIncident.evidenceById(warning)!,
          organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        ),
        isTrue,
      );
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: controller.currentIncident.evidenceById(orgVoice)!,
          organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        ),
        isTrue,
      );
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == warning,
        ),
        isFalse,
      );
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == orgVoice,
        ),
        isTrue,
      );

      expect(_frozen(controller, warning), frozenWarning);
      expect(_frozen(controller, photo), frozenPhoto);
      expect(_frozen(controller, orgVoice), frozenVoice);
      expect(_sequence(controller), sequenceBefore);
      expect(_timelineOrder(controller), timelineBefore);
      expect(controller.timelineRepository.anchors, anchorsBefore);
      expect(
        [
          for (final anchor in controller.organizeContextAnchors)
            '${anchor.contextEvidenceId}:${anchor.capturedEvidenceId}',
        ],
        organizeAnchorsBefore,
      );
      expect(
        [
          for (final item in controller.evidenceCollections)
            '${item.id}:${item.memberEvidenceIds.join(',')}',
        ],
        collectionsBefore,
      );
      final readinessAfter = OrganizeReadiness.assess(
        evidence: controller.currentIncident.evidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
      );
      expect(readinessAfter.status, readinessBefore.status);
      expect(readinessAfter.matchedPattern, readinessBefore.matchedPattern);
      expect(IncidentWorkspaceEntry.stageFor(readinessAfter), stageBefore);
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
    });
  });
}
