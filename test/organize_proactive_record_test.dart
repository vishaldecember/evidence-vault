import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/evidence_temporal_intent.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/organize/organize_chronology_eligibility.dart';
import 'package:evidence_vault/domain/organize/organize_proactive_record.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/incident_workspace_entry.dart';
import 'package:evidence_vault/presentation/evidence_inspector_semantics.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/widgets/investigation/inspector_record_sections.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  EvidenceTemporalIntent? temporalIntent,
  String? contentHash,
  String incidentId = 'inc-proactive',
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
    incidentId: incidentId,
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
      incidentId: 'inc-proactive',
    ))
      item.id,
  ];
}

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-proactive', title: 'Case'),
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
      'temporalIntent': captured.temporalIntent,
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
    'temporalIntent': supporting.temporalIntent,
  };
}

bool _isPrior(WorkspaceEvidenceItem item, List<WorkspaceEvidenceItem> all) {
  return OrganizeProactiveRecord.isPriorObservation(
    item: item,
    incidentEvidence: all,
  );
}

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
    SharedPreferences.setMockInitialValues({});
    IncidentLibraryService.instance.clear();
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
    IncidentLibraryService.instance.clear();
  });

  final t0 = DateTime.utc(2026, 8, 24, 8);
  final tEvent = DateTime.utc(2026, 8, 24, 10);

  test('A chronological Voice before Photo stays in canonical order', () {
    final voice = _item(
      id: 'voice',
      kind: WorkspaceEvidenceKind.voice,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.chronological,
      contentHash: 'h-v',
    );
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: tEvent,
      contentHash: 'h-p',
    );
    final all = [voice, photo];
    expect(_isPrior(voice, all), isTrue);
    expect(_isPrior(photo, all), isFalse);
    expect(
      _order(items: all, orderedCapturedEvidenceIds: const ['voice', 'photo']),
      ['voice', 'photo'],
    );
  });

  test('B chronological Text before Photo stays eligible without moving Photo',
      () {
    final text = _item(
      id: 'warn',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.chronological,
      contentHash: 'h-n',
    );
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: tEvent,
      contentHash: 'h-p',
    );
    final all = [text, photo];
    expect(_isPrior(text, all), isTrue);
    expect(
      _order(items: all, orderedCapturedEvidenceIds: const ['photo']),
      ['photo', 'warn'],
    );
    expect(photo.capturedAt, tEvent);
    expect(text.lastPreservedAt, t0);
  });

  test('C chronological Voice before Video stays in canonical order', () {
    final voice = _item(
      id: 'voice',
      kind: WorkspaceEvidenceKind.voice,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.chronological,
    );
    final video = _item(
      id: 'video',
      kind: WorkspaceEvidenceKind.video,
      at: tEvent,
    );
    expect(_isPrior(voice, [voice, video]), isTrue);
    expect(
      _order(
        items: [voice, video],
        orderedCapturedEvidenceIds: const ['voice', 'video'],
      ),
      ['voice', 'video'],
    );
  });

  test('D chronological Text before Video is a prior observation', () {
    final text = _item(
      id: 'warn',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.chronological,
    );
    final video = _item(
      id: 'video',
      kind: WorkspaceEvidenceKind.video,
      at: tEvent,
    );
    expect(_isPrior(text, [text, video]), isTrue);
    expect(
      _order(items: [text, video], orderedCapturedEvidenceIds: const ['video']),
      ['video', 'warn'],
    );
  });

  test('E caption is record-before, not event time', () {
    expect(OrganizeProactiveRecord.caption, 'Recorded before later evidence');
    expect(
      OrganizeProactiveRecord.caption.toLowerCase(),
      isNot(contains('occurred')),
    );
    expect(
      OrganizeProactiveRecord.caption.toLowerCase(),
      isNot(contains('event time')),
    );
    expect(
      OrganizeProactiveRecord.caption.toLowerCase(),
      isNot(contains('proof')),
    );
    expect(
      OrganizeProactiveRecord.caption.toLowerCase(),
      isNot(contains('confirm')),
    );
    expect(EvidenceInspectorSemantics.capturedLabel, 'Captured');
    expect(EvidenceInspectorSemantics.recordedLabel, 'Recorded');
  });

  test('F later Photo timestamp is not rewritten to the earlier record', () {
    final text = _item(
      id: 'warn',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.chronological,
    );
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: tEvent,
    );
    OrganizeChronologyCanvas.displayOrder(
      items: [text, photo],
      orderedCapturedEvidenceIds: const ['photo'],
      incidentId: 'inc-proactive',
    );
    expect(_isPrior(text, [text, photo]), isTrue);
    expect(photo.capturedAt, tEvent);
    expect(photo.lastPreservedAt, tEvent);
    expect(text.lastPreservedAt, t0);
  });

  test('G no occurredAt field is introduced', () {
    expect(
      OrganizeProactiveRecord.caption.contains('occurredAt'),
      isFalse,
    );
  });

  test('T context Voice/Text do not receive proactive-record presentation', () {
    final voice = _item(
      id: 'voice',
      kind: WorkspaceEvidenceKind.voice,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.context,
    );
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.context,
    );
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: tEvent,
    );
    expect(_isPrior(voice, [voice, photo]), isFalse);
    expect(_isPrior(note, [note, photo]), isFalse);
  });

  test('U null temporalIntent is not interpreted as proactive chronology', () {
    final voice = _item(
      id: 'voice',
      kind: WorkspaceEvidenceKind.voice,
      at: t0,
    );
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
    );
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: tEvent,
    );
    expect(voice.temporalIntent, isNull);
    expect(note.temporalIntent, isNull);
    expect(_isPrior(voice, [voice, photo]), isFalse);
    expect(_isPrior(note, [note, photo]), isFalse);
  });

  testWidgets('E Organize tile shows prior-observation caption, not event time',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final text = _item(
      id: 'warn',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.chronological,
    );
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: tEvent,
    );
    final display = OrganizeChronologyCanvas.displayOrder(
      items: [text, photo],
      orderedCapturedEvidenceIds: const ['photo'],
      incidentId: 'inc-proactive',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeChronologyCanvas(
            ordered: display,
            allEvidence: [text, photo],
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(OrganizeChronologyCanvas.priorObservationCaptionKey('warn')),
      findsOneWidget,
    );
    expect(find.text(OrganizeProactiveRecord.caption), findsOneWidget);
    expect(
      find.byKey(OrganizeChronologyCanvas.priorObservationCaptionKey('photo')),
      findsNothing,
    );
    expect(find.textContaining('Occurred'), findsNothing);
    expect(find.textContaining('Event occurred'), findsNothing);
    expect(find.textContaining('Proof'), findsNothing);
  });

  testWidgets('E Inspector chronology can show the derived caption',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InspectorChronologySection(
            position: null,
            priorObservationCaption: OrganizeProactiveRecord.caption,
          ),
        ),
      ),
    );
    expect(
      find.byKey(InspectorChronologySection.priorObservationKey),
      findsOneWidget,
    );
    expect(find.text(OrganizeProactiveRecord.caption), findsOneWidget);
    expect(
      find.text(EvidenceInspectorSemantics.chronologyUnsupported),
      findsOneWidget,
    );
    expect(find.textContaining('Occurred'), findsNothing);
  });

  testWidgets('T context tile does not show the prior-observation caption',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      at: t0,
      temporalIntent: EvidenceTemporalIntent.context,
    );
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: tEvent,
    );
    final display = OrganizeChronologyCanvas.displayOrder(
      items: [note, photo],
      orderedCapturedEvidenceIds: const ['photo'],
      organizeCreatedIds: const {'note'},
      incidentId: 'inc-proactive',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeChronologyCanvas(
            ordered: display,
            allEvidence: [note, photo],
            organizeCreatedIds: const {'note'},
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(OrganizeChronologyCanvas.priorObservationCaptionKey('note')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextCaptionKey('note')),
      findsNothing,
    );
  });

  group('H–X controller integrity', () {
    test('H–S presentation does not mutate chronology, clocks, or graph', () {
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
      final voice = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.voice,
      );
      controller.setTemporalIntent(
        evidenceId: voice,
        intent: EvidenceTemporalIntent.chronological,
      );

      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == warning,
        ),
        isFalse,
      );
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == voice,
        ),
        isTrue,
      );

      final frozenWarning = _frozen(controller, warning);
      final frozenPhoto = _frozen(controller, photo);
      final frozenVoice = _frozen(controller, voice);
      final sequenceBefore = _sequence(controller);
      final timelineBefore = _timelineOrder(controller);
      final anchorsBefore = List.of(controller.timelineRepository.anchors);
      final relationshipsBefore = [
        for (final rel in controller.relationshipRepository.all)
          '${rel.id}:${rel.sourceEvidenceId}:${rel.targetEvidenceId}:${rel.type.name}',
      ];
      final groupsBefore = [
        for (final group in controller.aggregate.store.relationshipGroups)
          '${group.id}:${group.memberEvidenceIds.join(',')}',
      ];
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

      final evidence = controller.currentIncident.evidence;
      final warnItem = controller.currentIncident.evidenceById(warning)!;
      final photoItem = controller.currentIncident.evidenceById(photo)!;
      final voiceItem = controller.currentIncident.evidenceById(voice)!;
      expect(_isPrior(warnItem, evidence), isTrue);
      expect(_isPrior(voiceItem, evidence), isFalse);
      expect(_isPrior(photoItem, evidence), isFalse);

      OrganizeChronologyCanvas.displayOrder(
        items: evidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
        organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        incidentId: controller.currentIncident.id,
      );
      OrganizeChronologyEligibilityPolicy.classify(
        item: warnItem,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
        organizeCreatedIds: controller.organizeCreatedEvidenceIds,
      );

      expect(_frozen(controller, warning), frozenWarning);
      expect(_frozen(controller, photo), frozenPhoto);
      expect(_frozen(controller, voice), frozenVoice);
      expect(_sequence(controller), sequenceBefore);
      expect(_timelineOrder(controller), timelineBefore);
      expect(controller.timelineRepository.anchors, anchorsBefore);
      expect(
        [
          for (final rel in controller.relationshipRepository.all)
            '${rel.id}:${rel.sourceEvidenceId}:${rel.targetEvidenceId}:${rel.type.name}',
        ],
        relationshipsBefore,
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
      expect(
        controller.timelineRepository.anchors.any(
          (anchor) => anchor.capturedEvidenceId == warning,
        ),
        isFalse,
      );
      final readinessAfter = OrganizeReadiness.assess(
        evidence: controller.currentIncident.evidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
      );
      expect(readinessAfter.status, readinessBefore.status);
      expect(readinessAfter.matchedPattern, readinessBefore.matchedPattern);
      expect(readinessAfter.structureSummary, readinessBefore.structureSummary);
      expect(IncidentWorkspaceEntry.stageFor(readinessAfter), stageBefore);
      expect(
        IncidentWorkspaceEntry.stageFor(readinessAfter),
        readinessAfter.isReady
            ? InvestigationMethodologyStage.evidence
            : InvestigationMethodologyStage.capture,
      );
    });

    test('X archived incidents remain read-only', () async {
      final controller = _controller();
      final warning = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setTemporalIntent(
        evidenceId: warning,
        intent: EvidenceTemporalIntent.chronological,
      );
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      IncidentLibraryService.instance.summaries = [
        const LibraryIncidentSummary(
          id: 'inc-proactive',
          title: 'Case',
          evidenceCount: 2,
          contextEnrichedCount: 0,
          integrityVerified: true,
          lastPreserved: 'Today',
        ),
      ];
      await IncidentLibraryService.instance.archiveIncident('inc-proactive');
      expect(controller.isArchivedReadOnly, isTrue);
      final frozen = _frozen(controller, warning);
      expect(
        controller.setTemporalIntent(
          evidenceId: warning,
          intent: EvidenceTemporalIntent.context,
        ),
        isFalse,
      );
      expect(_frozen(controller, warning), frozen);
      expect(
        _isPrior(
          controller.currentIncident.evidenceById(warning)!,
          controller.currentIncident.evidence,
        ),
        isTrue,
      );
    });
  });
}
