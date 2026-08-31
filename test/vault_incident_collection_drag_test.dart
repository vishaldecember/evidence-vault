import 'package:evidence_vault/domain/vault/incident_collection.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/screens/vault_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:evidence_vault/services/vault/vault_incident_grouping.dart';
import 'package:evidence_vault/widgets/vault/vault_collection_module.dart';
import 'package:evidence_vault/widgets/vault/vault_collection_organize_slot.dart';
import 'package:evidence_vault/widgets/vault/vault_incident_module.dart';
import 'package:evidence_vault/widgets/vault/vault_incident_organize_slot.dart';
import 'package:evidence_vault/widgets/vault/vault_recent_layout.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryIncidentSummary _incident({
  required String id,
  required String title,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: 3,
    contextEnrichedCount: 1,
    integrityVerified: true,
    lastPreserved: 'Today',
    isInProgress: false,
    createdAt: DateTime.utc(2026, 8, 20, 10),
    updatedAt: DateTime.utc(2026, 8, 21, 11),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-test';
  final grouping = VaultIncidentGrouping();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  tearDown(() {
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  test('compose hides grouped incidents and keeps library order', () {
    final a = _incident(id: 'incident-a', title: 'Alpha');
    final b = _incident(id: 'incident-b', title: 'Bravo');
    final c = _incident(id: 'incident-c', title: 'Charlie');
    final collection = IncidentCollection(
      id: 'collection-1',
      title: 'Collection',
      createdAt: DateTime.utc(2026, 8, 23),
      updatedAt: DateTime.utc(2026, 8, 23),
      memberIncidentIds: const ['incident-a', 'incident-b'],
    );

    final entries = composeVaultRecent(
      activeIncidents: [a, b, c],
      collections: [collection],
    );

    expect(entries, hasLength(2));
    expect(entries[0], isA<VaultRecentCollectionEntry>());
    expect(
      (entries[0] as VaultRecentCollectionEntry).collection.memberIncidentIds,
      ['incident-a', 'incident-b'],
    );
    expect(
      (entries[1] as VaultRecentIncidentEntry).incident.id,
      'incident-c',
    );
  });

  test('grouping writes IDs only and rejects self-drop', () async {
    expect(
      await grouping.groupIncidents(
        userId: userId,
        sourceIncidentId: 'incident-a',
        targetIncidentId: 'incident-a',
      ),
      isNull,
    );
    expect(await IncidentCollectionStore.instance.list(userId: userId), isEmpty);

    final created = await grouping.groupIncidents(
      userId: userId,
      sourceIncidentId: 'incident-a',
      targetIncidentId: 'incident-b',
    );
    expect(created, isNotNull);
    expect(created!.title, 'Collection');
    expect(created.memberIncidentIds, ['incident-a', 'incident-b']);
    expect(created.memberIncidentIds.toSet(), hasLength(2));

    final listed = await IncidentCollectionStore.instance.list(userId: userId);
    expect(listed, hasLength(1));
    expect(listed.single.memberIncidentIds, ['incident-a', 'incident-b']);
  });

  Future<void> pumpVault(
    WidgetTester tester,
    List<LibraryIncidentSummary> incidents,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(480, 915));
    IncidentLibraryService.instance.summaries = incidents;
    await tester.pumpWidget(
      const MaterialApp(
        home: VaultScreen(collectionUserId: userId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder tileTitle(String title) {
    return find.descendant(
      of: find.byType(VaultIncidentModule),
      matching: find.text(title),
    );
  }

  Future<void> enterOrganize(WidgetTester tester) async {
    await tester.ensureVisible(tileTitle('Alpha'));
    await tester.pump();
    await tester.longPress(tileTitle('Alpha'));
    await tester.pump();
  }

  Future<void> dragIncident(
    WidgetTester tester, {
    required String fromId,
    required String toId,
  }) async {
    await tester.ensureVisible(
      find.byKey(VaultIncidentOrganizeSlot.targetKey(toId)),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(VaultIncidentOrganizeSlot.dragKey(fromId)),
    );
    await tester.pump();
    final from = tester.getCenter(
      find.byKey(VaultIncidentOrganizeSlot.dragKey(fromId)),
    );
    final to = tester.getCenter(
      find.byKey(VaultIncidentOrganizeSlot.targetKey(toId)),
    );
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 120));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('drag cannot start while browsing', (tester) async {
    await pumpVault(tester, [
      _incident(id: 'incident-a', title: 'Alpha'),
      _incident(id: 'incident-b', title: 'Bravo'),
    ]);

    expect(find.byKey(VaultIncidentOrganizeSlot.dragKey('incident-a')),
        findsNothing);

    await enterOrganize(tester);
    expect(find.byKey(VaultIncidentOrganizeSlot.dragKey('incident-a')),
        findsOneWidget);
    expect(find.byKey(VaultIncidentOrganizeSlot.targetKey('incident-b')),
        findsOneWidget);
  });

  testWidgets('A onto B creates one collection and hides member tiles',
      (tester) async {
    final a = _incident(id: 'incident-a', title: 'Alpha');
    final b = _incident(id: 'incident-b', title: 'Bravo');
    final c = _incident(id: 'incident-c', title: 'Charlie');
    await pumpVault(tester, [a, b, c]);
    await enterOrganize(tester);

    await dragIncident(tester, fromId: 'incident-a', toId: 'incident-b');

    final collections =
        await IncidentCollectionStore.instance.list(userId: userId);
    expect(collections, hasLength(1));
    expect(collections.single.memberIncidentIds, ['incident-a', 'incident-b']);
    expect(collections.single.title, 'Collection');

    expect(
      find.byKey(VaultCollectionModule.moduleKey(collections.single.id)),
      findsOneWidget,
    );
    expect(find.text('2 incidents'), findsOneWidget);
    expect(tileTitle('Alpha'), findsNothing);
    expect(tileTitle('Bravo'), findsNothing);
    expect(tileTitle('Charlie'), findsOneWidget);
    expect(find.byKey(VaultScreen.organizeModeKey), findsOneWidget);
  });

  testWidgets('self drop and empty drop persist nothing', (tester) async {
    await pumpVault(tester, [
      _incident(id: 'incident-a', title: 'Alpha'),
      _incident(id: 'incident-b', title: 'Bravo'),
    ]);
    await enterOrganize(tester);

    await dragIncident(tester, fromId: 'incident-a', toId: 'incident-a');
    expect(await IncidentCollectionStore.instance.list(userId: userId), isEmpty);
    expect(tileTitle('Alpha'), findsOneWidget);

    final from = tester.getCenter(
      find.byKey(VaultIncidentOrganizeSlot.dragKey('incident-a')),
    );
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 120));
    await gesture.moveTo(const Offset(8, 8));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(await IncidentCollectionStore.instance.list(userId: userId), isEmpty);
  });

  testWidgets('grouping does not mutate incident library fields', (tester) async {
    final a = _incident(id: 'incident-a', title: 'Alpha');
    final b = _incident(id: 'incident-b', title: 'Bravo');
    await pumpVault(tester, [a, b]);
    final before = [
      for (final item in IncidentLibraryService.instance.summaries)
        (
          item.id,
          item.title,
          item.evidenceCount,
          item.contextEnrichedCount,
          item.lastPreserved,
          item.isArchived,
          item.isInProgress,
          item.createdAt,
          item.updatedAt,
          item.integrityVerified,
          item.narrativeCount,
        ),
    ];

    await enterOrganize(tester);
    await dragIncident(tester, fromId: 'incident-a', toId: 'incident-b');

    expect(
      [
        for (final item in IncidentLibraryService.instance.summaries)
          (
            item.id,
            item.title,
            item.evidenceCount,
            item.contextEnrichedCount,
            item.lastPreserved,
            item.isArchived,
            item.isInProgress,
            item.createdAt,
            item.updatedAt,
            item.integrityVerified,
            item.narrativeCount,
          ),
      ],
      before,
    );
  });

  testWidgets('collection membership is restored after Vault rebuild',
      (tester) async {
    await pumpVault(tester, [
      _incident(id: 'incident-a', title: 'Alpha'),
      _incident(id: 'incident-b', title: 'Bravo'),
    ]);
    await enterOrganize(tester);
    await dragIncident(tester, fromId: 'incident-a', toId: 'incident-b');
    final id =
        (await IncidentCollectionStore.instance.list(userId: userId)).single.id;

    await tester.pumpWidget(
      const MaterialApp(
        home: VaultScreen(collectionUserId: userId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(VaultCollectionModule.moduleKey(id)), findsOneWidget);
    expect(tileTitle('Alpha'), findsNothing);
    expect(tileTitle('Bravo'), findsNothing);
    expect(
      (await IncidentCollectionStore.instance.list(userId: userId)).single
          .memberIncidentIds,
      ['incident-a', 'incident-b'],
    );
  });

  test('addIncidentToCollection is idempotent', () async {
    final created = await grouping.groupIncidents(
      userId: userId,
      sourceIncidentId: 'incident-a',
      targetIncidentId: 'incident-b',
    );
    final first = await grouping.addIncidentToCollection(
      userId: userId,
      collectionId: created!.id,
      incidentId: 'incident-c',
    );
    expect(first!.memberIncidentIds, ['incident-a', 'incident-b', 'incident-c']);
    final duplicate = await grouping.addIncidentToCollection(
      userId: userId,
      collectionId: created.id,
      incidentId: 'incident-c',
    );
    expect(identical(duplicate, first), isTrue);
    expect(duplicate!.memberIncidentIds, ['incident-a', 'incident-b', 'incident-c']);
  });

  testWidgets('drop onto existing collection adds membership only',
      (tester) async {
    final a = _incident(id: 'incident-a', title: 'Alpha');
    final b = _incident(id: 'incident-b', title: 'Bravo');
    final c = _incident(id: 'incident-c', title: 'Charlie');
    final collection = await IncidentCollectionStore.instance.create(
      userId: userId,
      title: 'Collection',
      memberIncidentIds: const ['incident-a', 'incident-b'],
    );
    await pumpVault(tester, [a, b, c]);
    await tester.ensureVisible(tileTitle('Charlie'));
    await tester.pump();
    await tester.longPress(tileTitle('Charlie'));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(VaultCollectionOrganizeSlot.targetKey(collection.id)),
    );
    await tester.pump();
    final from = tester.getCenter(
      find.byKey(VaultIncidentOrganizeSlot.dragKey('incident-c')),
    );
    final to = tester.getCenter(
      find.byKey(VaultCollectionOrganizeSlot.targetKey(collection.id)),
    );
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 120));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final listed = await IncidentCollectionStore.instance.list(userId: userId);
    expect(listed, hasLength(1));
    expect(listed.single.id, collection.id);
    expect(
      listed.single.memberIncidentIds,
      ['incident-a', 'incident-b', 'incident-c'],
    );
    expect(tileTitle('Charlie'), findsNothing);
    expect(a.id, 'incident-a');
    expect(a.title, 'Alpha');
    expect(b.title, 'Bravo');
  });
}
