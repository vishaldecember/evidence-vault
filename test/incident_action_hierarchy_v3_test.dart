import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/navigation/incident_action_hierarchy.dart';
import 'package:evidence_vault/navigation/incident_workspace_entry.dart';
import 'package:evidence_vault/navigation/library_incident_routes.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/main_shell_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/widgets/home/session_resume_card.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/workspace/capture_section_header.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryIncidentSummary _summary({
  required String id,
  required String title,
  int evidenceCount = 1,
  bool archived = false,
  String lastPreserved = '10:42 PM',
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: evidenceCount,
    contextEnrichedCount: 0,
    integrityVerified: true,
    lastPreserved: lastPreserved,
    isInProgress: !archived,
    isArchived: archived,
    createdAt: DateTime.utc(2026, 8, 20, 10),
    updatedAt: DateTime.utc(2026, 8, 21, 11),
  );
}

void _bindIncident({
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

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: MainShellScreen()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
  });

  tearDown(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
  });

  group('IncidentActionHierarchy', () {
    test('archived incidents expose no mutation continue actions', () {
      final visibility = IncidentActionHierarchy.from(
        archived: true,
        readiness: OrganizeReadiness.assess(
          evidence: const [],
        ),
      );
      expect(visibility.showPreserve, isFalse);
      expect(visibility.showOrganize, isFalse);
      expect(visibility.showInvestigate, isFalse);
    });

    test('P one-evidence is preserve-only using assess()', () {
      _bindIncident(
        id: 'inc-one',
        title: 'One',
        modes: const [WorkspaceCaptureMode.photo],
      );
      final readiness = WorkspaceSession.instance.controller.organizeReadiness;
      expect(readiness.isReady, isFalse);
      final visibility = IncidentActionHierarchy.from(
        archived: false,
        readiness: readiness,
      );
      expect(visibility.showPreserve, isTrue);
      expect(visibility.showOrganize, isFalse);
      expect(visibility.showInvestigate, isFalse);
    });

    test('P organize-ready is deterministic from assess()', () {
      _bindIncident(
        id: 'inc-ready',
        title: 'Ready',
        modes: const [
          WorkspaceCaptureMode.video,
          WorkspaceCaptureMode.note,
        ],
      );
      final readiness = WorkspaceSession.instance.controller.organizeReadiness;
      expect(readiness.isReady, isTrue);
      final visibility = IncidentActionHierarchy.from(
        archived: false,
        readiness: readiness,
      );
      expect(visibility.showPreserve, isTrue);
      expect(visibility.showOrganize, isFalse);
      expect(visibility.showInvestigate, isTrue);
    });

    test('L OrganizeReadiness.assess rules are unchanged', () {
      _bindIncident(
        id: 'inc-ready',
        title: 'Ready',
        modes: const [
          WorkspaceCaptureMode.video,
          WorkspaceCaptureMode.note,
        ],
      );
      final controller = WorkspaceSession.instance.controller;
      final assessed = OrganizeReadiness.assess(
        evidence: controller.currentIncident.evidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
      );
      expect(controller.organizeReadiness.status, assessed.status);
      expect(controller.organizeReadiness.matchedPattern, assessed.matchedPattern);
      expect(
        IncidentWorkspaceEntry.stageFor(assessed),
        InvestigationMethodologyStage.evidence,
      );
    });

    test('K Phase 3E routing constants and stageFor remain unchanged', () {
      expect(
        IncidentWorkspaceEntry.fallbackStage,
        LibraryIncidentRoutes.cardBodyStage,
      );
      expect(
        IncidentWorkspaceEntry.stageFor(
          OrganizeReadiness.assess(evidence: const []),
        ),
        InvestigationMethodologyStage.capture,
      );
      expect(
        LibraryIncidentRoutes.continuePreservingStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        LibraryIncidentRoutes.continueOrganizingStage,
        InvestigationMethodologyStage.evidence,
      );
      expect(
        LibraryIncidentRoutes.continueInvestigationStage,
        InvestigationMethodologyStage.investigation,
      );
    });
  });

  group('SessionResumeCard hierarchy', () {
    testWidgets('A one evidence: preserve only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionResumeCard(
              incidentTitle: 'Street',
              evidenceCount: 1,
              lastActivityLabel: '10:42 PM',
              onContinueCapture: () {},
            ),
          ),
        ),
      );
      expect(find.text(IncidentActionHierarchy.preserveLabel), findsOneWidget);
      expect(find.text(IncidentActionHierarchy.organizeLabel), findsNothing);
      expect(find.text(IncidentActionHierarchy.investigateLabel), findsNothing);
      expect(find.byKey(const Key('session_resume_metadata_row')), findsOneWidget);
      expect(find.text('1 evidence'), findsOneWidget);
      expect(find.textContaining('Last activity'), findsOneWidget);
    });

    testWidgets('B organize-ready without investigation callback: preserve only',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionResumeCard(
              incidentTitle: 'Street',
              evidenceCount: 3,
              lastActivityLabel: '10:42 PM',
              onContinueCapture: () {},
            ),
          ),
        ),
      );
      expect(find.text(IncidentActionHierarchy.preserveLabel), findsOneWidget);
      expect(find.text(IncidentActionHierarchy.organizeLabel), findsNothing);
      expect(find.text(IncidentActionHierarchy.investigateLabel), findsNothing);
    });

    testWidgets('C investigation-ready: preserve + investigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionResumeCard(
              incidentTitle: 'Street',
              evidenceCount: 3,
              lastActivityLabel: '10:42 PM',
              onContinueCapture: () {},
              onContinueInvestigation: () {},
            ),
          ),
        ),
      );
      expect(find.text(IncidentActionHierarchy.preserveLabel), findsOneWidget);
      expect(find.text(IncidentActionHierarchy.organizeLabel), findsNothing);
      expect(find.text(IncidentActionHierarchy.investigateLabel), findsOneWidget);
      final preserve = tester.getRect(
        find.byKey(const Key('session_resume_continue_capture')),
      );
      final investigate = tester.getRect(
        find.byKey(const Key('session_resume_continue_investigation')),
      );
      expect(investigate.top, greaterThan(preserve.bottom));
      expect(investigate.height, greaterThanOrEqualTo(48));
    });

    testWidgets('O metadata row contains last activity and evidence count',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionResumeCard(
              incidentTitle: 'Street',
              evidenceCount: 5,
              lastActivityLabel: '10:42 PM',
              onContinueCapture: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('session_resume_metadata_row')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('session_resume_metadata_row')),
          matching: find.textContaining('Last activity'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('session_resume_metadata_row')),
          matching: find.byKey(const Key('session_resume_evidence_count')),
        ),
        findsOneWidget,
      );
      expect(find.text('5 evidence'), findsOneWidget);
      expect(find.text('Evidence 5'), findsNothing);
    });
  });

  group('Home continue card uses working-set readiness', () {
    testWidgets('A one evidence hides organize and investigation', (tester) async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [
          _summary(id: 'inc-one', title: 'Street', evidenceCount: 1),
        ],
        records: const [],
      );
      _bindIncident(
        id: 'inc-one',
        title: 'Street',
        modes: const [WorkspaceCaptureMode.photo],
      );
      await _pumpHome(tester);

      expect(find.byType(SessionResumeCard), findsOneWidget);
      expect(find.text(IncidentActionHierarchy.preserveLabel), findsWidgets);
      expect(find.text(IncidentActionHierarchy.organizeLabel), findsNothing);
      expect(find.text(IncidentActionHierarchy.investigateLabel), findsNothing);
      expect(find.text('1 evidence'), findsWidgets);
    });

    testWidgets('B/C organize-ready shows investigation, not organizing',
        (tester) async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [
          _summary(id: 'inc-ready', title: 'Street', evidenceCount: 2),
        ],
        records: const [],
      );
      _bindIncident(
        id: 'inc-ready',
        title: 'Street',
        modes: const [
          WorkspaceCaptureMode.video,
          WorkspaceCaptureMode.note,
        ],
      );
      await _pumpHome(tester);

      expect(find.text(IncidentActionHierarchy.preserveLabel), findsWidgets);
      expect(find.text(IncidentActionHierarchy.organizeLabel), findsNothing);
      expect(find.text(IncidentActionHierarchy.investigateLabel), findsOneWidget);
    });

    testWidgets('E evidence count uses the incident evidence source',
        (tester) async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [
          _summary(id: 'inc-count', title: 'Street', evidenceCount: 0),
        ],
        records: const [],
      );
      _bindIncident(
        id: 'inc-count',
        title: 'Street',
        modes: const [WorkspaceCaptureMode.photo, WorkspaceCaptureMode.photo],
      );
      await _pumpHome(tester);

      expect(
        WorkspaceSession.instance.controller.currentIncident.evidenceCount,
        2,
      );
      expect(find.text('2 evidence'), findsWidgets);
    });
  });

  group('Workspace evidence identity', () {
    testWidgets('D Organize ⓘ is not duplicated with Capture mounted',
        (tester) async {
      _bindIncident(
        id: 'inc-ready',
        title: 'Street',
        modes: const [
          WorkspaceCaptureMode.video,
          WorkspaceCaptureMode.note,
        ],
      );
      final controller = WorkspaceSession.instance.controller;
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: 'inc-ready',
            controller: controller,
            initialStage: InvestigationMethodologyStage.capture,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CaptureSectionHeader), findsOneWidget);
      expect(find.byType(OrganizeReadinessInfoButton), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(InvestigationJourneyHeader),
          matching: find.text('Organize'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrganizeReadinessInfoButton), findsOneWidget);
      expect(find.byKey(OrganizeReadinessInfoButton.buttonKey), findsOneWidget);
      await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byType(OrganizeReadinessGuideSheet), findsOneWidget);
    });

    testWidgets(
        'F/G/H/M/N card → workspace keeps incident and evidence identity',
        (tester) async {
      _bindIncident(
        id: 'inc-visible',
        title: 'Street',
        modes: const [
          WorkspaceCaptureMode.photo,
          WorkspaceCaptureMode.voice,
          WorkspaceCaptureMode.note,
        ],
      );
      final controller = WorkspaceSession.instance.controller;
      final before = {
        'incidentId': controller.currentIncident.id,
        'evidenceIds': [
          for (final item in controller.currentIncident.evidence) item.id,
        ],
        'hashes': [
          for (final item in controller.currentIncident.evidence)
            item.contentHash,
        ],
        'capturedAt': [
          for (final item in controller.currentIncident.evidence)
            item.capturedAt,
        ],
        'recordedAt': [
          for (final item in controller.currentIncident.evidence)
            item.recordedAt,
        ],
        'lastPreservedAt': [
          for (final item in controller.currentIncident.evidence)
            item.lastPreservedAt,
        ],
        'sequence': controller.timelineRepository.orderedCapturedEvidenceIds(),
      };

      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: 'inc-visible',
            controller: controller,
            initialStage: InvestigationMethodologyStage.evidence,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shell = tester.state<IncidentWorkspaceShellState>(
        find.byType(IncidentWorkspaceShell),
      );
      expect(shell.boundIncidentId, 'inc-visible');
      expect(controller.currentIncident.id, 'inc-visible');
      expect(
        [for (final item in controller.currentIncident.evidence) item.id],
        before['evidenceIds'],
      );
      expect(
        [for (final item in controller.currentIncident.evidence) item.contentHash],
        before['hashes'],
      );
      expect(
        [for (final item in controller.currentIncident.evidence) item.capturedAt],
        before['capturedAt'],
      );
      expect(
        [for (final item in controller.currentIncident.evidence) item.recordedAt],
        before['recordedAt'],
      );
      expect(
        [
          for (final item in controller.currentIncident.evidence)
            item.lastPreservedAt,
        ],
        before['lastPreservedAt'],
      );
      expect(
        controller.timelineRepository.orderedCapturedEvidenceIds(),
        before['sequence'],
      );
      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(find.text('3 preserved records'), findsOneWidget);
      expect(controller.currentIncident.evidenceCount, 3);
    });

    testWidgets('I empty incident still shows the existing empty state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizeWorkspaceView(
            incident: WorkspaceEvidenceController().currentIncident,
            onEvidenceSelected: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('No evidence in this incident yet. Capture to begin organizing.'),
        findsOneWidget,
      );
    });

    testWidgets('J archived Organize remains read-only', (tester) async {
      _bindIncident(
        id: 'inc-arch',
        title: 'Street',
        modes: const [
          WorkspaceCaptureMode.video,
          WorkspaceCaptureMode.note,
        ],
      );
      final controller = WorkspaceSession.instance.controller;
      IncidentLibraryService.instance.summaries = [
        _summary(id: 'inc-arch', title: 'Street', evidenceCount: 2),
      ];
      await IncidentLibraryService.instance.archiveIncident('inc-arch');

      expect(controller.isArchivedReadOnly, isTrue);
      final visibility = IncidentActionHierarchy.from(
        archived: true,
        readiness: controller.organizeReadiness,
      );
      expect(visibility.showPreserve, isFalse);
      expect(visibility.showOrganize, isFalse);
      expect(visibility.showInvestigate, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: OrganizeWorkspaceView(
            incident: controller.currentIncident,
            onEvidenceSelected: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(OrganizeReadinessInfoButton.buttonKey), findsOneWidget);
      await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byType(OrganizeReadinessGuideSheet), findsOneWidget);
    });
  });
}
