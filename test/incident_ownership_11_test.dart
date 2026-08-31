import 'dart:io';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_provenance_event.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/evidence_workspace_content.dart';
import 'package:evidence_vault/screens/investigation_workspace_screen.dart';
import 'package:evidence_vault/services/capture/capture_engine.dart';
import 'package:evidence_vault/services/capture/capture_job.dart';
import 'package:evidence_vault/services/capture/capture_provenance.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/durable_upload_queue.dart';
import 'package:evidence_vault/services/storage/evidence_upload_coordinator.dart';
import 'package:evidence_vault/services/storage/evidence_upload_queue.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/storage_upload_result.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/sync/evidence_sync_queue.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/investigation/inspector_context_section.dart';
import 'package:evidence_vault/widgets/investigation/investigate_incident_scope.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/workspace/workspace_body_presentation.dart';
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

class _SwitchingHost implements CapturePipelineHost {
  _SwitchingHost();

  var _reads = 0;
  final calls = <String>[];
  var created = false;

  @override
  String get captureIncidentId {
    _reads++;
    return _reads == 1 ? 'inc-A' : 'inc-B';
  }

  @override
  String get captureIncidentTitle => '';

  @override
  bool updateLifecycleStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  }) =>
      false;

  @override
  void abandonFailedLocalCapture(String evidenceId) {
    calls.add('abandon:$evidenceId');
  }

  @override
  void attachCaptureThumbnail({
    required String evidenceId,
    required String filePath,
    String? fileName,
    String? thumbnailPath,
    int? fileSizeBytes,
  }) {
    calls.add('attach:$evidenceId');
  }

  @override
  void scheduleCaptureMetadataPersist() {
    calls.add('persist');
  }

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

WorkspaceEvidenceController _controllerFor({
  required String id,
  required String title,
}) {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: id, title: title),
  );
}

