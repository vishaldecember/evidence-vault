import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/home_dashboard_mock.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_resume_target.dart';
import 'package:evidence_vault/navigation/incident_action_hierarchy.dart';
import 'package:evidence_vault/navigation/library_incident_routes.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/main_shell_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:evidence_vault/widgets/home/session_resume_card.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _seedWorkplaceOrganizeReady() {
  WorkspaceSession.instance.controller.replaceAggregate(
    IncidentAggregate.shell(
      id: 'incident-workplace-concern',
      title: 'Workplace Concern',
    ),
  );
  WorkspaceSession.instance.controller.preserveEvidence(
    WorkspaceCaptureMode.video,
  );
  WorkspaceSession.instance.controller.preserveEvidence(
    WorkspaceCaptureMode.note,
  );
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.summaries = [];
    IncidentLibraryService.instance.records = [];
  });

  tearDown(() {
    IncidentLibraryService.instance.summaries = [];
    IncidentLibraryService.instance.records = [];
  });

  group('LibraryIncidentRoutes constants', () {
    test('1 card body is Capture', () {
      expect(
        LibraryIncidentRoutes.cardBodyStage,
        InvestigationMethodologyStage.capture,
      );
    });

    test('2 View Evidence Map is Organize', () {
      expect(
        LibraryIncidentRoutes.viewEvidenceMapStage,
        InvestigationMethodologyStage.evidence,
      );
    });

    test('4 Continue Investigation is Investigate Timeline', () {
      expect(
        LibraryIncidentRoutes.continueInvestigationStage,
        InvestigationMethodologyStage.investigation,
      );
      expect(
        LibraryIncidentRoutes.continueInvestigationTab,
        InvestigationWorkspaceTab.timeline,
      );
    });
  });

  group('Home Library actions', () {
    Future<void> pumpHome(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      IncidentLibraryService.instance.summaries =
          HomeDashboardMock.activeLibraryIncidents;
      await tester.pumpWidget(const MaterialApp(home: MainShellScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('1 Library card body opens Capture', (tester) async {
      await pumpHome(tester);

      final card = find.byKey(
        LibraryIncidentSummaryTile.cardKey('incident-workplace-concern'),
      );
      await tester.scrollUntilVisible(card, 120);
      await tester.pumpAndSettle();
      expect(find.text('View Evidence Map'), findsNothing);
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expect(find.text('Capture what happened clearly'), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        'incident-workplace-concern',
      );
    });

    testWidgets('2 Library card has no View Evidence Map link', (tester) async {
      await pumpHome(tester);
      await tester.scrollUntilVisible(
        find.byKey(
          LibraryIncidentSummaryTile.cardKey('incident-workplace-concern'),
        ),
        120,
      );
      await tester.pumpAndSettle();

      expect(find.text('View Evidence Map'), findsNothing);
      expect(find.byType(LibraryIncidentSummaryTile), findsWidgets);
    });

    testWidgets('3 Continue Preserving is Continuous Capture, not the card-body shell',
        (tester) async {
      await pumpHome(tester);
      expect(find.byType(SessionResumeCard), findsOneWidget);
      expect(
        find.byKey(const Key('session_resume_continue_capture')),
        findsOneWidget,
      );
      expect(find.byType(LibraryIncidentSummaryTile), findsWidgets);

      // Production handler: HomeScreen._handleContinueCapture →
      // AppNavigation.openContinuousCapture. Do not push IncidentWorkspaceShell.
      expect(
        LibraryIncidentRoutes.continuePreservingStage,
        InvestigationMethodologyStage.capture,
      );
    });

    testWidgets('4 Continue Investigation opens Investigate Timeline',
        (tester) async {
      _seedWorkplaceOrganizeReady();
      await pumpHome(tester);
      WorkspaceSession.instance.setActiveStage(
        InvestigationMethodologyStage.evidence,
      );

      await tester.scrollUntilVisible(
        find.text(IncidentActionHierarchy.investigateLabel),
        120,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(IncidentActionHierarchy.investigateLabel));
      await tester.pumpAndSettle();

      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
      expect(find.text('Understand chronology and relationships'), findsOneWidget);
      expect(find.text('Timeline'), findsWidgets);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.investigation,
      );
      expect(
        WorkspaceSession.instance.activeInvestigationTab,
        InvestigationWorkspaceTab.timeline,
      );
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        'incident-workplace-concern',
      );
    });

    testWidgets('5 leftover Trust stage does not override Library card tap',
        (tester) async {
      await pumpHome(tester);
      WorkspaceSession.instance.setActiveStage(
        InvestigationMethodologyStage.trustPackage,
      );
      WorkspaceSession.instance.resumeTarget =
          WorkspaceResumeTarget.trustPackageScreen;

      final card = find.byKey(
        LibraryIncidentSummaryTile.cardKey('incident-workplace-concern'),
      );
      await tester.scrollUntilVisible(card, 120);
      await tester.pumpAndSettle();
      expect(find.text('View Evidence Map'), findsNothing);
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(find.text('Capture what happened clearly'), findsOneWidget);
      expect(find.text('Generate a professional evidence package'), findsNothing);
    });
  });

  group('Incident switch', () {
    test('6 opening B does not inherit A stage or evidence identity', () async {
      final session = WorkspaceSession.instance;
      session.controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      expect(session.controller.currentIncident.evidence, isNotEmpty);
      final aEvidenceIds =
          session.controller.currentIncident.evidence.map((e) => e.id).toSet();
      session.setActiveStage(InvestigationMethodologyStage.trustPackage);

      final opened = await session.openIncident('inc-B');
      expect(opened, isTrue);
      expect(session.controller.currentIncident.id, 'inc-B');
      expect(
        session.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        session.controller.currentIncident.evidence.any(
          (item) => aEvidenceIds.contains(item.id),
        ),
        isFalse,
      );
    });

    test('8 openIncident does not mint a new id for a known incident', () async {
      final session = WorkspaceSession.instance;
      session.controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
      );
      final opened = await session.openIncident('inc-A');
      expect(opened, isTrue);
      expect(session.controller.currentIncident.id, 'inc-A');
    });
  });
}
