import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_provenance_event.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/evidence_record_model.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/presentation/evidence_presentation_resolver.dart';
import 'package:evidence_vault/services/capture/capture_job.dart';
import 'package:evidence_vault/services/capture/capture_provenance.dart';
import 'package:evidence_vault/services/capture/thumbnail_job.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/local_evidence_hydrator.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_media_source.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/attachment_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/pdf_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/video_evidence_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(root, 'documents');

  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');
}

class _FakeHost implements CapturePipelineHost {
  String? lastThumb;
  int attachCount = 0;

  @override
  String get captureIncidentId => 'incident-14a';

  @override
  String get captureIncidentTitle => '';

  @override
  void attachCaptureThumbnail({
    required String evidenceId,
    required String filePath,
    String? fileName,
    String? thumbnailPath,
    int? fileSizeBytes,
  }) {
    attachCount++;
    lastThumb = thumbnailPath;
  }

  @override
  void scheduleCaptureMetadataPersist() {}

  @override
  void completeCaptureUpload({
    required String evidenceId,
    required String storagePath,
    required String downloadUrl,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {}

  @override
  void failCaptureUpload(String evidenceId) {}

  @override
  void abandonFailedLocalCapture(String evidenceId) {}

  @override
  bool updateLifecycleStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  }) =>
      true;

  @override
  void rememberCaptureProvenance(CaptureProvenanceSnapshot snapshot) {}

