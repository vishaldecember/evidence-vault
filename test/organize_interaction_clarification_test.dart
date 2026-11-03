import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_group_composition.dart';
import 'package:evidence_vault/widgets/workspace/organize_groups_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_suggestion_card.dart';
import 'package:evidence_vault/widgets/workspace/organize_suggestion_rail.dart';
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
    incidentId: 'inc-o10',
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
  List<EvidenceCollection> collections = const [],
  IncidentStatus status = IncidentStatus.active,
}) {
  return CurrentIncident(
    id: 'inc-o10',
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
    evidenceCollections: collections,
    trustPackageReady: evidence.isNotEmpty,
    trustPackageProgressPercent: 40,
  );
}

Map<String, Object?> _integrity(WorkspaceEvidenceItem item) {
  return {
    'id': item.id,
    'hash': item.contentHash,
    'capturedAt': item.capturedAt,
    'recordedAt': item.recordedAt,
    'lastPreservedAt': item.lastPreservedAt,
    'parent': item.parentEvidenceId,
  };
}

Future<void> _pumpOrganize(
  WidgetTester tester, {
  required CurrentIncident incident,
  List<String> orderedCapturedEvidenceIds = const [],
  Set<String> organizeCreatedIds = const {},
  List<OrganizeContextAnchor> contextAnchors = const [],
  VoidCallback? onCreateGroup,
  ValueChanged<WorkspaceCaptureMode>? onAddOrganizeContext,
  void Function(String contextId, String capturedId)? onSetContextAnchor,
  ValueChanged<String>? onClearContextAnchor,
  void Function(String collectionId, String evidenceId)? onRemoveFromGroup,
  ValueChanged<String>? onAcceptSuggestion,
  ValueChanged<String>? onDismissSuggestion,
  ValueChanged<String>? onRestoreSuggestion,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: incident,
          orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
          organizeCreatedIds: organizeCreatedIds,
          contextAnchors: contextAnchors,
          onEvidenceSelected: (_) {},
          onCreateGroup: onCreateGroup,
          onAddOrganizeContext: onAddOrganizeContext,
          onSetContextAnchor: onSetContextAnchor,
          onClearContextAnchor: onClearContextAnchor,
          onRemoveFromGroup: onRemoveFromGroup,
          onAcceptSuggestion: onAcceptSuggestion,
          onDismissSuggestion: onDismissSuggestion,
          onRestoreSuggestion: onRestoreSuggestion,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  final t0 = DateTime.utc(2026, 8, 24, 10);
  final photo = _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0);
  final video = _item(
    id: 'video',
    kind: WorkspaceEvidenceKind.video,
    at: t0.add(const Duration(minutes: 1)),
  );
  final addedNote = _item(
    id: 'note-org',
    kind: WorkspaceEvidenceKind.note,
    at: t0.add(const Duration(minutes: 2)),
  );

  EvidenceCollection group() {
    return EvidenceCollection(
      id: 'group-1',
      incidentId: 'inc-o10',
      name: 'Doorway',
      systemGenerated: false,
      pending: false,
      displayOrder: 0,
      createdAt: t0,
      updatedAt: t0,
      memberEvidenceIds: const ['photo', 'video'],
    );
  }

  EvidenceCollection suggestion() {
    return EvidenceCollection(
      id: 'suggest-1',
      incidentId: 'inc-o10',
      name: 'Possible pair',
      systemGenerated: true,
      pending: true,
      displayOrder: 1,
      createdAt: t0,
      updatedAt: t0,
      memberEvidenceIds: const ['photo', 'video'],
    );
  }

  testWidgets('A/B bottom bar is Add context and keeps Voice/Note/File', (
    tester,
  ) async {
    final tapped = <WorkspaceCaptureMode>[];
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, video]),
      orderedCapturedEvidenceIds: const ['photo', 'video'],
      onAddOrganizeContext: tapped.add,
    );

    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsOneWidget);
    expect(find.text(OrganizeWorkspaceView.addContextTitle), findsOneWidget);
    expect(find.text(OrganizeWorkspaceView.addContextCaption), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(OrganizeWorkspaceView.addContextBarKey),
        matching: find.text('Capture'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Voice'));
    await tester.tap(find.text('Note'));
    await tester.tap(find.text('File'));
    await tester.pump();
    expect(tapped, [
      WorkspaceCaptureMode.voice,
      WorkspaceCaptureMode.note,
      WorkspaceCaptureMode.file,
    ]);
  });

  testWidgets('C placement guidance appears only when placement can run', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, addedNote]),
      orderedCapturedEvidenceIds: const ['photo'],
      organizeCreatedIds: const {'note-org'},
      onSetContextAnchor: (_, _) {},
    );

    expect(
      find.text(OrganizeChronologyCanvas.placementGuidance),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) => widget is LongPressDraggable),
      findsOneWidget,
    );
  });

  test('D/M O-2 displayOrder is unchanged', () {
    final leftover = _item(
      id: 'leftover',
      kind: WorkspaceEvidenceKind.voice,
      at: t0.add(const Duration(hours: 2)),
    );
    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: [addedNote, leftover, video, photo],
      orderedCapturedEvidenceIds: const ['video', 'photo'],
      organizeCreatedIds: const {'note-org'},
      incidentId: 'inc-o10',
    );
    expect(
      [for (final item in ordered) item.id],
      ['video', 'photo', 'leftover', 'note-org'],
    );
  });

  testWidgets('E un-place clears the anchor and does not delete evidence', (
    tester,
  ) async {
    var cleared = <String>[];
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, addedNote]),
      orderedCapturedEvidenceIds: const ['photo'],
      organizeCreatedIds: const {'note-org'},
      contextAnchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'note-org',
          capturedEvidenceId: 'photo',
        ),
      ],
      onSetContextAnchor: (_, _) {},
      onClearContextAnchor: cleared.add,
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
    await tester.pump(kDoubleTapTimeout);
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
  });

  testWidgets(
    'F/G drag and placement chrome are absent without a placement callback',
    (tester) async {
      await _pumpOrganize(
        tester,
        incident: _incident(
          evidence: [photo, addedNote],
          status: IncidentStatus.archived,
        ),
        orderedCapturedEvidenceIds: const ['photo'],
        organizeCreatedIds: const {'note-org'},
        contextAnchors: const [
          OrganizeContextAnchor(
            contextEvidenceId: 'note-org',
            capturedEvidenceId: 'photo',
          ),
        ],
      );

      expect(
        find.byWidgetPredicate((widget) => widget is LongPressDraggable),
        findsNothing,
      );
      expect(
        find.text(OrganizeChronologyCanvas.placementGuidance),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.unplaceKey('note-org')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'H pending collections appear as Groups, not a Suggestions section',
    (tester) async {
      await _pumpOrganize(
        tester,
        incident: _incident(
          evidence: [photo, video],
          collections: [suggestion()],
        ),
        orderedCapturedEvidenceIds: const ['photo', 'video'],
      );

      expect(find.byKey(OrganizeWorkspaceView.suggestionsKey), findsNothing);
      expect(find.text('Suggestions'), findsNothing);
      expect(find.text('Suggested evidence group'), findsNothing);
      expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
      expect(find.text('Create Group'), findsNothing);
      expect(find.text('Add to Group'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
      expect(
        find.byKey(OrganizeSuggestionCard.acceptKey('suggest-1')),
        findsNothing,
      );
      expect(find.byKey(OrganizeSuggestionRail.railKey), findsNothing);
    },
  );

  testWidgets('I archived Organize does not expose mutation controls', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(
        evidence: [photo, video, addedNote],
        collections: [group(), suggestion()],
        status: IncidentStatus.archived,
      ),
      orderedCapturedEvidenceIds: const ['photo', 'video'],
      organizeCreatedIds: const {'note-org'},
    );

    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsNothing);
    expect(find.text('Add to Group'), findsNothing);
    expect(find.text(OrganizeWorkspaceView.removeFromGroupLabel), findsNothing);
    expect(
      find.byWidgetPredicate((widget) => widget is LongPressDraggable),
      findsNothing,
    );
  });

  testWidgets(
    'J/K remove from group is membership-only and does not mutate evidence',
    (tester) async {
      final collection = group();
      final evidence = [photo, video];
      final before = [for (final item in evidence) _integrity(item)];
      String? removedCollection;
      String? removedEvidence;

      await _pumpOrganize(
        tester,
        incident: _incident(evidence: evidence, collections: [collection]),
        orderedCapturedEvidenceIds: const ['photo', 'video'],
        onRemoveFromGroup: (collectionId, evidenceId) {
          removedCollection = collectionId;
          removedEvidence = evidenceId;
        },
      );

      expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
      await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPlusKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(OrganizeGroupsModal.transferBarKey));
      await tester.pump();
      expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsOneWidget);
      final saved = find.byKey(
        OrganizeGroupCompositionModal.savedGroupKey(collection.id),
      );
      await tester.scrollUntilVisible(
        saved,
        40,
        scrollable: find
            .descendant(
              of: find.byKey(OrganizeGroupCompositionModal.savedScrollKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(saved);
      await tester.pump();
      await tester.longPress(
        find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(OrganizeGroupCompositionModal.cloneDiscardKey('photo')),
      );
      await tester.pump();
      expect(
        find.text(OrganizeGroupCompositionModal.minMembersMessage),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
        findsNothing,
      );
      expect(removedCollection, isNull);
      expect(removedEvidence, isNull);
      expect([for (final item in evidence) _integrity(item)], before);
      expect(collection.memberEvidenceIds, ['photo', 'video']);
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        findsOneWidget,
      );
    },
  );

  test('L createUserCollection contract is unchanged', () {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-o10', title: 'Case'),
    );
    final a = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    expect(controller.createUserEvidenceCollection(evidenceIds: [a]), isNull);
    final b = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final created = controller.createUserEvidenceCollection(
      evidenceIds: [a, b],
    );
    expect(created, isNotNull);
    expect(created!.memberEvidenceIds, [a, b]);
    expect(created.pending, isFalse);
  });

  test('N O-3 classification remains origin-based', () {
    expect(
      OrganizeChronologyCanvas.isContextSpineItem(
        addedNote,
        organizeCreatedIds: const {'note-org'},
      ),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isFixedSpineItem(
        addedNote,
        organizeCreatedIds: const {},
      ),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isFixedSpineItem(
        _item(id: 'note-capture', kind: WorkspaceEvidenceKind.note, at: t0),
        organizeCreatedIds: const {'note-org'},
      ),
      isTrue,
    );
  });

  testWidgets('P compact Organize header remains intact', (tester) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, video]),
      orderedCapturedEvidenceIds: const ['photo', 'video'],
    );

    expect(find.byKey(OrganizeWorkspaceView.headerKey), findsOneWidget);
    expect(find.byKey(const Key('organize_incident_title')), findsOneWidget);
    expect(find.text('Evidence structure'), findsNothing);
    expect(find.text('Organize'), findsNothing);
  });

  test('O-10 does not change Organize Voice TimelineAnchor creation', () {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-voice', title: 'Case'),
    );
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final anchorsBefore = controller.timelineRepository.anchors.length;
    final voice = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.voice,
    );
    expect(voice, isNotEmpty);
    expect(controller.timelineRepository.anchors.length, anchorsBefore + 1);
    expect(controller.organizeCreatedEvidenceIds, contains(voice));
  });

  testWidgets('E controller un-place uses clearOrganizeContextAnchor only', (
    tester,
  ) async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-o10', title: 'Case'),
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
    final idsBefore = [
      for (final item in controller.currentIncident.evidence) item.id,
    ];
    final hashesBefore = [
      for (final item in controller.currentIncident.evidence) item.contentHash,
    ];
    final sequenceBefore = [
      for (final anchor in controller.timelineRepository.anchors)
        '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
    ];

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return OrganizeWorkspaceView(
                incident: controller.currentIncident,
                orderedCapturedEvidenceIds: controller.timelineRepository
                    .orderedCapturedEvidenceIds(),
                organizeCreatedIds: controller.organizeCreatedEvidenceIds,
                contextAnchors: controller.organizeContextAnchors,
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  controller.setOrganizeContextAnchor(
                    contextEvidenceId: contextId,
                    capturedEvidenceId: capturedId,
                  );
                },
                onClearContextAnchor: controller.clearOrganizeContextAnchor,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(noteId)),
    );
    await tester.pump();
    await tester.pump(kDoubleTapTimeout);
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(noteId)),
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

    expect(controller.organizeContextAnchors, isEmpty);
    expect([
      for (final item in controller.currentIncident.evidence) item.id,
    ], idsBefore);
    expect([
      for (final item in controller.currentIncident.evidence) item.contentHash,
    ], hashesBefore);
    expect([
      for (final anchor in controller.timelineRepository.anchors)
        '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
    ], sequenceBefore);
  });
}
