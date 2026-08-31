import 'package:evidence_vault/domain/vault/incident_collection.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/presentation/incident_cover_resolver.dart';
import 'package:evidence_vault/screens/collection_browser_screen.dart';
import 'package:evidence_vault/screens/vault_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:evidence_vault/widgets/common/status_badge.dart';
import 'package:evidence_vault/widgets/vault/collection_member_resolution.dart';
import 'package:evidence_vault/widgets/vault/incident_cover_preview.dart';
import 'package:evidence_vault/widgets/vault/vault_collection_module.dart';
import 'package:evidence_vault/widgets/vault/vault_incident_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryIncidentSummary _incident({
  required String id,
  required String title,
  String? coverEvidenceId,
  int evidenceCount = 6,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: evidenceCount,
    contextEnrichedCount: 1,
    integrityVerified: true,
    lastPreserved: 'Today',
    isInProgress: false,
    coverEvidenceId: coverEvidenceId,
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
  });

  tearDown(() {
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  testWidgets('incident module shows cover band when resolution is available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultIncidentModule(
          incident: _incident(
            id: 'incident-a',
            title: 'Street Fight',
            coverEvidenceId: 'evidence-a1',
          ),
          coverOverride: IncidentCoverResolution.resolved(
            '/cache/incident-a/evidence-a1_thumb.jpg',
          ),
        ),
      ),
    );

    expect(
      find.byKey(VaultIncidentModule.moduleKey('incident-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(IncidentCoverPreview.resolvedKey('incident-a')),
      findsOneWidget,
    );
    expect(find.text('Street Fight'), findsOneWidget);
    expect(find.textContaining('6 evidence'), findsOneWidget);
    expect(find.text('INCIDENT'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(VaultIncidentModule)),
      matchesSemantics(
        label: 'Street Fight, incident, READY, 6 evidence',
        isButton: false,
      ),
    );
  });

  testWidgets('incident module has no cover band when cover is unset',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultIncidentModule(
          incident: _incident(id: 'incident-a', title: 'Street Fight'),
        ),
      ),
    );

    expect(find.text('Street Fight'), findsOneWidget);
    expect(
      find.byKey(IncidentCoverPreview.resolvedKey('incident-a')),
      findsNothing,
    );
    expect(
      find.byKey(IncidentCoverPreview.fallbackKey('incident-a')),
      findsNothing,
    );
    expect(find.textContaining('Today'), findsOneWidget);
  });

  testWidgets('incident module falls back when cover cannot resolve',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultIncidentModule(
          incident: _incident(
            id: 'incident-a',
            title: 'Street Fight',
            coverEvidenceId: 'missing',
          ),
          coverOverride: IncidentCoverResolution.fallback,
        ),
      ),
    );

    expect(
      find.byKey(IncidentCoverPreview.fallbackKey('incident-a')),
      findsOneWidget,
    );
    expect(find.text('Street Fight'), findsOneWidget);
  });

  testWidgets('collection stack stays compact and reports incident count',
      (tester) async {
    final collection = IncidentCollection(
      id: 'collection-1',
      title: 'Collection',
      createdAt: DateTime.utc(2026, 8, 23),
      updatedAt: DateTime.utc(2026, 8, 23),
      memberIncidentIds: const ['incident-a', 'incident-b', 'incident-c'],
    );
    final members = resolveCollectionMembers(
      memberIncidentIds: collection.memberIncidentIds,
      summaries: [
        _incident(id: 'incident-a', title: 'Alpha'),
        _incident(id: 'incident-b', title: 'Bravo'),
        _incident(id: 'incident-c', title: 'Charlie'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: VaultCollectionModule(
              collection: collection,
              members: members,
              coverOverrides: const [
                IncidentCoverResolution.fallback,
                IncidentCoverResolution.fallback,
                IncidentCoverResolution.fallback,
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(VaultCollectionModule.moduleKey('collection-1')),
      findsOneWidget,
    );
    expect(find.text('COLLECTION'), findsOneWidget);
    expect(find.text('3 incidents'), findsOneWidget);
    expect(find.text('24 items'), findsNothing);
    final box = tester.getSize(
      find.byKey(VaultCollectionModule.moduleKey('collection-1')),
    );
    expect(box.height, lessThan(220));
    expect(find.byType(StatusBadge), findsNothing);
    expect(find.text('INCIDENT'), findsNothing);
    expect(
      tester.getSemantics(find.byType(VaultCollectionModule)),
      matchesSemantics(
        label: 'Collection, collection, 3 incidents',
        isButton: false,
      ),
    );
  });

  testWidgets('collection remains valid with zero usable imagery',
      (tester) async {
    final collection = IncidentCollection(
      id: 'collection-empty-visual',
      title: 'Collection',
      createdAt: DateTime.utc(2026, 8, 23),
      updatedAt: DateTime.utc(2026, 8, 23),
      memberIncidentIds: const ['ghost-1', 'ghost-2'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VaultCollectionModule(
          collection: collection,
          members: resolveCollectionMembers(
            memberIncidentIds: collection.memberIncidentIds,
            summaries: const [],
          ),
          coverOverrides: const [
            IncidentCoverResolution.fallback,
            IncidentCoverResolution.fallback,
            IncidentCoverResolution.fallback,
          ],
        ),
      ),
    );

    expect(find.text('2 incidents'), findsOneWidget);
    expect(find.text('COLLECTION'), findsOneWidget);
    expect(find.text('No image available'), findsNothing);
  });

  testWidgets('vault incident tap still opens through the existing seam',
      (tester) async {
    final opened = <LibraryIncidentSummary>[];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    IncidentLibraryService.instance.summaries = [
      _incident(id: 'incident-a', title: 'Street Fight'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: VaultScreen(onIncidentOpen: opened.add),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final module = find.byKey(VaultIncidentModule.moduleKey('incident-a'));
    await tester.ensureVisible(module);
    await tester.pump();
    await tester.tap(module);
    await tester.pump();
    expect(opened.single.id, 'incident-a');
  });

  testWidgets('vault collection tap still opens the collection browser',
      (tester) async {
    const userId = 'user-visual';
    final collection = await IncidentCollectionStore.instance.create(
      userId: userId,
      title: 'Collection',
      memberIncidentIds: const ['incident-a', 'incident-b'],
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    IncidentLibraryService.instance.summaries = [
      _incident(id: 'incident-a', title: 'Alpha'),
      _incident(id: 'incident-b', title: 'Bravo'),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: VaultScreen(collectionUserId: userId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final module = find.byKey(VaultCollectionModule.moduleKey(collection.id));
    await tester.scrollUntilVisible(module, 200);
    await tester.pump();
    await tester.tap(module);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CollectionBrowserScreen), findsOneWidget);
  });

  testWidgets('rendering does not mutate library or collection membership',
      (tester) async {
    final incident = _incident(
      id: 'incident-a',
      title: 'Street Fight',
      coverEvidenceId: 'evidence-a1',
    );
    IncidentLibraryService.instance.summaries = [incident];
    final before = IncidentLibraryService.instance.summaries.single;

    await tester.pumpWidget(
      MaterialApp(
        home: VaultIncidentModule(
          incident: incident,
          coverOverride: IncidentCoverResolution.resolved(
            '/cache/a1_thumb.jpg',
          ),
        ),
      ),
    );
    await tester.pump();

    final after = IncidentLibraryService.instance.summaries.single;
    expect(identical(after, before), isTrue);
    expect(after.coverEvidenceId, 'evidence-a1');
    expect(after.evidenceCount, 6);
    expect(after.title, 'Street Fight');
  });
}
