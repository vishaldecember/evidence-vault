import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/participant/evidence_person_relationship.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/inspector_context_section.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
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

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required WorkspaceEvidenceItem evidence,
  List<WorkspaceEvidenceItem>? ordered,
}) async {
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
                    evidence: evidence,
                    controller: controller,
                    orderedEvidence: ordered ??
                        evidenceInspectorOrder(controller.journeyEvidenceItems),
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
  await tester.pumpAndSettle();
}

Future<void> _commitRelatedPerson(
  WidgetTester tester, {
  required String name,
  String relationshipKey = 'related_person_relationship_witness',
}) async {
  await tester.ensureVisible(find.text('Add Person'));
  await tester.tap(find.text('Add Person').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('related_person_name_field')),
    name,
  );
  await tester.pump();
  await tester.tap(find.byKey(Key(relationshipKey)));
  await tester.pumpAndSettle();
}

void main() {
  group('A audio preview', () {
    testWidgets('play button has safe layout inside the preview frame',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.voice);
      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      final frame = tester.getRect(
        find.byKey(const Key('evidence_inspector_preview_frame')),
      );
      final play = tester.getRect(
        find.byKey(const Key('evidence_inspector_audio_play')),
      );
      final slider = tester.getRect(find.byType(Slider));

      expect(play.left - frame.left, greaterThanOrEqualTo(16));
      expect(play.left - frame.left, lessThanOrEqualTo(28));
      expect(play.top, greaterThan(frame.top));
      expect(play.bottom, lessThan(frame.bottom));
      expect(slider.left, greaterThanOrEqualTo(play.right));
      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
    });
  });

  group('B preview frame', () {
    testWidgets('restrained frame wraps the preview container, not a larger parent',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      final frameFinder =
          find.byKey(const Key('evidence_inspector_preview_frame'));
      final previewFinder = find.byType(EvidenceInspectorPreview);
      final frameRect = tester.getRect(frameFinder);
      final previewRect = tester.getRect(previewFinder);
      expect(frameRect, previewRect);

      final frame = tester.widget<DecoratedBox>(frameFinder);
      final decoration = frame.decoration as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, AppColors.navy.withValues(alpha: 0.18));
      expect(decoration.color, EvidenceInspectorPreview.mediaGutter);
      expect(previewRect.height, greaterThanOrEqualTo(196));
    });
  });

  group('C description', () {
    test('description stamp includes seconds and today-at phrasing', () {
      final now = DateTime(2026, 8, 13, 13, 21, 5);
      expect(
        WorkspaceEvidenceFormatters.descriptionStamp(
          now,
          updated: false,
          now: now,
        ),
        'Added today at 13:21:05',
      );
      expect(
        WorkspaceEvidenceFormatters.descriptionStamp(
          now,
          updated: true,
          now: now,
        ),
        'Updated today at 13:21:05',
      );
    });

    testWidgets(
        'description and stamp persist without changing capture timestamp',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      final evidence = controller.journeyEvidenceItems.first;
      final captureAt = evidence.lastPreservedAt;
      final evidenceId = evidence.id;
      final incidentId = controller.currentIncident.id;

      await _openInspector(
        tester,
        controller: controller,
        evidence: evidence,
      );

      await _revealObservationEditor(tester);
      await tester.tap(_inspectorContextField);
      await tester.pump();
      await tester.enterText(_inspectorContextField, 'Person approached the door.');
      await tester.pump();
      await tester.pump(InvestigationEvidenceInspectorModal.persistDebounce);
      await tester.pump();

      expect(find.text('Person approached the door.'), findsWidgets);
      expect(
        find.byKey(const Key('evidence_inspector_description_stamp')),
        findsOneWidget,
      );
      expect(find.textContaining('Added today at'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d{2}:\d{2}:\d{2}')), findsWidgets);
      expect(find.text('Save'), findsNothing);

      final note = controller.evidenceRepository.supportingEvidence.single;
      expect(note.notePreview, 'Person approached the door.');
      expect(note.createdAt, isNotNull);
      expect(
        controller.evidenceRepository.capturedById(evidenceId)!.capturedAt,
        captureAt,
      );
      expect(controller.currentIncident.id, incidentId);

      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Inspector'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Person approached the door.'), findsWidgets);
      expect(find.textContaining('Added today at'), findsOneWidget);
      expect(
        controller.journeyEvidenceItems
            .firstWhere((item) => item.id == evidenceId)
            .lastPreservedAt,
        captureAt,
      );
    });
  });

  group('D related person', () {
    testWidgets('Add Person persists name and relationship without Save',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      final ordered = evidenceInspectorOrder(controller.journeyEvidenceItems);
      final first = ordered.first;
      final second = ordered[1];
      final incidentId = controller.currentIncident.id;

      await _openInspector(
        tester,
        controller: controller,
        evidence: first,
        ordered: ordered,
      );

      expect(find.text('Add Person'), findsOneWidget);
      await _commitRelatedPerson(
        tester,
        name: 'Jane Smith',
        relationshipKey: 'related_person_relationship_friend',
      );

      expect(find.text('Save'), findsNothing);
      expect(find.text('Jane Smith'), findsWidgets);
      expect(find.text('Friend'), findsOneWidget);
      expect(
        find.byKey(const Key('evidence_inspector_related_person_card')),
        findsOneWidget,
      );

      final linked =
          controller.state.items.singleWhere((item) => item.id == first.id);
      expect(linked.relatedPersonName, 'Jane Smith');
      expect(linked.relatedPersonRole, EvidencePersonRelationship.friend.name);
      expect(linked.id, first.id);
      expect(controller.currentIncident.id, incidentId);

      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Inspector'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Jane Smith'), findsWidgets);
      expect(find.text('Friend'), findsOneWidget);

      tester
          .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
          .onSelected(1);
      await tester.pumpAndSettle();

      expect(find.text('Jane Smith'), findsNothing);
      expect(find.text('Friend'), findsNothing);
      expect(find.text('Add Person'), findsOneWidget);
      expect(
        controller.state.items
            .singleWhere((item) => item.id == second.id)
            .relatedPersonName,
        isNull,
      );
      expect(controller.currentIncident.id, incidentId);
      expect(second.id, isNot(first.id));
    });
  });

  group('E save removal', () {
    testWidgets('Inspector has no Save button and Close flushes description',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Save'), findsNothing);
      expect(find.byKey(const Key('evidence_inspector_close')), findsOneWidget);

      await _revealObservationEditor(tester);
      await tester.enterText(_inspectorContextField, 'Flushed on close.');
      await tester.pump();
      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      expect(find.text('Evidence Inspector'), findsNothing);
      expect(
        controller.evidenceRepository.supportingEvidence.single.notePreview,
        'Flushed on close.',
      );
    });
  });

  group('F carousel', () {
    testWidgets('n / total stays correct while browsing the same incident',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.voice);
      final ordered = evidenceInspectorOrder(controller.journeyEvidenceItems);
      final incidentId = controller.currentIncident.id;

      await _openInspector(
        tester,
        controller: controller,
        evidence: ordered.first,
        ordered: ordered,
      );

      expect(find.text('1 / 3'), findsOneWidget);
      tester
          .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
          .onSelected(2);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(controller.currentIncident.id, incidentId);
      expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
    });
  });
}
