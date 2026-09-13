import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/reconstruction/narrative_event.dart';
import 'package:evidence_vault/engines/narrative_builder.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_group_confidence.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

void main() {
  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('NarrativeEventRepository', () {
    test('ensureInitialStructure creates placeholder events for anchors', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
        ),
      );

      final events = controller.narrativeEvents;
      expect(controller.aggregate.store.narrativeEvents, hasLength(2));
      expect(events.first.event.title, '${NarrativeEvent.defaultTitlePrefix} 1');
    });

    test('updateTitle and updateSummary persist investigator edits', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
      );
      final eventId = controller.narrativeEvents.single.event.id;

      controller.updateNarrativeEventTitle(eventId: eventId, title: 'Arrival');
      controller.updateNarrativeEventSummary(
        eventId: eventId,
        summary: 'The suspect arrived at the entrance.',
      );

      final updated = controller.narrativeEvents.single.event;
      expect(updated.title, 'Arrival');
      expect(updated.summary, 'The suspect arrived at the entrance.');
      expect(updated.titleCustomized, isTrue);
      expect(updated.summaryCustomized, isTrue);
    });

    test('moveEventUp and moveEventDown reorder narrative only', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
        ),
      );
      final firstId = controller.narrativeEvents.first.event.id;
      final secondId = controller.narrativeEvents.last.event.id;

      controller.moveNarrativeEventDown(eventId: firstId);
      expect(controller.narrativeEvents.first.event.id, secondId);
      expect(controller.anchoredTimeline.first.capturedItem.id, 'photo');

      controller.moveNarrativeEventUp(eventId: firstId);
      expect(controller.narrativeEvents.first.event.id, firstId);
    });
  });

  group('Live narrative projection', () {
    test('preserves investigator title when relationship groups change', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          ],
        ),
      );
      final eventId = controller.narrativeEvents.first.event.id;
      controller.updateNarrativeEventTitle(eventId: eventId, title: 'Arrival');
      controller.commitRelationshipGroup(evidenceIds: ['photo', 'video']);

      expect(controller.narrativeEvents.first.event.title, 'Arrival');
      expect(
        controller.narrativeEvents.first.relationshipGroups,
        isNotEmpty,
      );
    });

    test('appends a new event when a timeline anchor is captured', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
      );
      expect(controller.narrativeEvents, hasLength(1));

      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.refreshNarrativeProjection();

      expect(controller.narrativeEvents, hasLength(2));
      expect(controller.narrativeEvents.last.event.isDefaultTitle, isTrue);
    });

    test('shows missing reference message when anchor evidence is absent', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
      );
      final event = controller.narrativeEvents.single.event;
      controller.aggregate.store.narrativeEvents[0] = event.copyWith(
        timelineAnchorEvidenceId: 'removed-photo',
        titleCustomized: true,
        title: 'Arrival',
        summary: 'Investigator summary preserved.',
        summaryCustomized: true,
      );
      controller.refreshNarrativeProjection();

      final viewModel = controller.narrativeEvents.firstWhere(
        (entry) => entry.hasMissingReferencedEvidence,
      );
      expect(viewModel.referenceStatusMessage,
          NarrativeEventViewModel.missingReferenceMessage);
      expect(viewModel.event.title, 'Arrival');
      expect(viewModel.event.summary, 'Investigator summary preserved.');
    });
  });

  group('NarrativeValidationService integration', () {
    test('builder attaches validation to each narrative event', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo'),
            _item(id: 'video', kind: WorkspaceEvidenceKind.video),
            _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
          ],
        ),
      );

      final validation = controller.narrativeEvents.first.validation;
      expect(validation.status, RelationshipGroupConfidence.medium);
      expect(validation.supportedByLines, isNotEmpty);
    });
  });
}