  @override
  void applyCaptureProvenance({
    required String evidenceId,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {}

  @override
  void recordContentHash({
    required String evidenceId,
    required String hash,
  }) {}

  @override
  void appendEvidenceProvenance(EvidenceProvenanceEvent event) {}
}

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  String? fileName,
  String? filePath,
  String? thumbnailPath,
  String? mimeType,
  int? fileSizeBytes,
  String? deviceModel,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 8, 19, 12),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    fileName: fileName,
    filePath: filePath,
    thumbnailPath: thumbnailPath,
    mimeType: mimeType,
    fileSizeBytes: fileSizeBytes,
    deviceModel: deviceModel,
    incidentId: 'incident-14a',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ev_14a_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    ThumbnailJob.debugPreviewThumbnailForMode = null;
    WorkspaceSession.instance.reset();
  });

  tearDown(() async {
    ThumbnailJob.debugPreviewThumbnailForMode = null;
    LocalEvidenceCache.resetForTests();
    WorkspaceSession.instance.reset();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('ThumbnailJob durable paths', () {
    test('stores generated JPEG beside durable evidence, not in temp', () async {
      final tmpDir = Directory(p.join(tempRoot.path, 'tmp'));
      await tmpDir.create(recursive: true);
      final tempThumb = File(p.join(tmpDir.path, 'ev_vthumb_temp.jpg'));
      await tempThumb.writeAsBytes(List<int>.filled(24, 3), flush: true);

      ThumbnailJob.debugPreviewThumbnailForMode =
          ({required mode, required localFilePath}) async => tempThumb.path;

      final host = _FakeHost();
      final media = CapturedMediaFile(
        localPath: p.join(tempRoot.path, 'documents', 'clip.mp4'),
        fileName: 'clip.mp4',
        fileSizeBytes: 2048,
      );
      await File(media.localPath).create(recursive: true);
      await File(media.localPath).writeAsBytes(List<int>.filled(8, 1));

      await ThumbnailJob().run(
        CaptureJobContext(
          evidenceId: 'ev-video-1',
          incidentId: 'incident-14a',
          mode: WorkspaceCaptureMode.video,
          media: media,
          controller: host,
        ),
      );

      expect(host.attachCount, 1);
      expect(host.lastThumb, isNotNull);
      expect(host.lastThumb, isNot(tempThumb.path));
      expect(host.lastThumb, contains('evidence_cache'));
      expect(host.lastThumb, contains('ev-video-1_thumb.jpg'));
      expect(File(host.lastThumb!).existsSync(), isTrue);
    });

    test('thumbnail generation failure does not throw', () async {
      ThumbnailJob.debugPreviewThumbnailForMode =
          ({required mode, required localFilePath}) async {
        throw StateError('decode failed');
      };

      final host = _FakeHost();
      await ThumbnailJob().run(
        CaptureJobContext(
          evidenceId: 'ev-video-fail',
          incidentId: 'incident-14a',
          mode: WorkspaceCaptureMode.video,
          media: const CapturedMediaFile(
            localPath: '/missing/clip.mp4',
            fileName: 'clip.mp4',
            fileSizeBytes: 10,
          ),
          controller: host,
        ),
      );

      expect(host.attachCount, 0);
      expect(host.lastThumb, isNull);
    });

    test('null thumbnail leaves existing identity untouched', () async {
      ThumbnailJob.debugPreviewThumbnailForMode =
          ({required mode, required localFilePath}) async => null;

      final host = _FakeHost();
      await ThumbnailJob().run(
        CaptureJobContext(
          evidenceId: 'ev-video-none',
          incidentId: 'incident-14a',
          mode: WorkspaceCaptureMode.video,
          media: const CapturedMediaFile(
            localPath: '/missing/clip.mp4',
            fileName: 'clip.mp4',
            fileSizeBytes: 10,
          ),
          controller: host,
        ),
      );

      expect(host.attachCount, 0);
    });

    test('durableizeThumbnail copies temp JPEG into evidence_cache', () async {
      final tmpDir = Directory(p.join(tempRoot.path, 'tmp'));
      await tmpDir.create(recursive: true);
      final tempThumb = File(p.join(tmpDir.path, 'generated.jpg'));
      await tempThumb.writeAsBytes(List<int>.filled(16, 7), flush: true);

      final durable = await LocalEvidenceCache.durableizeThumbnail(
        incidentId: 'incident-14a',
        evidenceId: 'ev-direct-thumb',
        thumbnailPath: tempThumb.path,
      );

      expect(durable, isNotNull);
      expect(durable, isNot(tempThumb.path));
      expect(durable, contains('evidence_cache'));
      expect(durable, contains('ev-direct-thumb_thumb.jpg'));
      expect(File(durable!).existsSync(), isTrue);
    });

    test('durableizeThumbnail fail-open returns null for missing source',
        () async {
      final durable = await LocalEvidenceCache.durableizeThumbnail(
        incidentId: 'incident-14a',
        evidenceId: 'ev-missing-thumb',
        thumbnailPath: p.join(tempRoot.path, 'tmp', 'gone.jpg'),
      );
      expect(durable, isNull);
    });
  });

  group('EvidencePresentationResolver', () {
    test('captured video resolves to real video presentation', () {
      final item = _item(
        id: 'cap-vid',
        kind: WorkspaceEvidenceKind.video,
        fileName: 'scene.mp4',
        filePath: '/data/scene.mp4',
        thumbnailPath: '/data/scene_thumb.jpg',
        mimeType: 'video/mp4',
        fileSizeBytes: 21113500,
      );

      final presentation = EvidencePresentationResolver.resolve(item);
      expect(presentation.semanticKind, WorkspaceEvidenceKind.video);
      expect(presentation.previewKind, EvidencePresentationKind.video);
      expect(presentation.renderer, isA<VideoEvidenceRenderer>());
      expect(presentation.thumbnailPath, '/data/scene_thumb.jpg');
      expect(presentation.playbackPath, '/data/scene.mp4');
      expect(item.isPrimaryChronologyEvidence, isTrue);

      final complete =
          EvidencePresentationResolver.resolveCompleteRecordPresentation(item);
      expect(complete, isA<VideoEvidenceRenderer>());
      expect(
        identical(
          complete.runtimeType,
          EvidencePresentationResolver.resolvePreview(item).runtimeType,
        ),
        isTrue,
      );
    });

    test(
      'file-attached video stays attachment but resolves video presentation',
      () {
        final item = _item(
          id: 'file-vid',
          kind: WorkspaceEvidenceKind.attachment,
          fileName: 'clip.mp4',
          filePath: '/data/clip.mp4',
          thumbnailPath: '/data/clip_thumb.jpg',
          mimeType: 'video/mp4',
          fileSizeBytes: 4096,
        );

        expect(item.kind, WorkspaceEvidenceKind.attachment);
        expect(item.isPrimaryChronologyEvidence, isFalse);

        final presentation = EvidencePresentationResolver.resolve(item);
        expect(presentation.semanticKind, WorkspaceEvidenceKind.attachment);
        expect(presentation.previewKind, EvidencePresentationKind.video);
        expect(presentation.renderer, isA<VideoEvidenceRenderer>());
        expect(
          EvidencePresentationResolver.resolveCompleteRecordPresentation(item),
          isA<VideoEvidenceRenderer>(),
        );
        expect(presentation.thumbnailPath, '/data/clip_thumb.jpg');
      },
    );

    test('PDF attachment stays attachment and resolves PDF presentation', () {
      final item = _item(
        id: 'pdf',
        kind: WorkspaceEvidenceKind.attachment,
        fileName: 'brief.pdf',
        filePath: '/data/brief.pdf',
        mimeType: 'application/pdf',
        fileSizeBytes: 21113500,
      );
      final presentation = EvidencePresentationResolver.resolve(item);
      expect(presentation.semanticKind, WorkspaceEvidenceKind.attachment);
      expect(presentation.previewKind, EvidencePresentationKind.pdf);
      expect(presentation.renderer, isA<PdfEvidenceRenderer>());
    });
  });

  group('Honest metadata', () {
    test('uses fileSizeBytes and does not fabricate 248 KB or 0:42', () {
      final item = _item(
        id: 'sized',
        kind: WorkspaceEvidenceKind.video,
        fileName: 'clip.mp4',
        fileSizeBytes: 21113500,
      );
      final metadata = EvidenceRecordMetadata.forItem(item);
      expect(metadata.fileSize, isNot('248 KB'));
      expect(metadata.fileSize, contains('MB'));
      expect(metadata.duration, isNull);
      expect(metadata.resolution, isNull);
      expect(metadata.device, isNull);
      expect(metadata.location, isNull);

      final record = EvidenceRecordModel.fromWorkspace(
        evidence: item,
        allItems: [item],
        relationships: const [],
      );
      expect(record.metadata.fileSize, metadata.fileSize);
      expect(EvidenceMediaSource.fileSizeLabel(record), isNot('248 KB'));
      expect(EvidenceMediaSource.durationLabel(record), isNull);
    });

    test('does not invent location or device', () {
      final photo = _item(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        fileName: 'shot.jpg',
      );
      final metadata = EvidenceRecordMetadata.forItem(photo);
      expect(metadata.device, isNot('Moto G35 5G'));
      expect(metadata.location, isNot('Pokhara, Nepal'));
      expect(metadata.fileSize, isNull);
    });

    test('does not duplicate evidence when resolving presentation', () {
      final a = _item(id: 'a', kind: WorkspaceEvidenceKind.video);
      final b = _item(id: 'b', kind: WorkspaceEvidenceKind.attachment);
      final items = [a, b];
      EvidencePresentationResolver.resolve(items[0]);
      EvidencePresentationResolver.resolve(items[1]);
      expect(items.map((e) => e.id).toList(), ['a', 'b']);
    });
  });

  group('Hydrated attachment presentation', () {
    test(
      'file-attached video stays attachment after hydrate and shares video preview',
      () async {
        const incidentId = 'incident-14a-file-vid';
        final now = DateTime.now();
        await LocalEvidenceCache.upsert(
          CachedEvidenceEntry(
            evidenceId: 'ev-file-vid',
            incidentId: incidentId,
            userId: 'user-14a',
            evidenceType: EvidenceRecordType.document,
            createdAt: now,
            capturedAt: now,
            syncStatus: EvidenceSyncStatus.localCaptured,
            localFilePath: p.join(tempRoot.path, 'clip.mp4'),
            fileName: 'clip.mp4',
            mimeType: 'video/mp4',
            captureMode: WorkspaceCaptureMode.file,
            fileSizeBytes: 4096,
            thumbnailPath: p.join(tempRoot.path, 'clip_thumb.jpg'),
          ),
        );

        final session = WorkspaceSession.instance;
        session.controller.replaceAggregate(
          IncidentAggregate.shell(id: incidentId),
        );
        final inserted = await LocalEvidenceHydrator.hydrateIncident(
          incidentId: incidentId,
          repository: session.controller.evidenceRepository,
          userId: 'user-14a',
        );
        expect(inserted, 1);
        session.controller.scheduleCaptureMetadataPersist();

        final item = session.controller.journeyEvidenceItems.single;
        expect(item.id, 'ev-file-vid');
        expect(item.kind, WorkspaceEvidenceKind.attachment);
        expect(item.isPrimaryChronologyEvidence, isFalse);

        final presentation = EvidencePresentationResolver.resolve(item);
        expect(presentation.semanticKind, WorkspaceEvidenceKind.attachment);
        expect(presentation.previewKind, EvidencePresentationKind.video);
        expect(presentation.renderer, isA<VideoEvidenceRenderer>());
        expect(
          EvidencePresentationResolver.resolveCompleteRecordPresentation(item),
          isA<VideoEvidenceRenderer>(),
        );
      },
    );

    test(
      'file-attached image stays attachment / document presentation after hydrate',
      () async {
        const incidentId = 'incident-14a-file-img';
        final now = DateTime.now();
        await LocalEvidenceCache.upsert(
          CachedEvidenceEntry(
            evidenceId: 'ev-file-img',
            incidentId: incidentId,
            userId: 'user-14a',
            evidenceType: EvidenceRecordType.document,
            createdAt: now,
            capturedAt: now,
            syncStatus: EvidenceSyncStatus.localCaptured,
            localFilePath: p.join(tempRoot.path, 'picked.jpg'),
            fileName: 'picked.jpg',
            mimeType: 'image/jpeg',
            captureMode: WorkspaceCaptureMode.file,
            fileSizeBytes: 24,
          ),
        );

        final session = WorkspaceSession.instance;
        session.controller.replaceAggregate(
          IncidentAggregate.shell(id: incidentId),
        );
        final inserted = await LocalEvidenceHydrator.hydrateIncident(
          incidentId: incidentId,
          repository: session.controller.evidenceRepository,
          userId: 'user-14a',
        );
        expect(inserted, 1);
        session.controller.scheduleCaptureMetadataPersist();

        final item = session.controller.journeyEvidenceItems.single;
        expect(item.kind, WorkspaceEvidenceKind.attachment);
        final presentation = EvidencePresentationResolver.resolve(item);
        expect(presentation.previewKind, EvidencePresentationKind.document);
        expect(presentation.renderer, isA<AttachmentEvidenceRenderer>());
      },
    );
  });
}
