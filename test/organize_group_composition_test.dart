import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_mark.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_group_composition.dart';
import 'package:evidence_vault/widgets/workspace/organize_groups_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    incidentId: 'inc-group-compose',
  );
}

final photo = _item(
  id: 'photo',
  kind: WorkspaceEvidenceKind.image,
  at: DateTime(2026, 3, 1, 21, 10),
);
final video = _item(
  id: 'video',
  kind: WorkspaceEvidenceKind.video,
  at: DateTime(2026, 3, 1, 21, 12),
);

CurrentIncident _incident({List<EvidenceCollection> collections = const []}) {
  return CurrentIncident(
    id: 'inc-group-compose',
    title: 'Street',
    status: IncidentStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    manuallyComplete: false,
    journeyStage: JourneyStage.building,
    captureProgressPercent: 0,
    timelineAnchorCount: 2,
    relationshipGroupCount: 0,
    narrativeEventCount: 0,
    evidence: [photo, video],
    journeyEvidence: [photo, video],
    relationshipGroups: const [],
    evidenceCollections: collections,
    trustPackageReady: true,
    trustPackageProgressPercent: 40,
  );
}

Future<void> _pumpOrganize(
  WidgetTester tester, {
  List<EvidenceCollection> collections = const [],
  EvidenceCollection? Function({
    required String name,
    required List<String> evidenceIds,
    String? collectionId,
  })?
  onCommit,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: _incident(collections: collections),
          orderedCapturedEvidenceIds: const ['photo', 'video'],
          onEvidenceSelected: (_) {},
          onAddOrganizeContext: (_) {},
          onCommitGroupComposition: onCommit,
        ),
      ),
    ),
  );
}

Future<void> _openTransferComposition(WidgetTester tester) async {
  await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPlusKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byKey(OrganizeGroupsModal.modalKey), findsOneWidget);
  expect(find.byKey(OrganizeGroupsModal.transferBarKey), findsOneWidget);
  await tester.tap(find.byKey(OrganizeGroupsModal.transferBarKey));
  await tester.pump();
}

Future<void> _openSavedGroupInComposition(
  WidgetTester tester,
  String collectionId,
) async {
  final saved = find.byKey(
    OrganizeGroupCompositionModal.savedGroupKey(collectionId),
  );
  expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsOneWidget);
  expect(saved, findsOneWidget);
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
}

