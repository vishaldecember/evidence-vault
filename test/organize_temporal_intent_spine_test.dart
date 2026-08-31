import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/evidence_temporal_intent.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/domain/organize/organize_spine_classification.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/incident_workspace_entry.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  EvidenceTemporalIntent? temporalIntent,
  String incidentId = 'inc-spine',
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    temporalIntent: temporalIntent,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
  );
}

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-spine', title: 'Case'),
  );
}

bool _isChronological(
  WorkspaceEvidenceItem item, {
  Set<String> organizeCreatedIds = const {},
}) {
  return OrganizeSpineClassification.isChronologicalSpine(
    item: item,
    organizeCreatedIds: organizeCreatedIds,
  );
}

bool _isContext(
  WorkspaceEvidenceItem item, {
  Set<String> organizeCreatedIds = const {},
}) {
  return OrganizeSpineClassification.isContextSpine(
    item: item,
    organizeCreatedIds: organizeCreatedIds,
  );
}

List<String> _displayIds({
  required List<WorkspaceEvidenceItem> items,
  required List<String> orderedCapturedEvidenceIds,
  Set<String> organizeCreatedIds = const {},
}) {
  return [
    for (final item in OrganizeChronologyCanvas.displayOrder(
      items: items,
      orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
      organizeCreatedIds: organizeCreatedIds,
      incidentId: 'inc-spine',
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
    final projected = controller.currentIncident.evidenceById(id);
    return {
      'id': captured.id,
      'contentHash': captured.contentHash,
      'capturedAt': captured.capturedAt,
      'createdAt': captured.createdAt,
      'lastPreservedAt': projected?.lastPreservedAt,
      'timelineOrder': captured.timelineOrder,
    };
  }
  final supporting = controller.evidenceRepository.supportingById(id)!;
  final projected = controller.currentIncident.evidenceById(id);
  return {
    'id': supporting.id,
    'contentHash': supporting.contentHash,
    'capturedAt': null,
    'createdAt': supporting.createdAt,
    'lastPreservedAt': projected?.lastPreservedAt,
    'timelineOrder': supporting.timelineOrder,
  };
}

Future<void> _pumpCanvas(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> ordered,
  Set<String> organizeCreatedIds = const {},
  List<String> orderedCapturedEvidenceIds = const [],
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final display = OrganizeChronologyCanvas.displayOrder(
    items: ordered,
    orderedCapturedEvidenceIds: orderedCapturedEvidenceIds.isEmpty
        ? [for (final item in ordered) item.id]
        : orderedCapturedEvidenceIds,
    organizeCreatedIds: organizeCreatedIds,
    incidentId: 'inc-spine',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeChronologyCanvas(
          ordered: display,
          allEvidence: display,
          organizeCreatedIds: organizeCreatedIds,
          onEvidenceSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(WorkspaceEvidenceFactory.resetForTests);
  tearDown(WorkspaceEvidenceFactory.useProductionIds);

  final t0 = DateTime(2026, 8, 24, 10);

  group('A–M spine classification', () {
    test('A Capture-origin Photo + null → chronological spine', () {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      expect(_isChronological(photo), isTrue);
      expect(_isContext(photo), isFalse);
    });

    test('B Capture-origin Voice + null → chronological spine', () {
      final voice = _item(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
      );
      expect(_isChronological(voice), isTrue);
      expect(_isContext(voice), isFalse);
    });

    test('C Capture-origin Note + null → chronological spine', () {
      final note = _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
      );
      expect(_isChronological(note), isTrue);
      expect(_isContext(note), isFalse);
    });

    test('D Organize-created Voice + null → context spine', () {
      final voice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
      );
      const origin = {'org-voice'};
      expect(_isContext(voice, organizeCreatedIds: origin), isTrue);
      expect(_isChronological(voice, organizeCreatedIds: origin), isFalse);
    });

    test('E Organize-created Text + null → context spine', () {
      final note = _item(
        id: 'org-note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
      );
      const origin = {'org-note'};
      expect(_isContext(note, organizeCreatedIds: origin), isTrue);
    });

    test('F Organize-created Voice + chronological stays context spine', () {
      final voice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      const origin = {'org-voice'};
      expect(_isChronological(voice, organizeCreatedIds: origin), isFalse);
      expect(_isContext(voice, organizeCreatedIds: origin), isTrue);
    });

    test('G Organize-created Text + chronological stays context spine', () {
      final note = _item(
        id: 'org-note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      const origin = {'org-note'};
      expect(_isChronological(note, organizeCreatedIds: origin), isFalse);
      expect(_isContext(note, organizeCreatedIds: origin), isTrue);
    });

    test('H Capture-origin Voice + context stays chronological spine', () {
      final voice = _item(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.context,
      );
      expect(_isContext(voice), isFalse);
      expect(_isChronological(voice), isTrue);
    });

    test('I Capture-origin Note + context stays chronological spine', () {
      final note = _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.context,
      );
      expect(_isContext(note), isFalse);
      expect(_isChronological(note), isTrue);
    });

    test('J Organize-created Voice + context → context spine', () {
      final voice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.context,
      );
      const origin = {'org-voice'};
      expect(_isContext(voice, organizeCreatedIds: origin), isTrue);
    });

    test('K chronological without TimelineAnchor → chronological spine', () {
      final note = _item(
        id: 'chrono-note',
        kind: WorkspaceEvidenceKind.note,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      expect(_isChronological(note), isTrue);
      expect(
        _displayIds(
          items: [
            _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
            note,
          ],
          orderedCapturedEvidenceIds: const ['photo'],
        ),
        ['photo', 'chrono-note'],
      );
    });

    test('L context with TimelineAnchor id still context spine', () {
      final voice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
        temporalIntent: EvidenceTemporalIntent.context,
      );
      const origin = {'org-voice'};
      expect(_isContext(voice, organizeCreatedIds: origin), isTrue);
      expect(
        _displayIds(
          items: [
            _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
            voice,
          ],
          orderedCapturedEvidenceIds: const ['photo', 'org-voice'],
          organizeCreatedIds: origin,
        ),
        ['photo', 'org-voice'],
      );
      expect(
        OrganizeChronologyCanvas.isContextSpineItem(
          voice,
          organizeCreatedIds: origin,
        ),
        isTrue,
      );
    });

    test('M missing temporalIntent uses legacy origin', () {
      final captureVoice = _item(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0,
      );
      final orgVoice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0.add(const Duration(minutes: 1)),
      );
      const origin = {'org-voice'};
      expect(_isChronological(captureVoice, organizeCreatedIds: origin), isTrue);
      expect(_isContext(orgVoice, organizeCreatedIds: origin), isTrue);
    });
  });

  group('N–P overrides', () {
    test('N null preserves legacy origin behavior', () {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      final orgNote = _item(
        id: 'org-note',
        kind: WorkspaceEvidenceKind.note,
        at: t0.subtract(const Duration(hours: 1)),
      );
      expect(
        _displayIds(
          items: [orgNote, photo],
          orderedCapturedEvidenceIds: const ['photo', 'org-note'],
          organizeCreatedIds: const {'org-note'},
        ),
        ['photo', 'org-note'],
      );
      expect(
        OrganizeChronologyCanvas.isContextSpineItem(
          orgNote,
          organizeCreatedIds: const {'org-note'},
        ),
        isTrue,
      );
      expect(
        OrganizeChronologyCanvas.isFixedSpineItem(
          photo,
          organizeCreatedIds: const {'org-note'},
        ),
        isTrue,
      );
    });

    test('O toolbar origin wins over chronological intent', () {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      final orgVoice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0.add(const Duration(minutes: 3)),
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      const origin = {'org-voice'};
      expect(_isChronological(orgVoice, organizeCreatedIds: origin), isFalse);
      expect(_isContext(orgVoice, organizeCreatedIds: origin), isTrue);
      expect(
        _displayIds(
          items: [orgVoice, photo],
          orderedCapturedEvidenceIds: const ['photo', 'org-voice'],
          organizeCreatedIds: origin,
        ),
        ['photo', 'org-voice'],
      );
    });

    test('P Capture context intent does not override origin', () {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      final voice = _item(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0.add(const Duration(minutes: 1)),
        temporalIntent: EvidenceTemporalIntent.context,
      );
      expect(_isContext(voice), isFalse);
      expect(
        OrganizeChronologyCanvas.isFixedSpineItem(voice),
        isTrue,
      );
      expect(
        _displayIds(
          items: [voice, photo],
          orderedCapturedEvidenceIds: const ['photo', 'voice'],
        ),
        ['photo', 'voice'],
      );
    });
  });

  group('Q–AH controller integrity', () {
    test('Q chronological Text does not receive sequenceOrder', () {
      final controller = _controller();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      final sequenceBefore = _sequence(controller);
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == note,
        ),
        isFalse,
      );

      controller.setTemporalIntent(
        evidenceId: note,
        intent: EvidenceTemporalIntent.chronological,
      );

      expect(_sequence(controller), sequenceBefore);
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == note,
        ),
        isFalse,
      );
      final projected = controller.currentIncident.evidenceById(note)!;
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: projected,
          organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        ),
        isTrue,
      );
      expect(
        OrganizeSpineClassification.isChronologicalSpine(
          item: projected,
          organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        ),
        isFalse,
      );
      expect(photo, isNotEmpty);
    });

    test('R context Voice keeps TimelineAnchor', () {
      final controller = _controller();
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == voice,
        ),
        isTrue,
      );
      final sequenceBefore = _sequence(controller);

      controller.setTemporalIntent(
        evidenceId: voice,
        intent: EvidenceTemporalIntent.context,
      );

      expect(_sequence(controller), sequenceBefore);
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == voice,
        ),
        isTrue,
      );
      final projected = controller.currentIncident.evidenceById(voice)!;
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: projected,
          organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        ),
        isTrue,
      );
    });

    test('S–AH changing intent is presentation-only', () {
      final controller = _controller();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final captureVoice = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.voice,
      );
      final orgVoice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      final orgNote = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setOrganizeContextAnchor(
        contextEvidenceId: orgNote,
        capturedEvidenceId: photo,
      );
      final collection = controller.createUserEvidenceCollection(
        evidenceIds: [photo, orgNote],
      );
      expect(collection, isNotNull);

      final frozenPhoto = _frozen(controller, photo);
      final frozenOrgVoice = _frozen(controller, orgVoice);
      final frozenOrgNote = _frozen(controller, orgNote);
      final sequenceBefore = _sequence(controller);
      final timelineBefore = _timelineOrder(controller);
      final anchorsBefore = List.of(controller.aggregate.store.timelineAnchors);
      final createdBefore = Set<String>.from(
        controller.organizeCreatedEvidenceIds,
      );
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

      final orgVoiceBefore = controller.currentIncident.evidenceById(orgVoice)!;
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: orgVoiceBefore,
          organizeCreatedIds: createdBefore,
        ),
        isTrue,
      );

      controller.setTemporalIntent(
        evidenceId: orgVoice,
        intent: EvidenceTemporalIntent.chronological,
      );
      controller.setTemporalIntent(
        evidenceId: captureVoice,
        intent: EvidenceTemporalIntent.context,
      );
      controller.setTemporalIntent(
        evidenceId: orgNote,
        intent: EvidenceTemporalIntent.chronological,
      );

      final orgVoiceAfter = controller.currentIncident.evidenceById(orgVoice)!;
      final captureVoiceAfter =
          controller.currentIncident.evidenceById(captureVoice)!;
      final orgNoteAfter = controller.currentIncident.evidenceById(orgNote)!;
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: orgVoiceAfter,
          organizeCreatedIds: createdBefore,
        ),
        isTrue,
      );
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: captureVoiceAfter,
          organizeCreatedIds: createdBefore,
        ),
        isFalse,
      );
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: orgNoteAfter,
          organizeCreatedIds: createdBefore,
        ),
        isTrue,
      );

      expect(_frozen(controller, photo), frozenPhoto);
      expect(_frozen(controller, orgVoice), frozenOrgVoice);
      expect(_frozen(controller, orgNote), frozenOrgNote);
      expect(_sequence(controller), sequenceBefore);
      expect(_timelineOrder(controller), timelineBefore);
      expect(controller.aggregate.store.timelineAnchors, anchorsBefore);
      expect(controller.organizeCreatedEvidenceIds, createdBefore);
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
      final readinessAfter = OrganizeReadiness.assess(
        evidence: controller.currentIncident.evidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
      );
      expect(
        IncidentWorkspaceEntry.stageFor(readinessAfter),
        readinessAfter.isReady
            ? InvestigationMethodologyStage.evidence
            : InvestigationMethodologyStage.capture,
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
    });
  });

  group('visual lanes', () {
    testWidgets('F chronological Organize Voice stays on the context lane',
        (tester) async {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      final orgVoice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0.add(const Duration(minutes: 2)),
        temporalIntent: EvidenceTemporalIntent.chronological,
      );
      await _pumpCanvas(
        tester,
        ordered: [photo, orgVoice],
        organizeCreatedIds: const {'org-voice'},
        orderedCapturedEvidenceIds: const ['photo', 'org-voice'],
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('org-voice')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('org-voice')),
        findsNothing,
      );
    });

    testWidgets('H capture Voice marked context stays on the fixed spine',
        (tester) async {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      final voice = _item(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: t0.add(const Duration(minutes: 1)),
        temporalIntent: EvidenceTemporalIntent.context,
      );
      await _pumpCanvas(
        tester,
        ordered: [photo, voice],
        orderedCapturedEvidenceIds: const ['photo', 'voice'],
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('voice')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('voice')),
        findsNothing,
      );
    });

    testWidgets('N undeclared Organize Text stays on the context lane',
        (tester) async {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      final note = _item(
        id: 'org-note',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(minutes: 1)),
      );
      await _pumpCanvas(
        tester,
        ordered: [photo, note],
        organizeCreatedIds: const {'org-note'},
        orderedCapturedEvidenceIds: const ['photo'],
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('org-note')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('org-note')),
        findsNothing,
      );
    });
  });
}
