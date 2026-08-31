import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/participant/evidence_person_relationship.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/common/app_back_button.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/inspector_context_section.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder get _inspectorContextField => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == InspectorContextSection.placeholder,
    );

Future<void> _revealObservationEditor(WidgetTester tester) async {
  if (_inspectorContextField.evaluate().isEmpty) {
    await tester.ensureVisible(
      find.byKey(const Key('evidence_inspector_add_observation')),
    );
    await tester.tap(find.byKey(const Key('evidence_inspector_add_observation')));
    await tester.pump();
  }
}

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail(
      'EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual',
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

Future<void> _pumpShell(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  InvestigationMethodologyStage? initialStage,
  bool pushedFromLibrary = false,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(412, 915));
  WorkspaceSession.instance.controller = controller;

  final shell = IncidentWorkspaceShell(
    incidentId: controller.currentIncident.id,
    controller: controller,
    initialStage: initialStage,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: pushedFromLibrary
          ? Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(builder: (_) => shell),
                        );
                      },
                      child: const Text('Library'),
                    ),
                  ),
                );
              },
            )
          : shell,
    ),
  );
  if (pushedFromLibrary) {
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> _tapStage(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(InvestigationJourneyHeader),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => WorkspaceSession.instance.reset());

  group('Organize workspace mode', () {
    testWidgets('1 organize opens for the bound incidentId', (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Street Fight',
        photos: 2,
      );
      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.evidence,
      );

      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expectIncident('inc-A', controller.currentIncident.id);
      expect(
        tester
            .state<IncidentWorkspaceShellState>(
              find.byType(IncidentWorkspaceShell),
            )
            .boundIncidentId,
        'inc-A',
      );
      expect(find.byKey(const Key('organize_incident_title')), findsOneWidget);
      expect(find.text('Street Fight'), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
    });

    testWidgets('2–4, 17 Capture → Organize → Investigate → Trust preserve identity',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Street Fight',
        photos: 3,
      );
      final incidentId = controller.currentIncident.id;
      await _pumpShell(tester, controller: controller);

      Future<void> assertSameIncident() async {
        expectIncident(incidentId, controller.currentIncident.id);
        expect(
          tester
              .state<IncidentWorkspaceShellState>(
                find.byType(IncidentWorkspaceShell),
              )
              .boundIncidentId,
          incidentId,
        );
      }

      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      await _tapStage(tester, 'Organize');
      await assertSameIncident();
      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );

      await _tapStage(tester, 'Investigate');
      await assertSameIncident();
      expect(find.text('Understand chronology and relationships'), findsOneWidget);

      await _tapStage(tester, 'Trust Package');
      await assertSameIncident();
      expect(find.text('Trust Package Preview'), findsOneWidget);

      await _tapStage(tester, 'Capture');
      await assertSameIncident();
      expect(find.text('Capture what happened clearly'), findsOneWidget);
    });

    testWidgets('5–8 evidence count, ids, timestamps, and order stay stable',
        (tester) async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Street Fight',
          items: [
            WorkspaceEvidenceItem(
              id: 'ev-photo',
              kind: WorkspaceEvidenceKind.image,
              title: 'Photo',
              lastPreservedAt: DateTime.utc(2026, 8, 13, 14, 7, 31),
              integrityVerified: true,
              verification: VerificationFactory.initial(),
              incidentId: 'incident-1',
            ),
            WorkspaceEvidenceItem(
              id: 'ev-video',
              kind: WorkspaceEvidenceKind.video,
              title: 'Video',
              lastPreservedAt: DateTime.utc(2026, 8, 13, 14, 8, 4),
              integrityVerified: true,
              verification: VerificationFactory.initial(),
              incidentId: 'incident-1',
            ),
            WorkspaceEvidenceItem(
              id: 'ev-note',
              kind: WorkspaceEvidenceKind.note,
              title: 'Note',
              lastPreservedAt: DateTime.utc(2026, 8, 13, 14, 8, 15),
              integrityVerified: true,
              verification: VerificationFactory.initial(),
              notePreview: 'Witness described the approach.',
              incidentId: 'incident-1',
            ),
          ],
        ),
      );
      final incidentId = controller.currentIncident.id;
      final beforeCount = controller.currentIncident.evidenceCount;
      final beforeIds =
          controller.journeyEvidenceItems.map((item) => item.id).toList();
      final beforeTimes = {
        for (final item in controller.journeyEvidenceItems)
          item.id: item.lastPreservedAt,
      };
      final chronological = evidenceInspectorOrder(
        controller.journeyEvidenceItems,
        incidentId: incidentId,
      );

      await _pumpShell(tester, controller: controller);
      await _tapStage(tester, 'Organize');

      void assertUnchanged() {
        expectIncident(incidentId, controller.currentIncident.id);
        expect(controller.currentIncident.evidenceCount, beforeCount);
        expect(
          controller.journeyEvidenceItems.map((item) => item.id).toList(),
          beforeIds,
        );
        for (final item in controller.journeyEvidenceItems) {
          expect(item.lastPreservedAt, beforeTimes[item.id]);
        }
        expect(
          evidenceInspectorOrder(
            controller.journeyEvidenceItems,
            incidentId: incidentId,
          ).map((item) => item.id),
          chronological.map((item) => item.id),
        );
      }

      assertUnchanged();
      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(
        find.byKey(OrganizeWorkspaceView.rowKey(chronological[0].id)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeWorkspaceView.rowKey(chronological[1].id)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeWorkspaceView.rowKey(chronological[2].id)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('ev-note')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('ev-note')),
        findsNothing,
      );
      expect(
        find.byKey(Key('organize_evidence_clock_${chronological.first.id}')),
        findsOneWidget,
      );
      expect(
        find.text(
          WorkspaceEvidenceFormatters.evidenceClock(
            chronological.first.lastPreservedAt,
          ),
        ),
        findsWidgets,
      );

      await _tapStage(tester, 'Investigate');
      assertUnchanged();
      await _tapStage(tester, 'Trust Package');
      assertUnchanged();
      await _tapStage(tester, 'Capture');
      assertUnchanged();
      await _tapStage(tester, 'Organize');
      assertUnchanged();
    });

    testWidgets('9–12 tap opens Inspector, swipe stays scoped, close returns to Organize',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Street Fight',
        photos: 6,
      );
      final incidentId = controller.currentIncident.id;
      final ordered = evidenceInspectorOrder(
        controller.journeyEvidenceItems,
        incidentId: incidentId,
      );
      expect(ordered, hasLength(6));

      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.evidence,
      );

      final first = ordered.first;
      await tester.ensureVisible(find.byKey(OrganizeWorkspaceView.rowKey(first.id)));
      await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey(first.id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Evidence Inspector'), findsOneWidget);
      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      var preview = tester.widget<EvidenceInspectorPreview>(
        find.byType(EvidenceInspectorPreview),
      );
      expect(preview.record.evidence.id, first.id);
      expect(find.text('1 / 6'), findsOneWidget);

      tester
          .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
          .onSelected(1);
      await tester.pumpAndSettle();
      expect(find.text('2 / 6'), findsOneWidget);
      preview = tester.widget<EvidenceInspectorPreview>(
        find.byType(EvidenceInspectorPreview),
      );
      expect(preview.record.evidence.id, ordered[1].id);
      expectIncident(incidentId, preview.record.evidence.incidentId);

      tester
          .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
          .onSelected(2);
      await tester.pumpAndSettle();
      expect(find.text('3 / 6'), findsOneWidget);
      preview = tester.widget<EvidenceInspectorPreview>(
        find.byType(EvidenceInspectorPreview),
      );
      expectIncident(incidentId, preview.record.evidence.incidentId);
      expect(
        ordered.map((item) => item.incidentId).toSet(),
        {incidentId},
      );

      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      expect(find.text('Evidence Inspector'), findsNothing);
      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
      expectIncident(incidentId, controller.currentIncident.id);
    });

    testWidgets('13 description edited in Inspector is visible on Organize return',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Street Fight',
        photos: 1,
      );
      final evidence = controller.journeyEvidenceItems.first;
      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.evidence,
      );

      await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey(evidence.id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _revealObservationEditor(tester);
      await tester.enterText(
        _inspectorContextField,
        'Person approached the door.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(find.text('Person approached the door.'), findsWidgets);
      expect(
        WorkspaceSession.instance.activeMethodologyStage,
        InvestigationMethodologyStage.evidence,
      );
    });

    testWidgets('14 related person remains visible after returning to Organize',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Street Fight',
        photos: 1,
      );
      final evidence = controller.journeyEvidenceItems.first;
      controller.assignRelatedPersonToEvidence(
        evidenceId: evidence.id,
        displayName: 'John Doe',
        relationship: EvidencePersonRelationship.witness,
      );

      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.evidence,
      );

      expect(find.text('John Doe · Witness'), findsOneWidget);

      await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey(evidence.id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('John Doe'), findsWidgets);

      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(find.text('John Doe · Witness'), findsOneWidget);
      expect(
        controller.currentIncident.evidenceById(evidence.id)?.relatedPersonName,
        'John Doe',
      );
    });

    testWidgets('15 opening incident B does not inherit Organize state from A',
        (tester) async {
      final incidentA = _controllerFor(
        id: 'inc-A',
        title: 'Street Fight',
        photos: 2,
      );
      incidentA.assignRelatedPersonToEvidence(
        evidenceId: incidentA.journeyEvidenceItems.first.id,
        displayName: 'John Doe',
        relationship: EvidencePersonRelationship.witness,
      );
      await _pumpShell(
        tester,
        controller: incidentA,
        initialStage: InvestigationMethodologyStage.evidence,
      );
      expect(find.text('Street Fight'), findsOneWidget);
      expect(find.text('John Doe · Witness'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final incidentB = _controllerFor(
        id: 'inc-B',
        title: 'Workplace Incident',
        photos: 1,
      );
      await _pumpShell(
        tester,
        controller: incidentB,
        initialStage: InvestigationMethodologyStage.evidence,
      );

      expectIncident('inc-B', incidentB.currentIncident.id);
      expect(find.text('Workplace Incident'), findsOneWidget);
      expect(find.text('Street Fight'), findsNothing);
      expect(find.text('John Doe · Witness'), findsNothing);
      expect(incidentB.currentIncident.evidenceCount, 1);
      expect(incidentA.currentIncident.evidenceCount, 2);
      for (final item in incidentB.journeyEvidenceItems) {
        expectIncident('inc-B', item.incidentId);
      }
    });

    testWidgets('16 back from Organize returns to Library', (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Street Fight',
        photos: 1,
      );
      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.evidence,
        pushedFromLibrary: true,
      );

      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(find.byType(AppBackButton), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(IncidentWorkspaceShell), findsNothing);
      expect(find.text('Library'), findsOneWidget);
      expectIncident('inc-A', controller.currentIncident.id);
    });

    testWidgets('17 switching into Organize does not create an incident',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Street Fight',
        photos: 2,
      );
      final incidentId = controller.currentIncident.id;
      await _pumpShell(tester, controller: controller);

      await _tapStage(tester, 'Organize');

      expectIncident(incidentId, controller.currentIncident.id);
      expect(controller.currentIncident.title, 'Street Fight');
      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(
        identical(
          WorkspaceSession.instance.controller,
          controller,
        ),
        isTrue,
      );
    });

    testWidgets('Add context toolbar is Voice | Note | File only',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-toolbar',
        title: 'Street Fight',
        photos: 1,
      );
      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.evidence,
      );

      final bar = find.byKey(OrganizeWorkspaceView.addContextBarKey);
      expect(bar, findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('Voice')),
          findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('Note')),
          findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('File')),
          findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('Photo')),
          findsNothing);
      expect(find.descendant(of: bar, matching: find.text('Video')),
          findsNothing);

      await tester.tap(find.descendant(of: bar, matching: find.text('Note')));
      await tester.pump();

      expect(controller.organizeCreatedEvidenceIds, hasLength(1));
      final created = controller.organizeCreatedEvidenceIds.single;
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(created)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(created)),
        findsNothing,
      );
    });

    testWidgets('Organize File toolbar creates floating Added context',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-org-file',
        title: 'Dogs Chasing',
        photos: 1,
      );
      await _pumpShell(
        tester,
        controller: controller,
        initialStage: InvestigationMethodologyStage.evidence,
      );

      final bar = find.byKey(OrganizeWorkspaceView.addContextBarKey);
      await tester.tap(find.descendant(of: bar, matching: find.text('File')));
      await tester.pump();

      expect(controller.organizeCreatedEvidenceIds, hasLength(1));
      final created = controller.organizeCreatedEvidenceIds.single;
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(created)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(created)),
        findsNothing,
      );
    });
  });
}
