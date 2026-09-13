import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/screens/vault_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:evidence_vault/widgets/home/library_of_truth_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryIncidentSummary _incident({
  required String id,
  required String title,
  bool isArchived = false,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: 2,
    contextEnrichedCount: 1,
    integrityVerified: false,
    lastPreserved: 'Today',
    isInProgress: !isArchived,
    isArchived: isArchived,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  tearDown(() {
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  Future<void> pumpLibrary(
    WidgetTester tester,
    List<LibraryIncidentSummary> incidents, {
    List<String>? opened,
    Size surfaceSize = const Size(390, 844),
    double horizontalInset = 0,
  }) async {
    final recorded = opened ?? <String>[];
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalInset),
            child: LibraryOfTruthSection(
              incidents: incidents,
              onIncidentTap: recorded.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to Active with thumb-sized tabs on the title row', (
    tester,
  ) async {
    await pumpLibrary(tester, [
      _incident(id: 'incident-a', title: 'Street Fight'),
    ]);

    expect(find.text('The Library of Truth'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('library_of_truth_title')))
          .style
          ?.fontSize,
      greaterThanOrEqualTo(18),
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Deleted'), findsOneWidget);
    expect(find.text('Recently Deleted'), findsNothing);
    expect(find.text('Street Fight'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Swipe to archive'), findsNothing);
    expect(find.text('>> Archive'), findsNothing);
    expect(find.text('All'), findsNothing);

    final title = tester.getRect(find.text('The Library of Truth'));
    final activeTab = tester.getRect(
      find.byKey(const Key('library_tab_active')),
    );
    final archivedTab = tester.getRect(
      find.byKey(const Key('library_tab_archived')),
    );
    final deletedTab = tester.getRect(
      find.byKey(const Key('library_tab_recently_deleted')),
    );
    expect((activeTab.center.dy - archivedTab.center.dy).abs(), lessThan(1));
    expect((activeTab.center.dy - deletedTab.center.dy).abs(), lessThan(1));
    expect((title.center.dy - activeTab.center.dy).abs(), lessThan(24));
    expect(activeTab.left, greaterThan(title.right - 0.5));
    expect(title.width, greaterThan(70));
    expect(activeTab.height, greaterThanOrEqualTo(48));
    expect(archivedTab.height, greaterThanOrEqualTo(48));
    expect(deletedTab.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);

    Color tabFill(Key key) {
      final fill = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (fill.decoration! as BoxDecoration).color!;
    }

    expect(tabFill(const Key('library_tab_active')), AppColors.primary);
    expect(tabFill(const Key('library_tab_archived')), Colors.white);
    expect(tabFill(const Key('library_tab_recently_deleted')), Colors.white);
    expect(
      tester.widget<Text>(find.text('Active')).style?.color,
      AppColors.onPrimary,
    );
    expect(
      tester.widget<Text>(find.text('Archived')).style?.color,
      AppColors.textMuted,
    );
    expect(
      tester.widget<Text>(find.text('Deleted')).style?.color,
      AppColors.textMuted,
    );
  });

  testWidgets('Library tabs stay on one row at Motorola g35 width', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      [_incident(id: 'incident-a', title: 'Street Fight')],
      surfaceSize: const Size(360, 800),
      horizontalInset: 24,
    );

    final title = tester.getRect(find.text('The Library of Truth'));
    final activeTab = tester.getRect(
      find.byKey(const Key('library_tab_active')),
    );
    final archivedTab = tester.getRect(
      find.byKey(const Key('library_tab_archived')),
    );
    final deletedTab = tester.getRect(
      find.byKey(const Key('library_tab_recently_deleted')),
    );

    expect((activeTab.center.dy - archivedTab.center.dy).abs(), lessThan(1));
    expect((activeTab.center.dy - deletedTab.center.dy).abs(), lessThan(1));
    expect((title.center.dy - activeTab.center.dy).abs(), lessThan(24));
    expect(activeTab.left, greaterThan(title.right - 0.5));
    expect(activeTab.height, greaterThanOrEqualTo(48));
    expect(archivedTab.height, greaterThanOrEqualTo(48));
    expect(deletedTab.height, greaterThanOrEqualTo(48));
    expect(activeTab.width, greaterThanOrEqualTo(48));
    expect(archivedTab.width, greaterThanOrEqualTo(48));
    expect(deletedTab.width, greaterThanOrEqualTo(48));
    expect(deletedTab.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('active card opens; archived card remains viewable', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpLibrary(tester, [
      _incident(id: 'incident-a', title: 'Street Fight'),
      _incident(id: 'incident-b', title: 'Workplace', isArchived: true),
    ], opened: opened);

    await tester.tap(find.text('Street Fight'));
    await tester.pumpAndSettle();
    expect(opened, ['incident-a']);

    await tester.tap(find.byKey(const Key('library_tab_archived')));
    await tester.pumpAndSettle();
    Color tabFill(Key key) {
      final fill = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (fill.decoration! as BoxDecoration).color!;
    }

    expect(tabFill(const Key('library_tab_archived')), AppColors.primary);
    expect(tabFill(const Key('library_tab_active')), Colors.white);
    expect(find.text('Workplace'), findsOneWidget);
    expect(find.text(' (Archived)'), findsNothing);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Swipe to restore'), findsNothing);
    expect(find.text('Swipe to archive'), findsNothing);

    opened.clear();
    await tester.tap(find.text('Workplace'));
    await tester.pumpAndSettle();
    expect(opened, ['incident-b']);
  });

  testWidgets('swipe-to-archive then restore keeps the same incident', (
    tester,
  ) async {
    final street = _incident(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];
    await pumpLibrary(tester, [street]);

    await tester.drag(find.byType(Dismissible), const Offset(220, 0));
    await tester.pumpAndSettle();

    expect(IncidentLibraryService.instance.isArchivedId('incident-a'), isTrue);
    expect(find.text('Street Fight'), findsNothing);
    expect(find.text('No active incidents.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library_tab_archived')));
    await tester.pumpAndSettle();
    expect(find.text('Street Fight'), findsOneWidget);
    expect(find.text(' (Archived)'), findsNothing);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Swipe to restore'), findsNothing);
    expect(find.text('Swipe to archive'), findsNothing);

    await tester.drag(find.byType(Dismissible), const Offset(220, 0));
    await tester.pumpAndSettle();

    expect(IncidentLibraryService.instance.isArchivedId('incident-a'), isFalse);
    expect(find.text('Street Fight'), findsNothing);

    await tester.tap(find.byKey(const Key('library_tab_active')));
    await tester.pumpAndSettle();
    expect(find.text('Street Fight'), findsOneWidget);
    expect(find.text(' (Archived)'), findsNothing);
    expect(find.text('Archive'), findsOneWidget);
    expect(IncidentLibraryService.instance.summaries.single.id, 'incident-a');
  });

  testWidgets('insufficient swipe does not archive', (tester) async {
    final street = _incident(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];
    await pumpLibrary(tester, [street]);

    await tester.drag(find.byType(Dismissible), const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(IncidentLibraryService.instance.isArchivedId('incident-a'), isFalse);
    expect(find.text('Street Fight'), findsOneWidget);
  });

  test('archive and restore keep the same incident id and data', () async {
    final street = _incident(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];

    await IncidentLibraryService.instance.archiveIncident('incident-a');
    expect(IncidentLibraryService.instance.summaries, hasLength(1));
    expect(IncidentLibraryService.instance.summaries.single.id, 'incident-a');
    expect(IncidentLibraryService.instance.summaries.single.isArchived, isTrue);
    expect(
      IncidentLibraryService.instance.summaries.single.title,
      'Street Fight',
    );
    expect(IncidentLibraryService.instance.summaries.single.evidenceCount, 2);

    await IncidentLibraryService.instance.restoreIncident('incident-a');
    expect(IncidentLibraryService.instance.summaries, hasLength(1));
    expect(IncidentLibraryService.instance.summaries.single.id, 'incident-a');
    expect(
      IncidentLibraryService.instance.summaries.single.isArchived,
      isFalse,
    );
    expect(IncidentLibraryService.instance.summaries.single.evidenceCount, 2);
  });

  test(
    'vault archive list excludes active and mirrors library archived',
    () async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [
          _incident(id: 'incident-a', title: 'Street Fight'),
          _incident(id: 'incident-b', title: 'Workplace', isArchived: true),
        ],
        records: const [],
      );
      await IncidentLibraryService.instance.archiveIncident('incident-a');

      expect(
        IncidentLibraryService.instance.activeSummaries.map((s) => s.id),
        isEmpty,
      );
      expect(
        IncidentLibraryService.instance.archivedSummaries.map((s) => s.id),
        ['incident-a', 'incident-b'],
      );
      expect(
        IncidentLibraryService.instance.archivedSummaries.every(
          (s) => s.isArchived,
        ),
        isTrue,
      );
    },
  );

  test('archive ids persist to SharedPreferences', () async {
    IncidentLibraryService.debugForceDiskPersist = true;
    addTearDown(() => IncidentLibraryService.debugForceDiskPersist = false);

    final street = _incident(id: 'incident-a', title: 'Street Fight');
    IncidentLibraryService.instance.summaries = [street];
    await IncidentLibraryService.instance.archiveIncident('incident-a');

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('incident_lifecycle_archived_ids'),
      contains('incident-a'),
    );
  });

  testWidgets('LibraryIncidentSummaryTile has no overflow at 390', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryIncidentSummaryTile(
            incident: _incident(id: 'incident-a', title: 'Street Fight'),
            onTap: () {},
            onArchive: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('untitled incident cannot archive; titled incident can', () async {
    IncidentLibraryService.instance.summaries = [
      _incident(id: 'incident-untitled', title: 'Untitled Incident'),
      _incident(id: 'incident-named', title: 'Parking dispute'),
    ];

    expect(
      await IncidentLibraryService.instance.archiveIncident(
        'incident-untitled',
      ),
      isFalse,
    );
    expect(
      IncidentLibraryService.instance.isArchivedId('incident-untitled'),
      isFalse,
    );

    expect(
      await IncidentLibraryService.instance.archiveIncident('incident-named'),
      isTrue,
    );
    expect(
      IncidentLibraryService.instance.isArchivedId('incident-named'),
      isTrue,
    );
  });

  testWidgets('untitled archive swipe explains the title requirement', (
    tester,
  ) async {
    final opened = <String>[];
    final untitled = _incident(
      id: 'incident-untitled',
      title: 'Untitled Incident',
    );
    IncidentLibraryService.instance.summaries = [untitled];
    await pumpLibrary(tester, [untitled], opened: opened);

    await tester.drag(find.byType(Dismissible), const Offset(220, 0));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('archive_title_required_dialog')),
      findsOneWidget,
    );
    expect(find.text('Name this incident before archiving'), findsOneWidget);
    expect(
      find.text(
        'Give this incident a title so you can easily recognize it later.',
      ),
      findsOneWidget,
    );
    expect(
      IncidentLibraryService.instance.isArchivedId('incident-untitled'),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('archive_add_title_action')));
    await tester.pumpAndSettle();
    expect(opened, ['incident-untitled']);
    expect(
      IncidentLibraryService.instance.isArchivedId('incident-untitled'),
      isFalse,
    );
  });

  testWidgets(
    'untitled title uses restrained red; archived uses rose surface',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LibraryIncidentSummaryTile(
                  incident: _incident(
                    id: 'incident-untitled',
                    title: 'Untitled Incident',
                  ),
                  onTap: () {},
                  onArchive: () {},
                ),
                LibraryIncidentSummaryTile(
                  incident: _incident(
                    id: 'incident-archived',
                    title: 'Workplace incident',
                    isArchived: true,
                  ),
                  onTap: () {},
                  onRestore: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final untitled = tester.widget<Text>(find.text('Untitled Incident'));
      expect(untitled.style?.color, AppColors.danger);

      expect(find.text('Restore'), findsOneWidget);
      expect(find.textContaining('Case readiness'), findsNWidgets(2));
      final archivedInk = tester.widget<Ink>(
        find
            .descendant(
              of: find.byType(LibraryIncidentSummaryTile).at(1),
              matching: find.byType(Ink),
            )
            .first,
      );
      expect(
        (archivedInk.decoration! as BoxDecoration).color,
        AppColors.archivedSurface,
      );
    },
  );

  testWidgets('Home Library does not enter Vault organize mode', (
    tester,
  ) async {
    await pumpLibrary(tester, [
      _incident(id: 'incident-a', title: 'Street Fight'),
      _incident(id: 'incident-b', title: 'Workplace'),
    ]);

    await tester.longPress(find.text('Street Fight'));
    await tester.pump();
    expect(find.byKey(VaultScreen.organizeModeKey), findsNothing);
    expect(find.byType(LongPressDraggable), findsNothing);
    expect(
      await IncidentCollectionStore.instance.list(userId: 'local'),
      isEmpty,
    );
  });
}
