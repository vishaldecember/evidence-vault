import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/screens/vault_screen.dart';
import 'package:evidence_vault/services/memory/memory_recall_service.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:evidence_vault/widgets/vault/vault_incident_module.dart';
import 'package:evidence_vault/widgets/vault/vault_organize_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Proven green-baseline clock from vault_recall_date_diagnostic_test.
/// Keeps the Aug 20–21 fixtures inside the 14-day first-incident window
/// so Memory Recall uses "Review Incident" (fits) not "View Investigation".
final _recallNow = DateTime.utc(2026, 8, 31, 23, 44, 42);

LibraryIncidentSummary _incident({
  required String id,
  required String title,
  bool isArchived = false,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: 3,
    contextEnrichedCount: 1,
    integrityVerified: false,
    lastPreserved: 'Today',
    isInProgress: !isArchived,
    isArchived: isArchived,
    createdAt: DateTime.utc(2026, 8, 20),
    updatedAt: DateTime.utc(2026, 8, 21),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
    MemoryRecallService.instance.resetForTests();
  });

  tearDown(() {
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
    MemoryRecallService.instance.resetForTests();
  });

  Future<void> pumpVault(
    WidgetTester tester, {
    required List<LibraryIncidentSummary> incidents,
    List<LibraryIncidentSummary>? openedRecorder,
  }) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));
    // Always start empty so no test can pre-seed the library before
    // VaultScreen.initState's DateTime.now() refresh paints recall.
    IncidentLibraryService.instance.summaries = const [];
    await tester.pumpWidget(
      MaterialApp(
        home: VaultScreen(
          onIncidentOpen: openedRecorder?.add,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Drain initState's unawaited wall-clock refresh while the library
    // is still empty, then pin now before the first incident paint.
    await MemoryRecallService.instance.refresh(now: _recallNow);
    IncidentLibraryService.instance.summaries = incidents;
    await MemoryRecallService.instance.refresh(now: _recallNow);
    await tester.pump();
    await MemoryRecallService.instance.refresh(now: _recallNow);
    await tester.pump();
  }

  Finder tileTitle(String title) {
    return find.descendant(
      of: find.byType(VaultIncidentModule),
      matching: find.text(title),
    );
  }

  testWidgets('starts browsing; long press enters organize; Done exits',
      (tester) async {
    await pumpVault(
      tester,
      incidents: [_incident(id: 'incident-a', title: 'Street Fight')],
    );

    expect(find.byKey(VaultScreen.organizeModeKey), findsNothing);
    expect(find.byKey(VaultScreen.doneKey), findsNothing);
    expect(
      find.byKey(VaultOrganizeModule.removeKey('incident-a')),
      findsNothing,
    );

    await tester.longPress(tileTitle('Street Fight'));
    await tester.pump();

    expect(find.byKey(VaultScreen.organizeModeKey), findsOneWidget);
    expect(find.byKey(VaultScreen.doneKey), findsOneWidget);
    expect(
      find.byKey(VaultOrganizeModule.removeKey('incident-a')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(VaultScreen.doneKey));
    await tester.pump();

    expect(find.byKey(VaultScreen.organizeModeKey), findsNothing);
    expect(find.byKey(VaultScreen.doneKey), findsNothing);
    expect(
      find.byKey(VaultOrganizeModule.removeKey('incident-a')),
      findsNothing,
    );
  });

  testWidgets('normal tap opens incident; organize tap does not', (tester) async {
    final opened = <LibraryIncidentSummary>[];
    await pumpVault(
      tester,
      incidents: [_incident(id: 'incident-a', title: 'Street Fight')],
      openedRecorder: opened,
    );

    await tester.tap(tileTitle('Street Fight'));
    await tester.pump();
    expect(opened.map((e) => e.id), ['incident-a']);

    await tester.longPress(tileTitle('Street Fight'));
    await tester.pump();
    opened.clear();

    await tester.tap(tileTitle('Street Fight'));
    await tester.pump();
    expect(opened, isEmpty);
    expect(find.byKey(VaultScreen.organizeModeKey), findsOneWidget);
  });

  testWidgets('back while organizing exits organize mode first', (tester) async {
    await pumpVault(
      tester,
      incidents: [_incident(id: 'incident-a', title: 'Street Fight')],
    );

    await tester.longPress(tileTitle('Street Fight'));
    await tester.pump();
    expect(find.byKey(VaultScreen.organizeModeKey), findsOneWidget);

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pump();

    expect(find.byKey(VaultScreen.organizeModeKey), findsNothing);
    expect(find.byType(VaultScreen), findsOneWidget);
  });

  testWidgets('minus affordance exits organize and does not write data',
      (tester) async {
    final incident = _incident(id: 'incident-a', title: 'Street Fight');
    final opened = <LibraryIncidentSummary>[];
    await pumpVault(
      tester,
      incidents: [incident],
      openedRecorder: opened,
    );

    final before = IncidentLibraryService.instance.summaries.single;
    await tester.longPress(tileTitle('Street Fight'));
    await tester.pump();

    await tester.tap(find.byKey(VaultOrganizeModule.removeKey('incident-a')));
    await tester.pump();

    expect(find.byKey(VaultScreen.organizeModeKey), findsNothing);
    expect(opened, isEmpty);
    final after = IncidentLibraryService.instance.summaries.single;
    expect(after.id, before.id);
    expect(after.title, before.title);
    expect(after.statusFieldsUnchanged(before), isTrue);
    expect(
      await IncidentCollectionStore.instance.list(userId: 'user-test'),
      isEmpty,
    );
  });

  testWidgets('entering and exiting organize does not mutate library or collections',
      (tester) async {
    final incidents = [
      _incident(id: 'incident-a', title: 'Street Fight'),
    ];
    await pumpVault(tester, incidents: incidents);

    final snapshot = [
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

    await tester.longPress(tileTitle('Street Fight'));
    await tester.pump();
    await tester.tap(find.byKey(VaultScreen.doneKey));
    await tester.pump();

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
      snapshot,
    );
    expect(
      await IncidentCollectionStore.instance.list(userId: 'user-test'),
      isEmpty,
    );
    expect(find.byType(VaultIncidentModule), findsOneWidget);
    expect(find.byType(LibraryIncidentSummaryTile), findsNothing);
  });

  testWidgets('organize animation runs then stops after Done', (tester) async {
    await pumpVault(
      tester,
      incidents: [_incident(id: 'incident-a', title: 'Street Fight')],
    );

    await tester.longPress(tileTitle('Street Fight'));
    await tester.pump();
    expect(find.byType(AnimatedBuilder), findsWidgets);

    await tester.tap(find.byKey(VaultScreen.doneKey));
    await tester.pump();
    expect(find.byKey(VaultScreen.organizeModeKey), findsNothing);
  });
}

extension on LibraryIncidentSummary {
  bool statusFieldsUnchanged(LibraryIncidentSummary other) {
    return evidenceCount == other.evidenceCount &&
        contextEnrichedCount == other.contextEnrichedCount &&
        lastPreserved == other.lastPreserved &&
        isArchived == other.isArchived &&
        isInProgress == other.isInProgress &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        integrityVerified == other.integrityVerified &&
        narrativeCount == other.narrativeCount;
  }
}
