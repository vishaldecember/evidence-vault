import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/home_dashboard_mock.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_resume_target.dart';
import 'package:evidence_vault/navigation/incident_action_hierarchy.dart';
import 'package:evidence_vault/screens/evidence_workspace_screen.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/main_shell_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/widgets/common/app_back_button.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/investigation/investigation_stage_header.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:evidence_vault/widgets/workspace/incident_product_header.dart';
import 'package:evidence_vault/widgets/workspace/incident_workspace_more_menu.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({required String id}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.summaries = [];
    IncidentLibraryService.instance.records = [];
  });

  group('WorkspaceSession navigation state', () {
    test('enterCapture resets methodology stage to Capture', () {
      WorkspaceSession.instance.enterEvidenceEditing();

      WorkspaceSession.instance.enterCapture();

      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        WorkspaceSession.instance.resumeTarget,
        WorkspaceResumeTarget.incidentWorkspace,
      );
    });

    test('enterEvidenceEditing preserves resume target', () {
      WorkspaceSession.instance.resumeTarget =
          WorkspaceResumeTarget.incidentWorkspace;
      WorkspaceSession.instance.setActiveStage(
        InvestigationMethodologyStage.investigation,
        investigationTab: InvestigationWorkspaceTab.timeline,
      );

      WorkspaceSession.instance.enterEvidenceEditing();

      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
      expect(
        WorkspaceSession.instance.resumeTarget,
        WorkspaceResumeTarget.incidentWorkspace,
      );
    });
  });

  group('Investigation navigation architecture', () {
    testWidgets('renders global branding and journey once in shell', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await tester.pumpWidget(
        const MaterialApp(home: IncidentWorkspaceShell()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IncidentProductHeader), findsOneWidget);
      expect(find.byType(InvestigationJourneyHeader), findsOneWidget);
      expect(find.text('Your incident lives here.'), findsOneWidget);
      expect(find.byKey(IncidentWorkspaceMoreMenu.buttonKey), findsOneWidget);
      expect(find.byType(AppBackButton), findsNothing);
    });

    testWidgets('stage switching preserves investigation tab in shell', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video'),
          ],
        ),
      );
      WorkspaceSession.instance.controller = controller;

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            controller: controller,
            initialStage: InvestigationMethodologyStage.investigation,
            initialInvestigationTab: InvestigationWorkspaceTab.reconstruction,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        WorkspaceSession.instance.activeInvestigationTab,
        InvestigationWorkspaceTab.reconstruction,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(InvestigationJourneyHeader),
          matching: find.text('Organize'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Organize and enrich your records'), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeInvestigationTab,
        InvestigationWorkspaceTab.reconstruction,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(InvestigationJourneyHeader),
          matching: find.text('Investigate'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Understand chronology and relationships'),
        findsOneWidget,
      );
      expect(
        WorkspaceSession.instance.activeInvestigationTab,
        InvestigationWorkspaceTab.reconstruction,
      );
      expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
    });

    testWidgets('Evidence stage does not render investigation tabs', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      WorkspaceSession.instance.setActiveStage(
        InvestigationMethodologyStage.evidence,
      );

      await tester.pumpWidget(
        const MaterialApp(home: IncidentWorkspaceShell()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationWorkspaceTabBar), findsNothing);
      expect(find.text('Organize and enrich your records'), findsOneWidget);
    });

    testWidgets('Investigation stage renders workspace title and tabs', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      WorkspaceSession.instance.setActiveStage(
        InvestigationMethodologyStage.investigation,
        investigationTab: InvestigationWorkspaceTab.timeline,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            initialStage: InvestigationMethodologyStage.investigation,
            controller: WorkspaceEvidenceController(
              initialState: WorkspaceEvidenceState(
                items: [
                  _item(id: 'photo'),
                  _item(id: 'video'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationStageHeader), findsOneWidget);
      expect(find.text('Investigation Workspace'), findsOneWidget);
      expect(
        find.text('Understand chronology and relationships'),
        findsOneWidget,
      );
      expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
      expect(find.text('Timeline'), findsWidgets);
      expect(find.text('Connections'), findsWidgets);
      expect(find.text('Reconstruct'), findsWidgets);
    });
  });

  group('Stateful Investigation Workspace', () {
    testWidgets(
      'journey evidence opens inspector without leaving capture stage',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final controller = WorkspaceEvidenceController();
        controller.preserveEvidence(WorkspaceCaptureMode.photo);
        WorkspaceSession.instance.controller = controller;

        await tester.pumpWidget(
          MaterialApp(home: EvidenceWorkspaceScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        expect(
          WorkspaceSession.instance.activeMethodologyStage,
          InvestigationMethodologyStage.capture,
        );
        expect(find.text('Capture what happened clearly'), findsOneWidget);

        await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail));
        await tester.tap(find.byType(JourneyEvidenceThumbnail));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Evidence Inspector'), findsOneWidget);
        expect(
          WorkspaceSession.instance.activeMethodologyStage,
          InvestigationMethodologyStage.capture,
        );

        await tester.tap(find.text('Close').last);
        await tester.pumpAndSettle();

        expect(find.text('Evidence Inspector'), findsNothing);
        expect(
          WorkspaceSession.instance.activeMethodologyStage,
          InvestigationMethodologyStage.capture,
        );
        expect(find.text('Capture what happened clearly'), findsOneWidget);
      },
    );

    testWidgets('advanced record from inspector switches to Evidence stage', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      WorkspaceSession.instance.controller = controller;

      await tester.pumpWidget(
        MaterialApp(home: EvidenceWorkspaceScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail));
      await tester.tap(find.byType(JourneyEvidenceThumbnail));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.text('View complete record →'));
      await tester.tap(find.text('View complete record →'));
      await tester.pumpAndSettle();

      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
      expect(find.text('Evidence Record'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
      expect(find.text('Organize and enrich your records'), findsOneWidget);
      expect(find.text('Capture what happened clearly'), findsNothing);
      expect(find.byType(InvestigationWorkspaceTabBar), findsNothing);
    });

    testWidgets('quick capture resets workspace to Capture stage', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      WorkspaceSession.instance.enterEvidenceEditing();

      await tester.pumpWidget(const MaterialApp(home: MainShellScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Photo').first);
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(find.text('Capture what happened clearly'), findsOneWidget);
    });

    testWidgets(
      'Continue Investigation always opens Investigate, not leftover stage',
      (tester) async {
        addTearDown(() {
          tester.binding.setSurfaceSize(null);
          IncidentLibraryService.instance.summaries = [];
        });
        await tester.binding.setSurfaceSize(const Size(412, 915));

        IncidentLibraryService.instance.summaries =
            HomeDashboardMock.activeLibraryIncidents;

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
        WorkspaceSession.instance.setActiveStage(
          InvestigationMethodologyStage.investigation,
          investigationTab: InvestigationWorkspaceTab.reconstruction,
        );
        WorkspaceSession.instance.resumeTarget =
            WorkspaceResumeTarget.incidentWorkspace;

        await tester.pumpWidget(const MaterialApp(home: MainShellScreen()));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text(IncidentActionHierarchy.investigateLabel),
          120,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(IncidentActionHierarchy.investigateLabel));
        await tester.pumpAndSettle();

        expect(find.byType(InvestigationStageHeader), findsOneWidget);
        expect(find.text('Investigation Workspace'), findsOneWidget);
        expect(
          find.text('Understand chronology and relationships'),
          findsOneWidget,
        );
        expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
        expect(
          WorkspaceSession.instance.activeMethodologyStage,
          InvestigationMethodologyStage.investigation,
        );
        expect(
          WorkspaceSession.instance.activeInvestigationTab,
          InvestigationWorkspaceTab.timeline,
        );
      },
    );

    testWidgets('Continue Investigation ignores leftover Organize stage', (
      tester,
    ) async {
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        IncidentLibraryService.instance.summaries = [];
      });
      await tester.binding.setSurfaceSize(const Size(412, 915));

      IncidentLibraryService.instance.summaries =
          HomeDashboardMock.activeLibraryIncidents;

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
      WorkspaceSession.instance.enterEvidenceEditing();
      WorkspaceSession.instance.resumeTarget =
          WorkspaceResumeTarget.incidentWorkspace;

      await tester.pumpWidget(const MaterialApp(home: MainShellScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(IncidentActionHierarchy.investigateLabel),
        120,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(IncidentActionHierarchy.investigateLabel));
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
      expect(
        find.text('Understand chronology and relationships'),
        findsOneWidget,
      );
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.investigation,
      );
      expect(
        WorkspaceSession.instance.activeInvestigationTab,
        InvestigationWorkspaceTab.timeline,
      );
    });
  });
}
