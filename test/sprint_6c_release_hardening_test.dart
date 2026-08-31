import 'dart:io';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/library_incident_record.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/capture/capture_cockpit_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/persistence/local_incident_pointer.dart';
import 'package:evidence_vault/services/storage/capture_media_service.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/storage/local_evidence_hydrator.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
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

  Future<void> prepareEnv({String userId = 'user-6c-harden'}) async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_6c_harden_');
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
    await LocalIncidentPointer.clearForTests(userId);
    IncidentLibraryService.instance.clear();
  }

  Future<void> cleanupEnv({String userId = 'user-6c-harden'}) async {
    await EvidenceSyncManager.instance.resetForTests();
    await manager.resetForTests();
    LocalEvidenceCache.resetForTests();
    LocalCaptureSessionStore.resetForTests();
    await LocalIncidentPointer.clearForTests(userId);
    IncidentLibraryService.instance.clear();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    try {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> pumpCockpit(
    WidgetTester tester,
    WorkspaceCaptureMode mode,
  ) async {
    final controller = WorkspaceSession.instance.controller;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureCockpitScreen(
          initialMode: mode,
          controller: controller,
        ),
      ),
    );
    await tester.pump();
  }

  group('Issue 1 — DONE commits pending capture (idempotent)', () {
    setUp(() async {
      await prepareEnv();
      final session = WorkspaceSession.instance;
      await manager.getOrCreateActiveSession(
        incidentId: session.controller.currentIncident.id,
        userId: 'user-6c-harden',
      );
    });

    tearDown(() async {
      await cleanupEnv();
    });

    testWidgets(
      'A. Photo preview → DONE → exactly one evidence record',
      (tester) async {
        final controller = WorkspaceSession.instance.controller;
        await pumpCockpit(tester, WorkspaceCaptureMode.photo);

        await tester.tap(find.byKey(const Key('photo_shutter')));
        await tester.pump();
        expect(find.byKey(const Key('capture_preview_accept')), findsOneWidget);
        expect(controller.currentIncident.evidenceCount, 0);

        await tester.tap(find.byKey(const Key('capture_cockpit_done')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.currentIncident.evidenceCount, 1);
      },
    );

    testWidgets(
      'B. Video preview → DONE → exactly one evidence record',
      (tester) async {
        final controller = WorkspaceSession.instance.controller;
        await pumpCockpit(tester, WorkspaceCaptureMode.video);

        await tester.tap(find.byKey(const Key('video_record')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('video_stop')));
        await tester.pump();
        expect(find.byKey(const Key('capture_preview_accept')), findsOneWidget);

        await tester.tap(find.byKey(const Key('capture_cockpit_done')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.currentIncident.evidenceCount, 1);
      },
    );

    testWidgets(
      'C. Voice preview → DONE → exactly one evidence record',
      (tester) async {
        final controller = WorkspaceSession.instance.controller;
        await pumpCockpit(tester, WorkspaceCaptureMode.voice);

        await tester.tap(find.byKey(const Key('voice_record')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('voice_stop')));
        await tester.pump();
        expect(find.text('Accept'), findsOneWidget);

        await tester.tap(find.byKey(const Key('capture_cockpit_done')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.currentIncident.evidenceCount, 1);
      },
    );

    testWidgets(
      'D. Accept then DONE → still exactly one evidence record',
      (tester) async {
        final controller = WorkspaceSession.instance.controller;
        await pumpCockpit(tester, WorkspaceCaptureMode.photo);

        await tester.tap(find.byKey(const Key('photo_shutter')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('capture_preview_accept')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.currentIncident.evidenceCount, 1);

        await tester.tap(find.byKey(const Key('capture_cockpit_done')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.currentIncident.evidenceCount, 1);
      },
    );

    testWidgets(
      'E. Discard then DONE → zero evidence for that capture',
      (tester) async {
        final controller = WorkspaceSession.instance.controller;
        await pumpCockpit(tester, WorkspaceCaptureMode.photo);

        await tester.tap(find.byKey(const Key('photo_shutter')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('capture_preview_discard')));
        await tester.pump();
        expect(controller.currentIncident.evidenceCount, 0);

        await tester.tap(find.byKey(const Key('capture_cockpit_done')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.currentIncident.evidenceCount, 0);
      },
    );

    testWidgets(
      'F. Active/incomplete capture → DONE must not create fake evidence',
      (tester) async {
        final controller = WorkspaceSession.instance.controller;
        await pumpCockpit(tester, WorkspaceCaptureMode.video);

        await tester.tap(find.byKey(const Key('video_record')));
        await tester.pump();
        expect(find.byKey(const Key('capture_preview_accept')), findsNothing);

        await tester.tap(find.byKey(const Key('capture_cockpit_done')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.currentIncident.evidenceCount, 0);
      },
    );
  });

  group('Issue 2 — offline / local-first capture', () {
    setUp(() async {
      await prepareEnv(userId: 'user-6c-offline');
    });

    tearDown(() async {
      await cleanupEnv(userId: 'user-6c-offline');
    });

    Future<File> seedFile(String name) async {
      final file = File('${tempRoot.path}/$name');
      await file.writeAsBytes(List<int>.filled(32, 7));
      return file;
    }

    test(
      'G/H/I. Photo/Video/Voice capture while offline → local evidence exists',
      () async {
        final controller = WorkspaceSession.instance.controller;
        final incidentId = controller.currentIncident.id;
        await manager.getOrCreateActiveSession(
          incidentId: incidentId,
          userId: 'user-6c-offline',
        );

        final photo = await seedFile('off_photo.jpg');
        final video = await seedFile('off_video.mp4');
        final voice = await seedFile('off_voice.m4a');

        await controller.preserveEvidenceWithMedia(
          mode: WorkspaceCaptureMode.photo,
          media: CapturedMediaFile(
            localPath: photo.path,
            fileName: 'off_photo.jpg',
            fileSizeBytes: 32,
            thumbnailPath: photo.path,
          ),
        );
        await controller.preserveEvidenceWithMedia(
          mode: WorkspaceCaptureMode.video,
          media: CapturedMediaFile(
            localPath: video.path,
            fileName: 'off_video.mp4',
            fileSizeBytes: 32,
          ),
        );
        await controller.preserveEvidenceWithMedia(
          mode: WorkspaceCaptureMode.voice,
          media: CapturedMediaFile(
            localPath: voice.path,
            fileName: 'off_voice.m4a',
            fileSizeBytes: 32,
          ),
        );

        expect(controller.currentIncident.evidenceCount, 3);
        final cached = await LocalEvidenceCache.forIncident(
          incidentId,
          userId: 'user-6c-offline',
        );
        expect(cached.length, 3);
        for (final entry in cached) {
          expect(
            entry.syncStatus == EvidenceSyncStatus.localCaptured ||
                entry.syncStatus == EvidenceSyncStatus.queuedForUpload,
            isTrue,
          );
          final path = entry.localFilePath;
          expect(path, isNotNull);
          expect(File(path!).existsSync(), isTrue);
        }
      },
    );

    test(
      'J. beginNewCaptureIncident does not await Firebase (completes promptly)',
      () async {
        final session = WorkspaceSession.instance;
        final priorId = session.controller.currentIncident.id;
        final photo = await seedFile('prior.jpg');
        await manager.getOrCreateActiveSession(
          incidentId: priorId,
          userId: 'user-6c-offline',
        );
        await session.controller.preserveEvidenceWithMedia(
          mode: WorkspaceCaptureMode.photo,
          media: CapturedMediaFile(
            localPath: photo.path,
            fileName: 'prior.jpg',
            fileSizeBytes: 32,
            thumbnailPath: photo.path,
          ),
        );
        expect(session.controller.currentIncident.evidenceCount, 1);

        final sw = Stopwatch()..start();
        await session.beginNewCaptureIncident().timeout(
          const Duration(seconds: 2),
        );
        sw.stop();

        expect(session.controller.currentIncident.id, isNot(priorId));
        expect(session.controller.currentIncident.evidenceCount, 0);
        expect(sw.elapsedMilliseconds, lessThan(1500));
      },
    );

    test(
      'K. Offline evidence survives app restart (cache hydrate)',
      () async {
        final session = WorkspaceSession.instance;
        final incidentId = session.controller.currentIncident.id;
        await manager.getOrCreateActiveSession(
          incidentId: incidentId,
          userId: 'user-6c-offline',
        );
        final photo = await seedFile('restart.jpg');
        await session.controller.preserveEvidenceWithMedia(
          mode: WorkspaceCaptureMode.photo,
          media: CapturedMediaFile(
            localPath: photo.path,
            fileName: 'restart.jpg',
            fileSizeBytes: 32,
            thumbnailPath: photo.path,
          ),
        );
        expect(session.controller.currentIncident.evidenceCount, 1);

        // Simulate restart: new controller shell + hydrate from local cache.
        session.controller.replaceAggregate(
          IncidentAggregate.shell(id: incidentId),
        );
        expect(session.controller.currentIncident.evidenceCount, 0);

        final n = await LocalEvidenceHydrator.hydrateIncident(
          incidentId: incidentId,
          repository: session.controller.evidenceRepository,
          userId: 'user-6c-offline',
        );
        session.controller.scheduleCaptureMetadataPersist();
        expect(n, 1);
        expect(session.controller.currentIncident.evidenceCount, 1);
        expect(session.controller.currentIncident.id, incidentId);
      },
    );

    test(
      'L. Pending evidence remains queued for later sync (no Firebase required)',
      () async {
        final controller = WorkspaceSession.instance.controller;
        final incidentId = controller.currentIncident.id;
        await manager.getOrCreateActiveSession(
          incidentId: incidentId,
          userId: 'user-6c-offline',
        );
        final photo = await seedFile('queued.jpg');
        final id = await controller.preserveEvidenceWithMedia(
          mode: WorkspaceCaptureMode.photo,
          media: CapturedMediaFile(
            localPath: photo.path,
            fileName: 'queued.jpg',
            fileSizeBytes: 32,
            thumbnailPath: photo.path,
          ),
        );
        final record = controller.evidenceRepository.recordById(id);
        expect(record, isNotNull);
        expect(
          record!.syncStatus == EvidenceSyncStatus.queuedForUpload ||
              record.syncStatus == EvidenceSyncStatus.localCaptured,
          isTrue,
        );
        // Uploads disabled — queue must not require connectivity to keep local row.
        expect(EvidenceSyncManager.instance.maxConcurrentUploads, 0);
        final cached = await LocalEvidenceCache.byId(id);
        expect(cached, isNotNull);
      },
    );
  });

  group('Issue 3 — incident title identity isolation', () {
    const userId = 'user-6c-titles';

    setUp(() async {
      await prepareEnv(userId: userId);
    });

    tearDown(() async {
      await cleanupEnv(userId: userId);
    });

    test('M–W. titles persist per incident id; rename isolates; evidence sticks',
        () async {
      // M. Incident A + Street Fight
      final controllerA = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'incident-A'),
      );
      controllerA.updateIncidentName('Street Fight');
      expect(controllerA.currentIncident.title, 'Street Fight');
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: 'incident-A',
        title: 'Street Fight',
      );

      // N. Incident B + Workplace Incident
      final controllerB = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'incident-B'),
      );
      controllerB.updateIncidentName('Workplace Incident');
      expect(controllerB.currentIncident.title, 'Workplace Incident');
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: 'incident-B',
        title: 'Workplace Incident',
      );

      // O. Incident C untitled
      final controllerC = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'incident-C'),
      );
      expect(controllerC.currentIncident.title, isEmpty);
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: 'incident-C',
      );

      // Seed Library cards
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: const [
          LibraryIncidentSummary(
            id: 'incident-A',
            title: 'Street Fight',
            evidenceCount: 1,
            contextEnrichedCount: 0,
            integrityVerified: false,
            lastPreserved: 'Just now',
            isInProgress: true,
          ),
          LibraryIncidentSummary(
            id: 'incident-B',
            title: 'Workplace Incident',
            evidenceCount: 1,
            contextEnrichedCount: 0,
            integrityVerified: false,
            lastPreserved: 'Just now',
            isInProgress: true,
          ),
          LibraryIncidentSummary(
            id: 'incident-C',
            title: 'Untitled Incident',
            evidenceCount: 0,
            contextEnrichedCount: 0,
            integrityVerified: false,
            lastPreserved: 'Just now',
            isInProgress: true,
          ),
        ],
        records: [
          LibraryIncidentRecord(
            id: 'incident-A',
            title: 'Street Fight',
            preservedAt: DateTime(2026, 1, 1),
          ),
          LibraryIncidentRecord(
            id: 'incident-B',
            title: 'Workplace Incident',
            preservedAt: DateTime(2026, 1, 2),
          ),
          LibraryIncidentRecord(
            id: 'incident-C',
            title: 'Untitled Incident',
            preservedAt: DateTime(2026, 1, 3),
          ),
        ],
      );

      // Attach evidence to A and B
      final photoA = File('${tempRoot.path}/a.jpg')
        ..writeAsBytesSync(List<int>.filled(16, 1));
      final photoB = File('${tempRoot.path}/b.jpg')
        ..writeAsBytesSync(List<int>.filled(16, 2));
      await manager.getOrCreateActiveSession(
        incidentId: 'incident-A',
        userId: userId,
      );
      final evidenceA = await controllerA.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.photo,
        media: CapturedMediaFile(
          localPath: photoA.path,
          fileName: 'a.jpg',
          fileSizeBytes: 16,
          thumbnailPath: photoA.path,
        ),
      );
      await manager.getOrCreateActiveSession(
        incidentId: 'incident-B',
        userId: userId,
      );
      final evidenceB = await controllerB.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.photo,
        media: CapturedMediaFile(
          localPath: photoB.path,
          fileName: 'b.jpg',
          fileSizeBytes: 16,
          thumbnailPath: photoB.path,
        ),
      );

      // P. Rename C → Apartment Dispute
      controllerC.updateIncidentName('Apartment Dispute');
      IncidentLibraryService.instance.patchTitle(
        'incident-C',
        'Apartment Dispute',
      );

      // Q/R/S
      expect(controllerA.currentIncident.title, 'Street Fight');
      expect(controllerB.currentIncident.title, 'Workplace Incident');
      expect(controllerC.currentIncident.title, 'Apartment Dispute');

      // T. Reload persistence — titles remain correct per id
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: 'incident-A',
        ),
        'Street Fight',
      );
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: 'incident-B',
        ),
        'Workplace Incident',
      );
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: 'incident-C',
        ),
        'Apartment Dispute',
      );

      // U. Evidence stays on original incident ids
      expect(
        controllerA.evidenceRepository.recordById(evidenceA)?.incidentId,
        'incident-A',
      );
      expect(
        controllerB.evidenceRepository.recordById(evidenceB)?.incidentId,
        'incident-B',
      );
      expect(controllerA.currentIncident.id, 'incident-A');
      expect(controllerB.currentIncident.id, 'incident-B');
      expect(controllerC.currentIncident.id, 'incident-C');

      // V. Library cards show correct titles
      final byId = {
        for (final s in IncidentLibraryService.instance.summaries) s.id: s.title,
      };
      expect(byId['incident-A'], 'Street Fight');
      expect(byId['incident-B'], 'Workplace Incident');
      expect(byId['incident-C'], 'Apartment Dispute');

      // W. Workspace (selected controller) shows its own title
      expect(controllerA.currentIncident.title, 'Street Fight');
      expect(controllerC.currentIncident.title, 'Apartment Dispute');
    });

    test('renaming C never bleeds into A/B via LocalIncidentPointer', () async {
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: 'incident-A',
        title: 'Street Fight',
      );
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: 'incident-B',
        title: 'Workplace Incident',
      );
      await LocalIncidentPointer.remember(
        userId: userId,
        incidentId: 'incident-C',
        title: 'Apartment Dispute',
      );

      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: 'incident-A',
        ),
        'Street Fight',
      );
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: 'incident-B',
        ),
        'Workplace Incident',
      );
      expect(
        await LocalIncidentPointer.recallTitleForIncident(
          userId: userId,
          incidentId: 'incident-C',
        ),
        'Apartment Dispute',
      );
    });
  });
}
