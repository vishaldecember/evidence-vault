import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/organize/organize_chronology_eligibility.dart';
import 'package:evidence_vault/domain/organize/organize_spine_classification.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/services/persistence/organize_context_persistence.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Evidence survived restart; Organize origin/snaps did not — until restore.
IncidentStore _evidenceOnlySnapshot(IncidentStore source) {
  return IncidentStore(
    incident: source.incident,
    capturedEvidence: List.of(source.capturedEvidence),
    supportingEvidence: List.of(source.supportingEvidence),
    timelineAnchors: List.of(source.timelineAnchors),
    relationships: List.of(source.relationships),
    relationshipGroups: List.of(source.relationshipGroups),
  );
}

Future<WorkspaceEvidenceController> _restart(
  WorkspaceEvidenceController live,
) async {
  await live.persistOrganizeContextPersistence();
  final snapshot = _evidenceOnlySnapshot(live.aggregate.store);
  expect(snapshot.organizeCreatedEvidenceIds, isEmpty);
  expect(snapshot.organizeContextAnchors, isEmpty);
  final restored = WorkspaceEvidenceController(
    aggregate: IncidentAggregate.fromStore(snapshot),
  );
  await restored.restoreOrganizeContextPersistence();
  return restored;
}

Future<void> _pumpRestoredOrganize(
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
              orderedCapturedEvidenceIds: [
                for (final item in controller.currentIncident.journeyEvidence)
                  if (OrganizeSpineClassification.isChronologicalSpine(
                    item: item,
                    organizeCreatedIds: created,
                  ))
                    item.id,
              ],
              onEvidenceSelected: (_) {},
              onSetContextAnchor: (contextId, capturedId) {
                controller.setOrganizeContextAnchor(
                  contextEvidenceId: contextId,
                  capturedEvidenceId: capturedId,
                );
              },
              onClearContextAnchor: controller.clearOrganizeContextAnchor,
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'unsnapped context survives restart as free-floating with no evidence link',
    (tester) async {
      final live = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(
          id: 'inc-org-persist-unsnapped',
          title: 'Case',
        ),
      );
      final photo = live.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      final note = live.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
      expect(live.organizeCreatedEvidenceIds, contains(note));
      expect(live.organizeContextAnchors, isEmpty);

      final restored = await _restart(live);

      expect(restored.organizeCreatedEvidenceIds, contains(note));
      expect(restored.organizeCreatedEvidenceIds, isNot(contains(photo)));
      expect(restored.organizeContextAnchors, isEmpty);

      final noteBefore = live.currentIncident.evidence
          .firstWhere((item) => item.id == note);
      final noteItem = restored.currentIncident.evidence
          .firstWhere((item) => item.id == note);
      expect(noteItem.recordedAt, noteBefore.recordedAt);
      expect(noteItem.lastPreservedAt, noteBefore.lastPreservedAt);
      expect(
        OrganizeSpineClassification.isContextSpine(
          item: noteItem,
          organizeCreatedIds: restored.organizeCreatedEvidenceIds,
        ),
        isTrue,
      );
      expect(
        OrganizeSpineClassification.isChronologicalSpine(
          item: noteItem,
          organizeCreatedIds: restored.organizeCreatedEvidenceIds,
        ),
        isFalse,
      );
      expect(
        OrganizeChronologyEligibilityPolicy.isChronologyEligible(
          item: noteItem,
          orderedCapturedEvidenceIds:
              restored.timelineRepository.orderedCapturedEvidenceIds(),
          organizeCreatedIds: restored.organizeCreatedEvidenceIds,
        ),
        isFalse,
      );
      expect(
        restored.timelineRepository.orderedCapturedEvidenceIds(),
        isNot(contains(note)),
      );
      expect(noteItem.parentEvidenceId, isNull);
      expect(noteItem.relatedEvidenceIds.contains(photo), isFalse);

      await _pumpRestoredOrganize(tester, restored);

      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(note)),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.discardKey(note)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextArrowKey(note)),
        findsNothing,
      );

      final contextRect = tester.getRect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
      );
      final photoRect = tester.getRect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo)),
      );
      final alignedX =
          (contextRect.left - (photoRect.right + 48)).abs() < 16;
      final alignedY =
          (contextRect.center.dy - photoRect.center.dy).abs() < 28;
      expect(
        alignedX && alignedY,
        isFalse,
        reason: 'unsnapped restore must not sit in the snapped spine slot',
      );

      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
        ),
      );
      await tester.pump(
        OrganizeChronologyCanvas.dragStartDelay +
            const Duration(milliseconds: 80),
      );
      expect(find.byKey(OrganizeChronologyCanvas.dragAuraKey), findsOneWidget);
      await gesture.moveBy(const Offset(-36, 48));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(restored.organizeContextAnchors, isEmpty);
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(note)),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.discardKey(note)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'explicitly snapped context restores its evidence link after restart',
    (tester) async {
      final live = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(
          id: 'inc-org-persist-snapped',
          title: 'Case',
        ),
      );
      final photo = live.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      final note = live.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
      final anchor = live.setOrganizeContextAnchor(
        contextEvidenceId: note,
        capturedEvidenceId: photo,
      );
      expect(anchor, isNotNull);
      expect(
        OrganizeChronologyEligibilityPolicy.isChronologyEligible(
          item: live.currentIncident.evidence.firstWhere((e) => e.id == note),
          orderedCapturedEvidenceIds:
              live.timelineRepository.orderedCapturedEvidenceIds(),
          organizeCreatedIds: live.organizeCreatedEvidenceIds,
        ),
        isFalse,
      );

      final timestampBefore = live.currentIncident.evidence
          .firstWhere((item) => item.id == note)
          .recordedAt;
      final restored = await _restart(live);

      expect(restored.organizeCreatedEvidenceIds, contains(note));
      expect(restored.organizeContextAnchors, hasLength(1));
      expect(restored.organizeContextAnchors.single.contextEvidenceId, note);
      expect(restored.organizeContextAnchors.single.capturedEvidenceId, photo);

      final noteItem = restored.currentIncident.evidence
          .firstWhere((item) => item.id == note);
      expect(noteItem.recordedAt, timestampBefore);
      expect(noteItem.parentEvidenceId, isNull);
      expect(noteItem.relatedEvidenceIds.contains(photo), isFalse);
      expect(
        OrganizeSpineClassification.isChronologicalSpine(
          item: noteItem,
          organizeCreatedIds: restored.organizeCreatedEvidenceIds,
        ),
        isFalse,
      );
      expect(
        OrganizeChronologyEligibilityPolicy.isChronologyEligible(
          item: noteItem,
          orderedCapturedEvidenceIds:
              restored.timelineRepository.orderedCapturedEvidenceIds(),
          organizeCreatedIds: restored.organizeCreatedEvidenceIds,
        ),
        isFalse,
      );
      expect(
        restored.timelineRepository.orderedCapturedEvidenceIds(),
        isNot(contains(note)),
      );

      await _pumpRestoredOrganize(tester, restored);

      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(note)),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextArrowKey(note)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.discardKey(note)),
        findsNothing,
      );
      final contextRect = tester.getRect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
      );
      final photoRect = tester.getRect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo)),
      );
      final alignedX =
          (contextRect.left - (photoRect.right + 48)).abs() < 16;
      final alignedY =
          (contextRect.center.dy - photoRect.center.dy).abs() < 40;
      expect(
        alignedX,
        isTrue,
        reason: 'snapped context must align horizontally with its evidence',
      );
      expect(
        alignedY,
        isTrue,
        reason: 'snapped context must sit beside its linked evidence moment',
      );
    },
  );

  test(
    'restore never infers a snap when persisted anchors are empty',
    () async {
      SharedPreferences.setMockInitialValues({});
      final live = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(
          id: 'inc-org-persist-no-infer',
          title: 'Case',
        ),
      );
      final photo = live.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      final note = live.addOrganizeContextEvidence(WorkspaceCaptureMode.note);
      await OrganizeContextPersistence.save(
        incidentId: live.currentIncident.id,
        createdIds: live.organizeCreatedEvidenceIds,
        anchors: const [],
      );

      final snapshot = _evidenceOnlySnapshot(live.aggregate.store);
      final changed = await OrganizeContextPersistence.applyTo(snapshot);
      expect(changed, isTrue);
      expect(snapshot.organizeCreatedEvidenceIds, contains(note));
      expect(snapshot.organizeCreatedEvidenceIds, isNot(contains(photo)));
      expect(snapshot.organizeContextAnchors, isEmpty);
    },
  );
}
