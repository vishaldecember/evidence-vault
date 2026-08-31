import 'package:evidence_vault/constants/app_spacing.dart';
import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/participant/evidence_person_relationship.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:evidence_vault/widgets/workspace/organize_group_composition.dart';
import 'package:evidence_vault/widgets/workspace/organize_groups_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(
      id: 'inc-v3r-nav',
      title: 'Street Fight',
    ),
  );
}

Future<void> _openPeopleLens(WidgetTester tester) async {
  await tester.tap(find.byKey(OrganizeWorkspaceView.groupsBrowseKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(
    find.byKey(
      OrganizeGroupsModal.lensKey(OrganizeGroupCategory.personParticipant),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'A Evidence Inspector overlays Groups and close returns to the same person',
    (tester) async {
      final controller = _controller();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      controller.addRelatedPersonToEvidence(
        evidenceId: photo,
        displayName: 'Jacob',
        relationship: EvidencePersonRelationship.witness,
      );

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    return OrganizeWorkspaceView(
                      incident: controller.currentIncident,
                      orderedCapturedEvidenceIds: controller.timelineRepository
                          .orderedCapturedEvidenceIds(),
                      onEvidenceSelected: (item) {
                        showInvestigationEvidenceInspectorModal(
                          context: context,
                          evidence: item,
                          controller: controller,
                          orderedEvidence: controller.currentIncident.evidence,
                        );
                      },
                      onCreateCustomGroup:
                          ({required name, evidenceIds = const []}) {
                            return controller.createCustomGroup(
                              name: name,
                              evidenceIds: evidenceIds,
                            );
                          },
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await _openPeopleLens(tester);
      expect(find.text('Jacob'), findsWidgets);
      expect(find.byKey(OrganizeGroupsModal.modalKey), findsOneWidget);

      await tester.tap(find.byKey(OrganizeGroupsModal.associatedKey(photo)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('evidence_inspector_close')), findsOneWidget);
      expect(find.byKey(OrganizeGroupsModal.modalKey), findsOneWidget);
      expect(find.text('Jacob'), findsWidgets);

      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('evidence_inspector_close')), findsNothing);
      expect(find.byKey(OrganizeGroupsModal.modalKey), findsOneWidget);
      expect(find.text('People / Participants'), findsOneWidget);
      expect(find.text('Jacob'), findsWidgets);
      expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);
    },
  );

  testWidgets('B group composition modal does not overflow on a small phone', (
    tester,
  ) async {
    final controller = _controller();
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    controller.preserveEvidence(WorkspaceCaptureMode.video);

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    final overflowErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('OVERFLOWED') || text.contains('overflowed')) {
        overflowErrors.add(details);
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: controller.currentIncident,
            orderedCapturedEvidenceIds: controller.timelineRepository
                .orderedCapturedEvidenceIds(),
            onEvidenceSelected: (_) {},
            onCreateCustomGroup: ({required name, evidenceIds = const []}) {
              return controller.createCustomGroup(
                name: name,
                evidenceIds: evidenceIds,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPlusKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(OrganizeGroupsModal.modalKey), findsOneWidget);
    await tester.tap(find.byKey(OrganizeGroupsModal.transferBarKey));
    await tester.pump();

    expect(find.byKey(OrganizeGroupCompositionModal.modalKey), findsOneWidget);
    expect(overflowErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'C associated evidence wraps horizontally instead of one item per row',
    (tester) async {
      final controller = _controller();
      final ids = <String>[];
      for (var i = 0; i < 6; i++) {
        ids.add(
          controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo),
        );
      }
      String? jacobId;
      for (final id in ids) {
        final person = controller.addRelatedPersonToEvidence(
          evidenceId: id,
          displayName: 'Jacob',
          relationship: EvidencePersonRelationship.witness,
          existingParticipantId: jacobId,
        );
        jacobId = person.id;
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeWorkspaceView(
              incident: controller.currentIncident,
              orderedCapturedEvidenceIds: controller.timelineRepository
                  .orderedCapturedEvidenceIds(),
              onEvidenceSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await _openPeopleLens(tester);

      final personFinder = find.byKey(OrganizeGroupsModal.personKey(jacobId!));
      expect(personFinder, findsOneWidget);

      final rects =
          [
            for (final id in ids)
              tester.getRect(
                find.descendant(
                  of: personFinder,
                  matching: find.byKey(OrganizeGroupsModal.associatedKey(id)),
                ),
              ),
          ]..sort((a, b) {
            final top = a.top.compareTo(b.top);
            return top != 0 ? top : a.left.compareTo(b.left);
          });

      final firstRow = [
        for (final rect in rects)
          if ((rect.top - rects.first.top).abs() < 8) rect,
      ];
      expect(firstRow.length, greaterThan(1));
      expect(firstRow.length, lessThan(ids.length));
      for (var i = 1; i < firstRow.length; i++) {
        expect(firstRow[i].left, greaterThan(firstRow[i - 1].right - 1));
      }
      expect(
        find.descendant(
          of: personFinder,
          matching: find.byWidgetPredicate(
            (widget) => widget is Wrap && widget.runSpacing == AppSpacing.xs,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: personFinder,
          matching: find.byType(JourneyEvidenceThumbnail),
        ),
        findsNWidgets(ids.length),
      );
    },
  );

  testWidgets(
    'D Suggestions section is gone; system groups remain in Groups cards',
    (tester) async {
      final controller = _controller();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.ensureEvidenceCollections();
      final pending = controller.evidenceCollections
          .where((collection) => collection.pending)
          .toList();
      expect(pending, isNotEmpty);

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeWorkspaceView(
              incident: controller.currentIncident,
              orderedCapturedEvidenceIds: controller.timelineRepository
                  .orderedCapturedEvidenceIds(),
              onEvidenceSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(OrganizeWorkspaceView.suggestionsKey), findsNothing);
      expect(find.text('Suggestions'), findsNothing);
      expect(find.text('Suggested evidence group'), findsNothing);
      expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
      expect(find.text('Create Group'), findsNothing);
    },
  );

  testWidgets('E incident title and information icon share one line', (
    tester,
  ) async {
    final controller = _controller();
    controller.preserveEvidence(WorkspaceCaptureMode.photo);

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: controller.currentIncident,
            orderedCapturedEvidenceIds: controller.timelineRepository
                .orderedCapturedEvidenceIds(),
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final title = tester.getRect(
      find.byKey(const Key('organize_incident_title')),
    );
    final info = tester.getRect(
      find.byKey(OrganizeReadinessInfoButton.buttonKey),
    );
    expect(info.left, greaterThanOrEqualTo(title.right - 0.5));
    expect((title.center.dy - info.center.dy).abs(), lessThan(16));
    expect(info.height, greaterThanOrEqualTo(36));
  });
}
