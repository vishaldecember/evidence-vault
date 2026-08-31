import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/widgets/workspace/organize_suggestion_card.dart';
import 'package:evidence_vault/widgets/workspace/organize_suggestion_rail.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceController _controllerWithMedia() {
  final controller = WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: 'inc-org', title: 'Organize case'),
  );
  controller.preserveEvidence(WorkspaceCaptureMode.photo);
  controller.preserveEvidence(WorkspaceCaptureMode.video);
  controller.preserveEvidence(WorkspaceCaptureMode.voice);
  controller.ensureEvidenceCollections();
  return controller;
}

Future<void> _pumpOrganize(
  WidgetTester tester,
  WorkspaceEvidenceController controller,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(412, 1200));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return OrganizeWorkspaceView(
              incident: controller.currentIncident,
              dismissedCollectionIds: controller.dismissedCollectionIds,
              onEvidenceSelected: (_) {},
              onAcceptSuggestion: controller.acceptEvidenceCollection,
              onDismissSuggestion: controller.dismissPendingEvidenceCollection,
              onRestoreSuggestion: controller.restorePendingEvidenceCollection,
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'pending engine collections appear as Groups, not a Suggestions section',
    (tester) async {
      final controller = _controllerWithMedia();
      final pending = controller.evidenceCollections
          .where((c) => c.pending)
          .toList();
      expect(pending, isNotEmpty);

      await _pumpOrganize(tester, controller);

      expect(find.byType(OrganizeWorkspaceView), findsOneWidget);
      expect(find.byKey(OrganizeWorkspaceView.suggestionsKey), findsNothing);
      expect(find.text('Suggestions'), findsNothing);
      expect(find.text('Suggested evidence group'), findsNothing);
      expect(find.text('Add to Group'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
      expect(find.byType(OrganizeSuggestionCard), findsNothing);
      expect(find.byKey(OrganizeWorkspaceView.headerKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(OrganizeWorkspaceView.structureKey));
      expect(find.byKey(OrganizeWorkspaceView.structureKey), findsOneWidget);
      expect(find.byType(OrganizeSuggestionRail), findsNothing);
      expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
      expect(find.text('Create Group'), findsNothing);
    },
  );

  testWidgets(
    'system-generated pending collections keep the same members in Groups',
    (tester) async {
      final controller = _controllerWithMedia();
      final suggestion = controller.evidenceCollections.firstWhere(
        (c) => c.pending,
      );
      final members = List<String>.from(suggestion.memberEvidenceIds);
      final groupsBefore = controller.currentIncident.relationshipGroups.length;

      await _pumpOrganize(tester, controller);

      final visible = controller.evidenceCollections.firstWhere(
        (c) => c.id == suggestion.id,
      );
      expect(visible.pending, isTrue);
      expect(visible.systemGenerated, isTrue);
      expect(visible.memberEvidenceIds, members);
      expect(
        controller.currentIncident.relationshipGroups,
        hasLength(groupsBefore),
      );
      expect(
        find.byKey(OrganizeSuggestionCard.cardKey(suggestion.id)),
        findsNothing,
      );
      expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
    },
  );

  testWidgets(
    'dismissed pending collections sit in the rail, not Groups',
    (tester) async {
      final controller = _controllerWithMedia();
      final suggestion = controller.evidenceCollections.firstWhere(
        (c) => c.pending,
      );
      final members = List<String>.from(suggestion.memberEvidenceIds);
      controller.dismissPendingEvidenceCollection(suggestion.id);

      await _pumpOrganize(tester, controller);

      expect(
        controller.evidenceCollections.any((c) => c.id == suggestion.id),
        isTrue,
      );
      expect(controller.dismissedCollectionIds, contains(suggestion.id));
      final dismissed = controller.evidenceCollections.firstWhere(
        (c) => c.id == suggestion.id,
      );
      expect(dismissed.pending, isTrue);
      expect(dismissed.memberEvidenceIds, members);
      expect(find.byType(OrganizeSuggestionRail), findsOneWidget);
      expect(
        find.byKey(OrganizeSuggestionRail.chipKey(suggestion.id)),
        findsOneWidget,
      );
      expect(find.byKey(Key('organize_group_${suggestion.id}')), findsNothing);
      expect(
        find.byKey(OrganizeSuggestionCard.cardKey(suggestion.id)),
        findsNothing,
      );
    },
  );

  testWidgets('rail chip restores a still-pending collection into Groups', (
    tester,
  ) async {
    final controller = _controllerWithMedia();
    final suggestion = controller.evidenceCollections.firstWhere(
      (c) => c.pending,
    );
    controller.dismissPendingEvidenceCollection(suggestion.id);

    await _pumpOrganize(tester, controller);
    await tester.tap(find.byKey(OrganizeSuggestionRail.chipKey(suggestion.id)));
    await tester.pumpAndSettle();

    final restored = controller.evidenceCollections.firstWhere(
      (c) => c.id == suggestion.id,
    );
    expect(restored.pending, isTrue);
    expect(restored.systemGenerated, isTrue);
    expect(controller.dismissedCollectionIds, isNot(contains(suggestion.id)));
    expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
    expect(
      find.byKey(OrganizeSuggestionCard.cardKey(suggestion.id)),
      findsNothing,
    );
    expect(find.text('Add to Group'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);
  });

  testWidgets('multiple dismissed collections stack as individual chips', (
    tester,
  ) async {
    final controller = _controllerWithMedia();
    final pending = controller.evidenceCollections
        .where((c) => c.pending)
        .toList();
    expect(pending.length, greaterThanOrEqualTo(2));

    for (final collection in pending) {
      controller.dismissPendingEvidenceCollection(collection.id);
    }

    await _pumpOrganize(tester, controller);

    expect(find.byType(OrganizeSuggestionRail), findsOneWidget);
    for (final collection in pending) {
      expect(
        find.byKey(OrganizeSuggestionRail.chipKey(collection.id)),
        findsOneWidget,
      );
      expect(
        controller.evidenceCollections.any((c) => c.id == collection.id),
        isTrue,
      );
      expect(find.byKey(Key('organize_group_${collection.id}')), findsNothing);
    }
    expect(find.byKey(OrganizeWorkspaceView.structureKey), findsOneWidget);
  });
}
