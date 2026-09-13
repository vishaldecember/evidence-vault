import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/navigation/incident_workspace_entry.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:evidence_vault/navigation/library_incident_routes.dart';
import 'package:evidence_vault/screens/collection_browser_screen.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/main_shell_screen.dart';
import 'package:evidence_vault/screens/vault_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:evidence_vault/widgets/vault/vault_incident_module.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryIncidentSummary _summary({
  required String id,
  required String title,
  bool isArchived = false,
  int evidenceCount = 2,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: evidenceCount,
    contextEnrichedCount: 0,
    integrityVerified: true,
    lastPreserved: 'Today',
    isInProgress: !isArchived,
    isArchived: isArchived,
    createdAt: DateTime.utc(2026, 8, 20, 10),
    updatedAt: DateTime.utc(2026, 8, 21, 11),
  );
}

void _bind({
  required String id,
  required String title,
  required List<WorkspaceCaptureMode> modes,
}) {
  final session = WorkspaceSession.instance;
  session.controller.replaceAggregate(
    IncidentAggregate.shell(id: id, title: title),
  );
  for (final mode in modes) {
    session.controller.preserveEvidence(mode);
  }
}

Map<String, Object?> _identitySnapshot(WorkspaceEvidenceController controller) {
  final incident = controller.currentIncident;
  return {
    'incidentId': incident.id,
    'createdAt': incident.createdAt,
    'evidenceIds': [for (final item in incident.evidence) item.id],
    'hashes': [for (final item in incident.evidence) item.contentHash],
    'capturedAt': [for (final item in incident.evidence) item.capturedAt],
    'recordedAt': [for (final item in incident.evidence) item.recordedAt],
    'lastPreservedAt': [
      for (final item in incident.evidence) item.lastPreservedAt,
    ],
    'sequence': controller.timelineRepository.orderedCapturedEvidenceIds(),
  };
}

