import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/navigation/app_navigator.dart';
import 'package:evidence_vault/screens/evidence_workspace_content.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/file_attach_flow.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final manager = CaptureSessionManager.instance;
  const userId = 'user-34a-shell-file';

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_34a_shell_file_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    await manager.resetForTests();
    await EvidenceSyncManager.instance.resetForTests();
    EvidenceSyncManager.instance.setMaxConcurrentUploads(0);
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: userId,
    );
    FileAttachFlow.endAttach();
  }

  Future<void> cleanupEnv() async {
    FileAttachFlow.endAttach();
    await EvidenceSyncManager.instance.resetForTests();
    await manager.resetForTests();
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<CapturedMediaFile> seedFile({
    required String name,
    int bytes = 64,
  }) async {
    final file = File(p.join(tempRoot.path, name));
    await file.writeAsBytes(List<int>.filled(bytes, 1));
    return CapturedMediaFile(
      localPath: file.path,
      fileName: name,
      fileSizeBytes: bytes,
    );
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  test('shell Capture File source delegates to FileAttachFlow, not raw acquire',
      () {
    final source = File(
      'lib/screens/evidence_workspace_content.dart',
    ).readAsStringSync();
    expect(source.contains('CaptureMediaService.acquire'), isFalse);
    expect(source.contains('FileAttachFlow.attach'), isTrue);
    expect(source.contains('FileAttachOrigin.workspaceSticky'), isTrue);
  });

  testWidgets(
      'shell Capture File uses FileAttachFlow and keeps the same incident',
      (tester) async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await manager.getOrCreateActiveSession(
        incidentId: incidentId,
        userId: userId,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: IncidentWorkspaceShell(
          incidentId: incidentId,
          controller: session.controller,
          initialStage: InvestigationMethodologyStage.capture,
        ),
      ),
    );
    await tester.pump();

    final state = tester.state<EvidenceWorkspaceContentState>(
      find.byType(EvidenceWorkspaceContent),
    );

    late FileAttachResult result;
    await tester.runAsync(() async {
      final media = await seedFile(name: 'shell-capture.pdf');
      result = await state.attachCaptureFile(acquireFile: () async => media);
    });
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.succeeded);
    expect(result.sourceIncidentId, incidentId);
    expect(session.controller.currentIncident.id, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 1);
    expect(FileAttachFlow.attachInProgress, isFalse);
  });

  testWidgets('shell Capture File cancel does not add evidence or change id',
      (tester) async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await tester.runAsync(() async {
      await manager.getOrCreateActiveSession(
        incidentId: incidentId,
        userId: userId,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: IncidentWorkspaceShell(
          incidentId: incidentId,
          controller: session.controller,
          initialStage: InvestigationMethodologyStage.capture,
        ),
      ),
    );
    await tester.pump();

    final state = tester.state<EvidenceWorkspaceContentState>(
      find.byType(EvidenceWorkspaceContent),
    );

    late FileAttachResult result;
    await tester.runAsync(() async {
      result = await state.attachCaptureFile(acquireFile: () async => null);
    });
    await tester.pump();

    expect(result.outcome, FileAttachOutcome.cancelled);
    expect(result.sourceIncidentId, incidentId);
    expect(session.controller.currentIncident.id, incidentId);
    expect(session.controller.currentIncident.evidenceCount, 0);
  });
}
