import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/timeline/timeline_anchor.dart';
import 'package:evidence_vault/models/timeline_anchor_node.dart';
import 'package:evidence_vault/models/timeline_workspace_filter.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/domain/participant/related_person_link.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/screens/investigation_workspace_screen.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/timeline/timeline_anchor_card_metadata.dart';
import 'package:evidence_vault/widgets/timeline/timeline_anchor_entry.dart';
import 'package:evidence_vault/widgets/workspace/timeline_workspace_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  DateTime? lastPreservedAt,
  bool isContextual = false,
  Set<String> relatedEvidenceIds = const {},
  String? relatedPersonRole,
  List<RelatedPersonLink> relatedPeople = const [],
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: lastPreservedAt ?? DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    isContextual: isContextual,
    relatedEvidenceIds: relatedEvidenceIds,
    relatedPersonRole: relatedPersonRole,
    relatedPeople: relatedPeople,
  );
}

TimelineAnchorNode _anchorNode({
  required String id,
  required WorkspaceEvidenceKind kind,
  int sequenceOrder = 0,
  List<WorkspaceEvidenceItem> supporting = const [],
}) {
  return TimelineAnchorNode(
    anchor: TimelineAnchor(
      id: 'anchor-$id',
      incidentId: 'incident-1',
      capturedEvidenceId: id,
      anchoredAt: DateTime(2026, 7, 28, 9, sequenceOrder),
      sequenceOrder: sequenceOrder,
    ),
    capturedItem: _item(
      id: id,
      kind: kind,
      lastPreservedAt: DateTime(2026, 7, 28, 9, sequenceOrder),
    ),
    supportingItems: supporting,
  );
}

