import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_group_composition.dart';
import 'package:evidence_vault/widgets/workspace/organize_groups_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-col', title: 'Case'),
  );
}

Map<String, String?> _hashes(WorkspaceEvidenceController controller) {
  return {
    for (final item in controller.aggregate.store.capturedEvidence)
      item.id: item.contentHash,
    for (final item in controller.aggregate.store.supportingEvidence)
      item.id: item.contentHash,
  };
}

List<String> _sequence(WorkspaceEvidenceController controller) {
  return [
    for (final anchor in controller.timelineRepository.anchors)
      '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
  ];
}

List<String> _timelineOrder(WorkspaceEvidenceController controller) {
  return [
    for (final item in controller.aggregate.store.capturedEvidence)
      '${item.id}:${item.timelineOrder}',
  ];
}

List<String> _displayIds(WorkspaceEvidenceController controller) {
  return [
    for (final item in OrganizeChronologyCanvas.displayOrder(
      items: controller.currentIncident.journeyEvidence,
      orderedCapturedEvidenceIds: controller.timelineRepository
          .orderedCapturedEvidenceIds(),
      organizeCreatedIds: controller.organizeCreatedEvidenceIds,
      incidentId: controller.currentIncident.id,
    ))
      item.id,
  ];
}

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
    SharedPreferences.setMockInitialValues({});
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  test('A EvidenceCollection is incident-scoped', () {
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final video = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final created = controller.createUserEvidenceCollection(
      evidenceIds: [photo, video],
    );
    expect(created, isNotNull);
    expect(created!.incidentId, 'inc-col');
    expect(created.memberEvidenceIds.toSet(), {photo, video});
    final incidentIds = {
      for (final item in controller.currentIncident.evidence) item.id,
    };
    for (final id in created.memberEvidenceIds) {
      expect(incidentIds, contains(id));
    }
  });

  test(
    'B/C/K membership does not mutate evidence, chronology, or other groups',
    () {
      final controller = _controller();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final video = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      final idsBefore = [
        for (final item in controller.currentIncident.evidence) item.id,
      ];
      final hashesBefore = _hashes(controller);
      final sequenceBefore = _sequence(controller);
      final timelineBefore = _timelineOrder(controller);
      final capturedBefore = [
        for (final item in controller.aggregate.store.capturedEvidence)
          item.capturedAt,
      ];
      final displayBefore = _displayIds(controller);
      final groupsBefore = controller.currentIncident.relationshipGroups.length;
      final relationshipsBefore = controller.state.relationships.length;
      final anchorsBefore = controller.organizeContextAnchors.length;

      final created = controller.createUserEvidenceCollection(
        evidenceIds: [photo, video],
      );
      expect(created, isNotNull);

      expect([
        for (final item in controller.currentIncident.evidence) item.id,
      ], idsBefore);
      expect(_hashes(controller), hashesBefore);
      expect(_sequence(controller), sequenceBefore);
      expect(_timelineOrder(controller), timelineBefore);
      expect([
        for (final item in controller.aggregate.store.capturedEvidence)
          item.capturedAt,
      ], capturedBefore);
      expect(_displayIds(controller), displayBefore);
      expect(
        controller.currentIncident.relationshipGroups,
        hasLength(groupsBefore),
      );
      expect(controller.state.relationships, hasLength(relationshipsBefore));
      expect(controller.organizeContextAnchors, hasLength(anchorsBefore));
    },
  );

  test('F create-group requires at least two members', () {
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    expect(
      controller.createUserEvidenceCollection(evidenceIds: [photo]),
      isNull,
    );
    expect(
      controller.createUserEvidenceCollection(evidenceIds: const []),
      isNull,
    );
    expect(controller.evidenceCollections.where((c) => !c.pending), isEmpty);
  });

  test('G accept changes only EvidenceCollection pending state', () {
    final controller = _controller();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
    controller.ensureEvidenceCollections();
    final suggestion = controller.evidenceCollections.firstWhere(
      (c) => c.pending,
    );
    final members = List<String>.from(suggestion.memberEvidenceIds);
    final hashesBefore = _hashes(controller);
    final sequenceBefore = _sequence(controller);
    final groupsBefore = controller.currentIncident.relationshipGroups.length;

    final accepted = controller.acceptEvidenceCollection(suggestion.id);
    expect(accepted, isNotNull);
    expect(accepted!.id, suggestion.id);
    expect(accepted.memberEvidenceIds, members);
    expect(accepted.pending, isFalse);
    expect(_hashes(controller), hashesBefore);
    expect(_sequence(controller), sequenceBefore);
    expect(
      controller.currentIncident.relationshipGroups,
      hasLength(groupsBefore),
    );
  });

  test('H/I dismiss stays session-local and restore keeps pending', () {
    final controller = _controller();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
    controller.ensureEvidenceCollections();
    final id = controller.evidenceCollections.firstWhere((c) => c.pending).id;

    controller.dismissPendingEvidenceCollection(id);
    expect(controller.dismissedCollectionIds, contains(id));
    expect(controller.evidenceCollections.any((c) => c.id == id), isTrue);
    expect(
      controller.evidenceCollections.firstWhere((c) => c.id == id).pending,
      isTrue,
    );

    controller.restorePendingEvidenceCollection(id);
    expect(controller.dismissedCollectionIds, isNot(contains(id)));
    expect(
      controller.evidenceCollections.firstWhere((c) => c.id == id).pending,
      isTrue,
    );
  });

  test('E remove from group is membership-only', () {
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final video = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final voice = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.voice,
    );
    final created = controller.createUserEvidenceCollection(
      evidenceIds: [photo, video, voice],
    )!;
    final hashesBefore = _hashes(controller);
    final idsBefore = [
      for (final item in controller.currentIncident.evidence) item.id,
    ];

    expect(
      controller.removeEvidenceFromCollection(
        collectionId: created.id,
        evidenceId: voice,
      ),
      isTrue,
    );
    final updated = controller.evidenceCollections.firstWhere(
      (c) => c.id == created.id,
    );
    expect(updated.memberEvidenceIds, isNot(contains(voice)));
    expect(updated.memberEvidenceIds.toSet(), {photo, video});
    expect([
      for (final item in controller.currentIncident.evidence) item.id,
    ], idsBefore);
    expect(_hashes(controller), hashesBefore);
    expect(
      controller.currentIncident.evidence.any((e) => e.id == voice),
      isTrue,
    );
  });

  test(
    'J archived Incident cannot mutate EvidenceCollection membership',
    () async {
      final controller = _controller();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final video = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      final created = controller.createUserEvidenceCollection(
        evidenceIds: [photo, video],
      )!;
      final membersBefore = List<String>.from(created.memberEvidenceIds);

      IncidentLibraryService.instance.summaries = [
        LibraryIncidentSummary(
          id: 'inc-col',
          title: 'Case',
          evidenceCount: 2,
          contextEnrichedCount: 0,
          integrityVerified: true,
          lastPreserved: 'Today',
        ),
      ];
      await IncidentLibraryService.instance.archiveIncident('inc-col');
      expect(controller.isArchivedReadOnly, isTrue);

      expect(
        controller.createUserEvidenceCollection(evidenceIds: [photo, video]),
        isNull,
      );
      expect(controller.acceptEvidenceCollection(created.id), isNull);
      expect(
        controller.removeEvidenceFromCollection(
          collectionId: created.id,
          evidenceId: photo,
        ),
        isFalse,
      );
      controller.dismissPendingEvidenceCollection(created.id);
      expect(
        controller.evidenceCollections
            .firstWhere((c) => c.id == created.id)
            .memberEvidenceIds,
        membersBefore,
      );
    },
  );

  testWidgets('D mixed origin keeps O-3 classification inside a group', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final note = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    final created = controller.createUserEvidenceCollection(
      evidenceIds: [photo, note],
    )!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: controller.currentIncident,
            orderedCapturedEvidenceIds: controller.timelineRepository
                .orderedCapturedEvidenceIds(),
            organizeCreatedIds: controller.organizeCreatedEvidenceIds,
            onEvidenceSelected: (_) {},
            onRemoveFromGroup: (collectionId, evidenceId) {
              controller.removeEvidenceFromCollection(
                collectionId: collectionId,
                evidenceId: evidenceId,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
    expect(find.text(OrganizeWorkspaceView.groupsTitle), findsWidgets);
    expect(find.text('Create Group'), findsNothing);
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo)),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
      findsOneWidget,
    );
    expect(created.memberEvidenceIds, containsAll([photo, note]));
  });

  testWidgets('E UI remove from group keeps evidence in the incident', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final video = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final created = controller.createUserEvidenceCollection(
      evidenceIds: [photo, video],
    )!;
    final hashesBefore = _hashes(controller);

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
                onEvidenceSelected: (_) {},
                onRemoveFromGroup: (collectionId, evidenceId) {
                  controller.removeEvidenceFromCollection(
                    collectionId: collectionId,
                    evidenceId: evidenceId,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPlusKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(OrganizeGroupsModal.transferBarKey));
    await tester.pump();
    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsOneWidget);
    final saved = find.byKey(
      OrganizeGroupCompositionModal.savedGroupKey(created.id),
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
      find.byKey(OrganizeGroupCompositionModal.cloneKey(video)),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(OrganizeGroupCompositionModal.cloneDiscardKey(video)),
    );
    await tester.pump();

    expect(
      find.text(OrganizeGroupCompositionModal.minMembersMessage),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey(video)),
      findsNothing,
    );
    expect(
      controller.evidenceCollections
          .firstWhere((c) => c.id == created.id)
          .memberEvidenceIds,
      contains(video),
    );
    expect(
      controller.currentIncident.evidence.any((e) => e.id == video),
      isTrue,
    );
    expect(_hashes(controller), hashesBefore);
  });

  testWidgets('J archived Organize view does not expose group mutation', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    final controller = _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final video = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final created = controller.createUserEvidenceCollection(
      evidenceIds: [photo, video],
    )!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: controller.currentIncident,
            orderedCapturedEvidenceIds: controller.timelineRepository
                .orderedCapturedEvidenceIds(),
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(
      find.byKey(OrganizeWorkspaceView.removeFromGroupKey(created.id, photo)),
      findsNothing,
    );
    expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
  });
}
