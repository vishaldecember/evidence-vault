import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WorkspaceSession.instance.reset());

  group('Shared evidence collection sync', () {
    testWidgets(
      'multiple captures appear on Organize without reopen',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final controller = WorkspaceEvidenceController();
        WorkspaceSession.instance.controller = controller;

        await tester.pumpWidget(
          MaterialApp(
            home: IncidentWorkspaceShell(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        for (final mode in WorkspaceCaptureMode.values) {
          controller.preserveEvidence(mode);
        }
        await tester.pumpAndSettle();

        expect(controller.currentIncident.evidence, hasLength(5));
        expect(controller.currentIncident.journeyEvidence, hasLength(5));
        expect(
          identical(
            controller.journeyEvidenceItems,
            controller.currentIncident.journeyEvidence,
          ),
          isTrue,
        );

        // Switch to Organize — must show the full shared collection immediately.
        await tester.tap(find.text('Organize'));
        await tester.pumpAndSettle();

        expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
        expect(find.byKey(OrganizeWorkspaceView.structureKey), findsOneWidget);
        expect(find.text('Evidence structure'), findsNothing);
        for (final item in controller.currentIncident.journeyEvidence) {
          expect(
            find.byKey(
              OrganizeWorkspaceView.rowKey(item.id),
              skipOffstage: false,
            ),
            findsOneWidget,
          );
        }
        expect(controller.currentIncident.journeyEvidence, hasLength(5));

        // Investigation counts from CurrentIncident.
        await tester.tap(find.text('Investigate'));
        await tester.pumpAndSettle();
        expect(
          controller.currentIncident.timelineAnchorCount,
          3,
        ); // photo/video/voice anchors
        expect(controller.currentIncident.evidenceCount, 5);

        // Trust Package sees the same collection.
        await tester.tap(find.text('Trust Package'));
        await tester.pumpAndSettle();
        expect(controller.currentIncident.evidence, hasLength(5));
      },
    );

    test('preserveEvidence grows CurrentIncident.evidence for every mode', () {
      final controller = WorkspaceEvidenceController();

      for (final mode in WorkspaceCaptureMode.values) {
        controller.preserveEvidence(mode);
      }

      expect(controller.currentIncident.evidence, hasLength(5));
      expect(controller.currentIncident.journeyEvidence, hasLength(5));
      expect(
        controller.currentIncident.journeyEvidence.map((e) => e.id).toSet(),
        controller.currentIncident.evidence.map((e) => e.id).toSet(),
      );
    });
  });
}
