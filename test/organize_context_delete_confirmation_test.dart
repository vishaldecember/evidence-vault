import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<WorkspaceEvidenceController> _controller() async {
  WorkspaceEvidenceFactory.resetForTests();
  SharedPreferences.setMockInitialValues({});
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-v3r-ctx', title: 'Case'),
  );
}

Future<void> _pumpOrganize(
  WidgetTester tester,
  WorkspaceEvidenceController controller,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final created = controller.organizeCreatedEvidenceIds;
            return OrganizeWorkspaceView(
              incident: controller.currentIncident,
              organizeCreatedIds: created,
              contextAnchors: controller.organizeContextAnchors,
              orderedCapturedEvidenceIds:
                  controller.timelineRepository.orderedCapturedEvidenceIds(),
              onEvidenceSelected: (_) {},
              onSetContextAnchor: (contextId, capturedId) {
                controller.setOrganizeContextAnchor(
                  contextEvidenceId: contextId,
                  capturedEvidenceId: capturedId,
                );
              },
              onClearContextAnchor: controller.clearOrganizeContextAnchor,
              onDiscardUnsnappedContext:
                  controller.discardUnsnappedOrganizeContext,
              onAddOrganizeContext: controller.addOrganizeContextEvidence,
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WorkspaceEvidenceFactory.resetForTests();
  });

  tearDown(WorkspaceEvidenceFactory.useProductionIds);

  testWidgets('A tapping minus shows Delete the context confirmation',
      (tester) async {
    final controller = await _controller();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final note = controller.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
    await _pumpOrganize(tester, controller);

    await tester.tap(find.byKey(OrganizeChronologyCanvas.discardKey(note)));
    await tester.pump();

    expect(find.byKey(const Key('organize_context_delete_dialog')), findsOneWidget);
    expect(find.text('Delete the context?'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(note)), findsOneWidget);
    expect(controller.organizeCreatedEvidenceIds, contains(note));
  });

  testWidgets('B CANCEL keeps the floating context', (tester) async {
    final controller = await _controller();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final note = controller.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
    await _pumpOrganize(tester, controller);

    await tester.tap(find.byKey(OrganizeChronologyCanvas.discardKey(note)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('organize_context_delete_cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('organize_context_delete_dialog')), findsNothing);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(note)), findsOneWidget);
    expect(controller.organizeCreatedEvidenceIds, contains(note));
    expect(
      [for (final item in controller.currentIncident.evidence) item.id],
      contains(note),
    );
  });

  testWidgets('C OK deletes the floating context', (tester) async {
    final controller = await _controller();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final keep = controller.addOrganizeContextEvidence(WorkspaceCaptureMode.voice);
    final note = controller.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
    await _pumpOrganize(tester, controller);

    await tester.tap(find.byKey(OrganizeChronologyCanvas.discardKey(note)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('organize_context_delete_ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(note)), findsNothing);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(keep)), findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo)), findsOneWidget);
    expect(controller.organizeCreatedEvidenceIds, isNot(contains(note)));
    expect(controller.organizeCreatedEvidenceIds, contains(keep));
  });

  testWidgets('D deleted context does not return after rebuild', (tester) async {
    final controller = await _controller();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final note = controller.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
    await _pumpOrganize(tester, controller);

    await tester.tap(find.byKey(OrganizeChronologyCanvas.discardKey(note)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('organize_context_delete_ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    final restored = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.fromStore(
        IncidentStore(
          incident: controller.aggregate.store.incident,
          capturedEvidence: List.of(controller.aggregate.store.capturedEvidence),
          supportingEvidence:
              List.of(controller.aggregate.store.supportingEvidence),
          timelineAnchors: List.of(controller.aggregate.store.timelineAnchors),
          relationships: List.of(controller.aggregate.store.relationships),
          relationshipGroups:
              List.of(controller.aggregate.store.relationshipGroups),
        ),
      ),
    );
    await restored.restoreOrganizeContextPersistence();
    await _pumpOrganize(tester, restored);

    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(note)), findsNothing);
    expect(restored.organizeCreatedEvidenceIds, isNot(contains(note)));
  });
}
