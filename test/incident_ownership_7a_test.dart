import 'dart:async';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/mappers/evidence_projection.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/app_navigation.dart';
import 'package:evidence_vault/navigation/library_incident_routes.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/investigation_workspace_screen.dart';
import 'package:evidence_vault/screens/trust_package_screen.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigate_incident_scope.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail('EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual');
  }
}

WorkspaceEvidenceController _controllerFor({
  required String id,
  required String title,
  int photos = 0,
}) {
  final controller = WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: id, title: title),
  );
  for (var i = 0; i < photos; i++) {
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
  }
  return controller;
}

WorkspaceEvidenceItem _item({
  required String id,
  required String incidentId,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Photo $id',
    lastPreservedAt: DateTime(2026, 8, 15, 12),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WorkspaceSession.instance.reset();
  });

  testWidgets('1. Incident A opens → workspace bound to A', (tester) async {
    final controller = _controllerFor(id: 'inc-A', title: 'Alpha', photos: 1);
    WorkspaceSession.instance.controller = controller;

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          incidentId: 'inc-A',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shell = tester.state<IncidentWorkspaceShellState>(
      find.byType(IncidentWorkspaceShell),
    );
    expectIncident('inc-A', shell.boundIncidentId);
    expectIncident('inc-A', controller.currentIncident.id);
  });

  testWidgets('2. Incident B opens after A → bound to B, A not retained',
      (tester) async {
    final controllerA = _controllerFor(id: 'inc-A', title: 'Alpha', photos: 1);
    WorkspaceSession.instance.controller = controllerA;

    late BuildContext navContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            navContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    unawaited(AppNavigation.openIncidentWorkspace(navContext));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    var shell = tester.state<IncidentWorkspaceShellState>(
      find.byType(IncidentWorkspaceShell),
    );
    expectIncident('inc-A', shell.boundIncidentId);

    final controllerB = _controllerFor(id: 'inc-B', title: 'Beta', photos: 1);
    WorkspaceSession.instance.controller = controllerB;
    unawaited(AppNavigation.openIncidentWorkspace(navContext));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
    shell = tester.state<IncidentWorkspaceShellState>(
      find.byType(IncidentWorkspaceShell),
    );
    expectIncident('inc-B', shell.boundIncidentId);
    expect(shell.boundIncidentId, isNot('inc-A'));
  });

  test('3–4. Evidence of A cannot appear in B and vice versa', () {
    final a = _item(id: 'ev-a', incidentId: 'inc-A');
    final b = _item(id: 'ev-b', incidentId: 'inc-B');
    final scopedB = InvestigateIncidentScope.evidence([a, b], 'inc-B');
    expect(scopedB.map((item) => item.id), ['ev-b']);
    final scopedA = InvestigateIncidentScope.evidence([a, b], 'inc-A');
    expect(scopedA.map((item) => item.id), ['ev-a']);
  });

  test('5. Blank incidentId fails closed and cannot widen scope', () {
    final blank = _item(id: 'ev-blank', incidentId: '');
    final owned = _item(id: 'ev-a', incidentId: 'inc-A');
    expect(blank.belongsToIncident('inc-A'), isFalse);
    expect(blank.belongsToIncident('inc-B'), isFalse);
    expect(owned.belongsToIncident(''), isFalse);

    final scoped = InvestigateIncidentScope.evidence([blank, owned], 'inc-A');
    expect(scoped.map((item) => item.id), ['ev-a']);

    final ordered = evidenceInspectorOrder(
      [blank, owned],
      incidentId: 'inc-A',
    );
    expect(ordered.map((item) => item.id), ['ev-a']);
    expect(
      evidenceInspectorOrder([blank, owned], incidentId: ''),
      isEmpty,
    );
  });

  test('6. Legacy blank domain row is stamped only at projection', () {
    final now = DateTime(2026, 8, 15, 10);
    final store = IncidentStore(
      incident: Incident(
        id: 'inc-A',
        title: 'Alpha',
        status: IncidentStatus.draft,
        createdAt: now,
        updatedAt: now,
      ),
      capturedEvidence: [
        CapturedEvidence(
          id: 'ev-legacy',
          incidentId: '',
          type: CapturedEvidenceType.photo,
          capturedAt: now,
          title: 'Legacy photo',
          integrityVerified: true,
          verification: VerificationFactory.initial(),
          timelineAnchorId: 'anchor-1',
        ),
      ],
    );
    final projected = EvidenceProjection.toWorkspaceItems(store);
    expect(projected, hasLength(1));
    expectIncident('inc-A', projected.single.incidentId);
    expect(projected.single.belongsToIncident('inc-A'), isTrue);
    expect(projected.single.belongsToIncident('inc-B'), isFalse);
  });

  testWidgets(
      '7. Session controller cannot override the shell bound identity',
      (tester) async {
    final controller = _controllerFor(id: 'inc-A', title: 'Alpha', photos: 1);
    WorkspaceSession.instance.controller = controller;

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          incidentId: 'inc-A',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-B', title: 'Beta'),
    );
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    await tester.pumpAndSettle();

    final shell = tester.state<IncidentWorkspaceShellState>(
      find.byType(IncidentWorkspaceShell),
    );
    expectIncident('inc-A', shell.boundIncidentId);
    expectIncident('inc-B', controller.currentIncident.id);

    final presented = InvestigateIncidentScope.presentation(
      controller.currentIncident,
      shell.boundIncidentId,
    );
    expectIncident('inc-A', presented.id);
    expect(presented.evidence, isEmpty);
    expect(
      presented.evidence.any((item) => item.incidentId == 'inc-B'),
      isFalse,
    );
  });

  testWidgets('8. Reopening the same incident preserves identity',
      (tester) async {
    final controller = _controllerFor(id: 'inc-A', title: 'Alpha', photos: 1);
    WorkspaceSession.instance.controller = controller;

    late BuildContext navContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            navContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    unawaited(AppNavigation.openIncidentWorkspace(navContext));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expectIncident(
      'inc-A',
      tester
          .state<IncidentWorkspaceShellState>(find.byType(IncidentWorkspaceShell))
          .boundIncidentId,
    );

    unawaited(AppNavigation.openIncidentWorkspace(navContext));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
    expectIncident(
      'inc-A',
      tester
          .state<IncidentWorkspaceShellState>(find.byType(IncidentWorkspaceShell))
          .boundIncidentId,
    );
  });

  test('9. Explicit Library stage actions remain unchanged', () {
    expect(
      LibraryIncidentRoutes.cardBodyStage,
      InvestigationMethodologyStage.capture,
    );
    expect(
      LibraryIncidentRoutes.viewEvidenceMapStage,
      InvestigationMethodologyStage.evidence,
    );
    expect(
      LibraryIncidentRoutes.continueInvestigationStage,
      InvestigationMethodologyStage.investigation,
    );
    expect(
      LibraryIncidentRoutes.continueTrustStage,
      InvestigationMethodologyStage.trustPackage,
    );
  });

  testWidgets(
      '10. Capture Organize Investigate Trust share the bound identity',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final controller = _controllerFor(id: 'inc-A', title: 'Alpha', photos: 2);
    WorkspaceSession.instance.controller = controller;

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentWorkspaceShell(
          incidentId: 'inc-A',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shell = tester.state<IncidentWorkspaceShellState>(
      find.byType(IncidentWorkspaceShell),
    );

    Future<void> tapStage(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(InvestigationJourneyHeader),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expectIncident('inc-A', shell.boundIncidentId);
      expectIncident('inc-A', controller.currentIncident.id);
    }

    await tapStage('Organize');
    expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
    await tapStage('Investigate');
    expect(find.byType(InvestigationWorkspaceScreen), findsOneWidget);
    await tapStage('Trust Package');
    expect(find.byType(TrustPackageScreen), findsOneWidget);
    await tapStage('Capture');
  });
}
