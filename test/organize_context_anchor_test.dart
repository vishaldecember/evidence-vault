import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/engines/evidence_semantics.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/organize/organize_context_anchor_store.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setAnchor records context → captured without touching other systems',
      () {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-anchor', title: 'Case'),
    );
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final note = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.note,
    );
    controller.ensureEvidenceCollections();

    final parentBefore = controller.currentIncident.evidence
        .firstWhere((e) => e.id == note)
        .parentEvidenceId;
    final collectionsBefore = controller.evidenceCollections
        .map((c) => '${c.id}:${c.memberEvidenceIds.join(',')}')
        .toList();
    final groupsBefore = controller.currentIncident.relationshipGroups.length;
    final relationshipsBefore = controller.state.relationships.length;
    final photoTime = controller.currentIncident.evidence
        .firstWhere((e) => e.id == photo)
        .lastPreservedAt;
    final noteTime = controller.currentIncident.evidence
        .firstWhere((e) => e.id == note)
        .lastPreservedAt;

    final anchor = controller.setOrganizeContextAnchor(
      contextEvidenceId: note,
      capturedEvidenceId: photo,
    );
    expect(anchor, isNotNull);
    expect(anchor!.contextEvidenceId, note);
    expect(anchor.capturedEvidenceId, photo);
    expect(controller.organizeContextAnchors, hasLength(1));

    final noteAfter =
        controller.currentIncident.evidence.firstWhere((e) => e.id == note);
    expect(noteAfter.parentEvidenceId, parentBefore);
    expect(noteAfter.relatedEvidenceIds.contains(photo), isFalse);
    expect(noteAfter.lastPreservedAt, noteTime);
    expect(
      controller.currentIncident.evidence
          .firstWhere((e) => e.id == photo)
          .lastPreservedAt,
      photoTime,
    );
    expect(
      controller.evidenceCollections
          .map((c) => '${c.id}:${c.memberEvidenceIds.join(',')}')
          .toList(),
      collectionsBefore,
    );
    expect(
      controller.currentIncident.relationshipGroups,
      hasLength(groupsBefore),
    );
    expect(controller.state.relationships, hasLength(relationshipsBefore));
    expect(
      EvidenceSemantics.structurallySupports(
        child: noteAfter,
        parentId: photo,
        relationships: controller.state.relationships,
      ),
      isFalse,
    );
  });

  test('replacing an anchor keeps a single mapping for the context id', () {
    final controller = WorkspaceEvidenceController();
    final photoA = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final photoB = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final file = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.file,
    );

    controller.setOrganizeContextAnchor(
      contextEvidenceId: file,
      capturedEvidenceId: photoA,
    );
    controller.setOrganizeContextAnchor(
      contextEvidenceId: file,
      capturedEvidenceId: photoB,
    );

    expect(controller.organizeContextAnchors, hasLength(1));
    expect(controller.organizeContextAnchors.single.capturedEvidenceId, photoB);
    expect(
      OrganizeContextAnchorStore.instance
          .anchorsForCaptured(
            store: controller.aggregate.store,
            capturedEvidenceId: photoA,
          )
          .isEmpty,
      isTrue,
    );
  });

  test('clearAnchor removes only the Organize placement', () {
    final controller = WorkspaceEvidenceController();
    final voice = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.voice,
    );
    final note = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.note,
    );
    controller.setOrganizeContextAnchor(
      contextEvidenceId: note,
      capturedEvidenceId: voice,
    );
    controller.clearOrganizeContextAnchor(note);
    expect(controller.organizeContextAnchors, isEmpty);
    expect(
      controller.currentIncident.evidence
          .firstWhere((e) => e.id == note)
          .parentEvidenceId,
      isNull,
    );
  });

  test('multiple contexts can share one captured target independently', () {
    final controller = WorkspaceEvidenceController();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final noteA = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.note,
    );
    final noteB = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.note,
    );
    final file = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.file,
    );
    controller.ensureEvidenceCollections();
    final collectionsBefore = controller.evidenceCollections
        .map((c) => '${c.id}:${c.memberEvidenceIds.join(',')}')
        .toList();
    final groupsBefore = controller.currentIncident.relationshipGroups.length;
    final relationshipsBefore = controller.state.relationships.length;

    controller.setOrganizeContextAnchor(
      contextEvidenceId: noteA,
      capturedEvidenceId: photo,
    );
    controller.setOrganizeContextAnchor(
      contextEvidenceId: noteB,
      capturedEvidenceId: photo,
    );
    controller.setOrganizeContextAnchor(
      contextEvidenceId: file,
      capturedEvidenceId: photo,
    );

    expect(controller.organizeContextAnchors, hasLength(3));
    expect(
      controller.organizeContextAnchors.map((a) => a.contextEvidenceId).toSet(),
      {noteA, noteB, file},
    );
    expect(
      controller.organizeContextAnchors.every(
        (a) => a.capturedEvidenceId == photo,
      ),
      isTrue,
    );
    expect(
      controller.evidenceCollections
          .map((c) => '${c.id}:${c.memberEvidenceIds.join(',')}')
          .toList(),
      collectionsBefore,
    );
    expect(
      controller.currentIncident.relationshipGroups,
      hasLength(groupsBefore),
    );
    expect(controller.state.relationships, hasLength(relationshipsBefore));
    for (final id in [noteA, noteB, file]) {
      expect(
        controller.currentIncident.evidence
            .firstWhere((e) => e.id == id)
            .parentEvidenceId,
        isNull,
      );
    }
  });

  test('rejects missing, blank, or self IDs', () {
    final controller = WorkspaceEvidenceController();
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    expect(
      controller.setOrganizeContextAnchor(
        contextEvidenceId: 'missing',
        capturedEvidenceId: photo,
      ),
      isNull,
    );
    expect(
      controller.setOrganizeContextAnchor(
        contextEvidenceId: photo,
        capturedEvidenceId: photo,
      ),
      isNull,
    );
    expect(
      controller.setOrganizeContextAnchor(
        contextEvidenceId: '',
        capturedEvidenceId: photo,
      ),
      isNull,
    );
    expect(controller.organizeContextAnchors, isEmpty);
  });

  test('Organize origin, not kind, marks flexible-spine context', () {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-origin', title: 'Case'),
    );
    final capturedVoice = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.voice,
    );
    final capturedNote = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.note,
    );
    final capturedFile = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.file,
    );
    final capturedOrder = evidenceInspectorOrder(
      controller.currentIncident.journeyEvidence,
      incidentId: controller.currentIncident.id,
    ).map((e) => e.id).toList();
    final capturedTimes = {
      for (final item in controller.currentIncident.evidence)
        item.id: item.lastPreservedAt,
    };

    expect(controller.organizeCreatedEvidenceIds, isEmpty);

    final orgVoice = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.voice,
    );
    final orgNote = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    final orgFile = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.file,
    );

    expect(
      controller.organizeCreatedEvidenceIds,
      {orgVoice, orgNote, orgFile},
    );
    expect(controller.organizeCreatedEvidenceIds.contains(capturedVoice), isFalse);
    expect(controller.organizeCreatedEvidenceIds.contains(capturedNote), isFalse);
    expect(controller.organizeCreatedEvidenceIds.contains(capturedFile), isFalse);

    for (final entry in capturedTimes.entries) {
      expect(
        controller.currentIncident.evidence
            .firstWhere((e) => e.id == entry.key)
            .lastPreservedAt,
        entry.value,
      );
    }
    expect(
      evidenceInspectorOrder(
        [
          for (final item in controller.currentIncident.journeyEvidence)
            if (!controller.organizeCreatedEvidenceIds.contains(item.id)) item,
        ],
        incidentId: controller.currentIncident.id,
      ).map((e) => e.id),
      capturedOrder,
    );

    expect(
      () => controller.addOrganizeContextEvidence(WorkspaceCaptureMode.photo),
      throwsArgumentError,
    );
    expect(
      () => controller.addOrganizeContextEvidence(WorkspaceCaptureMode.video),
      throwsArgumentError,
    );
  });
}
