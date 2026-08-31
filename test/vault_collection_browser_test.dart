import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/vault/incident_collection.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/navigation/app_navigation.dart';
import 'package:evidence_vault/screens/collection_browser_screen.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/vault_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:evidence_vault/widgets/common/status_badge.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:evidence_vault/widgets/vault/collection_member_resolution.dart';
import 'package:evidence_vault/widgets/vault/vault_collection_module.dart';
import 'package:evidence_vault/widgets/vault/vault_incident_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryIncidentSummary _incident({
  required String id,
  required String title,
  bool isArchived = false,
  int evidenceCount = 3,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: evidenceCount,
    contextEnrichedCount: 1,
    integrityVerified: true,
    lastPreserved: 'Today',
    isInProgress: !isArchived,
    isArchived: isArchived,
    createdAt: DateTime.utc(2026, 8, 20, 10),
    updatedAt: DateTime.utc(2026, 8, 21, 11),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-phase4';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  tearDown(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  test('resolveCollectionMembers keeps ID order and isolates missing members',
      () {
    final a = _incident(id: 'incident-a', title: 'Alpha');
    final b = _incident(id: 'incident-b', title: 'Bravo');
    final members = resolveCollectionMembers(
      memberIncidentIds: ['incident-a', 'missing-x', 'incident-b'],
      summaries: [b, a],
    );

    expect(members, hasLength(3));
    expect(members[0].incidentId, 'incident-a');
    expect(members[0].summary?.title, 'Alpha');
    expect(members[1].incidentId, 'missing-x');
    expect(members[1].isAvailable, isFalse);
    expect(members[2].incidentId, 'incident-b');
  });

  Future<IncidentCollection> seedCollection({
    List<String> memberIds = const ['incident-a', 'incident-b'],
  }) {
    return IncidentCollectionStore.instance.create(
      userId: userId,
      title: 'Collection',
      memberIncidentIds: memberIds,
    );
  }

  Future<void> pumpVault(
    WidgetTester tester,
    List<LibraryIncidentSummary> incidents, {
    ValueChanged<LibraryIncidentSummary>? onIncidentOpen,
  }) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    IncidentLibraryService.instance.summaries = incidents;
    await tester.pumpWidget(
      MaterialApp(
        home: VaultScreen(
          collectionUserId: userId,
          onIncidentOpen: onIncidentOpen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpBrowser(
    WidgetTester tester, {
    required IncidentCollection collection,
    ValueChanged<LibraryIncidentSummary>? onIncidentOpen,
    List<LibraryIncidentSummary> incidents = const [],
    String? collectionIdOverride,
  }) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(480, 915));
    IncidentLibraryService.instance.summaries = incidents;
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionBrowserScreen(
          collectionId: collectionIdOverride ?? collection.id,
          userId: userId,
          initialCollection: collectionIdOverride == null ? collection : null,
          onIncidentOpen: onIncidentOpen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder tileTitle(String title) {
    return find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is VaultIncidentModule ||
            widget is LibraryIncidentSummaryTile,
      ),
      matching: find.text(title),
    );
  }

  Future<void> tapCollection(
    WidgetTester tester,
    String collectionId,
  ) async {
    final module = find.byKey(VaultCollectionModule.moduleKey(collectionId));
    await tester.ensureVisible(module);
    await tester.pump();
    await tester.tap(module);
  }

  testWidgets('collection module shows title, count, and is not an incident tile',
      (tester) async {
    final collection = await seedCollection();
    await pumpVault(tester, [
      _incident(id: 'incident-a', title: 'Alpha'),
      _incident(id: 'incident-b', title: 'Bravo'),
      _incident(id: 'incident-c', title: 'Charlie'),
    ]);

    final module = find.byKey(VaultCollectionModule.moduleKey(collection.id));
    expect(module, findsOneWidget);
    expect(
      find.descendant(of: module, matching: find.text('COLLECTION')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: module, matching: find.text('2 incidents')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: module, matching: find.text('Alpha')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: module, matching: find.byType(StatusBadge)),
      findsNothing,
    );
    expect(
      find.descendant(of: module, matching: find.text('Evidence')),
      findsNothing,
    );
    expect(tileTitle('Charlie'), findsOneWidget);
  });

  testWidgets('tapping collection opens the collection browser', (tester) async {
    final collection = await seedCollection();
    await pumpVault(tester, [
      _incident(id: 'incident-a', title: 'Alpha'),
      _incident(id: 'incident-b', title: 'Bravo'),
    ]);

    await tapCollection(tester, collection.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CollectionBrowserScreen), findsOneWidget);
    expect(
      find.byKey(CollectionBrowserScreen.screenKey(collection.id)),
      findsOneWidget,
    );
    expect(tileTitle('Alpha'), findsOneWidget);
    expect(tileTitle('Bravo'), findsOneWidget);
    expect(find.text('2 incidents'), findsWidgets);
  });

  testWidgets('browser loads the persisted collection and member IDs',
      (tester) async {
    final collection = await seedCollection();
    final opened = <LibraryIncidentSummary>[];
    await pumpBrowser(
      tester,
      collection: collection,
      incidents: [
        _incident(id: 'incident-a', title: 'Alpha'),
        _incident(id: 'incident-b', title: 'Bravo'),
      ],
      onIncidentOpen: opened.add,
    );

    expect(
      find.byKey(CollectionBrowserScreen.screenKey(collection.id)),
      findsOneWidget,
    );
    expect(tileTitle('Alpha'), findsOneWidget);
    expect(tileTitle('Bravo'), findsOneWidget);
    expect(find.text('2 incidents'), findsOneWidget);

    await tester.tap(tileTitle('Alpha'));
    await tester.pump();
    expect(opened, hasLength(1));
    expect(opened.single.id, 'incident-a');
  });

  testWidgets('missing members do not crash the browser', (tester) async {
    final collection = await seedCollection(
      memberIds: ['incident-a', 'ghost-id'],
    );
    await pumpBrowser(
      tester,
      collection: collection,
      incidents: [_incident(id: 'incident-a', title: 'Alpha')],
    );

    expect(tileTitle('Alpha'), findsOneWidget);
    expect(
      find.byKey(CollectionBrowserScreen.unavailableMemberKey('ghost-id')),
      findsOneWidget,
    );
    expect(find.text('Unavailable incident'), findsOneWidget);
    expect(find.byType(CollectionBrowserScreen), findsOneWidget);
  });

  testWidgets('empty collection does not crash', (tester) async {
    final collection = await seedCollection(memberIds: const []);
    await pumpBrowser(tester, collection: collection);

    expect(find.byKey(CollectionBrowserScreen.emptyKey), findsOneWidget);
    expect(find.text('No incidents in this collection'), findsOneWidget);
    expect(find.text('0 incidents'), findsOneWidget);
  });

  testWidgets('unknown collection shows error and retry', (tester) async {
    await pumpBrowser(
      tester,
      collection: IncidentCollection(
        id: 'missing-collection',
        title: 'Collection',
        createdAt: DateTime.utc(2026, 8, 23),
        updatedAt: DateTime.utc(2026, 8, 23),
      ),
      collectionIdOverride: 'missing-collection',
    );

    expect(find.byKey(CollectionBrowserScreen.errorKey), findsOneWidget);
    expect(find.text('Couldn’t load this collection.'), findsOneWidget);
    expect(find.byKey(CollectionBrowserScreen.retryKey), findsOneWidget);
  });

  testWidgets('member tap uses the existing Incident Workspace route and id',
      (tester) async {
    final collection = await seedCollection();
    await pumpBrowser(
      tester,
      collection: collection,
      incidents: [
        _incident(id: 'incident-a', title: 'Alpha'),
        _incident(id: 'incident-b', title: 'Bravo'),
      ],
    );

    await tester.tap(tileTitle('Alpha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
    final route = ModalRoute.of(
      tester.element(find.byType(IncidentWorkspaceShell)),
    );
    expect(route?.settings.name, AppNavigation.incidentWorkspaceRouteName);
    expect(
      tester
          .state<IncidentWorkspaceShellState>(
            find.byType(IncidentWorkspaceShell),
          )
          .boundIncidentId,
      'incident-a',
    );
  });

  testWidgets('workspace back returns to browser, then vault', (tester) async {
    final collection = await seedCollection();
    await pumpVault(tester, [
      _incident(id: 'incident-a', title: 'Alpha'),
      _incident(id: 'incident-b', title: 'Bravo'),
    ]);

    await tapCollection(tester, collection.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CollectionBrowserScreen), findsOneWidget);

    await tester.tap(tileTitle('Alpha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IncidentWorkspaceShell), findsOneWidget);

    await tester.tap(find.byTooltip('Back').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(IncidentWorkspaceShell), findsNothing);
    expect(find.byType(CollectionBrowserScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CollectionBrowserScreen), findsNothing);
    expect(find.byType(VaultScreen), findsOneWidget);
  });

  testWidgets('browsing does not mutate incidents or membership', (tester) async {
    final a = _incident(id: 'incident-a', title: 'Alpha');
    final b = _incident(id: 'incident-b', title: 'Bravo');
    final collection = await seedCollection();
    await pumpVault(tester, [a, b]);
    final beforeLibrary = [
      for (final item in IncidentLibraryService.instance.summaries)
        (
          item.id,
          item.title,
          item.evidenceCount,
          item.lastPreserved,
          item.isArchived,
          item.isInProgress,
          item.createdAt,
          item.updatedAt,
          item.integrityVerified,
        ),
    ];
    final beforeMembers = collection.memberIncidentIds;

    await tapCollection(tester, collection.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tileTitle('Alpha'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      [
        for (final item in IncidentLibraryService.instance.summaries)
          (
            item.id,
            item.title,
            item.evidenceCount,
            item.lastPreserved,
            item.isArchived,
            item.isInProgress,
            item.createdAt,
            item.updatedAt,
            item.integrityVerified,
          ),
      ],
      beforeLibrary,
    );
    final after =
        await IncidentCollectionStore.instance.get(
      userId: userId,
      collectionId: collection.id,
    );
    expect(after!.memberIncidentIds, beforeMembers);
    expect(after.title, collection.title);
  });
}
