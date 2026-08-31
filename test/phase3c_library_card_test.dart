import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
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
  bool isInProgress = true,
  bool integrityVerified = false,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: 2,
    contextEnrichedCount: 1,
    integrityVerified: integrityVerified,
    lastPreserved: 'Today',
    isInProgress: isInProgress && !isArchived,
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
  }) async {
    final recorded = opened ?? <String>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
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

  testWidgets('1 active Incident card is compact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryIncidentSummaryTile(
            incident: _incident(id: 'incident-a', title: 'Parking dispute'),
            onTap: () {},
            onArchive: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(
      find.byKey(LibraryIncidentSummaryTile.cardKey('incident-a')),
    );
    expect(
      size.height,
      lessThan(108),
      reason: 'active card should stay compact after whitespace reduction',
    );
    expect(find.text('View Evidence Map'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2 Incident card tap opens the incident, not a second route',
      (tester) async {
    final opened = <String>[];
    await pumpLibrary(
      tester,
      [_incident(id: 'incident-a', title: 'Parking dispute')],
      opened: opened,
    );

    await tester.tap(find.text('Parking dispute'));
    await tester.pumpAndSettle();
    expect(opened, ['incident-a']);
  });

  testWidgets('3 View Evidence Map is no longer present', (tester) async {
    await pumpLibrary(tester, [
      _incident(id: 'incident-a', title: 'Parking dispute', isInProgress: true),
    ]);

    expect(find.text('View Evidence Map'), findsNothing);
    expect(find.text('Evidence Map'), findsNothing);
  });

  testWidgets('4 Archive and Restore stay on the Case readiness row',
      (tester) async {
    await pumpLibrary(tester, [
      _incident(id: 'incident-a', title: 'Parking dispute'),
    ]);

    final readiness = tester.getCenter(find.textContaining('Case readiness'));
    final archive = tester.getCenter(
      find.byKey(const Key('library_archive_affordance')),
    );
    expect((readiness.dy - archive.dy).abs(), lessThan(6));
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Swipe to archive'), findsNothing);

    await pumpLibrary(tester, [
      _incident(id: 'incident-b', title: 'Landlord call', isArchived: true),
    ]);
    await tester.tap(find.byKey(const Key('library_tab_archived')));
    await tester.pumpAndSettle();

    final archivedReadiness =
        tester.getCenter(find.textContaining('Case readiness'));
    final restore = tester.getCenter(
      find.byKey(const Key('library_restore_action')),
    );
    expect((archivedReadiness.dy - restore.dy).abs(), lessThan(6));
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Swipe to restore'), findsNothing);
  });

  testWidgets('5 untitled Incident receives restrained red title attention',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryIncidentSummaryTile(
          incident: _incident(
            id: 'incident-untitled',
            title: 'Untitled Incident',
          ),
          onTap: () {},
          onArchive: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Untitled Incident'));
    expect(title.style?.color, AppColors.danger);

    final ink = tester.widget<Ink>(
      find.byKey(LibraryIncidentSummaryTile.cardKey('incident-untitled')),
    );
    expect((ink.decoration! as BoxDecoration).color, isNot(AppColors.danger));
    expect((ink.decoration! as BoxDecoration).color, AppColors.card);
  });

  testWidgets('6 untitled Incident cannot be archived', (tester) async {
    final opened = <String>[];
    final untitled = _incident(
      id: 'incident-untitled',
      title: 'Untitled Incident',
    );
    IncidentLibraryService.instance.summaries = [untitled];
    await pumpLibrary(tester, [untitled], opened: opened);

    await tester.tap(find.byKey(const Key('library_archive_affordance')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archive_title_required_dialog')), findsOneWidget);
    expect(find.text('Name this incident before archiving'), findsOneWidget);
    expect(
      find.text('Give this incident a title so you can easily recognize it later.'),
      findsOneWidget,
    );
    expect(
      IncidentLibraryService.instance.isArchivedId('incident-untitled'),
      isFalse,
    );
    expect(opened, isEmpty);

    await tester.tap(find.byKey(const Key('archive_add_title_action')));
    await tester.pumpAndSettle();
    expect(opened, ['incident-untitled']);
    expect(
      IncidentLibraryService.instance.isArchivedId('incident-untitled'),
      isFalse,
    );
  });

  testWidgets('7 meaningfully titled Incident can be archived without opening',
      (tester) async {
    final opened = <String>[];
    final named = _incident(id: 'incident-named', title: 'Parking dispute');
    IncidentLibraryService.instance.summaries = [named];
    await pumpLibrary(tester, [named], opened: opened);

    await tester.tap(find.byKey(const Key('library_archive_affordance')));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(
      IncidentLibraryService.instance.isArchivedId('incident-named'),
      isTrue,
    );
    expect(find.text('Name this incident before archiving'), findsNothing);
  });

  testWidgets('8 archived Incident has muted rose treatment', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryIncidentSummaryTile(
          incident: _incident(
            id: 'incident-archived',
            title: 'Noise complaint',
            isArchived: true,
          ),
          onTap: () {},
          onRestore: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ink = tester.widget<Ink>(
      find.byKey(LibraryIncidentSummaryTile.cardKey('incident-archived')),
    );
    expect(
      (ink.decoration! as BoxDecoration).color,
      AppColors.archivedSurface,
    );
    final title = tester.widget<Text>(find.text('Noise complaint'));
    expect(title.style?.color, AppColors.navy);
  });

  testWidgets('9 archived Incident remains viewable', (tester) async {
    final opened = <String>[];
    await pumpLibrary(
      tester,
      [_incident(id: 'incident-b', title: 'Workplace', isArchived: true)],
      opened: opened,
    );
    await tester.tap(find.byKey(const Key('library_tab_archived')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workplace'));
    await tester.pumpAndSettle();
    expect(opened, ['incident-b']);
  });

  test('10 archived Incident remains read-only until restored', () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(
        id: 'incident-a',
        title: 'Parking dispute',
      ),
    );
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final evidenceBefore = [
      for (final item in controller.currentIncident.evidence) item.id,
    ];
    IncidentLibraryService.instance.summaries = [
      _incident(id: 'incident-a', title: 'Parking dispute'),
    ];
    await IncidentLibraryService.instance.archiveIncident('incident-a');

    expect(controller.isArchivedReadOnly, isTrue);
    controller.updateIncidentName('Changed');
    expect(controller.currentIncident.title, 'Parking dispute');
    controller.preserveEvidence(WorkspaceCaptureMode.note);
    expect(
      [for (final item in controller.currentIncident.evidence) item.id],
      evidenceBefore,
    );
  });

  test('11 Restore returns the Incident to an editable state', () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(
        id: 'incident-a',
        title: 'Parking dispute',
      ),
    );
    IncidentLibraryService.instance.summaries = [
      _incident(id: 'incident-a', title: 'Parking dispute'),
    ];
    await IncidentLibraryService.instance.archiveIncident('incident-a');
    expect(controller.isArchivedReadOnly, isTrue);

    await IncidentLibraryService.instance.restoreIncident('incident-a');
    expect(controller.isArchivedReadOnly, isFalse);
    controller.updateIncidentName('Named after restore');
    expect(controller.currentIncident.title, 'Named after restore');
  });

  testWidgets('12 Home Library does not gain Vault organize behavior',
      (tester) async {
    await pumpLibrary(tester, [
      _incident(id: 'incident-a', title: 'Street Fight'),
      _incident(id: 'incident-b', title: 'Workplace'),
    ]);

    expect(find.text('View Evidence Map'), findsNothing);
    await tester.longPress(find.text('Street Fight'));
    await tester.pump();
    expect(find.byKey(VaultScreen.organizeModeKey), findsNothing);
    expect(find.byType(LongPressDraggable), findsNothing);
    expect(find.text('New Collection'), findsNothing);
    expect(await IncidentCollectionStore.instance.list(userId: 'local'), isEmpty);
  });
}
