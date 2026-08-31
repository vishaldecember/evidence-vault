import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/capture/capture_sticky_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<void> prepareEnv() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_cockpit_65_');
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
      userId: 'user-6c5',
    );
  }

  Future<void> cleanupEnv() async {
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

  Future<void> seed({String title = 'Workplace incident'}) async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-6c5',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: title),
    );
  }

  Future<void> pumpCockpit(WidgetTester tester) async {
    await tester.runAsync(() => seed());
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureCockpitScreen(
          controller: WorkspaceSession.instance.controller,
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  testWidgets('Cockpit modality bar is Photo/Video/Voice only', (tester) async {
    await pumpCockpit(tester);

    expect(find.byKey(const Key('capture_cockpit_modality_bar')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_photo')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_video')), findsOneWidget);
    expect(find.byKey(const Key('capture_modality_voice')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_note')), findsNothing);
    expect(find.byKey(const Key('capture_action_file')), findsNothing);
    expect(find.byKey(const Key('capture_sticky_bar')), findsNothing);
  });

  testWidgets('modality bar remains while evidence changes', (tester) async {
    await pumpCockpit(tester);
    final controller = WorkspaceSession.instance.controller;
    await tester.runAsync(() async {
      await controller.preserveTextNote('Timeline grows');
    });
    await tester.pump();

    expect(find.byKey(const Key('capture_cockpit_modality_bar')), findsOneWidget);
    expect(controller.currentIncident.evidenceCount, greaterThan(0));
  });

  testWidgets('Photo/Video/Voice modality switching remains functional',
      (tester) async {
    await pumpCockpit(tester);
    expect(find.text('Camera'), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_modality_video')));
    await tester.pump();
    expect(find.byKey(const Key('capture_cockpit_screen')), findsOneWidget);
    expect(find.text('Video'), findsWidgets);

    await tester.tap(find.byKey(const Key('capture_modality_voice')));
    await tester.pump();
    expect(find.text('Voice'), findsWidgets);

    await tester.tap(find.byKey(const Key('capture_modality_photo')));
    await tester.pump();
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('workspace sticky bar widget exposes five actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureStickyBar(
            onModalitySelected: (_) {},
            onNoteTap: () {},
            onFileTap: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('capture_sticky_bar')), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
    expect(find.byKey(const Key('capture_action_photo')), findsOneWidget);
    expect(find.byKey(const Key('capture_action_note')), findsOneWidget);
  });
}
