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
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/inspector_record_sections.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:evidence_vault/theme/organize_visuals.dart';
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
    incidentId: 'inc-refine',
    fileName: kind == WorkspaceEvidenceKind.attachment ? '$id.pdf' : null,
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
}) {
  return CurrentIncident(
    id: 'inc-refine',
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

Future<void> _pumpView(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> evidence,
  Set<String> organizeCreatedIds = const {},
  List<OrganizeContextAnchor> anchors = const [],
  void Function(String contextId, String capturedId)? onSetContextAnchor,
  ValueChanged<String>? onDiscardUnsnappedContext,
  ValueChanged<WorkspaceCaptureMode>? onAddOrganizeContext,
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
          onDiscardUnsnappedContext: onDiscardUnsnappedContext,
          onAddOrganizeContext: onAddOrganizeContext ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpCanvas(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> ordered,
  Set<String> organizeCreatedIds = const {},
  List<OrganizeContextAnchor> anchors = const [],
  void Function(String contextId, String capturedId)? onSetContextAnchor,
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
          onDiscardUnsnapped: onDiscardUnsnapped,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void _expectNotSnappedBesideSpine(
  WidgetTester tester, {
  required String contextId,
  required List<String> capturedIds,
}) {
  final contextRect = tester.getRect(
    find.byKey(OrganizeChronologyCanvas.contextTileKey(contextId)),
  );
  for (final id in capturedIds) {
    final finder = find.byKey(OrganizeChronologyCanvas.fixedTileKey(id));
    if (finder.evaluate().isEmpty) {
      continue;
    }
    final capturedRect = tester.getRect(finder);
    final snapLeft =
        capturedRect.right + OrganizeFloatingContextLayout.fingerGap;
    final alignedX = (contextRect.left - snapLeft).abs() < 16;
    final alignedY = (contextRect.center.dy - capturedRect.center.dy).abs() < 28;
    expect(
      alignedX && alignedY,
      isFalse,
      reason:
          'unsnapped context $contextId must not sit in the snapped slot beside $id',
    );
  }
  expect(
    find.byKey(OrganizeChronologyCanvas.contextArrowKey(contextId)),
    findsNothing,
  );
}

void main() {
  final t0 = DateTime(2026, 8, 25, 10, 42);
  final photo = _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0);
  final pdf = _item(
    id: 'pdf-large',
    kind: WorkspaceEvidenceKind.attachment,
    at: t0.add(const Duration(minutes: 1)),
  );
  final note = _item(
    id: 'note-org',
    kind: WorkspaceEvidenceKind.note,
    at: t0.add(const Duration(seconds: 20)),
  );

  testWidgets(
    '1 context never auto-aligns with the fixed spine after large PDF attachment',
    (tester) async {
      Future<void> pumpEvidence(List<WorkspaceEvidenceItem> evidence) {
        return _pumpView(
          tester,
          evidence: evidence,
          organizeCreatedIds: const {'note-org'},
        );
      }

      await pumpEvidence([photo, note]);
      _expectNotSnappedBesideSpine(
        tester,
        contextId: 'note-org',
        capturedIds: const ['photo'],
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
        findsOneWidget,
      );

      await pumpEvidence([
        photo,
        pdf,
        ...[
          for (var i = 0; i < 8; i++)
            _item(
              id: 'pdf-$i',
              kind: WorkspaceEvidenceKind.attachment,
              at: t0.add(Duration(minutes: 2 + i)),
            ),
        ],
        note,
      ]);
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('pdf-large')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('note-org')),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
        findsOneWidget,
      );
      _expectNotSnappedBesideSpine(
        tester,
        contextId: 'note-org',
        capturedIds: [
          'photo',
          'pdf-large',
          for (var i = 0; i < 8; i++) 'pdf-$i',
        ],
      );
    },
  );

  testWidgets(
    '2 context remains free-floating while chronology scrolls',
    (tester) async {
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
      );

      final before = tester.getTopLeft(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      );
      await tester.drag(
        find.byKey(OrganizeWorkspaceView.viewKey),
        const Offset(0, -280),
      );
      await tester.pump();

      final after = tester.getTopLeft(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      );
      expect(after.dy, closeTo(before.dy, 1));
      expect(after.dx, closeTo(before.dx, 1));
      expect(
        find.byKey(OrganizeChronologyCanvas.contextArrowKey('note-org')),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
        findsOneWidget,
      );
      _expectNotSnappedBesideSpine(
        tester,
        contextId: 'note-org',
        capturedIds: [for (var i = 0; i < 12; i++) 'cap-$i'],
      );
    },
  );

  testWidgets(
    '3 minus exists while unsnapped and disappears after successful snap',
    (tester) async {
      var discarded = <String>[];
      final anchors = <OrganizeContextAnchor>[];
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return OrganizeChronologyCanvas(
                  ordered: [photo, note],
                  allEvidence: [photo, note],
                  organizeCreatedIds: const {'note-org'},
                  anchors: List<OrganizeContextAnchor>.from(anchors),
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
                  onDiscardUnsnapped: (id) {
                    discarded.add(id);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
        findsOneWidget,
      );
      expect(discarded, isEmpty);

      final noteFinder =
          find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org'));
      final photoFinder =
          find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo'));
      final gesture = await tester.startGesture(tester.getCenter(noteFinder));
      await tester.pump(
        OrganizeChronologyCanvas.dragStartDelay +
            const Duration(milliseconds: 80),
      );
      await gesture.moveTo(tester.getCenter(photoFinder));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(anchors, hasLength(1));
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
    },
  );

  testWidgets('4 explicit drag is required before linking', (tester) async {
    var linked = false;
    await _pumpCanvas(
      tester,
      ordered: [photo, note],
      organizeCreatedIds: const {'note-org'},
      onSetContextAnchor: (_, _) {
        linked = true;
      },
    );

    expect(linked, isFalse);
    await tester.tap(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
    );
    await tester.pump();
    expect(linked, isFalse);

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.up();
    await tester.pump();
    expect(linked, isFalse);

    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note-org')),
      findsNothing,
    );
  });

  testWidgets(
    '5 multiple contexts on one evidence are collected into the modal',
    (tester) async {
      final noteB = _item(
        id: 'note-b',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 30)),
      );
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
        find.byKey(OrganizeChronologyCanvas.clusterKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.clusterArrowKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-b')),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.clusterModalKey),
        findsNothing,
      );
    },
  );

  testWidgets('6 modal supports >4 contexts via internal scrolling',
      (tester) async {
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

    expect(find.byKey(OrganizeChronologyCanvas.clusterModalKey), findsOneWidget);
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterModalScrollbarKey),
      findsOneWidget,
    );
    final grid = tester.widget<GridView>(
      find.byKey(OrganizeChronologyCanvas.clusterModalScrollKey),
    );
    expect(grid.physics, isA<BouncingScrollPhysics>());

    for (final item in extras.take(4)) {
      expect(
        find.byKey(OrganizeChronologyCanvas.clusterItemKey(item.id)),
        findsOneWidget,
      );
    }

    final first = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.clusterItemKey('ctx-0')),
    );
    await tester.drag(
      find.byKey(OrganizeChronologyCanvas.clusterModalScrollKey),
      const Offset(0, -90),
    );
    await tester.pump();
    final after = tester.getTopLeft(
      find.byKey(OrganizeChronologyCanvas.clusterItemKey('ctx-0')),
    );
    expect(after.dy, lessThan(first.dy));
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterItemKey('ctx-4')),
      findsOneWidget,
    );
  });

  testWidgets('7 outside tap dismisses the context cluster modal',
      (tester) async {
    final noteB = _item(
      id: 'note-b',
      kind: WorkspaceEvidenceKind.note,
      at: t0.add(const Duration(seconds: 30)),
    );
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
    expect(find.byKey(OrganizeChronologyCanvas.clusterModalKey), findsOneWidget);

    final scrim = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.clusterScrimKey),
    );
    await tester.tapAt(scrim.topLeft + const Offset(12, 12));
    await tester.pump();
    expect(find.byKey(OrganizeChronologyCanvas.clusterModalKey), findsNothing);
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterKey('photo')),
      findsOneWidget,
    );
  });

  testWidgets(
    '8 linked evidence appears in Evidence Inspector instead of Timeline Role',
    (tester) async {
      WorkspaceEvidenceFactory.resetForTests();
      SharedPreferences.setMockInitialValues({});
      addTearDown(WorkspaceEvidenceFactory.useProductionIds);

      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-refine', title: 'Case'),
      );
      final photoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final noteId = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setOrganizeContextAnchor(
        contextEvidenceId: noteId,
        capturedEvidenceId: photoId,
      );

      Future<void> open(WorkspaceEvidenceItem evidence) async {
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
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 900));

      final snapped = controller.currentIncident.evidenceById(noteId)!;
      await open(snapped);
      expect(
        find.byKey(InspectorLinkedOrganizeMomentSection.sectionKey),
        findsOneWidget,
      );
      expect(find.text(InspectorLinkedOrganizeMomentSection.header), findsOneWidget);
      expect(
        find.byKey(const Key('evidence_inspector_timeline_role')),
        findsNothing,
      );

      Navigator.of(tester.element(find.text('Close'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final captured = controller.currentIncident.evidenceById(photoId)!;
      await open(captured);
      expect(
        find.byKey(const Key('evidence_inspector_timeline_role')),
        findsNothing,
      );
      expect(
        find.byKey(InspectorLinkedOrganizeMomentSection.sectionKey),
        findsNothing,
      );
    },
  );

  testWidgets(
    '9 toolbar instruction wobble/color follows unsnapped-context state',
    (tester) async {
      final noteB = _item(
        id: 'note-b',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 30)),
      );

      Future<void> pumpBar({
        required List<WorkspaceEvidenceItem> extra,
        required List<OrganizeContextAnchor> anchors,
      }) {
        return _pumpView(
          tester,
          evidence: [photo, ...extra],
          organizeCreatedIds: {for (final item in extra) item.id},
          anchors: anchors,
        );
      }

      await pumpBar(extra: [note], anchors: const []);
      expect(
        tester
            .widget<OrganizePlacementWobble>(
              find.byKey(
                OrganizeWorkspaceView.addContextInstructionWobbleKey,
              ),
            )
            .active,
        isTrue,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(
                  OrganizeWorkspaceView.addContextInstructionWobbleKey,
                ),
                matching: find.text(OrganizeWorkspaceView.addContextCaption),
              ),
            )
            .style
            ?.color,
        OrganizeVisuals.contextInstruction,
      );
      expect(
        find.descendant(
          of: find.byKey(
            OrganizeWorkspaceView.addContextInstructionWobbleKey,
          ),
          matching: find.byType(ShaderMask),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text(OrganizeWorkspaceView.addContextTitle),
          matching: find.byType(OrganizePlacementWobble),
        ),
        findsNothing,
      );

      await pumpBar(
        extra: [note],
        anchors: const [
          OrganizeContextAnchor(
            contextEvidenceId: 'note-org',
            capturedEvidenceId: 'photo',
          ),
        ],
      );
      expect(
        tester
            .widget<OrganizePlacementWobble>(
              find.byKey(
                OrganizeWorkspaceView.addContextInstructionWobbleKey,
              ),
            )
            .active,
        isFalse,
      );
      expect(
        find.descendant(
          of: find.byKey(
            OrganizeWorkspaceView.addContextInstructionWobbleKey,
          ),
          matching: find.byType(ShaderMask),
        ),
        findsNothing,
      );

      await pumpBar(extra: [note, noteB], anchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
      ]);
      final restarted = tester.widget<OrganizePlacementWobble>(
        find.byKey(OrganizeWorkspaceView.addContextInstructionWobbleKey),
      );
      expect(restarted.active, isTrue);
      expect(restarted.restartToken, 'note-b');
    },
  );
}