Future<void> _pumpBoundInvestigate(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required String boundIncidentId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: InvestigationWorkspaceScreen(
        controller: controller,
        boundIncidentId: boundIncidentId,
        onOpenFullEvidenceRecord: (_) async {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    LocalEvidenceCache.resetForTests();
    tempRoot = await Directory.systemTemp.createTemp('ev_step11_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
  });

  tearDown(() async {
    await EvidenceSyncManager.instance.resetForTests();
    UserSessionService.resetForTests();
    LocalEvidenceCache.resetForTests();
    WorkspaceSession.instance.reset();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  EvidenceSyncQueueItem queueItem({
    required String evidenceId,
    required String userId,
    String incidentId = 'inc-A',
  }) {
    return EvidenceSyncQueueItem(
      evidenceId: evidenceId,
      incidentId: incidentId,
      userId: userId,
      lane: EvidenceSyncLane.fastSync,
      priority: SyncWorkPriority.high,
      enqueuedAt: DateTime.now(),
      mode: WorkspaceCaptureMode.photo,
      localFilePath: p.join(tempRoot.path, '$evidenceId.jpg'),
    );
  }

  Future<void> seedCache({
    required String evidenceId,
    required String userId,
    String incidentId = 'inc-A',
  }) async {
    final path = p.join(tempRoot.path, '$evidenceId.jpg');
    await File(path).writeAsBytes(List<int>.filled(8, 1));
    final now = DateTime.now();
    await LocalEvidenceCache.upsert(
      CachedEvidenceEntry(
        evidenceId: evidenceId,
        incidentId: incidentId,
        userId: userId,
        evidenceType: EvidenceRecordType.photo,
        createdAt: now,
        capturedAt: now,
        syncStatus: EvidenceSyncStatus.queuedForUpload,
        localFilePath: path,
        captureMode: WorkspaceCaptureMode.photo,
        fileName: '$evidenceId.jpg',
        fileSizeBytes: 8,
      ),
    );
  }

  group('11A upload ownership', () {
    test('1-3. User A queue item cannot upload under User B', () async {
      await seedCache(evidenceId: 'ev-a', userId: 'user-a');
      final queue = EvidenceSyncQueue();
      final manager = EvidenceSyncManager(
        queue: queue,
        maxConcurrentUploads: 1,
        enableDebugLogging: false,
      );
      var uploads = 0;
      manager.setUploadFnForTests((item) async {
        uploads++;
        return StorageUploadResult(
          storagePath: 'users/${item.userId}/incidents/${item.incidentId}/photos/${item.evidenceId}',
          downloadUrl: 'https://example.com/${item.evidenceId}',
          fileSize: 8,
          contentType: 'image/jpeg',
        );
      });

      UserSessionService.establishSession(
        email: 'a@test.com',
        name: 'A',
        userId: 'user-a',
      );
      await queue.enqueue(queueItem(evidenceId: 'ev-a', userId: 'user-a'));

      UserSessionService.signOut();
      UserSessionService.establishSession(
        email: 'b@test.com',
        name: 'B',
        userId: 'user-b',
      );

      await manager.schedule();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(uploads, 0);
      expect(queue.items.single.userId, 'user-a');
      expect(queue.items.single.incidentId, 'inc-A');
      expect(
        (await LocalEvidenceCache.byId('ev-a'))?.syncStatus,
        isNot(EvidenceSyncStatus.ready),
      );

      await manager.resetForTests();
    });

    test('4. Queue item incidentId is never rewritten', () async {
      final item = queueItem(
        evidenceId: 'ev-a',
        userId: 'user-a',
        incidentId: 'inc-A',
      );
      final bumped = item.copyWith(attempts: 3);
      expect(bumped.incidentId, 'inc-A');
      expect(bumped.userId, 'user-a');
      expect(bumped.evidenceId, 'ev-a');
    });

    test('5. Same-user logout/login still uploads', () async {
      await seedCache(evidenceId: 'ev-a', userId: 'user-a');
      final queue = EvidenceSyncQueue();
      final manager = EvidenceSyncManager(
        queue: queue,
        maxConcurrentUploads: 1,
        enableDebugLogging: false,
      );
      var uploads = 0;
      manager.setUploadFnForTests((item) async {
        uploads++;
        expect(item.userId, 'user-a');
        expect(item.incidentId, 'inc-A');
        return StorageUploadResult(
          storagePath: 'users/user-a/incidents/inc-A/photos/ev-a',
          downloadUrl: 'https://example.com/ev-a',
          fileSize: 8,
          contentType: 'image/jpeg',
        );
      });

      UserSessionService.establishSession(
        email: 'a@test.com',
        name: 'A',
        userId: 'user-a',
      );
      await queue.enqueue(queueItem(evidenceId: 'ev-a', userId: 'user-a'));
      UserSessionService.signOut();
      UserSessionService.establishSession(
        email: 'a@test.com',
        name: 'A',
        userId: 'user-a',
      );

      await manager.schedule();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(uploads, 1);
      expect(
        (await LocalEvidenceCache.byId('ev-a'))?.syncStatus,
        EvidenceSyncStatus.ready,
      );
      await manager.resetForTests();
    });

    test('legacy queue JSON without userId fails closed', () {
      final item = EvidenceSyncQueueItem.fromJson({
        'evidenceId': 'ev-legacy',
        'incidentId': 'inc-A',
        'lane': 'fastSync',
        'priority': 'high',
        'enqueuedAt': DateTime.now().toIso8601String(),
      });
      expect(item.userId, isEmpty);
      expect(item.isOwnedBy('user-b'), isFalse);
      expect(item.isOwnedBy(''), isFalse);
    });

    test('DurableUploadQueue persists userId and does not remap', () async {
      final durable = DurableUploadQueue();
      await durable.enqueue(
        buildQueuedEvidenceUpload(
          evidenceId: 'ev-a',
          incidentId: 'inc-A',
          userId: 'user-a',
          localFilePath: '/tmp/a.jpg',
          mode: WorkspaceCaptureMode.photo,
          intendedStoragePath: 'users/user-a/incidents/inc-A/photos/ev-a',
        ),
      );
      final restored = DurableUploadQueue();
      await restored.load();
      expect(restored.items.single.userId, 'user-a');
      expect(restored.items.single.incidentId, 'inc-A');
      expect(restored.items.single.isOwnedBy('user-b'), isFalse);
    });

    test('peekLane skips foreign-user work', () async {
      final queue = EvidenceSyncQueue();
      await queue.enqueue(queueItem(evidenceId: 'ev-a', userId: 'user-a'));
      expect(queue.peekLane(EvidenceSyncLane.fastSync, ownerUserId: 'user-b'), isNull);
      expect(
        queue.peekLane(EvidenceSyncLane.fastSync, ownerUserId: 'user-a')?.evidenceId,
        'ev-a',
      );
    });
  });

  group('11B async incident identity', () {
    test('6/12. Capture started for A is not remapped to B', () async {
      final host = _SwitchingHost();
      var created = false;
      await expectLater(
        CaptureEngine.instance.receive(
          host: host,
          mode: WorkspaceCaptureMode.note,
          noteText: 'stale',
          createLocalEvidence: (_) {
            created = true;
            return 'ev-stale';
          },
          uploadCoordinator: EvidenceUploadCoordinator(
            queue: EvidenceUploadQueue(),
          ),
        ),
        throwsA(isA<StaleCaptureIncidentException>()),
      );
      expect(created, isFalse);
      expect(host.calls, isNot(contains('persist')));
    });

    testWidgets('7. Inspector autosave started for A is rejected after switch',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = _controllerFor(id: 'inc-A', title: 'Alpha');
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      final evidence = controller.sortedItems.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showInvestigationEvidenceInspectorModal(
                    context: context,
                    evidence: evidence,
                    controller: controller,
                    boundIncidentId: 'inc-A',
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      controller.replaceAggregate(
        IncidentAggregate.shell(id: 'inc-B', title: 'Beta'),
      );
      await tester.pump();

      final addObservation = find.byKey(
        const Key('evidence_inspector_add_observation'),
      );
      if (addObservation.evaluate().isNotEmpty) {
        await tester.ensureVisible(addObservation);
        await tester.tap(addObservation);
        await tester.pump();
      }
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == InspectorContextSection.placeholder,
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'Should not land on B');
      await tester.pump();
      await tester.pump(InvestigationEvidenceInspectorModal.persistDebounce);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.currentIncident.id, 'inc-B');
      expect(controller.currentIncident.evidenceCount, 0);
      expect(controller.sortedItems, isEmpty);
    });

    testWidgets('8. Reflection write started for A is rejected after switch',
        (tester) async {
      final controller = _controllerFor(id: 'inc-A', title: 'Alpha');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceWorkspaceContent(
              controller: controller,
              boundIncidentId: 'inc-A',
              presentation: WorkspaceBodyPresentation.capture,
              onShowEvidenceInspector: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();

      controller.replaceAggregate(
        IncidentAggregate.shell(id: 'inc-B', title: 'Beta'),
      );
      await tester.pump();

      final state = tester.state<EvidenceWorkspaceContentState>(
        find.byType(EvidenceWorkspaceContent),
      );
      state.applyAddReflection(title: 'Note', body: 'Should not persist');
      expect(controller.sortedReflections, isEmpty);
    });

    testWidgets('9. Investigation header rename started for A is rejected',
        (tester) async {
      final controller = _controllerFor(id: 'inc-A', title: 'Alpha');
      await _pumpBoundInvestigate(
        tester,
        controller: controller,
        boundIncidentId: 'inc-A',
      );
      controller.replaceAggregate(
        IncidentAggregate.shell(id: 'inc-B', title: 'Beta'),
      );
      await tester.pump();
      tester
          .state<InvestigationWorkspaceScreenState>(
            find.byType(InvestigationWorkspaceScreen),
          )
          .applyIncidentName('Renamed from stale A');
      expect(controller.currentIncident.title, 'Beta');
    });

    testWidgets('10. Primary/group/narrative mutations cannot cross incidents',
        (tester) async {
      final controller = _controllerFor(id: 'inc-A', title: 'Alpha');
      controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      final evidenceId = controller.sortedItems.first.id;
      await _pumpBoundInvestigate(
        tester,
        controller: controller,
        boundIncidentId: 'inc-A',
      );
      controller.replaceAggregate(
        IncidentAggregate.shell(id: 'inc-B', title: 'Beta'),
      );
      await tester.pump();
      final state = tester.state<InvestigationWorkspaceScreenState>(
        find.byType(InvestigationWorkspaceScreen),
      );
      state.applySetPrimaryEvidence(evidenceId, true);
      state.applyCommitRelationshipGroup([evidenceId, 'other']);
      state.applyNarrativeEventTitle('missing', 'Stale title');
      expect(controller.currentIncident.id, 'inc-B');
      expect(controller.currentIncident.evidenceCount, 0);
      expect(controller.currentIncident.relationshipGroups, isEmpty);
    });

    testWidgets('11. ensureInvestigationRelationships skips the wrong bound',
        (tester) async {
      final controller = _controllerFor(id: 'inc-A', title: 'Alpha');
      await _pumpBoundInvestigate(
        tester,
        controller: controller,
        boundIncidentId: 'inc-A',
      );
      controller.replaceAggregate(
        IncidentAggregate.shell(id: 'inc-B', title: 'Beta'),
      );
      await tester.pump();
      tester
          .state<InvestigationWorkspaceScreenState>(
            find.byType(InvestigationWorkspaceScreen),
          )
          .ensureInvestigationRelationshipsIfBound();
      expect(controller.currentIncident.id, 'inc-B');
      expect(controller.state.relationships, isEmpty);
    });

    test('sessionMatchesBound never remaps A onto B', () {
      expect(
        InvestigateIncidentScope.sessionMatchesBound('inc-A', 'inc-B'),
        isFalse,
      );
    });
  });

  group('11C media durability', () {
    test('13-15. Ephemeral or missing media does not preserve evidence',
        () async {
      final controller = _controllerFor(id: 'inc-A', title: 'Alpha');
      UserSessionService.establishSession(
        email: 'a@test.com',
        name: 'A',
        userId: 'user-a',
      );

      await expectLater(
        controller.preserveEvidenceWithMedia(
          mode: WorkspaceCaptureMode.photo,
          media: const CapturedMediaFile(
            localPath: '/missing/ephemeral.jpg',
            fileName: 'ephemeral.jpg',
            fileSizeBytes: 10,
          ),
        ),
        throwsA(isA<MediaDurabilityException>()),
      );
      expect(controller.currentIncident.evidenceCount, 0);

      await expectLater(
        LocalEvidenceCache.durableize(
          incidentId: 'inc-A',
          evidenceId: 'ev-missing',
          media: const CapturedMediaFile(
            localPath: '/missing/gone.jpg',
            fileName: 'gone.jpg',
            fileSizeBytes: 4,
          ),
        ),
        throwsA(isA<MediaDurabilityException>()),
      );
    });

    test('16. Successful photo/video/voice capture remains intact', () async {
      final controller = _controllerFor(id: 'inc-A', title: 'Alpha');
      UserSessionService.establishSession(
        email: 'a@test.com',
        name: 'A',
        userId: 'user-a',
      );

      Future<CapturedMediaFile> writeMedia(String name) async {
        final file = File(p.join(tempRoot.path, name));
        await file.writeAsBytes(List<int>.filled(24, 3));
        return CapturedMediaFile(
          localPath: file.path,
          fileName: name,
          fileSizeBytes: 24,
        );
      }

      final photoId = await controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.photo,
        media: await writeMedia('ok.jpg'),
      );
      final videoId = await controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.video,
        media: await writeMedia('ok.mp4'),
      );
      final voiceId = await controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.voice,
        media: await writeMedia('ok.m4a'),
      );

      expect(controller.currentIncident.evidenceCount, 3);
      expect({photoId, videoId, voiceId}.length, 3);
      for (final item in controller.sortedItems) {
        expect(item.incidentId, 'inc-A');
        expect(item.filePath, isNotNull);
        expect(File(item.filePath!).existsSync(), isTrue);
        expect(item.filePath!.contains('evidence_cache'), isTrue);
      }
    });
  });
}