Future<void> _dragCloneOntoModal(WidgetTester tester, String evidenceId) async {
  final origin = tester.getCenter(
    find.byKey(OrganizeWorkspaceView.rowKey(evidenceId)),
  );
  final target = tester.getCenter(
    find.byKey(OrganizeGroupCompositionModal.dropKey),
  );
  final gesture = await tester.startGesture(origin);
  await tester.pump(
    OrganizeChronologyCanvas.dragStartDelay + const Duration(milliseconds: 80),
  );
  await gesture.moveTo(target);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets(
    'plus opens an empty right-side composition modal and freezes chrome',
    (tester) async {
      await _pumpOrganize(tester);

      expect(
        find.byKey(OrganizeWorkspaceView.addContextBarKey),
        findsOneWidget,
      );

      await _openTransferComposition(tester);

      expect(
        find.byKey(OrganizeGroupCompositionModal.modalKey),
        findsOneWidget,
      );
      expect(find.text(OrganizeGroupCompositionModal.dropHint), findsOneWidget);
      expect(
        find.text(OrganizeGroupCompositionModal.namePlaceholder),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeGroupCompositionModal.titleBoxKey),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeGroupCompositionModal.dropZoneKey),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(OrganizeGroupCompositionModal.dropZoneKey))
            .height,
        greaterThanOrEqualTo(
          OrganizeGroupCompositionModal.dropZoneMinHeight - 1,
        ),
      );
      expect(
        tester
            .getSize(find.byKey(OrganizeGroupCompositionModal.modalKey))
            .height,
        greaterThanOrEqualTo(
          OrganizeGroupCompositionModal.fourCloneMinHeight - 1,
        ),
      );
      expect(
        tester
            .getSize(find.byKey(OrganizeGroupCompositionModal.modalKey))
            .height,
        lessThan(330),
      );
      expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsNothing);
      expect(
        find.byKey(OrganizeChronologyCanvas.groupSelectDiscardKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.groupSelectDiscardKey('video')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('video')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OrganizePlacementWobble>(
              find
                  .ancestor(
                    of: find.byKey(
                      OrganizeChronologyCanvas.fixedTileKey('photo'),
                    ),
                    matching: find.byType(OrganizePlacementWobble),
                  )
                  .first,
            )
            .active,
        isTrue,
      );
      expect(
        tester.getCenter(find.byKey(OrganizeGroupCompositionModal.modalKey)).dx,
        greaterThan(
          tester.getCenter(find.byKey(OrganizeWorkspaceView.viewKey)).dx,
        ),
      );
    },
  );

  testWidgets(
    'dragging a clone leaves the original chronology moment in place',
    (tester) async {
      String? committedName;
      List<String>? committedIds;
      await _pumpOrganize(
        tester,
        onCommit: ({required name, required evidenceIds, collectionId}) {
          committedName = name;
          committedIds = evidenceIds;
          return null;
        },
      );

      await _openTransferComposition(tester);

      final photoBefore = tester.getRect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      );

      await _dragCloneOntoModal(tester, 'photo');

      expect(
        find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        findsOneWidget,
      );
      final photoAfter = tester.getRect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      );
      expect((photoAfter.center - photoBefore.center).distance, lessThan(12));
      expect(
        find.text(OrganizeGroupCompositionModal.namePlaceholder),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InvestigationNodeWobble>(
              find
                  .descendant(
                    of: find.byKey(
                      OrganizeGroupCompositionModal.cloneKey('photo'),
                    ),
                    matching: find.byType(InvestigationNodeWobble),
                  )
                  .first,
            )
            .active,
        isTrue,
      );

      final modalRect = tester.getRect(
        find.byKey(OrganizeGroupCompositionModal.modalKey),
      );
      final cloneRect = tester.getRect(
        find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
      );
      await tester.tapAt(Offset(modalRect.right - 14, cloneRect.center.dy));
      await tester.pump();
      expect(
        tester
            .widget<InvestigationNodeWobble>(
              find
                  .descendant(
                    of: find.byKey(
                      OrganizeGroupCompositionModal.cloneKey('photo'),
                    ),
                    matching: find.byType(InvestigationNodeWobble),
                  )
                  .first,
            )
            .active,
        isFalse,
      );
      expect(
        find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
        findsOneWidget,
      );

      await _dragCloneOntoModal(tester, 'video');

      expect(
        find.byKey(OrganizeGroupCompositionModal.cloneKey('video')),
        findsOneWidget,
      );
      expect(
        find.text(OrganizeGroupCompositionModal.namePlaceholder),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(OrganizeGroupCompositionModal.nameFieldKey),
        'Night walk',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(committedName, 'Night walk');
      expect(committedIds, ['photo', 'video']);
    },
  );

  testWidgets('tapping Organize workspace exits composition and stops wobble', (
    tester,
  ) async {
    await _pumpOrganize(tester);
    await _openTransferComposition(tester);

    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsOneWidget);
    expect(
      tester
          .widget<OrganizePlacementWobble>(
            find
                .ancestor(
                  of: find.byKey(
                    OrganizeChronologyCanvas.fixedTileKey('photo'),
                  ),
                  matching: find.byType(OrganizePlacementWobble),
                )
                .first,
          )
          .active,
      isTrue,
    );

    final workspace = tester.getRect(
      find.byKey(OrganizeWorkspaceView.workspaceDismissKey),
    );
    await tester.tapAt(Offset(workspace.left + 16, workspace.top + 8));
    await tester.pump();

    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsNothing);
    expect(
      find.byKey(OrganizeChronologyCanvas.groupSelectDiscardKey('photo')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      findsOneWidget,
    );
    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsOneWidget);
  });

  testWidgets('naming an empty draft does not persist a custom group', (
    tester,
  ) async {
    var committed = false;
    await _pumpOrganize(
      tester,
      onCommit: ({required name, required evidenceIds, collectionId}) {
        committed = true;
        return null;
      },
    );
    await _openTransferComposition(tester);
    await tester.enterText(
      find.byKey(OrganizeGroupCompositionModal.nameFieldKey),
      'Night Incident',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(committed, isFalse);

    final workspace = tester.getRect(
      find.byKey(OrganizeWorkspaceView.workspaceDismissKey),
    );
    await tester.tapAt(Offset(workspace.left + 16, workspace.top + 8));
    await tester.pump();
    expect(committed, isFalse);
    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsNothing);
  });

  testWidgets(
    'removing a clone never deletes chronology and can return to zero moments',
    (tester) async {
      await _pumpOrganize(tester);

      await _openTransferComposition(tester);
      await _dragCloneOntoModal(tester, 'photo');
      await _dragCloneOntoModal(tester, 'video');

      expect(
        find.text(OrganizeGroupCompositionModal.namePlaceholder),
        findsOneWidget,
      );

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
      expect(
        find.byKey(OrganizeGroupCompositionModal.cloneKey('video')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('video')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(OrganizeGroupCompositionModal.cloneDiscardKey('video')),
      );
      await tester.pump();
      expect(
        find.byKey(OrganizeGroupCompositionModal.cloneKey('video')),
        findsNothing,
      );
      expect(
        find.text(OrganizeGroupCompositionModal.namePlaceholder),
        findsOneWidget,
      );
    },
  );

  testWidgets('opening an existing custom group restores member clones', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 1);
    final collections = <EvidenceCollection>[
      EvidenceCollection(
        id: 'col-night',
        incidentId: 'inc-group-compose',
        name: 'Night walk',
        systemGenerated: false,
        pending: false,
        displayOrder: 0,
        createdAt: now,
        updatedAt: now,
        category: 'custom',
        memberEvidenceIds: const ['photo', 'video'],
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
                incident: _incident(collections: collections),
                orderedCapturedEvidenceIds: const ['photo', 'video'],
                onEvidenceSelected: (_) {},
                onAddOrganizeContext: (_) {},
                onCommitGroupComposition:
                    ({required name, required evidenceIds, collectionId}) {
                      final index = collections.indexWhere(
                        (group) => group.id == collectionId,
                      );
                      if (index < 0 || evidenceIds.isEmpty) {
                        return null;
                      }
                      final updated = collections[index].copyWith(
                        name: name,
                        memberEvidenceIds: evidenceIds,
                        updatedAt: now,
                      );
                      setState(() => collections[index] = updated);
                      return updated;
                    },
                onDeleteCustomGroup: (id) {
                  setState(
                    () => collections.removeWhere((group) => group.id == id),
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    await _openTransferComposition(tester);
    await _openSavedGroupInComposition(tester, 'col-night');

    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsOneWidget);
    expect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('video')),
      findsOneWidget,
    );
    expect(find.text('Night walk'), findsWidgets);
    expect(
      find.byKey(OrganizeGroupCompositionModal.nameFieldKey),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      findsOneWidget,
    );

    await tester.longPress(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('video')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(OrganizeGroupCompositionModal.cloneDiscardKey('video')),
    );
    await tester.pump();

    expect(
      find.text(OrganizeGroupCompositionModal.minMembersMessage),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('video')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('video')),
      findsOneWidget,
    );
    expect(collections.single.memberEvidenceIds, ['photo']);

    await tester.scrollUntilVisible(
      find.byKey(OrganizeGroupCompositionModal.closeKey),
      -40,
      scrollable: find
          .descendant(
            of: find.byKey(OrganizeGroupCompositionModal.savedScrollKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(OrganizeGroupCompositionModal.closeKey));
    await tester.pump();
    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsNothing);
    await _openTransferComposition(tester);
    await _openSavedGroupInComposition(tester, 'col-night');
    expect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('video')),
      findsNothing,
    );

    await tester.longPress(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(OrganizeGroupCompositionModal.cloneDiscardKey('photo')),
    );
    await tester.pump();

    expect(collections, isEmpty);
    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsNothing);
    expect(find.text('Night walk'), findsNothing);
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('video')),
      findsOneWidget,
    );
  });

  testWidgets('saved groups stay in the workspace modal and bottom matrix', (
    tester,
  ) async {
    final collections = <EvidenceCollection>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeWorkspaceView(
                incident: _incident(collections: collections),
                orderedCapturedEvidenceIds: const ['photo', 'video'],
                onEvidenceSelected: (_) {},
                onAddOrganizeContext: (_) {},
                onCommitGroupComposition:
                    ({required name, required evidenceIds, collectionId}) {
                      final created = EvidenceCollection(
                        id: 'col-${collections.length}',
                        incidentId: 'inc-group-compose',
                        name: name,
                        systemGenerated: false,
                        pending: false,
                        displayOrder: collections.length,
                        createdAt: DateTime(2026, 3, 1),
                        updatedAt: DateTime(2026, 3, 1),
                        category: 'custom',
                        memberEvidenceIds: evidenceIds,
                      );
                      setState(() => collections.add(created));
                      return created;
                    },
              );
            },
          ),
        ),
      ),
    );

    await _openTransferComposition(tester);
    final emptyHeight = tester
        .getSize(find.byKey(OrganizeGroupCompositionModal.modalKey))
        .height;
    expect(
      emptyHeight,
      greaterThanOrEqualTo(
        OrganizeGroupCompositionModal.fourCloneMinHeight - 1,
      ),
    );
    expect(emptyHeight, lessThan(330));

    await _dragCloneOntoModal(tester, 'photo');
    await _dragCloneOntoModal(tester, 'video');
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getSize(find.byKey(OrganizeGroupCompositionModal.modalKey)).height,
      greaterThanOrEqualTo(emptyHeight),
    );
    final photoClone = tester.getRect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
    );
    final videoClone = tester.getRect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('video')),
    );
    expect(photoClone.overlaps(videoClone), isFalse);

    await tester.enterText(
      find.byKey(OrganizeGroupCompositionModal.nameFieldKey),
      'Night walk',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsOneWidget);
    expect(find.text('Night walk'), findsWidgets);
    expect(
      find.byKey(OrganizeGroupCompositionModal.savedGroupKey('col-0')),
      findsOneWidget,
    );
    expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
    expect(find.text('Create Group'), findsNothing);
  });

  testWidgets('workspace group list scrolls inside the compact modal', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 1);
    await _pumpOrganize(
      tester,
      collections: [
        for (var i = 0; i < 8; i++)
          EvidenceCollection(
            id: 'col-$i',
            incidentId: 'inc-group-compose',
            name: i.isEven ? 'Night $i' : 'Media $i',
            systemGenerated: i.isOdd,
            pending: false,
            displayOrder: i,
            createdAt: now,
            updatedAt: now,
            category: i.isOdd ? 'media' : 'custom',
            memberEvidenceIds: const ['photo', 'video'],
          ),
      ],
    );

    expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
    expect(find.text('Create Group'), findsNothing);

    await _openTransferComposition(tester);

    expect(
      find.byKey(OrganizeGroupCompositionModal.savedListKey),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(OrganizeGroupCompositionModal.modalKey)).height,
      lessThanOrEqualTo(
        OrganizeGroupCompositionModal.maxHeightFor(const Size(390, 844), 0) + 1,
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(OrganizeGroupCompositionModal.savedGroupKey('col-7')),
      40,
      scrollable: find
          .descendant(
            of: find.byKey(OrganizeGroupCompositionModal.savedScrollKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(OrganizeGroupCompositionModal.savedGroupKey('col-7')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(OrganizeGroupCompositionModal.savedGroupKey('col-3')),
      -40,
      scrollable: find
          .descendant(
            of: find.byKey(OrganizeGroupCompositionModal.savedScrollKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(
      find.byKey(OrganizeGroupCompositionModal.savedGroupKey('col-3')),
    );
    await tester.pump();
    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsOneWidget);
    expect(
      find.byKey(OrganizeGroupCompositionModal.cloneKey('photo')),
      findsOneWidget,
    );
  });
}