Future<void> _pumpUntilWorkspace(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    if (find.byType(IncidentWorkspaceShell).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 50));
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
    UserSessionService.resetForTests();
  });

  tearDown(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
    UserSessionService.resetForTests();
  });

  group('IncidentWorkspaceEntry routing', () {
    test('A. notReady → Capture', () {
      _bind(
        id: 'inc-sparse',
        title: 'Sparse',
        modes: [WorkspaceCaptureMode.photo],
      );
      final readiness =
          WorkspaceSession.instance.controller.organizeReadiness;
      expect(readiness.status, OrganizeReadinessStatus.notReady);
      expect(
        IncidentWorkspaceEntry.stageFor(readiness),
        InvestigationMethodologyStage.capture,
      );
      expect(
        IncidentWorkspaceEntry.stageFromWorkingSet(
          WorkspaceSession.instance.controller,
        ),
        InvestigationMethodologyStage.capture,
      );
    });

    test('B. ready → Organize uses Phase 3D OrganizeReadiness', () {
      _bind(
        id: 'inc-ready',
        title: 'Ready',
        modes: [WorkspaceCaptureMode.video, WorkspaceCaptureMode.note],
      );
      final readiness =
          WorkspaceSession.instance.controller.organizeReadiness;
      expect(readiness.status, OrganizeReadinessStatus.ready);
      expect(readiness.matchedPattern, OrganizeReadinessPattern.videoText);
      expect(
        IncidentWorkspaceEntry.stageFor(readiness),
        InvestigationMethodologyStage.evidence,
      );
    });

    test('C. re-evaluate after qualifying capture; readiness is not persisted',
        () async {
      _bind(
        id: 'inc-grow',
        title: 'Growing',
        modes: [WorkspaceCaptureMode.photo],
      );
      final session = WorkspaceSession.instance;
      expect(
        await IncidentWorkspaceEntry.resolveAfterHydrate(session),
        InvestigationMethodologyStage.capture,
      );

      session.controller.preserveEvidence(WorkspaceCaptureMode.video);
      session.controller.preserveEvidence(WorkspaceCaptureMode.note);
      expect(session.controller.organizeReadiness.isReady, isTrue);
      expect(
        await IncidentWorkspaceEntry.resolveAfterHydrate(session),
        InvestigationMethodologyStage.evidence,
      );

      final persisted = FirestoreSerializers.incidentToMap(
        incident: session.controller.aggregate.incident,
        ownerId: 'test-owner',
        timelineCount: session.controller.currentIncident.timelineAnchorCount,
        relationshipCount: 0,
        narrativeCount: 0,
        reconstructionHealth: 0,
      );
      expect(persisted.containsKey('organizeReadiness'), isFalse);
      expect(persisted.containsKey('organizeReadinessStatus'), isFalse);
    });

    test(
      'empty shell routes Capture immediately without waiting for hydrate',
      () async {
        final session = WorkspaceSession.instance;
        session.controller.replaceAggregate(
          IncidentAggregate.shell(id: 'inc-pending', title: 'Pending'),
        );
        expect(session.controller.currentIncident.evidence, isEmpty);

        final stopwatch = Stopwatch()..start();
        final stage = await IncidentWorkspaceEntry.resolveAfterHydrate(session);
        stopwatch.stop();

        expect(stage, InvestigationMethodologyStage.capture);
        expect(session.controller.currentIncident.id, 'inc-pending');
        expect(session.controller.currentIncident.evidence, isEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      },
    );

    test('G. unevaluable working set falls back to Capture, never ready', () {
      WorkspaceSession.instance.controller.replaceAggregate(
        IncidentAggregate.shell(id: '', title: ''),
      );
      expect(
        IncidentWorkspaceEntry.tryAssess(WorkspaceSession.instance.controller),
        isNull,
      );
      expect(
        IncidentWorkspaceEntry.stageFromWorkingSet(
          WorkspaceSession.instance.controller,
        ),
        LibraryIncidentRoutes.cardBodyStage,
      );
      expect(
        IncidentWorkspaceEntry.fallbackStage,
        InvestigationMethodologyStage.capture,
      );
    });

    test('H/I/J. routing does not mutate identity, chronology, or evidence', () {
      _bind(
        id: 'inc-stable',
        title: 'Stable',
        modes: [
          WorkspaceCaptureMode.photo,
          WorkspaceCaptureMode.photo,
          WorkspaceCaptureMode.note,
        ],
      );
      final controller = WorkspaceSession.instance.controller;
      final before = _identitySnapshot(controller);
      final stage = IncidentWorkspaceEntry.stageFromWorkingSet(controller);
      expect(stage, InvestigationMethodologyStage.evidence);
      expect(_identitySnapshot(controller), before);
      expect(controller.currentIncident.id, 'inc-stable');
    });
  });

  group('Library / Vault / Collection entry', () {
    Future<void> pumpHome(WidgetTester tester, String id, String title) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      IncidentLibraryService.instance.summaries = [
        _summary(id: id, title: title),
      ];
      await tester.pumpWidget(const MaterialApp(home: MainShellScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
    }

    Future<void> pumpVault(WidgetTester tester, String id, String title) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(480, 1400));
      IncidentLibraryService.instance.summaries = [
        _summary(id: id, title: title),
      ];
      await tester.pumpWidget(const MaterialApp(home: VaultScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
    }

    testWidgets('A. Home not-ready tap opens Capture', (tester) async {
      _bind(
        id: 'inc-home-sparse',
        title: 'Parking dispute',
        modes: [WorkspaceCaptureMode.photo],
      );
      await pumpHome(tester, 'inc-home-sparse', 'Parking dispute');

      final card = find.byKey(
        LibraryIncidentSummaryTile.cardKey('inc-home-sparse'),
      );
      await tester.scrollUntilVisible(card, 120);
      await tester.tap(card);
      await _pumpUntilWorkspace(tester);

      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expect(find.text('Capture what happened clearly'), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        'inc-home-sparse',
      );
    });

    testWidgets('B. Home ready tap opens Organize via shared helper',
        (tester) async {
      _bind(
        id: 'inc-home-ready',
        title: 'Workplace concern',
        modes: [WorkspaceCaptureMode.video, WorkspaceCaptureMode.note],
      );
      await pumpHome(tester, 'inc-home-ready', 'Workplace concern');

      final card = find.byKey(
        LibraryIncidentSummaryTile.cardKey('inc-home-ready'),
      );
      await tester.scrollUntilVisible(card, 120);
      await tester.tap(card);
      await _pumpUntilWorkspace(tester);

      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expect(find.byKey(OrganizeWorkspaceView.viewKey), findsOneWidget);
      expect(find.text('Organize and enrich your records'), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
    });

    testWidgets('C. reopen after qualifying evidence routes to Organize',
        (tester) async {
      _bind(
        id: 'inc-reopen',
        title: 'Noise complaint',
        modes: [WorkspaceCaptureMode.photo],
      );
      await pumpHome(tester, 'inc-reopen', 'Noise complaint');

      final card = find.byKey(
        LibraryIncidentSummaryTile.cardKey('inc-reopen'),
      );
      await tester.scrollUntilVisible(card, 120);
      await tester.tap(card);
      await _pumpUntilWorkspace(tester);
      expect(find.text('Capture what happened clearly'), findsOneWidget);

      WorkspaceSession.instance.controller
          .preserveEvidence(WorkspaceCaptureMode.video);
      WorkspaceSession.instance.controller
          .preserveEvidence(WorkspaceCaptureMode.note);

      await tester.tap(find.byTooltip('Back').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(IncidentWorkspaceShell), findsNothing);
      expect(find.byType(MainShellScreen), findsOneWidget);

      await tester.scrollUntilVisible(card, 120);
      await tester.tap(card);
      await _pumpUntilWorkspace(tester);
      expect(find.byKey(OrganizeWorkspaceView.viewKey), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        'inc-reopen',
      );
    });

    testWidgets('E. Vault uses the same readiness routing', (tester) async {
      _bind(
        id: 'inc-vault-ready',
        title: 'Landlord call',
        modes: [WorkspaceCaptureMode.video, WorkspaceCaptureMode.note],
      );
      await pumpVault(tester, 'inc-vault-ready', 'Landlord call');

      await tester.tap(find.byKey(VaultIncidentModule.moduleKey('inc-vault-ready')));
      await _pumpUntilWorkspace(tester);

      expect(find.byKey(OrganizeWorkspaceView.viewKey), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        'inc-vault-ready',
      );

      await tester.tap(find.byTooltip('Back').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(IncidentWorkspaceShell), findsNothing);
      expect(find.byType(VaultScreen), findsOneWidget);
    });

    testWidgets('D. Collection member uses the same readiness decision',
        (tester) async {
      _bind(
        id: 'incident-a',
        title: 'Alpha',
        modes: [WorkspaceCaptureMode.photo],
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(480, 915));
      const userId = 'user-phase3e';
      IncidentLibraryService.instance.summaries = [
        _summary(id: 'incident-a', title: 'Alpha'),
        _summary(id: 'incident-b', title: 'Bravo'),
      ];
      final collection = await IncidentCollectionStore.instance.create(
        userId: userId,
        title: 'Collection',
        memberIncidentIds: const ['incident-a', 'incident-b'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionBrowserScreen(
            collectionId: collection.id,
            userId: userId,
            initialCollection: collection,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.text('Alpha'));
      await _pumpUntilWorkspace(tester);

      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expect(find.text('Capture what happened clearly'), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        'incident-a',
      );

      await tester.tap(find.byTooltip('Back').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(IncidentWorkspaceShell), findsNothing);
      expect(find.byType(CollectionBrowserScreen), findsOneWidget);
    });

    testWidgets('F. archived ready incident stays read-only', (tester) async {
      _bind(
        id: 'inc-archived',
        title: 'Parking dispute',
        modes: [WorkspaceCaptureMode.video, WorkspaceCaptureMode.note],
      );
      IncidentLibraryService.instance.summaries = [
        _summary(id: 'inc-archived', title: 'Parking dispute'),
      ];
      await IncidentLibraryService.instance.archiveIncident('inc-archived');

      final beforeIds = [
        for (final item
            in WorkspaceSession.instance.controller.currentIncident.evidence)
          item.id,
      ];
      expect(
        WorkspaceSession.instance.controller.organizeReadiness.isReady,
        isTrue,
      );

      await pumpVault(tester, 'inc-archived', 'Parking dispute');
      final archivedCard = find.byKey(
        LibraryIncidentSummaryTile.cardKey('inc-archived'),
      );
      await tester.ensureVisible(archivedCard);
      await tester.pump();
      await tester.tap(archivedCard);
      await _pumpUntilWorkspace(tester);

      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expect(
        WorkspaceSession.instance.controller.isArchivedReadOnly,
        isTrue,
      );
      WorkspaceSession.instance.controller
          .preserveEvidence(WorkspaceCaptureMode.photo);
      expect(
        [
          for (final item in WorkspaceSession
              .instance.controller.currentIncident.evidence)
            item.id,
        ],
        beforeIds,
      );
    });

    testWidgets('G. failed hydrate still opens default Capture', (tester) async {
      await pumpHome(tester, 'inc-unknown', 'Unknown');
      final card = find.byKey(
        LibraryIncidentSummaryTile.cardKey('inc-unknown'),
      );
      await tester.scrollUntilVisible(card, 120);
      await tester.tap(card);
      await _pumpUntilWorkspace(tester);

      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expect(find.text('Capture what happened clearly'), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        'inc-unknown',
      );
    });
  });

}
