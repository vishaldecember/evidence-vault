import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/workspace_evidence_repository.dart';
import 'package:evidence_vault/services/storage/evidence_upload_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
    WorkspaceSession.instance.reset();
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
  });

  group('Upload pipeline evidence identity', () {
    test('rapid captures produce unique immutable evidence ids', () {
      final controller = WorkspaceEvidenceController();

      final ids = <String>[];
      for (var i = 0; i < 10; i++) {
        ids.add(controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo));
      }
      for (var i = 0; i < 5; i++) {
        ids.add(controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video));
      }
      for (var i = 0; i < 5; i++) {
        ids.add(controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.file));
      }

      expect(ids.toSet(), hasLength(ids.length));
      expect(controller.currentIncident.evidence.map((e) => e.id).toSet(), hasLength(20));
      expect(
        controller.currentIncident.journeyEvidence.map((e) => e.id).toSet(),
        hasLength(20),
      );
    });

    test('all capture modes share unique id namespace', () {
      final controller = WorkspaceEvidenceController();
      final ids = [
        for (final mode in WorkspaceCaptureMode.values)
          controller.preserveEvidenceAndReturnId(mode),
      ];

      expect(ids.toSet(), hasLength(WorkspaceCaptureMode.values.length));
    });

    test('applyStorageUpload updates placeholder in place — no duplicate', () {
      final controller = WorkspaceEvidenceController();
      final id = controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);

      controller.evidenceRepository.attachLocalMedia(
        evidenceId: id,
        filePath: '/tmp/photo.jpg',
        fileName: 'photo.jpg',
        fileSizeBytes: 12,
      );

      expect(controller.currentIncident.evidence, hasLength(1));
      expect(
        controller.currentIncident.evidence.single.uploadStatus,
        EvidenceUploadStatus.pending,
      );

      controller.evidenceRepository.applyStorageUpload(
        evidenceId: id,
        storagePath: 'users/u/incidents/i/photos/$id.jpg',
        downloadUrl: 'https://example.test/$id.jpg',
        mimeType: 'image/jpeg',
        fileSizeBytes: 12,
        thumbnailUrl: 'https://example.test/$id-thumb.jpg',
      );
      // Refresh projection from the same store (upload path calls
      // _invalidateDerivedCaches after applyStorageUpload).
      controller.replaceAggregate(
        IncidentAggregate.fromStore(controller.aggregate.store),
      );

      expect(controller.currentIncident.evidence, hasLength(1));
      expect(controller.currentIncident.evidence.single.id, id);
      expect(
        controller.currentIncident.evidence.single.uploadStatus,
        EvidenceUploadStatus.uploaded,
      );
      expect(
        controller.currentIncident.evidence.single.downloadUrl,
        'https://example.test/$id.jpg',
      );
    });

    test('journeySequence drops duplicate ids defensively', () {
      final now = DateTime.now();
      const duplicateId = 'ev-dup';
      final verification =
          WorkspaceEvidenceFactory.createFromCapture(WorkspaceCaptureMode.photo)
              .verification;
      final items = [
        WorkspaceEvidenceItem(
          id: duplicateId,
          kind: WorkspaceEvidenceKind.image,
          title: 'Photo',
          lastPreservedAt: now,
          integrityVerified: true,
          verification: verification,
        ),
        WorkspaceEvidenceItem(
          id: duplicateId,
          kind: WorkspaceEvidenceKind.note,
          title: 'Note',
          lastPreservedAt: now.add(const Duration(seconds: 1)),
          integrityVerified: true,
          verification: verification,
        ),
      ];

      final journey =
          WorkspaceEvidenceRepository.journeySequenceFromItems(items);

      expect(journey, hasLength(1));
      expect(journey.single.id, duplicateId);
    });

    test('session restore replaces aggregate without new ChangeNotifier',
        () async {
      final session = WorkspaceSession.instance;
      final original = session.controller;
      var notifications = 0;
      original.addListener(() => notifications++);

      final hydrated = IncidentAggregate.empty();
      hydrated.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      session.controller.replaceAggregate(hydrated);
      await Future<void>.microtask(() {});

      expect(identical(session.controller, original), isTrue);
      expect(session.controller.currentIncident.evidence, hasLength(1));
      expect(notifications, greaterThan(0));
    });
  });
}
