import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/domain/organize/organize_floating_context_layout.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_composition_matrix.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:evidence_vault/widgets/workspace/product_concept_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    contentHash: 'hash-$id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-ctx-ix',
  );
}

CurrentIncident _incident({required List<WorkspaceEvidenceItem> evidence}) {
  return CurrentIncident(
    id: 'inc-ctx-ix',
    title: 'Street Fight',
    status: IncidentStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    manuallyComplete: false,
    journeyStage: JourneyStage.building,
    captureProgressPercent: 0,
    timelineAnchorCount: evidence.length,
    relationshipGroupCount: 0,
    narrativeEventCount: 0,
    evidence: evidence,
    journeyEvidence: evidence,
    relationshipGroups: const [],
    evidenceCollections: const [],
    trustPackageReady: evidence.isNotEmpty,
    trustPackageProgressPercent: 40,
  );
}

Future<void> _pumpCanvas(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> ordered,
  Set<String> organizeCreatedIds = const {},
  List<OrganizeContextAnchor> anchors = const [],
  void Function(String contextId, String capturedId)? onSetContextAnchor,
  ValueChanged<String>? onClearContextAnchor,
  ValueChanged<String>? onDiscardUnsnapped,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeChronologyCanvas(
          ordered: ordered,
          allEvidence: ordered,
          organizeCreatedIds: organizeCreatedIds,
          anchors: anchors,
          onEvidenceSelected: (_) {},
          onSetContextAnchor: onSetContextAnchor ?? (_, _) {},
          onClearContextAnchor: onClearContextAnchor,
          onDiscardUnsnapped: onDiscardUnsnapped,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpView(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> evidence,
  Set<String> organizeCreatedIds = const {},
  List<OrganizeContextAnchor> anchors = const [],
  void Function(String contextId, String capturedId)? onSetContextAnchor,
  ValueChanged<String>? onClearContextAnchor,
  ValueChanged<String>? onDiscardUnsnappedContext,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final capturedIds = [
    for (final item in evidence)
      if (!organizeCreatedIds.contains(item.id)) item.id,
  ];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: _incident(evidence: evidence),
          orderedCapturedEvidenceIds: capturedIds,
          organizeCreatedIds: organizeCreatedIds,
          contextAnchors: anchors,
          onEvidenceSelected: (_) {},
          onSetContextAnchor: onSetContextAnchor ?? (_, _) {},
          onClearContextAnchor: onClearContextAnchor,
          onDiscardUnsnappedContext: onDiscardUnsnappedContext,
          onAddOrganizeContext: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void _expectSnappedBeside(
  WidgetTester tester, {
  required String contextId,
  required String capturedId,
}) {
  final contextRect = tester.getRect(
    find.byKey(OrganizeChronologyCanvas.contextTileKey(contextId)),
  );
  final capturedRect = tester.getRect(
    find.byKey(OrganizeChronologyCanvas.fixedTileKey(capturedId)),
  );
  final snapLeft =
      capturedRect.right + OrganizeFloatingContextLayout.fingerGap;
  expect(
    (contextRect.left - snapLeft).abs(),
    lessThan(16),
    reason: 'context must align horizontally with $capturedId',
  );
  expect(
    (contextRect.center.dy - capturedRect.center.dy).abs(),
    lessThan(36),
    reason: 'context must sit beside $capturedId',
  );
}

Future<void> _armAndDragAway(
  WidgetTester tester,
  String contextId, {
  Offset delta = const Offset(220, 160),
}) async {
  final finder = find.byKey(OrganizeChronologyCanvas.contextTileKey(contextId));
  await tester.tap(finder);
  await tester.pump();
  final gesture = await tester.startGesture(
    tester.getCenter(finder) + const Offset(16, 16),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(delta);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  final t0 = DateTime(2026, 8, 25, 10, 42);
  final photo = _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0);
  final photoB = _item(
    id: 'photo-b',
    kind: WorkspaceEvidenceKind.image,
    at: t0.add(const Duration(minutes: 2)),
  );
  final note = _item(
    id: 'note-org',
    kind: WorkspaceEvidenceKind.note,
    at: t0.add(const Duration(seconds: 20)),
  );
  final noteB = _item(
    id: 'note-b',
    kind: WorkspaceEvidenceKind.note,
    at: t0.add(const Duration(seconds: 30)),
  );

  test('1 minus deletes only that Organize context from the store', () async {
    WorkspaceEvidenceFactory.resetForTests();
    SharedPreferences.setMockInitialValues({});
    addTearDown(WorkspaceEvidenceFactory.useProductionIds);

    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-ctx-ix', title: 'Case'),
    );
    final photoId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final keepId = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    final dropId = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    final chronologyBefore = List.of(
      controller.timelineRepository.orderedCapturedEvidenceIds(),
    );

    await controller.discardUnsnappedOrganizeContext(dropId);

    final ids = [for (final item in controller.currentIncident.evidence) item.id];
    expect(ids, isNot(contains(dropId)));
    expect(ids, containsAll([photoId, keepId]));
    expect(controller.organizeCreatedEvidenceIds, isNot(contains(dropId)));
    expect(controller.organizeCreatedEvidenceIds, contains(keepId));
    expect(
      controller.timelineRepository.orderedCapturedEvidenceIds(),
      chronologyBefore,
    );
  });

  testWidgets('1b minus on a wobbling context removes it from Organize', (
    tester,
  ) async {
    var ordered = [photo, note, noteB];
    final created = <String>{'note-org', 'note-b'};
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeChronologyCanvas(
                ordered: ordered,
                allEvidence: ordered,
                organizeCreatedIds: created,
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (_, _) {},
                onDiscardUnsnapped: (id) {
                  setState(() {
                    ordered = [
                      for (final item in ordered)
                        if (item.id != id) item,
                    ];
                    created.remove(id);
                  });
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(
      find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
    );
    await tester.pump();
    expect(find.byKey(const Key('organize_context_delete_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('organize_context_delete_ok')));
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      findsOneWidget,
    );
  });

  Future<WorkspaceEvidenceController> liveController() async {
    WorkspaceEvidenceFactory.resetForTests();
    SharedPreferences.setMockInitialValues({});
    addTearDown(WorkspaceEvidenceFactory.useProductionIds);
    return WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-ctx-ix', title: 'Case'),
    );
  }

  Future<void> pumpLiveOrganize(
    WidgetTester tester,
    WorkspaceEvidenceController controller,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final created = controller.organizeCreatedEvidenceIds;
              return OrganizeWorkspaceView(
                incident: controller.currentIncident,
                organizeCreatedIds: created,
                contextAnchors: controller.organizeContextAnchors,
                orderedCapturedEvidenceIds:
                    controller.timelineRepository.orderedCapturedEvidenceIds(),
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  controller.setOrganizeContextAnchor(
                    contextEvidenceId: contextId,
                    capturedEvidenceId: capturedId,
                  );
                },
                onClearContextAnchor: controller.clearOrganizeContextAnchor,
                onDiscardUnsnappedContext:
                    controller.discardUnsnappedOrganizeContext,
                onAddOrganizeContext: controller.addOrganizeContextEvidence,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> expectDiscardedAfterRebuild(
    WidgetTester tester,
    WorkspaceEvidenceController controller,
    String contextId,
  ) async {
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(contextId)),
      findsNothing,
    );
    expect(controller.organizeCreatedEvidenceIds, isNot(contains(contextId)));
    expect(
      [for (final item in controller.currentIncident.evidence) item.id],
      isNot(contains(contextId)),
    );

    await pumpLiveOrganize(tester, controller);
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(contextId)),
      findsNothing,
    );
    expect(controller.organizeCreatedEvidenceIds, isNot(contains(contextId)));
  }

  Future<void> addDiscardAndRebuild(
    WidgetTester tester, {
    required WorkspaceCaptureMode mode,
  }) async {
    final controller = await liveController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final contextId = controller.addOrganizeContextEvidence(mode);
    await pumpLiveOrganize(tester, controller);

    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(contextId)),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.discardKey(contextId)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OrganizePlacementWobble>(
            find.byKey(
              OrganizeChronologyCanvas.awaitingPlacementKey(contextId),
            ),
          )
          .active,
      isTrue,
    );

    await tester.tap(
      find.byKey(OrganizeChronologyCanvas.discardKey(contextId)),
    );
    await tester.pump();
    expect(find.byKey(const Key('organize_context_delete_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('organize_context_delete_ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectDiscardedAfterRebuild(tester, controller, contextId);
  }

  testWidgets('A minus deletes a wobbling voice context and it stays gone', (
    tester,
  ) async {
    await addDiscardAndRebuild(tester, mode: WorkspaceCaptureMode.voice);
  });

  testWidgets('B minus deletes a wobbling text context and it stays gone', (
    tester,
  ) async {
    await addDiscardAndRebuild(tester, mode: WorkspaceCaptureMode.note);
  });

  testWidgets('C minus deletes a wobbling file context and it stays gone', (
    tester,
  ) async {
    await addDiscardAndRebuild(tester, mode: WorkspaceCaptureMode.file);
  });

  testWidgets('D minus deletes only the middle floating context', (
    tester,
  ) async {
    final controller = await liveController();
    final photoId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final voice = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.voice,
    );
    final text = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    final file = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.file,
    );
    await pumpLiveOrganize(tester, controller);

    final voiceBefore = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(voice)),
    );
    await tester.tap(find.byKey(OrganizeChronologyCanvas.discardKey(text)));
    await tester.pump();
    expect(find.byKey(const Key('organize_context_delete_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('organize_context_delete_ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(text)),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(voice)),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(file)),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey(photoId)),
      findsOneWidget,
    );

    final voiceAfter = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(voice)),
    );
    final fileAfter = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(file)),
    );
    expect(voiceAfter.width, greaterThan(0));
    expect(fileAfter.width, greaterThan(0));
    expect(
      OrganizeFloatingContextLayout.rectsOverlap(voiceAfter, fileAfter),
      isFalse,
    );
    expect(
      (voiceAfter.center - voiceBefore.center).distance,
      lessThan(120),
    );
    expect(controller.organizeCreatedEvidenceIds, containsAll([voice, file]));
    expect(controller.organizeCreatedEvidenceIds, isNot(contains(text)));
    expect(
      [for (final item in controller.currentIncident.evidence) item.id],
      containsAll([photoId, voice, file]),
    );
    expect(
      [for (final item in controller.currentIncident.evidence) item.id],
      isNot(contains(text)),
    );
  });

  testWidgets('E deleted wobbling context stays gone after leaving Organize', (
    tester,
  ) async {
    final controller = await liveController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final note = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    await pumpLiveOrganize(tester, controller);

    await tester.tap(find.byKey(OrganizeChronologyCanvas.discardKey(note)));
    await tester.pump();
    expect(find.byKey(const Key('organize_context_delete_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('organize_context_delete_ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
      findsNothing,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    final restored = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.fromStore(
        IncidentStore(
          incident: controller.aggregate.store.incident,
          capturedEvidence: List.of(controller.aggregate.store.capturedEvidence),
          supportingEvidence: List.of(
            controller.aggregate.store.supportingEvidence,
          ),
          timelineAnchors: List.of(controller.aggregate.store.timelineAnchors),
          relationships: List.of(controller.aggregate.store.relationships),
          relationshipGroups: List.of(
            controller.aggregate.store.relationshipGroups,
          ),
        ),
      ),
    );
    await restored.restoreOrganizeContextPersistence();
    await pumpLiveOrganize(tester, restored);

    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
      findsNothing,
    );
    expect(restored.organizeCreatedEvidenceIds, isNot(contains(note)));
    expect(
      [for (final item in restored.currentIncident.evidence) item.id],
      isNot(contains(note)),
    );
  });

  testWidgets(
    'F discarding a wobbling context does not change preserved evidence',
    (tester) async {
      final controller = await liveController();
      final photoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final photoBefore = controller.currentIncident.evidence.firstWhere(
        (item) => item.id == photoId,
      );
      final chronologyBefore = List.of(
        controller.timelineRepository.orderedCapturedEvidenceIds(),
      );
      final groupsBefore = List.of(
        controller.currentIncident.relationshipGroups,
      );
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      await pumpLiveOrganize(tester, controller);

      expect(
        find.byKey(OrganizeChronologyCanvas.discardKey(photoId)),
        findsNothing,
      );

      await tester.tap(find.byKey(OrganizeChronologyCanvas.discardKey(note)));
      await tester.pump();
      expect(find.byKey(const Key('organize_context_delete_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('organize_context_delete_ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final photoAfter = controller.currentIncident.evidence.firstWhere(
        (item) => item.id == photoId,
      );
      expect(photoAfter.id, photoBefore.id);
      expect(photoAfter.contentHash, photoBefore.contentHash);
      expect(photoAfter.capturedAt, photoBefore.capturedAt);
      expect(photoAfter.recordedAt, photoBefore.recordedAt);
      expect(photoAfter.lastPreservedAt, photoBefore.lastPreservedAt);
      expect(
        controller.timelineRepository.orderedCapturedEvidenceIds(),
        chronologyBefore,
      );
      expect(controller.currentIncident.relationshipGroups, groupsBefore);
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(photoId)),
        findsOneWidget,
      );
      expect(
        [for (final item in controller.currentIncident.evidence) item.id],
        isNot(contains(note)),
      );
    },
  );

  testWidgets('2 snap associates the context with the intended evidence', (
    tester,
  ) async {
    final anchors = <OrganizeContextAnchor>[];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeChronologyCanvas(
                ordered: [photo, photoB, note],
                allEvidence: [photo, photoB, note],
                organizeCreatedIds: const {'note-org'},
                anchors: List.of(anchors),
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  setState(() {
                    anchors
                      ..clear()
                      ..add(
                        OrganizeContextAnchor(
                          contextEvidenceId: contextId,
                          capturedEvidenceId: capturedId,
                        ),
                      );
                  });
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      ) +
          const Offset(16, 16),
    );
    await tester.pump(
      const Duration(milliseconds: 500) + const Duration(milliseconds: 100),
    );
    await gesture.moveTo(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo-b')),
      ),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(anchors, hasLength(1));
    expect(anchors.single.contextEvidenceId, 'note-org');
    expect(anchors.single.capturedEvidenceId, 'photo-b');
    _expectSnappedBeside(
      tester,
      contextId: 'note-org',
      capturedId: 'photo-b',
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note-org')),
      findsOneWidget,
    );
  });

  testWidgets('3 snapped context follows its evidence while chronology scrolls', (
    tester,
  ) async {
    await _pumpView(
      tester,
      evidence: [
        for (var i = 0; i < 12; i++)
          _item(
            id: 'cap-$i',
            kind: WorkspaceEvidenceKind.image,
            at: t0.add(Duration(minutes: i)),
          ),
        note,
      ],
      organizeCreatedIds: const {'note-org'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'cap-0',
        ),
      ],
    );

    final photoBefore = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('cap-0')),
    );
    final contextBefore = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
    );

    await tester.drag(
      find.byKey(OrganizeWorkspaceView.viewKey),
      const Offset(0, -280),
    );
    await tester.pump();

    final photoAfter = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('cap-0')),
    );
    final contextAfter = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
    );
    expect(photoAfter.dy, isNot(closeTo(photoBefore.dy, 1)));
    expect(
      contextAfter.dy - contextBefore.dy,
      closeTo(photoAfter.dy - photoBefore.dy, 2),
    );
  });

  testWidgets('4 remove-placement action no longer exists', (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [photo, note],
      organizeCreatedIds: const {'note-org'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
      ],
      onClearContextAnchor: (_) {},
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.unplaceKey('note-org')),
      findsNothing,
    );
    expect(find.text(OrganizeChronologyCanvas.unplaceLabel), findsNothing);
    expect(find.text('Remove placement'), findsNothing);
  });

  testWidgets('5 tapping a snapped context enters wobble with minus', (
    tester,
  ) async {
    await _pumpCanvas(
      tester,
      ordered: [photo, note],
      organizeCreatedIds: const {'note-org'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
      ],
      onClearContextAnchor: (_) {},
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
      findsNothing,
    );
    expect(
      tester
          .widget<OrganizePlacementWobble>(
            find.byKey(
              OrganizeChronologyCanvas.awaitingPlacementKey('note-org'),
            ),
          )
          .active,
      isFalse,
    );

    await tester.tap(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
    );
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OrganizePlacementWobble>(
            find.byKey(
              OrganizeChronologyCanvas.awaitingPlacementKey('note-org'),
            ),
          )
          .active,
      isTrue,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note-org')),
      findsOneWidget,
    );
  });

  testWidgets('6 dragging a wobbling snapped context away removes the link', (
    tester,
  ) async {
    final cleared = <String>[];
    await _pumpCanvas(
      tester,
      ordered: [photo, note],
      organizeCreatedIds: const {'note-org'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
      ],
      onClearContextAnchor: cleared.add,
    );

    await _armAndDragAway(tester, 'note-org');
    expect(cleared, ['note-org']);
  });

  testWidgets('7 more than four clustered contexts show an internal scrollbar', (
    tester,
  ) async {
    final extras = [
      for (var i = 0; i < 5; i++)
        _item(
          id: 'ctx-$i',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(Duration(seconds: 20 + i)),
        ),
    ];
    await _pumpView(
      tester,
      evidence: [photo, ...extras],
      organizeCreatedIds: {for (final item in extras) item.id},
      anchors: [
        for (final item in extras)
          OrganizeContextAnchor(
            contextEvidenceId: item.id,
            capturedEvidenceId: 'photo',
          ),
      ],
    );

    await tester.tap(find.byKey(OrganizeChronologyCanvas.clusterKey('photo')));
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.clusterModalScrollbarKey),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Scrollbar>(
            find.byKey(OrganizeChronologyCanvas.clusterModalScrollbarKey),
          )
          .thickness,
      5,
    );

    await tester.tapAt(
      tester.getRect(find.byKey(OrganizeChronologyCanvas.clusterScrimKey)).topLeft +
          const Offset(12, 12),
    );
    await tester.pump();

    await _pumpView(
      tester,
      evidence: [photo, note, noteB],
      organizeCreatedIds: const {'note-org', 'note-b'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
        OrganizeContextAnchor(
          contextEvidenceId: 'note-b',
          capturedEvidenceId: 'photo',
        ),
      ],
    );
    await tester.tap(find.byKey(OrganizeChronologyCanvas.clusterKey('photo')));
    await tester.pump();
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterModalScrollbarKey),
      findsNothing,
    );
  });

  testWidgets('8 press-hold in the expanded modal enters wobble with minus', (
    tester,
  ) async {
    await _pumpView(
      tester,
      evidence: [photo, note, noteB],
      organizeCreatedIds: const {'note-org', 'note-b'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
        OrganizeContextAnchor(
          contextEvidenceId: 'note-b',
          capturedEvidenceId: 'photo',
        ),
      ],
    );

    await tester.tap(find.byKey(OrganizeChronologyCanvas.clusterKey('photo')));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.clusterItemKey('note-org')),
      ),
    );
    await tester.pump(
      OrganizeChronologyCanvas.dragStartDelay +
          const Duration(milliseconds: 80),
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OrganizePlacementWobble>(
            find.byKey(
              OrganizeChronologyCanvas.awaitingPlacementKey('note-org'),
            ),
          )
          .active,
      isTrue,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.discardKey('note-b')),
      findsNothing,
    );

    await gesture.up();
    await tester.pump();
  });

  testWidgets('9 dragging a modal context out unlinks it as free-floating', (
    tester,
  ) async {
    var anchors = <OrganizeContextAnchor>[
      const OrganizeContextAnchor(
        contextEvidenceId: 'note-org',
        capturedEvidenceId: 'photo',
      ),
      const OrganizeContextAnchor(
        contextEvidenceId: 'note-b',
        capturedEvidenceId: 'photo',
      ),
    ];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeWorkspaceView(
                incident: _incident(evidence: [photo, note, noteB]),
                orderedCapturedEvidenceIds: const ['photo'],
                organizeCreatedIds: const {'note-org', 'note-b'},
                contextAnchors: List.of(anchors),
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  setState(() {
                    anchors = [
                      for (final anchor in anchors)
                        if (anchor.contextEvidenceId != contextId) anchor,
                      OrganizeContextAnchor(
                        contextEvidenceId: contextId,
                        capturedEvidenceId: capturedId,
                      ),
                    ];
                  });
                },
                onClearContextAnchor: (id) {
                  setState(() {
                    anchors = [
                      for (final anchor in anchors)
                        if (anchor.contextEvidenceId != id) anchor,
                    ];
                  });
                },
                onAddOrganizeContext: (_) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(OrganizeChronologyCanvas.clusterKey('photo')));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.clusterItemKey('note-org')),
      ),
    );
    await tester.pump(
      OrganizeChronologyCanvas.dragStartDelay +
          const Duration(milliseconds: 80),
    );
    await gesture.moveTo(const Offset(16, 16));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      anchors.any((anchor) => anchor.contextEvidenceId == 'note-org'),
      isFalse,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterModalKey),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterKey('photo')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note-org')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-b')),
      findsOneWidget,
    );
    _expectSnappedBeside(
      tester,
      contextId: 'note-b',
      capturedId: 'photo',
    );
  });

  testWidgets('10 a single linked context never creates a modal', (
    tester,
  ) async {
    await _pumpView(
      tester,
      evidence: [photo, note],
      organizeCreatedIds: const {'note-org'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
      ],
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.clusterKey('photo')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterModalKey),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterArrowKey('photo')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      findsOneWidget,
    );
    _expectSnappedBeside(
      tester,
      contextId: 'note-org',
      capturedId: 'photo',
    );
  });

  testWidgets('11 multi-context modal dissolves when one context remains', (
    tester,
  ) async {
    var anchors = <OrganizeContextAnchor>[
      const OrganizeContextAnchor(
        contextEvidenceId: 'note-org',
        capturedEvidenceId: 'photo',
      ),
      const OrganizeContextAnchor(
        contextEvidenceId: 'note-b',
        capturedEvidenceId: 'photo',
      ),
    ];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeWorkspaceView(
                incident: _incident(evidence: [photo, note, noteB]),
                orderedCapturedEvidenceIds: const ['photo'],
                organizeCreatedIds: const {'note-org', 'note-b'},
                contextAnchors: List.of(anchors),
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (_, _) {},
                onClearContextAnchor: (id) {
                  setState(() {
                    anchors = [
                      for (final anchor in anchors)
                        if (anchor.contextEvidenceId != id) anchor,
                    ];
                  });
                },
                onAddOrganizeContext: (_) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(OrganizeChronologyCanvas.clusterKey('photo')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(OrganizeChronologyCanvas.clusterKey('photo')));
    await tester.pump();
    expect(find.byKey(OrganizeChronologyCanvas.clusterModalKey), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.clusterItemKey('note-org')),
      ),
    );
    await tester.pump(
      OrganizeChronologyCanvas.dragStartDelay +
          const Duration(milliseconds: 80),
    );
    await gesture.moveTo(const Offset(16, 16));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.clusterModalKey),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterKey('photo')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-b')),
      findsOneWidget,
    );
    _expectSnappedBeside(
      tester,
      contextId: 'note-b',
      capturedId: 'photo',
    );
  });

  testWidgets('grouped contexts keep an evidence-to-modal arrow', (tester) async {
    await _pumpView(
      tester,
      evidence: [photo, note, noteB],
      organizeCreatedIds: const {'note-org', 'note-b'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
        OrganizeContextAnchor(
          contextEvidenceId: 'note-b',
          capturedEvidenceId: 'photo',
        ),
      ],
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.clusterArrowKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note-org')),
      findsNothing,
    );

    await tester.tap(find.byKey(OrganizeChronologyCanvas.clusterKey('photo')));
    await tester.pump();
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterArrowKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterExpandedArrowKey('photo')),
      findsOneWidget,
    );
  });

  testWidgets('cluster arrow follows its evidence while chronology scrolls', (
    tester,
  ) async {
    await _pumpView(
      tester,
      evidence: [
        for (var i = 0; i < 12; i++)
          _item(
            id: 'cap-$i',
            kind: WorkspaceEvidenceKind.image,
            at: t0.add(Duration(minutes: i)),
          ),
        note,
        noteB,
      ],
      organizeCreatedIds: const {'note-org', 'note-b'},
      anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'cap-0',
        ),
        OrganizeContextAnchor(
          contextEvidenceId: 'note-b',
          capturedEvidenceId: 'cap-0',
        ),
      ],
    );

    final photoBefore = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('cap-0')),
    );
    final arrowBefore = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.clusterArrowKey('cap-0')),
    );

    await tester.drag(
      find.byKey(OrganizeWorkspaceView.viewKey),
      const Offset(0, -280),
    );
    await tester.pump();

    final photoAfter = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('cap-0')),
    );
    final arrowAfter = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.clusterArrowKey('cap-0')),
    );
    expect(photoAfter.dy, isNot(closeTo(photoBefore.dy, 1)));
    expect(
      arrowAfter.dy - arrowBefore.dy,
      closeTo(photoAfter.dy - photoBefore.dy, 2),
    );
  });

  testWidgets('white overflow scrollbar is on collapsed and expanded modal', (
    tester,
  ) async {
    final extras = [
      for (var i = 0; i < 5; i++)
        _item(
          id: 'ctx-$i',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(Duration(seconds: 20 + i)),
        ),
    ];
    await _pumpView(
      tester,
      evidence: [photo, ...extras],
      organizeCreatedIds: {for (final item in extras) item.id},
      anchors: [
        for (final item in extras)
          OrganizeContextAnchor(
            contextEvidenceId: item.id,
            capturedEvidenceId: 'photo',
          ),
      ],
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.clusterChipScrollbarKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterModalScrollbarKey),
      findsNothing,
    );

    await tester.tap(find.byKey(OrganizeChronologyCanvas.clusterKey('photo')));
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.clusterChipScrollbarKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterModalScrollbarKey),
      findsOneWidget,
    );
  });

  testWidgets('Organize copy is updated and stays within two lines', (
    tester,
  ) async {
    await _pumpView(
      tester,
      evidence: [photo, note],
      organizeCreatedIds: const {'note-org'},
    );

    expect(find.text('Evidence structure'), findsNothing);
    expect(
      OrganizeChronologyCanvas.placementGuidance,
      'Captured context placed beside a captured moment — does not change chronology',
    );
    final guidance = tester.widget<Text>(
      find.byKey(OrganizeChronologyCanvas.placementGuidanceKey),
    );
    expect(guidance.maxLines, 2);
    expect(guidance.data, OrganizeChronologyCanvas.placementGuidance);
    final size = tester.getSize(
      find.byKey(OrganizeChronologyCanvas.placementGuidanceKey),
    );
    expect(size.height, lessThanOrEqualTo(11 * 1.25 * 2 + 4));
  });

  testWidgets(
    'information view presents the product concept chart, not incident composition',
    (tester) async {
      await _pumpView(
        tester,
        evidence: [photo, photoB, note, noteB],
        organizeCreatedIds: const {'note-org', 'note-b'},
        anchors: const [
          OrganizeContextAnchor(
            contextEvidenceId: 'note-org',
            capturedEvidenceId: 'photo',
          ),
        ],
      );

      await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(ProductConceptChart.chartKey),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeCompositionMatrix.matrixKey),
        findsNothing,
      );
      expect(find.textContaining('This incident'), findsNothing);
      expect(
        find.byKey(ProductConceptChart.captureKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ProductConceptChart.organizeKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ProductConceptChart.investigateKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ProductConceptChart.groupsKey),
        findsOneWidget,
      );
      expect(
        find.byKey(ProductConceptChart.connectionsKey),
        findsOneWidget,
      );
    },
  );
}
