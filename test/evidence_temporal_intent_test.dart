import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_temporal_intent.dart';
import 'package:evidence_vault/domain/evidence/supporting_evidence.dart';
import 'package:evidence_vault/domain/evidence/supporting_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/incident_workspace_entry.dart';
import 'package:evidence_vault/presentation/evidence_inspector_semantics.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/investigation/timeline_role_choice_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-intent', title: 'Case'),
  );
}

EvidenceTemporalIntent? _intentOf(
  WorkspaceEvidenceController controller,
  String id,
) {
  return controller.evidenceRepository.capturedById(id)?.temporalIntent ??
      controller.evidenceRepository.supportingById(id)?.temporalIntent;
}

Map<String, dynamic> _capturedMap(
  CapturedEvidence item, {
  int timelineOrder = 0,
}) {
  return FirestoreSerializers.capturedToMap(
    item,
    userId: 'uid-1',
    timelineOrder: timelineOrder,
    supportingEvidenceIds: const [],
  );
}

Map<String, dynamic> _supportingMap(
  SupportingEvidence item, {
  int timelineOrder = 0,
}) {
  return FirestoreSerializers.supportingToMap(
    item,
    userId: 'uid-1',
    timelineOrder: timelineOrder,
    supportingEvidenceIds: const [],
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

Map<String, Object?> _frozenEvidence(
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

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required WorkspaceEvidenceItem evidence,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  showInvestigationEvidenceInspectorModal(
                    context: context,
                    evidence: evidence,
                    controller: controller,
                    orderedEvidence: evidenceInspectorOrder(
                      controller.journeyEvidenceItems,
                    ),
                  );
                },
                child: const Text('Open Inspector'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open Inspector'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
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

  group('O-13 temporal intent persistence', () {
    test('A new evidence defaults to null when no intent is selected', () {
      final controller = _controller();
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      expect(_intentOf(controller, voice), isNull);
      expect(_intentOf(controller, note), isNull);
      expect(_intentOf(controller, photo), isNull);
    });

    test('B chronological serializes as chronological', () {
      final controller = _controller();
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      expect(
        controller.setTemporalIntent(
          evidenceId: voice,
          intent: EvidenceTemporalIntent.chronological,
        ),
        isTrue,
      );
      final map = _capturedMap(
        controller.evidenceRepository.capturedById(voice)!,
      );
      expect(map['temporalIntent'], 'chronological');
    });

    test('C context serializes as context', () {
      final controller = _controller();
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      expect(
        controller.setTemporalIntent(
          evidenceId: note,
          intent: EvidenceTemporalIntent.context,
        ),
        isTrue,
      );
      final map = _supportingMap(
        controller.evidenceRepository.supportingById(note)!,
      );
      expect(map['temporalIntent'], 'context');
    });

    test('D missing Firestore field hydrates as null', () {
      final captured = CapturedEvidence(
        id: 'ev-legacy',
        incidentId: 'inc-intent',
        type: CapturedEvidenceType.voice,
        capturedAt: DateTime.utc(2026, 8, 24, 12),
        title: 'Voice',
        integrityVerified: true,
        verification: VerificationFactory.initial(),
        timelineAnchorId: 'anchor-legacy',
      );
      final map = _capturedMap(captured);
      expect(map.containsKey('temporalIntent'), isFalse);
      final restored = FirestoreSerializers.capturedFromMap(map)!;
      expect(restored.temporalIntent, isNull);

      final supporting = SupportingEvidence(
        id: 'note-legacy',
        incidentId: 'inc-intent',
        type: SupportingEvidenceType.note,
        createdAt: DateTime.utc(2026, 8, 24, 12),
        title: 'Note',
        integrityVerified: true,
        verification: VerificationFactory.initial(),
      );
      final noteMap = _supportingMap(supporting);
      expect(noteMap.containsKey('temporalIntent'), isFalse);
      expect(
        FirestoreSerializers.supportingFromMap(noteMap)!.temporalIntent,
        isNull,
      );
    });

    test('E invalid Firestore value hydrates safely as null', () {
      final controller = _controller();
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      controller.setTemporalIntent(
        evidenceId: voice,
        intent: EvidenceTemporalIntent.chronological,
      );
      final map = _capturedMap(
        controller.evidenceRepository.capturedById(voice)!,
      );
      map['temporalIntent'] = 'primary';
      expect(
        FirestoreSerializers.capturedFromMap(map)!.temporalIntent,
        isNull,
      );
      map['temporalIntent'] = '';
      expect(
        FirestoreSerializers.capturedFromMap(map)!.temporalIntent,
        isNull,
      );
      map['temporalIntent'] = 3;
      expect(
        FirestoreSerializers.capturedFromMap(map)!.temporalIntent,
        isNull,
      );

      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setTemporalIntent(
        evidenceId: note,
        intent: EvidenceTemporalIntent.context,
      );
      final noteMap = _supportingMap(
        controller.evidenceRepository.supportingById(note)!,
      );
      noteMap['temporalIntent'] = 'unknown';
      expect(
        FirestoreSerializers.supportingFromMap(noteMap)!.temporalIntent,
        isNull,
      );
    });

    test('F Voice can persist chronological', () {
      final controller = _controller();
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      controller.setTemporalIntent(
        evidenceId: voice,
        intent: EvidenceTemporalIntent.chronological,
      );
      expect(
        _intentOf(controller, voice),
        EvidenceTemporalIntent.chronological,
      );
      final restored = FirestoreSerializers.capturedFromMap(
        _capturedMap(controller.evidenceRepository.capturedById(voice)!),
      )!;
      expect(restored.temporalIntent, EvidenceTemporalIntent.chronological);
    });

    test('G Voice can persist context', () {
      final controller = _controller();
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      controller.setTemporalIntent(
        evidenceId: voice,
        intent: EvidenceTemporalIntent.context,
      );
      expect(_intentOf(controller, voice), EvidenceTemporalIntent.context);
      final restored = FirestoreSerializers.capturedFromMap(
        _capturedMap(controller.evidenceRepository.capturedById(voice)!),
      )!;
      expect(restored.temporalIntent, EvidenceTemporalIntent.context);
    });

    test('H Text can persist chronological', () {
      final controller = _controller();
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setTemporalIntent(
        evidenceId: note,
        intent: EvidenceTemporalIntent.chronological,
      );
      expect(
        _intentOf(controller, note),
        EvidenceTemporalIntent.chronological,
      );
      final restored = FirestoreSerializers.supportingFromMap(
        _supportingMap(controller.evidenceRepository.supportingById(note)!),
      )!;
      expect(restored.temporalIntent, EvidenceTemporalIntent.chronological);
    });

    test('I Text can persist context', () {
      final controller = _controller();
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setTemporalIntent(
        evidenceId: note,
        intent: EvidenceTemporalIntent.context,
      );
      expect(_intentOf(controller, note), EvidenceTemporalIntent.context);
      final restored = FirestoreSerializers.supportingFromMap(
        _supportingMap(controller.evidenceRepository.supportingById(note)!),
      )!;
      expect(restored.temporalIntent, EvidenceTemporalIntent.context);
    });
  });

  group('O-13 Inspector', () {
    testWidgets('J Inspector does not show chronology/context radios',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 900));
      final controller = _controller();
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      final evidence = controller.currentIncident.evidenceById(voice)!;
      await _openInspector(
        tester,
        controller: controller,
        evidence: evidence,
      );
      expect(
        find.byKey(const Key('evidence_inspector_timeline_role')),
        findsNothing,
      );
      expect(find.text('Chronological'), findsNothing);
      expect(find.text('Part of the event timeline'), findsNothing);
      expect(find.text('Supporting context, not a timeline event'), findsNothing);
    });

    testWidgets('K Inspector does not classify chronology/context',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 900));
      final controller = _controller();
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      final evidence = controller.currentIncident.evidenceById(note)!;
      await _openInspector(
        tester,
        controller: controller,
        evidence: evidence,
      );
      expect(
        find.byKey(const Key('evidence_inspector_timeline_role_chronological')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('evidence_inspector_timeline_role_context')),
        findsNothing,
      );
      expect(_intentOf(controller, note), isNull);
    });

    testWidgets('L archived evidence cannot mutate intent', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 900));
      final controller = _controller();
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      IncidentLibraryService.instance.summaries = [
        const LibraryIncidentSummary(
          id: 'inc-intent',
          title: 'Case',
          evidenceCount: 1,
          contextEnrichedCount: 0,
          integrityVerified: true,
          lastPreserved: 'Today',
        ),
      ];
      await IncidentLibraryService.instance.archiveIncident('inc-intent');
      expect(controller.isArchivedReadOnly, isTrue);
      expect(
        controller.setTemporalIntent(
          evidenceId: voice,
          intent: EvidenceTemporalIntent.chronological,
        ),
        isFalse,
      );
      expect(_intentOf(controller, voice), isNull);

      final evidence = controller.currentIncident.evidenceById(voice)!;
      await _openInspector(
        tester,
        controller: controller,
        evidence: evidence,
      );
      expect(
        find.byKey(const Key('evidence_inspector_timeline_role')),
        findsNothing,
      );
      expect(find.text('Chronological'), findsNothing);
      expect(
        find.byKey(const Key('evidence_inspector_timeline_role_context')),
        findsNothing,
      );
    });
  });

  group('O-13 integrity isolation', () {
    test('M/N changing intent does not alter identity, clocks, or graph', () {
      final controller = _controller();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final voice = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.voice,
      );
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setOrganizeContextAnchor(
        contextEvidenceId: note,
        capturedEvidenceId: photo,
      );
      final collection = controller.createUserEvidenceCollection(
        evidenceIds: [photo, note],
      );
      expect(collection, isNotNull);

      final frozenVoice = _frozenEvidence(controller, voice);
      final frozenNote = _frozenEvidence(controller, note);
      final sequenceBefore = _sequence(controller);
      final timelineBefore = _timelineOrder(controller);
      final anchorsBefore = List.of(
        controller.aggregate.store.timelineAnchors,
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

      controller.setTemporalIntent(
        evidenceId: voice,
        intent: EvidenceTemporalIntent.context,
      );
      controller.setTemporalIntent(
        evidenceId: note,
        intent: EvidenceTemporalIntent.chronological,
      );

      expect(_frozenEvidence(controller, voice), frozenVoice);
      expect(_frozenEvidence(controller, note), frozenNote);
      expect(_sequence(controller), sequenceBefore);
      expect(_timelineOrder(controller), timelineBefore);
      expect(controller.aggregate.store.timelineAnchors, anchorsBefore);
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
    });

    test(
      'O/P/Q/R/S/T origin, 3E API, Inspector order, and sequence stay identical',
      () {
        final controller = _controller();
        final photo = controller.preserveEvidenceAndReturnId(
          WorkspaceCaptureMode.photo,
        );
        final captureVoice = controller.preserveEvidenceAndReturnId(
          WorkspaceCaptureMode.voice,
        );
        final captureNote = controller.preserveEvidenceAndReturnId(
          WorkspaceCaptureMode.note,
        );
        final orgVoice = controller.addOrganizeContextEvidence(
          WorkspaceCaptureMode.voice,
        );
        final orgNote = controller.addOrganizeContextEvidence(
          WorkspaceCaptureMode.note,
        );

        final createdBefore = Set<String>.from(
          controller.organizeCreatedEvidenceIds,
        );
        final inspectorBefore = [
          for (final item in evidenceInspectorOrder(
            controller.journeyEvidenceItems,
            incidentId: controller.currentIncident.id,
          ))
            item.id,
        ];
        final sequenceBefore = _sequence(controller);

        expect(_intentOf(controller, photo), isNull);
        expect(_intentOf(controller, captureVoice), isNull);
        expect(_intentOf(controller, captureNote), isNull);
        expect(_intentOf(controller, orgVoice), isNull);
        expect(_intentOf(controller, orgNote), isNull);

        controller.setTemporalIntent(
          evidenceId: orgVoice,
          intent: EvidenceTemporalIntent.chronological,
        );
        controller.setTemporalIntent(
          evidenceId: orgNote,
          intent: EvidenceTemporalIntent.context,
        );
        controller.setTemporalIntent(
          evidenceId: captureVoice,
          intent: EvidenceTemporalIntent.context,
        );
        controller.setTemporalIntent(
          evidenceId: captureNote,
          intent: EvidenceTemporalIntent.chronological,
        );

        expect(controller.organizeCreatedEvidenceIds, createdBefore);
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
        expect(_sequence(controller), sequenceBefore);
      },
    );
  });

  group('O-13 Organize create choice sheet', () {
    testWidgets('skip / dismiss persist null', (tester) async {
      EvidenceTemporalIntent? result = EvidenceTemporalIntent.chronological;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await TimelineRoleChoiceSheet.open(
                    context,
                    prompt:
                        EvidenceInspectorSemantics.timelineRoleVoicePrompt,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text(EvidenceInspectorSemantics.timelineRoleVoicePrompt),
        findsOneWidget,
      );
      await tester.tap(find.byKey(TimelineRoleChoiceSheet.skipKey));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('choosing chronological returns chronological', (tester) async {
      EvidenceTemporalIntent? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await TimelineRoleChoiceSheet.open(
                    context,
                    prompt: EvidenceInspectorSemantics.timelineRoleNotePrompt,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TimelineRoleChoiceSheet.chronologicalKey));
      await tester.pumpAndSettle();
      expect(result, EvidenceTemporalIntent.chronological);
    });
  });
}
