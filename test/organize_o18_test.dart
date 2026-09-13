import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/incident_action_hierarchy.dart';
import 'package:evidence_vault/widgets/investigation/timeline_role_choice_sheet.dart';
import 'package:evidence_vault/widgets/workspace/evidence_maturity_engine.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  String? contentHash,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    contentHash: contentHash ?? 'hash-$id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-o18',
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
  IncidentStatus status = IncidentStatus.active,
}) {
  return CurrentIncident(
    id: 'inc-o18',
    title: 'Street Fight',
    status: status,
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
          onSetContextAnchor: onSetContextAnchor,
          onClearContextAnchor: onClearContextAnchor,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  final t0 = DateTime(2026, 8, 25, 10, 42);
  final photo = _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0);
  final video = _item(
    id: 'video',
    kind: WorkspaceEvidenceKind.video,
    at: t0.add(const Duration(minutes: 1)),
  );

  test('K toolbar copy is exact', () {
    expect(
      OrganizeWorkspaceView.addContextCaption,
      'Drag the context on the moments preserved',
    );
  });

  test('D no InvestigationReadiness engine — hierarchy uses OrganizeReadiness', () {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-o18-d', title: 'Case'),
    );
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final one = controller.organizeReadiness;
    expect(one.isReady, isFalse);
    final oneVisibility = IncidentActionHierarchy.from(
      archived: false,
      readiness: one,
    );
    expect(oneVisibility.showPreserve, isTrue);
    expect(oneVisibility.showOrganize, isFalse);
    expect(oneVisibility.showInvestigate, isFalse);

    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-o18-ready', title: 'Ready'),
    );
    controller.preserveEvidence(WorkspaceCaptureMode.video);
    controller.preserveEvidence(WorkspaceCaptureMode.note);
    final ready = controller.organizeReadiness;
    expect(ready.isReady, isTrue);
    final readyVisibility = IncidentActionHierarchy.from(
      archived: false,
      readiness: ready,
    );
    expect(readyVisibility.showPreserve, isTrue);
    expect(readyVisibility.showOrganize, isFalse);
    expect(readyVisibility.showInvestigate, isTrue);
    expect(EvidenceMaturityEngine.showStrengtheningLane, isFalse);
  });

  testWidgets('A Continue organizing is not shown on the resume path labels',
      (tester) async {
    expect(IncidentActionHierarchy.organizeLabel, 'Continue organizing');
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizeWorkspaceView(
          incident: _incident(evidence: [photo, video]),
          orderedCapturedEvidenceIds: const ['photo', 'video'],
          onEvidenceSelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text(IncidentActionHierarchy.organizeLabel), findsNothing);
  });

  testWidgets('E no context classification prompt after Organize create',
      (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [
        photo,
        _item(
          id: 'voice-org',
          kind: WorkspaceEvidenceKind.voice,
          at: t0.add(const Duration(seconds: 20)),
        ),
      ],
      organizeCreatedIds: const {'voice-org'},
      onSetContextAnchor: (_, _) {},
    );
    expect(find.byType(TimelineRoleChoiceSheet), findsNothing);
    expect(find.byKey(TimelineRoleChoiceSheet.sheetKey), findsNothing);
    expect(find.textContaining('timeline or context'), findsNothing);
    expect(find.textContaining('chronological'), findsNothing);
  });

  testWidgets('F Voice context appears as floating context', (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [
        photo,
        _item(
          id: 'voice-org',
          kind: WorkspaceEvidenceKind.voice,
          at: t0.add(const Duration(seconds: 20)),
        ),
      ],
      organizeCreatedIds: const {'voice-org'},
      onSetContextAnchor: (_, _) {},
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.floatingLayerKey),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('voice-org')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('voice-org')),
      findsNothing,
    );
  });

  testWidgets('G Text context appears as floating context', (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [
        photo,
        _item(
          id: 'note-org',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 20)),
        ),
      ],
      organizeCreatedIds: const {'note-org'},
      onSetContextAnchor: (_, _) {},
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('note-org')),
      findsNothing,
    );
  });

  testWidgets('H File context appears as floating context', (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [
        photo,
        _item(
          id: 'file-org',
          kind: WorkspaceEvidenceKind.attachment,
          at: t0.add(const Duration(seconds: 20)),
        ),
      ],
      organizeCreatedIds: const {'file-org'},
      onSetContextAnchor: (_, _) {},
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('file-org')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('file-org')),
      findsNothing,
    );
  });

  testWidgets('I/J floating contexts are not parallel timeline items',
      (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [
        photo,
        video,
        _item(
          id: 'note-a',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 20)),
        ),
        _item(
          id: 'note-b',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 30)),
        ),
        _item(
          id: 'note-c',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 40)),
        ),
      ],
      organizeCreatedIds: const {'note-a', 'note-b', 'note-c'},
      onSetContextAnchor: (_, _) {},
    );

    final a = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-a')),
    );
    final b = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-b')),
    );
    final c = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-c')),
    );
    final captured = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
    );

    expect(a.overlaps(b), isFalse);
    expect(b.overlaps(c), isFalse);
    expect(a.overlaps(c), isFalse);
    expect(a.left, greaterThan(captured.left));
    expect(b.top, greaterThan(a.top));
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('note-a')),
      findsNothing,
    );
  });

  testWidgets('L drag affordance exists only when placement can run',
      (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [
        photo,
        _item(
          id: 'note-org',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 20)),
        ),
      ],
      organizeCreatedIds: const {'note-org'},
    );
    expect(find.byType(LongPressDraggable<String>), findsNothing);

    await _pumpCanvas(
      tester,
      ordered: [
        photo,
        _item(
          id: 'note-org',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 20)),
        ),
      ],
      organizeCreatedIds: const {'note-org'},
      onSetContextAnchor: (_, _) {},
    );
    expect(find.byType(LongPressDraggable<String>), findsOneWidget);
  });

  testWidgets('M/N/O/P placement uses OrganizeContextAnchor; drag-away unlinks',
      (tester) async {
    final note = _item(
      id: 'note-org',
      kind: WorkspaceEvidenceKind.note,
      at: t0.add(const Duration(seconds: 20)),
      contentHash: 'hash-note-org',
    );
    final idsBefore = [photo.id, note.id];
    final hashesBefore = [photo.contentHash, note.contentHash];
    final capturedBefore = [photo.capturedAt, note.capturedAt];
    final recordedBefore = [photo.recordedAt, note.recordedAt];
    final preservedBefore = [photo.lastPreservedAt, note.lastPreservedAt];
    var cleared = <String>[];

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
      onSetContextAnchor: (_, _) {},
      onClearContextAnchor: cleared.add,
    );

    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note-org')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.unplaceKey('note-org')),
      findsNothing,
    );
    expect(find.text(OrganizeChronologyCanvas.unplaceLabel), findsNothing);
    await tester.tap(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
    );
    await tester.pump();
    expect(
      find.byKey(OrganizeChronologyCanvas.discardKey('note-org')),
      findsOneWidget,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      ),
    );
    await tester.pump(
      OrganizeChronologyCanvas.dragStartDelay +
          const Duration(milliseconds: 80),
    );
    await gesture.moveBy(const Offset(220, 160));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(cleared, ['note-org']);
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      findsOneWidget,
    );
    expect([photo.id, note.id], idsBefore);
    expect([photo.contentHash, note.contentHash], hashesBefore);
    expect([photo.capturedAt, note.capturedAt], capturedBefore);
    expect([photo.recordedAt, note.recordedAt], recordedBefore);
    expect([photo.lastPreservedAt, note.lastPreservedAt], preservedBefore);
  });

  testWidgets('Q successful placement shows target aura then settles',
      (tester) async {
    final anchors = <OrganizeContextAnchor>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeChronologyCanvas(
                ordered: [
                  photo,
                  _item(
                    id: 'note-org',
                    kind: WorkspaceEvidenceKind.note,
                    at: t0.add(const Duration(seconds: 20)),
                  ),
                ],
                allEvidence: [
                  photo,
                  _item(
                    id: 'note-org',
                    kind: WorkspaceEvidenceKind.note,
                    at: t0.add(const Duration(seconds: 20)),
                  ),
                ],
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
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final noteFinder =
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org'));
    final photoFinder =
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo'));
    final gesture = await tester.startGesture(tester.getCenter(noteFinder));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    expect(find.byKey(OrganizeChronologyCanvas.dragAuraKey), findsOneWidget);
    await gesture.moveTo(tester.getCenter(photoFinder));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(anchors, hasLength(1));
    expect(anchors.single.capturedEvidenceId, 'photo');
    expect(find.byKey(OrganizeChronologyCanvas.targetAuraKey), findsOneWidget);
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note-org')),
      findsOneWidget,
    );

    await tester.pump(OrganizeChronologyCanvas.placementAuraDuration);
    await tester.pump();
    expect(find.byKey(OrganizeChronologyCanvas.targetAuraKey), findsNothing);
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('note-org')),
      findsNothing,
    );
  });

  testWidgets('R archived incidents remain read-only for placement',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizeWorkspaceView(
          incident: _incident(
            evidence: [
              photo,
              _item(
                id: 'note-org',
                kind: WorkspaceEvidenceKind.note,
                at: t0.add(const Duration(seconds: 20)),
              ),
            ],
            status: IncidentStatus.archived,
          ),
          orderedCapturedEvidenceIds: const ['photo'],
          organizeCreatedIds: const {'note-org'},
          onEvidenceSelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LongPressDraggable<String>), findsNothing);
    expect(find.byKey(const Key('organize_create_group')), findsNothing);
  });

  testWidgets('S captured evidence remains visually primary', (tester) async {
    await _pumpCanvas(
      tester,
      ordered: [
        photo,
        _item(
          id: 'note-org',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 20)),
        ),
      ],
      organizeCreatedIds: const {'note-org'},
      onSetContextAnchor: (_, _) {},
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.capturedLaneHeaderKey),
      findsNothing,
    );
    final captured = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
    );
    final context = tester.getRect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
    );
    expect(captured.left, lessThan(context.left));
  });

  testWidgets('U Create Group text stays off the Groups card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizeWorkspaceView(
          incident: _incident(evidence: [photo]),
          orderedCapturedEvidenceIds: const ['photo'],
          onEvidenceSelected: (_) {},
          onCreateGroup: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('organize_create_group')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: OrganizeWorkspaceView(
          incident: _incident(evidence: [photo, video]),
          orderedCapturedEvidenceIds: const ['photo', 'video'],
          onEvidenceSelected: (_) {},
          onCreateGroup: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(find.text('Create Group'), findsNothing);
    expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
  });

  testWidgets('W empty Organize state remains valid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrganizeWorkspaceView(
          incident: _incident(evidence: const []),
          onEvidenceSelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('No evidence in this incident yet. Capture to begin organizing.'),
      findsOneWidget,
    );
    expect(find.byKey(OrganizeWorkspaceView.viewKey), findsOneWidget);
  });

  test('O/P controller placement does not mutate identity or chronology clocks',
      () {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-o18', title: 'Case'),
    );
    final photoId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final noteId = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    final photoItem = controller.currentIncident.evidence
        .firstWhere((e) => e.id == photoId);
    final noteItem = controller.currentIncident.evidence
        .firstWhere((e) => e.id == noteId);
    final ids = [photoItem.id, noteItem.id];
    final hashes = [photoItem.contentHash, noteItem.contentHash];
    final captured = [photoItem.capturedAt, noteItem.capturedAt];
    final recorded = [photoItem.recordedAt, noteItem.recordedAt];
    final preserved = [photoItem.lastPreservedAt, noteItem.lastPreservedAt];
    final sequence = controller.timelineRepository.orderedCapturedEvidenceIds();

    controller.setOrganizeContextAnchor(
      contextEvidenceId: noteId,
      capturedEvidenceId: photoId,
    );
    final photoAfter = controller.currentIncident.evidence
        .firstWhere((e) => e.id == photoId);
    final noteAfter = controller.currentIncident.evidence
        .firstWhere((e) => e.id == noteId);
    expect([photoAfter.id, noteAfter.id], ids);
    expect([photoAfter.contentHash, noteAfter.contentHash], hashes);
    expect([photoAfter.capturedAt, noteAfter.capturedAt], captured);
    expect([photoAfter.recordedAt, noteAfter.recordedAt], recorded);
    expect([photoAfter.lastPreservedAt, noteAfter.lastPreservedAt], preserved);
    expect(
      controller.timelineRepository.orderedCapturedEvidenceIds(),
      sequence,
    );
    expect(controller.organizeContextAnchors, hasLength(1));

    controller.clearOrganizeContextAnchor(noteId);
    expect(controller.currentIncident.evidence.map((e) => e.id), contains(noteId));
    expect(controller.organizeContextAnchors, isEmpty);
  });

  testWidgets('context thumbnail shows date above HH:mm:ss without labels',
      (tester) async {
    final note = _item(
      id: 'note-org',
      kind: WorkspaceEvidenceKind.note,
      at: t0.add(const Duration(seconds: 20)),
    );
    await _pumpCanvas(
      tester,
      ordered: [photo, note],
      organizeCreatedIds: const {'note-org'},
      onSetContextAnchor: (_, _) {},
    );

    final tile = find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(OrganizeChronologyCanvas.addedContextLabel),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Note')),
      findsNothing,
    );
    expect(
      find.descendant(of: tile, matching: find.textContaining('Today')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.addedContextLaneHeaderKey),
      findsNothing,
    );

    final dateFinder = find.byKey(
      OrganizeChronologyCanvas.contextDateKey('note-org'),
    );
    final timeFinder = find.byKey(const Key('organize_evidence_clock_note-org'));
    expect(dateFinder, findsOneWidget);
    expect(timeFinder, findsOneWidget);
    expect(tester.widget<Text>(timeFinder).data, '10:42:20');
    expect(tester.getTopLeft(dateFinder).dy, lessThan(tester.getTopLeft(timeFinder).dy));
    expect(
      tester.widget<OrganizePlacementWobble>(
        find.byKey(OrganizeChronologyCanvas.awaitingPlacementKey('note-org')),
      ).active,
      isTrue,
    );
  });

  testWidgets('snapped context stops wobble and stays off the chronology spine',
      (tester) async {
    final note = _item(
      id: 'note-org',
      kind: WorkspaceEvidenceKind.note,
      at: t0.add(const Duration(seconds: 20)),
    );
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
      onSetContextAnchor: (_, _) {},
      onClearContextAnchor: (_) {},
    );

    expect(
      tester.widget<OrganizePlacementWobble>(
        find.byKey(OrganizeChronologyCanvas.awaitingPlacementKey('note-org')),
      ).active,
      isFalse,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.unplaceKey('note-org')),
      findsNothing,
    );
    expect(find.text(OrganizeChronologyCanvas.unplaceLabel), findsNothing);
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('note-org')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      findsOneWidget,
    );
  });

  testWidgets('toolbar instruction wobbles only while context awaits placement',
      (tester) async {
    final note = _item(
      id: 'note-org',
      kind: WorkspaceEvidenceKind.note,
      at: t0.add(const Duration(seconds: 20)),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    Future<void> pumpBar({
      required List<WorkspaceEvidenceItem> extra,
      required List<OrganizeContextAnchor> anchors,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeWorkspaceView(
              incident: _incident(evidence: [photo, ...extra]),
              orderedCapturedEvidenceIds: const ['photo'],
              organizeCreatedIds: {for (final item in extra) item.id},
              contextAnchors: anchors,
              onEvidenceSelected: (_) {},
              onAddOrganizeContext: (_) {},
              onSetContextAnchor: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    await pumpBar(extra: [note], anchors: const []);
    expect(
      find.text(OrganizeWorkspaceView.addContextCaption),
      findsOneWidget,
    );
    expect(
      tester.widget<OrganizePlacementWobble>(
        find.byKey(OrganizeWorkspaceView.addContextInstructionWobbleKey),
      ).active,
      isTrue,
    );
    expect(
      find.ancestor(
        of: find.text(OrganizeWorkspaceView.addContextTitle),
        matching: find.byType(OrganizePlacementWobble),
      ),
      findsNothing,
    );

    const placed = [
      OrganizeContextAnchor(
        contextEvidenceId: 'note-org',
        capturedEvidenceId: 'photo',
      ),
    ];
    await pumpBar(extra: [note], anchors: placed);
    expect(
      tester.widget<OrganizePlacementWobble>(
        find.byKey(OrganizeWorkspaceView.addContextInstructionWobbleKey),
      ).active,
      isFalse,
    );

    final second = _item(
      id: 'voice-org',
      kind: WorkspaceEvidenceKind.voice,
      at: t0.add(const Duration(seconds: 30)),
    );
    await pumpBar(extra: [note, second], anchors: placed);
    final restarted = tester.widget<OrganizePlacementWobble>(
      find.byKey(OrganizeWorkspaceView.addContextInstructionWobbleKey),
    );
    expect(restarted.active, isTrue);
    expect(restarted.restartToken, 'voice-org');
  });

  testWidgets(
    'tapping a snapped context wobbles the instruction immediately',
    (tester) async {
      final note = _item(
        id: 'note-org',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 20)),
      );
      final voice = _item(
        id: 'voice-org',
        kind: WorkspaceEvidenceKind.voice,
        at: t0.add(const Duration(seconds: 30)),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeWorkspaceView(
              incident: _incident(evidence: [photo, video, note, voice]),
              orderedCapturedEvidenceIds: const ['photo', 'video'],
              organizeCreatedIds: const {'note-org', 'voice-org'},
              contextAnchors: const [
                OrganizeContextAnchor(
                  contextEvidenceId: 'note-org',
                  capturedEvidenceId: 'photo',
                ),
                OrganizeContextAnchor(
                  contextEvidenceId: 'voice-org',
                  capturedEvidenceId: 'video',
                ),
              ],
              onEvidenceSelected: (_) {},
              onAddOrganizeContext: (_) {},
              onSetContextAnchor: (_, _) {},
              onClearContextAnchor: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

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

      await tester.tap(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note-org')),
      );
      await tester.pump();

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
        tester
            .widget<OrganizePlacementWobble>(
              find.byKey(
                OrganizeWorkspaceView.addContextInstructionWobbleKey,
              ),
            )
            .active,
        isTrue,
      );

      await tester.tap(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('voice-org')),
      );
      await tester.pump();
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
    },
  );
}
