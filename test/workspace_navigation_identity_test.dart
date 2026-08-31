import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/common/app_back_button.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail(
      'EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual',
    );
  }
}

void expectEvidence(String expected, String actual) {
  if (expected != actual) {
    fail(
      'EXPECTED EVIDENCE:\n$expected\n\nACTUAL EVIDENCE:\n$actual',
    );
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

WorkspaceEvidenceItem _foreignItem({
  required String id,
  required String incidentId,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Foreign $id',
    lastPreservedAt: DateTime(2026, 8, 13, 12),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
  );
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
  });

  group('Incident navigation identity', () {
    test('libraryIncidentAOpensIncidentA', () {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
      );
      WorkspaceSession.instance.controller = controller;

      expectIncident('inc-A', controller.currentIncident.id);
      expect(controller.currentIncident.title, 'Alpha Case');
      expect(controller.journeyEvidenceItems, isNotEmpty);
      for (final item in controller.journeyEvidenceItems) {
        expectIncident('inc-A', item.incidentId);
      }
    });

    testWidgets('workspaceIdentityRemainsStableAcrossModes', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      WorkspaceSession.instance.controller = controller;
      final incidentId = controller.currentIncident.id;

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: incidentId,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shell = tester.state<IncidentWorkspaceShellState>(
        find.byType(IncidentWorkspaceShell),
      );
      expectIncident(incidentId, shell.boundIncidentId);

      Future<void> tapStage(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(InvestigationJourneyHeader),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expectIncident(incidentId, controller.currentIncident.id);
        expectIncident(incidentId, shell.boundIncidentId);
      }

      await tapStage('Organize');
      await tapStage('Investigate');
      await tapStage('Trust Package');
      await tapStage('Capture');
    });

    testWidgets('inspectorCannotSwitchIncident', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 3,
      );
      WorkspaceSession.instance.controller = controller;
      final incidentId = controller.currentIncident.id;

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: incidentId,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail).first);
      await tester.tap(find.byType(JourneyEvidenceThumbnail).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Evidence Inspector'), findsOneWidget);
      expectIncident(incidentId, controller.currentIncident.id);

      final ordered = evidenceInspectorOrder(
        controller.journeyEvidenceItems,
        incidentId: incidentId,
      );
      expect(ordered.length, greaterThanOrEqualTo(2));

      tester
          .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
          .onSelected(1);
      await tester.pumpAndSettle();

      expectIncident(incidentId, controller.currentIncident.id);
      expect(find.text('Evidence Inspector'), findsOneWidget);
      final preview = tester.widget<EvidenceInspectorPreview>(
        find.byType(EvidenceInspectorPreview),
      );
      expectEvidence(ordered[1].id, preview.record.evidence.id);
      expectIncident(incidentId, preview.record.evidence.incidentId);
    });

    test('inspectorEvidenceBelongsToWorkspaceIncident', () {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 3,
      );
      final incidentId = controller.currentIncident.id;
      final foreign = _foreignItem(id: 'ev-foreign', incidentId: 'inc-B');
      final ordered = evidenceInspectorOrder(
        [...controller.journeyEvidenceItems, foreign],
        incidentId: incidentId,
      );

      expect(
        ordered.any((item) => item.id == 'ev-foreign'),
        isFalse,
      );
      for (final item in ordered) {
        if (!item.belongsToIncident(incidentId)) {
          fail(
            'EXPECTED INCIDENT:\n$incidentId\n\n'
            'ACTUAL INCIDENT:\n${item.incidentId}\n\n'
            'EXPECTED EVIDENCE:\n(owned by $incidentId)\n\n'
            'ACTUAL EVIDENCE:\n${item.id}',
          );
        }
      }
      expect(foreign.belongsToIncident(incidentId), isFalse);
    });

    testWidgets('carouselSwipePreservesIncidentId', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 3,
      );
      final incidentId = controller.currentIncident.id;
      final ordered = evidenceInspectorOrder(
        controller.journeyEvidenceItems,
        incidentId: incidentId,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      showInvestigationEvidenceInspectorModal(
                        context: context,
                        evidence: ordered.first,
                        controller: controller,
                        orderedEvidence: ordered,
                      );
                    },
                    child: const Text('Open Inspector'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open Inspector'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(
        find.byType(EvidenceSpatialCarousel),
        const Offset(-72, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 280));
      await tester.pumpAndSettle();

      expectIncident(incidentId, controller.currentIncident.id);
      expect(find.text('2 / 3'), findsOneWidget);
      final preview = tester.widget<EvidenceInspectorPreview>(
        find.byType(EvidenceInspectorPreview),
      );
      expectIncident(incidentId, preview.record.evidence.incidentId);
    });

    testWidgets('inspectorCloseReturnsToSameWorkspace', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      WorkspaceSession.instance.controller = controller;
      final incidentId = controller.currentIncident.id;

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: incidentId,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(JourneyEvidenceThumbnail).first);
      await tester.tap(find.byType(JourneyEvidenceThumbnail).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      expect(find.text('Evidence Inspector'), findsNothing);
      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expectIncident(incidentId, controller.currentIncident.id);
      expect(
        tester
            .state<IncidentWorkspaceShellState>(
              find.byType(IncidentWorkspaceShell),
            )
            .boundIncidentId,
        incidentId,
      );
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
    });

    testWidgets('workspaceBackReturnsToLibrary', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
      );
      final incidentId = controller.currentIncident.id;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => IncidentWorkspaceShell(
                            incidentId: incidentId,
                            controller: controller,
                          ),
                        ),
                      );
                    },
                    child: const Text('Library'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      expect(find.byType(IncidentWorkspaceShell), findsOneWidget);
      expectIncident(incidentId, controller.currentIncident.id);

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(IncidentWorkspaceShell), findsNothing);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Evidence Inspector'), findsNothing);
      expectIncident(incidentId, controller.currentIncident.id);
    });

    testWidgets('openingIncidentBDoesNotInheritIncidentAState', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final incidentA = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      final aEvidenceIds =
          incidentA.journeyEvidenceItems.map((item) => item.id).toSet();
      final aCount = incidentA.currentIncident.evidenceCount;

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: 'inc-A',
            controller: incidentA,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectIncident('inc-A', incidentA.currentIncident.id);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final incidentB = _controllerFor(
        id: 'inc-B',
        title: 'Bravo Case',
        photos: 1,
      );
      WorkspaceSession.instance.controller = incidentB;

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: 'inc-B',
            controller: incidentB,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectIncident('inc-B', incidentB.currentIncident.id);
      expect(incidentB.currentIncident.title, 'Bravo Case');
      expect(incidentB.currentIncident.title, isNot('Alpha Case'));
      expect(incidentB.currentIncident.evidenceCount, isNot(aCount));
      expect(
        incidentB.journeyEvidenceItems.map((item) => item.id).toSet(),
        isNot(aEvidenceIds),
      );
      for (final item in incidentB.journeyEvidenceItems) {
        expectIncident('inc-B', item.incidentId);
      }
      expect(find.text('Alpha Case'), findsNothing);
    });

    testWidgets('incidentTitleDoesNotLeakAcrossIncidents', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final incidentA = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: 'inc-A',
            controller: incidentA,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alpha Case'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final incidentB = _controllerFor(
        id: 'inc-B',
        title: 'Bravo Case',
        photos: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: 'inc-B',
            controller: incidentB,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectIncident('inc-B', incidentB.currentIncident.id);
      expect(find.text('Bravo Case'), findsWidgets);
      expect(find.text('Alpha Case'), findsNothing);
    });

    testWidgets('evidenceCountDoesNotLeakAcrossIncidents', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final incidentA = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 3,
      );
      final aCount = incidentA.currentIncident.evidenceCount;
      expect(aCount, 3);

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: 'inc-A',
            controller: incidentA,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(JourneyEvidenceThumbnail), findsNWidgets(3));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final incidentB = _controllerFor(
        id: 'inc-B',
        title: 'Bravo Case',
        photos: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            incidentId: 'inc-B',
            controller: incidentB,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectIncident('inc-B', incidentB.currentIncident.id);
      expect(incidentB.currentIncident.evidenceCount, 1);
      expect(incidentB.currentIncident.evidenceCount, isNot(aCount));
      expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);
    });
  });
}
