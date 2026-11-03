import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_composition.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/persistence/vault_wipe_pending.dart';
import 'package:evidence_vault/widgets/common/status_badge.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
  });

  tearDown(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
  });

  group('IncidentComposition', () {
    test('Incident A — 1 photo + 2 organise contexts', () {
      final controller = WorkspaceSession.instance.controller;
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      controller.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
      controller.addOrganizeContextEvidence(WorkspaceCaptureMode.voice);

      final composition = IncidentComposition.fromStore(
        controller.aggregate.store,
      );
      expect(composition.evidenceCount, 1);
      expect(composition.contextEnrichedCount, 2);
      expect(controller.currentIncident.evidenceCount, 3);
    });

    test('Incident B — 2 evidence, 0 contexts', () {
      final controller = WorkspaceSession.instance.controller;
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      controller.preserveForWidgetTest(WorkspaceCaptureMode.video);

      final composition = IncidentComposition.fromStore(
        controller.aggregate.store,
      );
      expect(composition.evidenceCount, 2);
      expect(composition.contextEnrichedCount, 0);
    });

    test('Incident C — 0 evidence, 2 contexts', () {
      final controller = WorkspaceSession.instance.controller;
      controller.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
      controller.addOrganizeContextEvidence(WorkspaceCaptureMode.file);

      final composition = IncidentComposition.fromStore(
        controller.aggregate.store,
      );
      expect(composition.evidenceCount, 0);
      expect(composition.contextEnrichedCount, 2);
    });

    test('Organise attach does not increase evidence count', () {
      final controller = WorkspaceSession.instance.controller;
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      var composition = IncidentComposition.fromStore(
        controller.aggregate.store,
      );
      expect(composition.evidenceCount, 1);

      controller.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
      composition = IncidentComposition.fromStore(controller.aggregate.store);
      expect(composition.evidenceCount, 1);
      expect(composition.contextEnrichedCount, 1);

      final card = IncidentLibraryService.instance.summaries.single;
      expect(card.evidenceCount, 1);
      expect(card.contextEnrichedCount, 1);
    });
  });

  group('Library of Truth composition', () {
    testWidgets('status follows composition, not merely incident existence', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryIncidentSummaryTile(
              incident: LibraryIncidentSummary(
                id: 'inc-rich',
                title: 'Named incident',
                evidenceCount: 1,
                contextEnrichedCount: 2,
                integrityVerified: false,
                lastPreserved: 'Just now',
                isInProgress: true,
                journeyStage: JourneyStage.rich,
              ),
            ),
          ),
        ),
      );

      expect(find.text('READY'), findsOneWidget);
      expect(find.text('BUILDING'), findsNothing);
    });

    test('empty + evidence maps to BUILDING via adapter', () {
      expect(
        IncidentStatus.resolve(journeyStage: JourneyStage.building).label,
        'BUILDING',
      );
      expect(
        IncidentStatus.resolve(journeyStage: JourneyStage.rich).label,
        'READY',
      );
    });
  });

  test('Add Title sets session title-edit request', () {
    expect(WorkspaceSession.instance.requestTitleEdit, isFalse);
    WorkspaceSession.instance.requestTitleEdit = true;
    expect(WorkspaceSession.instance.consumeTitleEditRequest(), isTrue);
    expect(WorkspaceSession.instance.requestTitleEdit, isFalse);
    expect(WorkspaceSession.instance.consumeTitleEditRequest(), isFalse);
  });

  test('pending vault wipe ids are stored per user', () async {
    await VaultWipePending.mark(
      userId: 'user-a',
      incidentIds: const ['inc-1', 'inc-2'],
    );
    expect(
      await VaultWipePending.incidentIdsFor('user-a'),
      {'inc-1', 'inc-2'},
    );
    expect(await VaultWipePending.incidentIdsFor('user-b'), isEmpty);
    await VaultWipePending.removeIds(const ['inc-1']);
    expect(await VaultWipePending.incidentIdsFor('user-a'), {'inc-2'});
    await VaultWipePending.clear();
    expect(await VaultWipePending.incidentIdsFor('user-a'), isEmpty);
  });
}
