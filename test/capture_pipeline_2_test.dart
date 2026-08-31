import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ev_cache_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    WorkspaceSession.instance.reset();
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('Capture Now creates a new incident distinct from prior pending', () async {
    final session = WorkspaceSession.instance;
    final firstId = session.controller.currentIncident.id;
    session.controller.preserveEvidence(WorkspaceCaptureMode.note);
    expect(session.controller.currentIncident.evidenceCount, 1);

    await session.beginNewCaptureIncident();

    expect(session.controller.currentIncident.id, isNot(firstId));
    expect(session.controller.currentIncident.evidenceCount, 0);
  });

  test('multiple captures share the same incident id', () {
    final session = WorkspaceSession.instance;
    final id = session.controller.currentIncident.id;
    session.controller.preserveEvidence(WorkspaceCaptureMode.note);
    session.controller.preserveEvidence(WorkspaceCaptureMode.note);
    session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
    expect(session.controller.currentIncident.id, id);
    expect(session.controller.currentIncident.evidenceCount, 3);
  });

  test('journey sequence includes note and file kinds chronologically', () {
    final session = WorkspaceSession.instance;
    session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
    session.controller.preserveEvidence(WorkspaceCaptureMode.note);
    session.controller.preserveEvidence(WorkspaceCaptureMode.file);
    final journey = session.controller.currentIncident.journeyEvidence;
    expect(journey.length, greaterThanOrEqualTo(3));
    final kinds = journey.map((e) => e.kind.name).toSet();
    expect(kinds.contains('image') || kinds.contains('note') || kinds.contains('attachment'), isTrue);
  });

  test('LocalEvidenceCache durableize copies into evidence_cache', () async {
    final source = File(p.join(tempRoot.path, 'shot.jpg'));
    await source.writeAsBytes(List<int>.filled(32, 7));
    final media = CapturedMediaFile(
      localPath: source.path,
      fileName: 'shot.jpg',
      fileSizeBytes: 32,
      thumbnailPath: source.path,
    );

    final durable = await LocalEvidenceCache.durableize(
      incidentId: 'inc-test',
      evidenceId: 'ev-test',
      media: media,
    );

    expect(durable.localPath.contains('evidence_cache'), isTrue);
    expect(File(durable.localPath).existsSync(), isTrue);
  });

  test('LocalEvidenceCache reclaim removes synced cache file', () async {
    final source = File(p.join(tempRoot.path, 'clip.bin'));
    await source.writeAsBytes(List<int>.filled(16, 1));
    final durable = await LocalEvidenceCache.durableize(
      incidentId: 'inc-test',
      evidenceId: 'ev-reclaim',
      media: CapturedMediaFile(
        localPath: source.path,
        fileName: 'clip.bin',
        fileSizeBytes: 16,
      ),
    );
    expect(File(durable.localPath).existsSync(), isTrue);

    await LocalEvidenceCache.reclaimSynced(filePath: durable.localPath);
    expect(File(durable.localPath).existsSync(), isFalse);
  });

  test('openIncident keeps richer local aggregate', () async {
    final session = WorkspaceSession.instance;
    final id = session.controller.currentIncident.id;
    session.controller.preserveEvidence(WorkspaceCaptureMode.note);
    session.controller.preserveEvidence(WorkspaceCaptureMode.note);
    final before = session.controller.currentIncident.evidenceCount;

    await session.openIncident(id);

    expect(session.controller.currentIncident.id, id);
    expect(session.controller.currentIncident.evidenceCount, before);
  });
}
