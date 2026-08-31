import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/home_dashboard_mock.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/navigation/incident_action_hierarchy.dart';
import 'package:evidence_vault/screens/evidence_workspace_screen.dart';
import 'package:evidence_vault/screens/main_shell_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';

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

  testWidgets('Main shell home renders launch pad without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preserve your truth now.'), findsOneWidget);
    expect(find.text('Protect that matters later'), findsOneWidget);
    expect(find.text('Capture Now'), findsOneWidget);
    expect(
      find.textContaining('Something happened? Don’t wait, capture it'),
      findsOneWidget,
    );
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
    expect(find.text('The Library of Truth'), findsOneWidget);
    expect(
      find.textContaining('Every library begins with one piece of truth.'),
      findsOneWidget,
    );
    expect(find.text('As your library grows'), findsNothing);
    expect(
      find.textContaining('Enrich it as your story unfolds.'),
      findsOneWidget,
    );
    expect(find.text('Workplace Harassment'), findsOneWidget);
    expect(find.text('Traffic Collision'), findsOneWidget);
    expect(find.text('Wrong Item Delivered'), findsOneWidget);
    expect(find.text('UPI Payment Disputed'), findsOneWidget);
    expect(find.text('Ride Dispute'), findsOneWidget);
    expect(find.text('Security Deposit Dispute'), findsOneWidget);
    expect(find.text('Builder Promise vs Reality'), findsOneWidget);
    expect(find.text('Service Complaint Unresolved'), findsOneWidget);
    expect(find.text('Service vs What Was Promised'), findsOneWidget);
    expect(find.text('Repeated Unwanted Contact'), findsOneWidget);
    expect(find.text('Continue Preserving'), findsNothing);
    expect(find.text('Continue Investigation'), findsNothing);
    expect(find.text(IncidentActionHierarchy.investigateLabel), findsNothing);
    expect(find.text('Continue →'), findsNothing);
    expect(find.text('Recent Activity'), findsNothing);
    expect(find.text('Remember'), findsNothing);
    expect(find.text('Create Evidence'), findsNothing);
    expect(find.text('New Incident'), findsNothing);
    expect(find.text('Start Incident'), findsNothing);
    expect(find.text('Create Incident'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home shows empty library preview when no real incidents', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      IncidentLibraryService.instance.summaries = [];
    });

    IncidentLibraryService.instance.summaries = [];

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('The Library of Truth'), findsOneWidget);
    expect(find.text('Workplace Harassment'), findsOneWidget);
    expect(find.text('Traffic Collision'), findsOneWidget);
    expect(find.text('Wrong Item Delivered'), findsOneWidget);
    expect(find.text('UPI Payment Disputed'), findsOneWidget);
    expect(find.text('Ride Dispute'), findsOneWidget);
    expect(find.text('Security Deposit Dispute'), findsOneWidget);
    expect(find.text('Builder Promise vs Reality'), findsOneWidget);
    expect(find.text('Service Complaint Unresolved'), findsOneWidget);
    expect(find.text('Service vs What Was Promised'), findsOneWidget);
    expect(find.text('Repeated Unwanted Contact'), findsOneWidget);
    expect(find.text('As your library grows'), findsNothing);
    expect(
      find.textContaining('Enrich it as your story unfolds.'),
      findsOneWidget,
    );
    expect(find.text('Continue Investigation'), findsNothing);
    expect(find.text(IncidentActionHierarchy.investigateLabel), findsNothing);
    expect(find.text('Continue →'), findsNothing);
    expect(find.text('Capture Now'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Home hides library preview when real incidents exist', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      IncidentLibraryService.instance.summaries = [];
    });

    IncidentLibraryService.instance.summaries =
        HomeDashboardMock.activeLibraryIncidents;

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workplace Concern'), findsWidgets);
    expect(find.text(IncidentActionHierarchy.preserveLabel), findsWidgets);
    expect(find.text('Continue →'), findsNothing);
    expect(find.text('Workplace Harassment'), findsNothing);
    expect(find.text('As your library grows'), findsNothing);
    expect(
      find.text('Every library begins with one piece of truth.'),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Home keeps capture actions fixed while scrolling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Photo'), findsOneWidget);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Photo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Bottom navigation switches to Vault and Profile', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();
    expect(find.text('The Library of Truth'), findsOneWidget);
    expect(find.text('Memory Recall'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('Quick Capture navigates to Evidence Workspace', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo').first);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Capture what happened clearly'), findsOneWidget);
    expect(find.text('Evidence Maturity'), findsOneWidget);
    expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);
    expect(find.textContaining('Name Incident'), findsOneWidget);
  });

  testWidgets('Home quick capture preserves evidence in Evidence Maturity', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);
    expect(find.text('Evidence Maturity'), findsOneWidget);
    expect(find.text('Capture what happened clearly'), findsOneWidget);
  });
  testWidgets('Capture immediately adds evidence to Evidence Maturity', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: EvidenceWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo'));
    await tester.pump();

    expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);
    expect(find.byKey(const Key('success_confirmation')), findsOneWidget);
  });
  testWidgets('Evidence Inspector opens from journey artifact without navigation',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: EvidenceWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();

    expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);
    await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail));
    await tester.tap(find.byType(JourneyEvidenceThumbnail));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.text('Evidence Record'), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    expect(find.text('Evidence Inspector'), findsNothing);
    expect(find.text('Capture'), findsWidgets);
  });

  testWidgets('Resume navigates to Evidence Workspace', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      IncidentLibraryService.instance.summaries = [];
    });

    IncidentLibraryService.instance.summaries =
        HomeDashboardMock.activeLibraryIncidents;
    _seedWorkplaceOrganizeReady();

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workplace Harassment'), findsNothing);

    await tester.scrollUntilVisible(
      find.text(IncidentActionHierarchy.investigateLabel),
      120,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(IncidentActionHierarchy.investigateLabel));
    await tester.pumpAndSettle();

    expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
    expect(find.text('Understand chronology and relationships'), findsOneWidget);
    expect(find.text('Timeline'), findsWidgets);
    expect(find.text('Evidence Map'), findsNothing);
    expect(find.text('Incident Timeline'), findsNothing);
  });

  testWidgets('Library card tap opens Incident Workspace; View Evidence Map is absent', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      IncidentLibraryService.instance.summaries = [];
    });

    IncidentLibraryService.instance.summaries =
        HomeDashboardMock.activeLibraryIncidents;

    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(
      LibraryIncidentSummaryTile.cardKey('incident-workplace-concern'),
    );
    await tester.scrollUntilVisible(card, 120);
    await tester.pumpAndSettle();

    expect(find.text('View Evidence Map'), findsNothing);

    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byType(InvestigationWorkspaceTabBar), findsNothing);
    expect(find.text('Capture what happened clearly'), findsOneWidget);
    expect(
      WorkspaceSession.instance.activeMethodologyStage,
      InvestigationMethodologyStage.capture,
    );
  });

  testWidgets('Evidence Workspace capture preserves evidence immediately', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: EvidenceWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voice'));
    await tester.pump();

    expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);
    expect(find.byKey(const Key('success_confirmation')), findsOneWidget);
  });
  testWidgets('Evidence Workspace shows only operational sections (8.5.20.2)', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: EvidenceWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evidence Maturity'), findsOneWidget);
    expect(find.text('Capture'), findsWidgets);
    expect(find.text('Capture what happened clearly'), findsOneWidget);
    expect(find.text('Photo'), findsWidgets);
    expect(find.text('Evidence Map'), findsNothing);
    expect(find.text('Incident Timeline'), findsNothing);
    expect(find.text('Insights'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Evidence Workspace keeps capture actions fixed while scrolling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: EvidenceWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Voice'), findsOneWidget);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Voice'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
  });
}
