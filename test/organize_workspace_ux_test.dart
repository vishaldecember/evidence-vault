import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:evidence_vault/widgets/workspace/product_concept_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  String? contentHash,
  DateTime? capturedAt,
  DateTime? recordedAt,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: capturedAt ?? (kind.isPrimaryChronology ? at : null),
    recordedAt: recordedAt ?? (kind.isPrimaryChronology ? null : at),
    contentHash: contentHash ?? 'hash-$id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-o8',
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
  List<EvidenceCollection> collections = const [],
  IncidentStatus status = IncidentStatus.active,
}) {
  return CurrentIncident(
    id: 'inc-o8',
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
  VoidCallback? onCreateGroup,
  ValueChanged<WorkspaceEvidenceItem>? onEvidenceSelected,
  void Function(String collectionId, String evidenceId)? onRemoveFromGroup,
  ValueChanged<String>? onAcceptSuggestion,
  ValueChanged<String>? onDismissSuggestion,
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
          onEvidenceSelected: onEvidenceSelected ?? (_) {},
          onCreateGroup: onCreateGroup,
          onRemoveFromGroup: onRemoveFromGroup,
          onAcceptSuggestion: onAcceptSuggestion,
          onDismissSuggestion: onDismissSuggestion,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final t0 = DateTime.utc(2026, 8, 24, 10);
  final photo = _item(
    id: 'photo',
    kind: WorkspaceEvidenceKind.image,
    at: t0.add(const Duration(minutes: 2)),
  );
  final video = _item(
    id: 'video',
    kind: WorkspaceEvidenceKind.video,
    at: t0.add(const Duration(minutes: 3)),
  );
  final capturedNote = _item(
    id: 'note-capture',
    kind: WorkspaceEvidenceKind.note,
    at: t0.add(const Duration(seconds: 5)),
  );
  final capturedVoice = _item(
    id: 'voice-capture',
    kind: WorkspaceEvidenceKind.voice,
    at: t0.add(const Duration(seconds: 6)),
  );
  final capturedFile = _item(
    id: 'file-capture',
    kind: WorkspaceEvidenceKind.attachment,
    at: t0.add(const Duration(seconds: 7)),
  );
  final addedNote = _item(
    id: 'note-org',
    kind: WorkspaceEvidenceKind.note,
    at: t0.add(const Duration(minutes: 8)),
  );

  EvidenceCollection group() {
    return EvidenceCollection(
      id: 'group-1',
      incidentId: 'inc-o8',
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
      incidentId: 'inc-o8',
      name: 'Possible pair',
      systemGenerated: true,
      pending: true,
      displayOrder: 1,
      createdAt: t0,
      updatedAt: t0,
      memberEvidenceIds: const ['photo', 'video'],
    );
  }

  testWidgets(
    'A evidence structure appears before Groups; Suggestions section is gone',
    (tester) async {
      await _pumpOrganize(
        tester,
        incident: _incident(
          evidence: [photo, video],
          collections: [group(), suggestion()],
        ),
        orderedCapturedEvidenceIds: const ['photo', 'video'],
      );

      final structure = tester.getTopLeft(
        find.byKey(OrganizeWorkspaceView.structureKey),
      );
      final groups = tester.getTopLeft(
        find.byKey(OrganizeWorkspaceView.groupsKey),
      );

      expect(structure.dy, lessThan(groups.dy));
      expect(find.byKey(OrganizeWorkspaceView.structureKey), findsOneWidget);
      expect(find.text('Evidence structure'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(OrganizeWorkspaceView.groupsKey),
          matching: find.text(OrganizeWorkspaceView.groupsTitle),
        ),
        findsOneWidget,
      );
      expect(find.byKey(OrganizeWorkspaceView.suggestionsKey), findsNothing);
      expect(find.text('Suggestions'), findsNothing);
      expect(find.text('Suggested evidence group'), findsNothing);
      expect(find.text('Create Group'), findsNothing);
    },
  );

  testWidgets('B compact header keeps readiness information discoverable', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, video]),
      orderedCapturedEvidenceIds: const ['photo', 'video'],
    );

    expect(find.byKey(OrganizeWorkspaceView.headerKey), findsOneWidget);
    expect(find.byKey(const Key('organize_incident_title')), findsOneWidget);
    expect(find.byKey(OrganizeReadinessInfoButton.buttonKey), findsOneWidget);
    expect(find.text('Organize readiness'), findsNothing);

    await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(OrganizeReadinessGuideSheet.sheetKey), findsOneWidget);
    expect(find.text(ProductConceptCopy.title), findsOneWidget);
  });

  test('C O-2 chronology ordering is unchanged by presentation', () {
    final leftover = _item(
      id: 'leftover',
      kind: WorkspaceEvidenceKind.voice,
      at: t0.add(const Duration(hours: 2)),
    );
    final scrambled = [addedNote, leftover, video, photo];
    final ordered = OrganizeChronologyCanvas.displayOrder(
      items: scrambled,
      orderedCapturedEvidenceIds: const ['video', 'photo'],
      organizeCreatedIds: const {'note-org'},
      incidentId: 'inc-o8',
    );
    expect(
      [for (final item in ordered) item.id],
      ['video', 'photo', 'leftover', 'note-org'],
    );
  });

  testWidgets(
    'C visual chronology keeps earlier canonical items above later ones',
    (tester) async {
      await _pumpOrganize(
        tester,
        incident: _incident(evidence: [video, photo]),
        orderedCapturedEvidenceIds: const ['photo', 'video'],
      );

      final earlier = tester.getTopLeft(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      );
      final later = tester.getTopLeft(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('video')),
      );
      expect(earlier.dy, lessThan(later.dy));
    },
  );

  testWidgets(
    'D/E/F captured vs added context still uses organizeCreatedEvidenceIds only',
    (tester) async {
      await _pumpOrganize(
        tester,
        incident: _incident(
          evidence: [
            photo,
            capturedNote,
            capturedVoice,
            capturedFile,
            addedNote,
          ],
        ),
        orderedCapturedEvidenceIds: const ['photo', 'voice-capture'],
        organizeCreatedIds: const {'note-org'},
      );

      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('note-capture')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('voice-capture')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('file-capture')),
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
        find.byKey(
          OrganizeChronologyCanvas.addedContextCaptionKey('note-capture'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.addedContextCaptionKey('note-org')),
        findsNothing,
      );
      expect(
        find.text(OrganizeChronologyCanvas.capturedEvidenceLabel),
        findsNothing,
      );
      expect(find.text('Groups'), findsWidgets);
      expect(find.text('+'), findsOneWidget);
      expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
      expect(
        find.text(OrganizeChronologyCanvas.addedContextLabel),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.addedContextLaneHeaderKey),
        findsNothing,
      );
    },
  );

  testWidgets('G group membership IDs are unchanged by presentation', (
    tester,
  ) async {
    final collection = group();
    final membersBefore = List<String>.from(collection.memberEvidenceIds);
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, video], collections: [collection]),
      orderedCapturedEvidenceIds: const ['photo', 'video'],
    );

    expect(collection.memberEvidenceIds, membersBefore);
    expect(collection.memberEvidenceIds, ['photo', 'video']);
  });

  testWidgets('H Create Group is not actionable with fewer than two records', (
    tester,
  ) async {
    var created = false;
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo]),
      orderedCapturedEvidenceIds: const ['photo'],
      onCreateGroup: () => created = true,
    );

    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(find.text('Create Group'), findsNothing);
    expect(created, isFalse);
  });

  testWidgets('H Create Group text is no longer on the Groups card', (
    tester,
  ) async {
    var created = false;
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, video]),
      orderedCapturedEvidenceIds: const ['photo', 'video'],
      onCreateGroup: () => created = true,
    );

    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(find.text('Create Group'), findsNothing);
    expect(created, isFalse);
    expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
  });

  testWidgets('I inspector still opens from evidence tiles', (tester) async {
    String? selectedId;
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: [photo, video]),
      orderedCapturedEvidenceIds: const ['photo', 'video'],
      onEvidenceSelected: (item) => selectedId = item.id,
    );

    await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey('photo')));
    await tester.pump();
    expect(selectedId, 'photo');
  });

  testWidgets('J archived incidents remain read-only', (tester) async {
    await _pumpOrganize(
      tester,
      incident: _incident(
        evidence: [photo, video],
        collections: [group(), suggestion()],
        status: IncidentStatus.archived,
      ),
      orderedCapturedEvidenceIds: const ['photo', 'video'],
    );

    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsNothing);
    expect(
      find.byKey(OrganizeWorkspaceView.removeFromGroupKey('group-1', 'photo')),
      findsNothing,
    );
    expect(find.text('Create Group'), findsNothing);
  });

  testWidgets(
    'K/L presentation does not mutate chronology or evidence fields',
    (tester) async {
      final evidence = [photo, video, addedNote];
      final collection = group();
      final before = [for (final item in evidence) _integrity(item)];
      final membersBefore = List<String>.from(collection.memberEvidenceIds);
      final capturedOrder = ['photo', 'video'];

      await _pumpOrganize(
        tester,
        incident: _incident(evidence: evidence, collections: [collection]),
        orderedCapturedEvidenceIds: capturedOrder,
        organizeCreatedIds: const {'note-org'},
      );

      expect([for (final item in evidence) _integrity(item)], before);
      expect(capturedOrder, ['photo', 'video']);
      expect(collection.memberEvidenceIds, membersBefore);
      expect(
        OrganizeChronologyCanvas.displayOrder(
          items: evidence,
          orderedCapturedEvidenceIds: capturedOrder,
          organizeCreatedIds: const {'note-org'},
          incidentId: 'inc-o8',
        ).map((item) => item.id),
        ['photo', 'video', 'note-org'],
      );
    },
  );

  testWidgets('empty state copy is preserved without synthetic chronology', (
    tester,
  ) async {
    await _pumpOrganize(tester, incident: _incident(evidence: const []));

    expect(
      find.text(
        'No evidence in this incident yet. Capture to begin organizing.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.capturedLaneHeaderKey),
      findsNothing,
    );
    expect(find.byKey(const Key('organize_create_group')), findsNothing);
    expect(find.text('fake'), findsNothing);
  });
}