void main() {
  group('WorkspaceEvidenceController.anchoredTimeline', () {
    test('orders captured evidence by timeline anchors', () {
      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.voice);
      controller.preserveEvidence(WorkspaceCaptureMode.video);

      final tree = controller.anchoredTimeline;

      expect(tree, hasLength(3));
      expect(tree[0].capturedItem.kind, WorkspaceEvidenceKind.image);
      expect(tree[1].capturedItem.kind, WorkspaceEvidenceKind.voice);
      expect(tree[2].capturedItem.kind, WorkspaceEvidenceKind.video);
    });

    test('attaches contextual supporting evidence beneath parent anchor', () {
      final controller = WorkspaceEvidenceController();
      final photoId =
          controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      controller.addContextTextNote(
        parentEvidenceId: photoId,
        text: 'Observed at the entrance.',
      );

      final tree = controller.anchoredTimeline;

      expect(tree, hasLength(1));
      expect(tree.first.supportingItems, hasLength(1));
      expect(tree.first.supportingItems.first.kind, WorkspaceEvidenceKind.note);
      expect(
        tree.first.supportingItems.first.relatedEvidenceIds,
        contains(photoId),
      );
    });

    test('includes standalone file and note without reordering captured anchors',
        () {
      final controller = WorkspaceEvidenceController();
      final photoId =
          controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      final photoCapturedAt = controller.anchoredTimeline
          .singleWhere((node) => node.capturedItem.id == photoId)
          .capturedItem
          .lastPreservedAt;
      final fileId =
          controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.file);
      final noteId =
          controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.note);

      final tree = controller.anchoredTimeline;
      final photoNode = tree.singleWhere(
        (node) => node.capturedItem.id == photoId,
      );
      expect(photoNode.capturedItem.lastPreservedAt, photoCapturedAt);
      expect(
        tree.map((node) => node.capturedItem.id),
        containsAll([photoId, fileId, noteId]),
      );
      expect(
        tree
            .singleWhere((node) => node.capturedItem.id == fileId)
            .capturedItem
            .kind,
        WorkspaceEvidenceKind.attachment,
      );
      expect(
        tree
            .singleWhere((node) => node.capturedItem.id == noteId)
            .capturedItem
            .kind,
        WorkspaceEvidenceKind.note,
      );
    });
  });

  group('TimelineWorkspaceFilter', () {
    test('captured filters hide non-matching anchors without reordering', () {
      final nodes = [
        _anchorNode(id: 'photo', kind: WorkspaceEvidenceKind.image, sequenceOrder: 0),
        _anchorNode(id: 'voice', kind: WorkspaceEvidenceKind.voice, sequenceOrder: 1),
        _anchorNode(id: 'video', kind: WorkspaceEvidenceKind.video, sequenceOrder: 2),
      ];

      final filtered = TimelineWorkspaceFilter.apply(
        filter: TimelineWorkspaceFilter.voice,
        nodes: nodes,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.capturedItem.kind, WorkspaceEvidenceKind.voice);
    });

    test('supporting filters keep anchor order and trim children', () {
      const photoId = 'photo';
      final photo = _anchorNode(
        id: photoId,
        kind: WorkspaceEvidenceKind.image,
        supporting: [
          _item(
            id: 'note',
            kind: WorkspaceEvidenceKind.note,
            isContextual: true,
            relatedEvidenceIds: {photoId},
          ),
          _item(
            id: 'witness',
            kind: WorkspaceEvidenceKind.witness,
            isContextual: true,
            relatedEvidenceIds: {photoId},
          ),
        ],
      );

      final filtered = TimelineWorkspaceFilter.apply(
        filter: TimelineWorkspaceFilter.witness,
        nodes: [photo],
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.supportingItems, hasLength(1));
      expect(
        filtered.single.supportingItems.single.kind,
        WorkspaceEvidenceKind.witness,
      );
    });

    test('Documents, Notes, and Witness match captured or related items', () {
      final photo = _anchorNode(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        supporting: [
          _item(
            id: 'note',
            kind: WorkspaceEvidenceKind.note,
            isContextual: true,
            relatedEvidenceIds: {'photo'},
          ),
        ],
      );
      final file = _anchorNode(
        id: 'file',
        kind: WorkspaceEvidenceKind.attachment,
        sequenceOrder: 1,
      );
      final witnessed = TimelineAnchorNode(
        anchor: TimelineAnchor(
          id: 'anchor-witnessed',
          incidentId: 'incident-1',
          capturedEvidenceId: 'witnessed',
          anchoredAt: DateTime(2026, 7, 28, 9, 2),
          sequenceOrder: 2,
        ),
        capturedItem: _item(
          id: 'witnessed',
          kind: WorkspaceEvidenceKind.image,
          lastPreservedAt: DateTime(2026, 7, 28, 9, 2),
          relatedPersonRole: 'witness',
          relatedPeople: const [
            RelatedPersonLink(
              participantId: 'p-jacob',
              displayName: 'Jacob',
              roleName: 'witness',
            ),
          ],
        ),
        supportingItems: const [],
      );
      final nodes = [photo, file, witnessed];

      final documents = TimelineWorkspaceFilter.apply(
        filter: TimelineWorkspaceFilter.documents,
        nodes: nodes,
      );
      expect(documents, hasLength(1));
      expect(documents.single.capturedItem.id, 'file');

      final notes = TimelineWorkspaceFilter.apply(
        filter: TimelineWorkspaceFilter.notes,
        nodes: nodes,
      );
      expect(notes, hasLength(1));
      expect(notes.single.supportingItems.single.id, 'note');

      final witness = TimelineWorkspaceFilter.apply(
        filter: TimelineWorkspaceFilter.witness,
        nodes: nodes,
      );
      expect(witness, hasLength(1));
      expect(witness.single.capturedItem.id, 'witnessed');
    });
  });

  group('TimelineAnchorCardMetadata', () {
    test('uses shared evidence clock and omits unrecorded device/location', () {
      final node = _anchorNode(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        sequenceOrder: 13,
      );

      final metadata = TimelineAnchorCardMetadata.fromNode(node);

      expect(metadata.evidenceTypeLabel, 'Photo');
      expect(
        metadata.captureTime,
        WorkspaceEvidenceFormatters.evidenceClock(
          DateTime(2026, 7, 28, 9, 13),
        ),
      );
      expect(metadata.captureTime, contains('09:13:00'));
      expect(metadata.deviceName, isNull);
      expect(metadata.captureLocation, isNull);
    });

    test('shows recorded device and coordinates only when present', () {
      final node = TimelineAnchorNode(
        anchor: TimelineAnchor(
          id: 'anchor-photo',
          incidentId: 'incident-1',
          capturedEvidenceId: 'photo',
          anchoredAt: DateTime(2026, 7, 28, 9, 13),
          sequenceOrder: 13,
        ),
        capturedItem: WorkspaceEvidenceItem(
          id: 'photo',
          kind: WorkspaceEvidenceKind.image,
          title: 'Evidence photo',
          lastPreservedAt: DateTime(2026, 7, 28, 9, 13),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
          deviceModel: 'Pixel 8',
          latitude: 27.7172,
          longitude: 85.3240,
        ),
        supportingItems: const [],
      );

      final metadata = TimelineAnchorCardMetadata.fromNode(node);

      expect(metadata.deviceName, 'Pixel 8');
      expect(metadata.captureLocation, '27.7172, 85.3240');
      expect(metadata.deviceName, isNot('Moto G35 5G'));
      expect(metadata.captureLocation, isNot('Pokhara, Nepal'));
    });

    test('hides location when coordinates are unavailable', () {
      final node = _anchorNode(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        sequenceOrder: 41,
      );

      final metadata = TimelineAnchorCardMetadata.fromNode(node);

      expect(metadata.deviceName, isNull);
      expect(metadata.captureLocation, isNull);
    });
  });

  group('TimelineWorkspaceSummary', () {
    testWidgets('hidden when no timeline anchors exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimelineWorkspaceSummary(
              timelineAnchorCount: 0,
              supportingEvidenceCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('Timeline'), findsNothing);
    });

    testWidgets('journey header opens investigation timeline workspace',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      controller.addContextTextNote(
        parentEvidenceId: controller.journeyEvidenceItems.first.id,
        text: 'Additional detail.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(InvestigationJourneyHeader),
          matching: find.text('Investigate'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationWorkspaceScreen), findsOneWidget);
      expect(find.text('Investigation Workspace'), findsOneWidget);
      expect(find.byType(TimelineAnchorEntry), findsNWidgets(2));
      expect(find.textContaining('Moto G35 5G'), findsNothing);
      expect(find.textContaining('Pokhara, Nepal'), findsNothing);
    });
  });
}
