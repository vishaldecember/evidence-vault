import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_deletion_lifecycle.dart';
import 'package:evidence_vault/models/library_incident_record.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/memory/memory_recall_service.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/persistence/incident_owned_deletion_service.dart';
import 'package:evidence_vault/services/persistence/organize_context_persistence.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/widgets/home/home_incident_display_state.dart';
import 'package:evidence_vault/widgets/home/incident_lifecycle_dialogs.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/home/library_of_truth_section.dart';
import 'package:evidence_vault/widgets/workspace/incident_workspace_more_menu.dart';
import 'package:evidence_vault/widgets/vault/collection_member_resolution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryIncidentSummary _summary({
  required String id,
  required String title,
  bool isArchived = false,
  bool isRecentlyDeleted = false,
  DateTime? deletedAt,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: 2,
    contextEnrichedCount: 1,
    integrityVerified: true,
    lastPreserved: 'Today',
    isInProgress: !isArchived && !isRecentlyDeleted,
    isArchived: isArchived,
    isRecentlyDeleted: isRecentlyDeleted,
    deletedAt: deletedAt,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
    LocalEvidenceCache.resetForTests();
    MemoryRecallService.instance.resetForTests();
  });

  tearDown(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
    LocalEvidenceCache.resetForTests();
    MemoryRecallService.instance.resetForTests();
  });

  Future<void> pumpLibrary(
    WidgetTester tester,
    List<LibraryIncidentSummary> incidents,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LibraryOfTruthSection(
              incidents: incidents,
              onIncidentTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('H persisted deletion timestamp determines 30-day eligibility', () {
    final deletedAt = DateTime.utc(2026, 7, 30, 12);
    expect(
      IncidentDeletionLifecycle.eligibilityAt(deletedAt),
      DateTime.utc(2026, 8, 29, 12),
    );
    expect(
      IncidentDeletionLifecycle.daysRemaining(
        deletedAt: deletedAt,
        now: DateTime.utc(2026, 8, 6, 12),
      ),
      23,
    );
    expect(
      IncidentDeletionLifecycle.daysSinceDeleted(
        deletedAt: deletedAt,
        now: DateTime.utc(2026, 8, 11, 12),
      ),
      12,
    );
    expect(
      IncidentDeletionLifecycle.deletedAgoLabel(
        deletedAt: deletedAt,
        now: DateTime.utc(2026, 8, 11, 12),
      ),
      'Deleted 12 days ago',
    );
    expect(
      IncidentDeletionLifecycle.permanentInLabel(
        deletedAt: deletedAt,
        now: DateTime.utc(2026, 8, 11, 12),
      ),
      'Permanently deleted in 18 days',
    );
    expect(
      IncidentDeletionLifecycle.isEligibleForPermanentDeletion(
        deletedAt: deletedAt,
        now: DateTime.utc(2026, 8, 29, 11, 59),
      ),
      isFalse,
    );
    expect(
      IncidentDeletionLifecycle.isEligibleForPermanentDeletion(
        deletedAt: deletedAt,
        now: DateTime.utc(2026, 8, 29, 12),
      ),
      isTrue,
    );
  });

  test('active incidents move directly to Deleted without archiving', () async {
    final street = _summary(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];
    final when = DateTime.utc(2026, 8, 1, 9);

    expect(
      await IncidentLibraryService.instance.moveToRecentlyDeleted(
        'incident-a',
        deletedAt: when,
      ),
      isTrue,
    );
    expect(
      IncidentLibraryService.instance.isRecentlyDeletedId('incident-a'),
      isTrue,
    );
    expect(IncidentLibraryService.instance.isArchivedId('incident-a'), isFalse);
    expect(IncidentLibraryService.instance.activeSummaries, isEmpty);
    expect(IncidentLibraryService.instance.deletedAtFor('incident-a'), when);
  });

  test(
    'E archived incident moves to Recently Deleted and leaves Archived',
    () async {
      final street = _summary(id: 'incident-a', title: 'Street Fight');
      IncidentLibraryService.instance.summaries = [street];
      await IncidentLibraryService.instance.archiveIncident('incident-a');
      expect(
        IncidentLibraryService.instance.isArchivedId('incident-a'),
        isTrue,
      );

      final when = DateTime.utc(2026, 8, 1, 9);
      expect(
        await IncidentLibraryService.instance.moveToRecentlyDeleted(
          'incident-a',
          deletedAt: when,
        ),
        isTrue,
      );

      expect(
        IncidentLibraryService.instance.isArchivedId('incident-a'),
        isFalse,
      );
      expect(
        IncidentLibraryService.instance.isRecentlyDeletedId('incident-a'),
        isTrue,
      );
      expect(IncidentLibraryService.instance.archivedSummaries, isEmpty);
      expect(
        IncidentLibraryService.instance.recentlyDeletedSummaries.single.id,
        'incident-a',
      );
      expect(IncidentLibraryService.instance.deletedAtFor('incident-a'), when);
      expect(
        IncidentLibraryService.instance.summaries.single.title,
        'Street Fight',
      );
      expect(IncidentLibraryService.instance.summaries.single.evidenceCount, 2);
    },
  );

  testWidgets('F cancel keeps the incident Archived', (tester) async {
    final street = _summary(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];
    await IncidentLibraryService.instance.archiveIncident('incident-a');
    await pumpLibrary(tester, IncidentLibraryService.instance.summaries);

    await tester.tap(find.byKey(const Key('library_tab_archived')));
    await tester.pumpAndSettle();
    expect(find.text('Street Fight'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('library_incident_overflow_incident-a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_delete_incident')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_incident_dialog')), findsOneWidget);
    expect(find.text('Delete this incident?'), findsOneWidget);
    expect(
      find.text(
        'This incident will move to Deleted and be permanently removed after 30 days.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('delete_incident_cancel')));
    await tester.pumpAndSettle();

    expect(IncidentLibraryService.instance.isArchivedId('incident-a'), isTrue);
    expect(
      IncidentLibraryService.instance.isRecentlyDeletedId('incident-a'),
      isFalse,
    );
    expect(find.text('Street Fight'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
  });

  testWidgets('E widget path moves archived incident into Recently Deleted', (
    tester,
  ) async {
    final street = _summary(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];
    await IncidentLibraryService.instance.archiveIncident('incident-a');
    await pumpLibrary(tester, IncidentLibraryService.instance.summaries);

    await tester.tap(find.byKey(const Key('library_tab_archived')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library_incident_overflow_incident-a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_delete_incident')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_incident_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Street Fight'), findsNothing);
    expect(find.text('No archived incidents.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library_tab_recently_deleted')));
    await tester.pumpAndSettle();
    expect(find.text('Street Fight'), findsOneWidget);
    expect(find.textContaining('Deleted'), findsWidgets);
    expect(find.textContaining('Permanently deleted in'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Trash'), findsNothing);
  });

  test('G restore from Deleted returns the incident to Active', () async {
    final street = _summary(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];
    await IncidentLibraryService.instance.moveToRecentlyDeleted('incident-a');
    await IncidentLibraryService.instance.restoreFromRecentlyDeleted(
      'incident-a',
    );

    expect(
      IncidentLibraryService.instance.isRecentlyDeletedId('incident-a'),
      isFalse,
    );
    expect(IncidentLibraryService.instance.isArchivedId('incident-a'), isFalse);
    expect(
      IncidentLibraryService.instance.activeSummaries.single.id,
      'incident-a',
    );
    expect(IncidentLibraryService.instance.archivedSummaries, isEmpty);
  });

  testWidgets('G widget restore returns Deleted to Active', (tester) async {
    final street = _summary(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];
    await IncidentLibraryService.instance.moveToRecentlyDeleted('incident-a');
    await pumpLibrary(tester, IncidentLibraryService.instance.summaries);

    await tester.tap(find.byKey(const Key('library_tab_recently_deleted')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_restore_action')));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Street Fight'), findsNothing);
    await tester.tap(find.byKey(const Key('library_tab_active')));
    await tester.pumpAndSettle();
    expect(find.text('Street Fight'), findsOneWidget);
    expect(IncidentLibraryService.instance.isArchivedId('incident-a'), isFalse);
    expect(
      IncidentLibraryService.instance.isRecentlyDeletedId('incident-a'),
      isFalse,
    );
  });

  test(
    'I Recently Deleted is isolated from Active, Archived, search, counts',
    () async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [
          _summary(id: 'active-1', title: 'Live case'),
          _summary(id: 'archived-1', title: 'Old case', isArchived: true),
          _summary(
            id: 'deleted-1',
            title: 'Hidden case',
            isRecentlyDeleted: true,
            deletedAt: DateTime.utc(2026, 8, 1),
          ),
        ],
        records: [
          LibraryIncidentRecord(
            id: 'deleted-1',
            title: 'Hidden case',
            preservedAt: DateTime.utc(2026, 8, 1),
          ),
          LibraryIncidentRecord(
            id: 'active-1',
            title: 'Live case',
            preservedAt: DateTime.utc(2026, 8, 2),
          ),
        ],
      );

      expect(IncidentLibraryService.instance.activeSummaries.map((s) => s.id), [
        'active-1',
      ]);
      expect(
        IncidentLibraryService.instance.archivedSummaries.map((s) => s.id),
        ['archived-1'],
      );
      expect(
        IncidentLibraryService.instance.visibleOperationalSummaries.map(
          (s) => s.id,
        ),
        ['active-1', 'archived-1'],
      );
      expect(
        IncidentLibraryService.instance.recentlyDeletedSummaries.map(
          (s) => s.id,
        ),
        ['deleted-1'],
      );

      final display = HomeIncidentDisplayState.resolve(
        libraryIncidents: IncidentLibraryService.instance.summaries,
        sessionIncidentId: 'deleted-1',
        sessionTitle: 'Hidden case',
        sessionEvidenceCount: 2,
        sessionNarrativeCount: 0,
      );
      expect(display.continueIncident?.id, isNot('deleted-1'));

      MemoryRecallService.instance.recomputeFromLibrary();
      await Future<void>.delayed(Duration.zero);
      expect(
        MemoryRecallService.instance.items.any(
          (item) => item.incidentId == 'deleted-1',
        ),
        isFalse,
      );

      final members = resolveCollectionMembers(
        memberIncidentIds: ['active-1', 'deleted-1'],
        summaries: IncidentLibraryService.instance.summaries,
      );
      expect(members.first.isAvailable, isTrue);
      expect(members.last.isAvailable, isFalse);
    },
  );

  test('J permanent deletion removes only incident-owned local data', () async {
    final other = CachedEvidenceEntry(
      evidenceId: 'ev-other',
      incidentId: 'incident-b',
      userId: 'user-1',
      evidenceType: EvidenceRecordType.photo,
      createdAt: DateTime.utc(2026, 8, 1),
      capturedAt: DateTime.utc(2026, 8, 1),
      syncStatus: EvidenceSyncStatus.localCaptured,
      hash: 'hash-other',
    );
    final owned = CachedEvidenceEntry(
      evidenceId: 'ev-owned',
      incidentId: 'incident-a',
      userId: 'user-1',
      evidenceType: EvidenceRecordType.photo,
      createdAt: DateTime.utc(2026, 8, 1),
      capturedAt: DateTime.utc(2026, 8, 1),
      syncStatus: EvidenceSyncStatus.localCaptured,
      hash: 'hash-owned',
    );
    await LocalEvidenceCache.upsert(other);
    await LocalEvidenceCache.upsert(owned);
    await OrganizeContextPersistence.save(
      incidentId: 'incident-a',
      createdIds: {'ctx-a'},
      anchors: const [],
    );
    await OrganizeContextPersistence.save(
      incidentId: 'incident-b',
      createdIds: {'ctx-b'},
      anchors: const [],
    );

    IncidentLibraryService.instance.summaries = [
      _summary(id: 'incident-a', title: 'Street Fight'),
      _summary(id: 'incident-b', title: 'Keep me'),
    ];
    await IncidentLibraryService.instance.archiveIncident('incident-a');
    await IncidentLibraryService.instance.moveToRecentlyDeleted('incident-a');

    IncidentLibraryService.instance.debugDeletionService =
        const IncidentOwnedDeletionService();
    final result = await IncidentLibraryService.instance
        .permanentlyDeleteIncident('incident-a');

    expect(result, isNotNull);
    expect(result!.localEvidenceIds, ['ev-owned']);
    expect(IncidentLibraryService.instance.summaries.map((s) => s.id), [
      'incident-b',
    ]);
    expect(await LocalEvidenceCache.byId('ev-owned'), isNull);
    expect(await LocalEvidenceCache.byId('ev-other'), isNotNull);
    expect(await OrganizeContextPersistence.load('incident-a'), isNull);
    expect(
      (await OrganizeContextPersistence.load('incident-b'))!.createdIds,
      contains('ctx-b'),
    );
  });

  testWidgets('J manual permanent delete requires confirmation', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  confirmed = await showPermanentlyDeleteIncidentDialog(
                    context,
                  );
                },
                child: const Text('ask'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ask'));
    await tester.pump();

    expect(
      find.byKey(const Key('permanently_delete_incident_dialog')),
      findsOneWidget,
    );
    expect(find.text('Permanently delete this incident?'), findsOneWidget);
    expect(
      find.text(
        'This will permanently remove the incident and its associated data. This action cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('permanently_delete_incident_cancel')),
    );
    await tester.pump();
    expect(confirmed, isFalse);

    await tester.tap(find.text('ask'));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('permanently_delete_incident_confirm')),
    );
    await tester.pump();
    expect(confirmed, isTrue);
  });

  testWidgets('J Recently Deleted tile exposes overflow, not a card Delete', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryIncidentSummaryTile(
            incident: _summary(
              id: 'incident-a',
              title: 'Street Fight',
              isRecentlyDeleted: true,
              deletedAt: DateTime.utc(2026, 8, 1),
            ),
            onRestore: () {},
            onDeletePermanently: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('library_incident_overflow_incident-a')),
      findsOneWidget,
    );
    expect(find.text('Delete permanently'), findsNothing);
    expect(find.text('DELETE'), findsNothing);
  });

  test(
    'H sweep permanently deletes only after the persisted 30 days',
    () async {
      IncidentLibraryService.instance.summaries = [
        _summary(id: 'incident-old', title: 'Expired'),
        _summary(id: 'incident-new', title: 'Still recoverable'),
      ];
      await IncidentLibraryService.instance.archiveIncident('incident-old');
      await IncidentLibraryService.instance.archiveIncident('incident-new');
      await IncidentLibraryService.instance.moveToRecentlyDeleted(
        'incident-old',
        deletedAt: DateTime.utc(2026, 7, 1),
      );
      await IncidentLibraryService.instance.moveToRecentlyDeleted(
        'incident-new',
        deletedAt: DateTime.utc(2026, 8, 20),
      );

      final expired = await IncidentLibraryService.instance
          .sweepExpiredRecentlyDeleted(now: DateTime.utc(2026, 8, 29));
      expect(expired, ['incident-old']);
      expect(IncidentLibraryService.instance.summaries.map((s) => s.id), [
        'incident-new',
      ]);
      expect(
        IncidentLibraryService.instance.isRecentlyDeletedId('incident-new'),
        isTrue,
      );

      IncidentLibraryService.instance.summaries = [
        _summary(id: 'incident-29', title: 'Almost expired'),
      ];
      await IncidentLibraryService.instance.moveToRecentlyDeleted(
        'incident-29',
        deletedAt: DateTime.utc(2026, 7, 31, 12),
      );
      final stillHeld = await IncidentLibraryService.instance
          .sweepExpiredRecentlyDeleted(now: DateTime.utc(2026, 8, 29, 12));
      expect(stillHeld, isEmpty);
      expect(
        IncidentLibraryService.instance.isRecentlyDeletedId('incident-29'),
        isTrue,
      );
    },
  );

  test(
    'K archive → Recently Deleted → restore preserves integrity fields',
    () async {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(
          id: 'incident-a',
          title: 'Street Fight',
        ),
      );
      final photoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final before = controller.currentIncident.evidence.firstWhere(
        (item) => item.id == photoId,
      );
      final provenanceBefore = List.of(before.provenanceEvents);

      IncidentLibraryService.instance.summaries = [
        _summary(id: 'incident-a', title: 'Street Fight'),
      ];
      await IncidentLibraryService.instance.archiveIncident('incident-a');
      await IncidentLibraryService.instance.moveToRecentlyDeleted('incident-a');
      await IncidentLibraryService.instance.restoreFromRecentlyDeleted(
        'incident-a',
      );

      final after = controller.currentIncident.evidence.firstWhere(
        (item) => item.id == photoId,
      );
      expect(after.id, before.id);
      expect(after.contentHash, before.contentHash);
      expect(after.capturedAt, before.capturedAt);
      expect(after.recordedAt, before.recordedAt);
      expect(after.lastPreservedAt, before.lastPreservedAt);
      expect(after.provenanceEvents, provenanceBefore);
      expect(controller.currentIncident.id, 'incident-a');
    },
  );

  test(
    'L archive → Recently Deleted → restore preserves relationships',
    () async {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(
          id: 'incident-a',
          title: 'Street Fight',
        ),
      );
      final photoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final note = controller.addOrganizeContextEvidence(
        WorkspaceCaptureMode.note,
      );
      controller.setOrganizeContextAnchor(
        contextEvidenceId: note,
        capturedEvidenceId: photoId,
      );
      controller.commitRelationshipGroup(evidenceIds: [photoId, note]);
      final groupsBefore = [
        for (final group in controller.currentIncident.relationshipGroups)
          (group.id, List.of(group.memberEvidenceIds)),
      ];
      final anchorsBefore = [
        for (final anchor in controller.organizeContextAnchors)
          (anchor.contextEvidenceId, anchor.capturedEvidenceId),
      ];
      final relationshipsBefore = List.of(
        controller.aggregate.store.relationships,
      );

      IncidentLibraryService.instance.summaries = [
        _summary(id: 'incident-a', title: 'Street Fight'),
      ];
      await IncidentLibraryService.instance.archiveIncident('incident-a');
      await IncidentLibraryService.instance.moveToRecentlyDeleted('incident-a');
      await IncidentLibraryService.instance.restoreFromRecentlyDeleted(
        'incident-a',
      );

      expect(controller.organizeCreatedEvidenceIds, contains(note));
      expect([
        for (final anchor in controller.organizeContextAnchors)
          (anchor.contextEvidenceId, anchor.capturedEvidenceId),
      ], anchorsBefore);
      final groupsAfter = [
        for (final group in controller.currentIncident.relationshipGroups)
          (group.id, List.of(group.memberEvidenceIds)),
      ];
      expect(groupsAfter, hasLength(groupsBefore.length));
      expect(groupsAfter.single.$1, groupsBefore.single.$1);
      expect(groupsAfter.single.$2, groupsBefore.single.$2);
      expect(controller.aggregate.store.relationships, relationshipsBefore);
    },
  );

  test('recently deleted timestamps persist to SharedPreferences', () async {
    IncidentLibraryService.debugForceDiskPersist = true;
    addTearDown(() => IncidentLibraryService.debugForceDiskPersist = false);

    IncidentLibraryService.instance.summaries = [
      _summary(id: 'incident-a', title: 'Street Fight'),
    ];
    await IncidentLibraryService.instance.archiveIncident('incident-a');
    final when = DateTime.utc(2026, 8, 1, 10);
    await IncidentLibraryService.instance.moveToRecentlyDeleted(
      'incident-a',
      deletedAt: when,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('incident_lifecycle_recently_deleted_ids'),
      contains('incident-a'),
    );
    expect(
      prefs.getString('incident_lifecycle_deleted_at'),
      contains('incident-a'),
    );
    expect(
      prefs.getString('incident_lifecycle_deleted_at'),
      contains(when.toIso8601String()),
    );
  });

  testWidgets('workspace More menu can cancel or soft-delete the incident', (
    tester,
  ) async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(
        id: 'incident-a',
        title: 'Street Fight',
      ),
    );
    IncidentLibraryService.instance.summaries = [
      _summary(id: 'incident-a', title: 'Street Fight'),
    ];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));
    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          incidentId: 'incident-a',
          controller: controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(IncidentWorkspaceMoreMenu.buttonKey), findsOneWidget);
    await tester.tap(find.byKey(IncidentWorkspaceMoreMenu.buttonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(IncidentWorkspaceMoreMenu.renameLabel), findsOneWidget);
    expect(find.text(IncidentWorkspaceMoreMenu.archiveLabel), findsOneWidget);
    expect(find.text(IncidentWorkspaceMoreMenu.deleteLabel), findsOneWidget);

    await tester.tap(find.byKey(IncidentWorkspaceMoreMenu.deleteKey).last);
    await tester.pump();
    expect(find.byKey(const Key('delete_incident_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete_incident_cancel')));
    await tester.pump();
    expect(
      IncidentLibraryService.instance.isRecentlyDeletedId('incident-a'),
      isFalse,
    );

    await tester.tap(find.byKey(IncidentWorkspaceMoreMenu.buttonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(IncidentWorkspaceMoreMenu.deleteKey).last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete_incident_confirm')));
    await tester.pump();
    expect(
      IncidentLibraryService.instance.isRecentlyDeletedId('incident-a'),
      isTrue,
    );
    expect(
      IncidentLibraryService.instance.deletedAtFor('incident-a'),
      isNotNull,
    );
    expect(controller.currentIncident.evidence, isEmpty);
    expect(controller.currentIncident.id, 'incident-a');
  });
}
