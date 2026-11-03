import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceController _controller() {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(
      id: 'inc-capture-seq',
      title: 'Case',
    ),
  );
}

void main() {
  test('Capture Note joins sequenceOrder before later Video and Voice', () {
    final controller = _controller();
    final noteId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.note,
    );
    final note = controller.currentIncident.evidenceById(noteId)!;
    final recordedAt = note.recordedAt;
    final lastPreservedAt = note.lastPreservedAt;

    final videoId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final voiceId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.voice,
    );

    expect(
      controller.timelineRepository.orderedCapturedEvidenceIds(),
      [noteId, videoId, voiceId],
    );
    final after = controller.currentIncident.evidenceById(noteId)!;
    expect(after.recordedAt, recordedAt);
    expect(after.lastPreservedAt, lastPreservedAt);
  });

  test('Capture File joins sequenceOrder before later Video and Voice', () {
    final controller = _controller();
    final fileId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.file,
    );
    final videoId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.video,
    );
    final voiceId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.voice,
    );

    expect(
      controller.timelineRepository.orderedCapturedEvidenceIds(),
      [fileId, videoId, voiceId],
    );
  });

  test('Organize Note does not receive a TimelineAnchor', () {
    final controller = _controller();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final noteId = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );

    expect(
      controller.timelineRepository.anchors.any(
        (anchor) => anchor.capturedEvidenceId == noteId,
      ),
      isFalse,
    );
    expect(
      controller.timelineRepository.orderedCapturedEvidenceIds(),
      isNot(contains(noteId)),
    );
  });

  test('Organize File with asOrganizeContext does not receive a TimelineAnchor',
      () {
    final controller = _controller();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final fileId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.file,
      asOrganizeContext: true,
    );
    controller.registerOrganizeCreatedEvidence(fileId);

    expect(
      controller.timelineRepository.anchors.any(
        (anchor) => anchor.capturedEvidenceId == fileId,
      ),
      isFalse,
    );
    expect(
      controller.timelineRepository.orderedCapturedEvidenceIds(),
      isNot(contains(fileId)),
    );
  });

  test(
    'Organize display order follows Capture Note then Video then Voice',
    () {
      final controller = _controller();
      final noteId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.note,
      );
      final videoId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      final voiceId = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.voice,
      );

      final ordered = OrganizeChronologyCanvas.displayOrder(
        items: controller.currentIncident.journeyEvidence,
        orderedCapturedEvidenceIds:
            controller.timelineRepository.orderedCapturedEvidenceIds(),
        organizeCreatedIds: controller.organizeCreatedEvidenceIds,
        incidentId: controller.currentIncident.id,
      );

      expect(
        [for (final item in ordered) item.id],
        [noteId, videoId, voiceId],
      );
    },
  );
}
