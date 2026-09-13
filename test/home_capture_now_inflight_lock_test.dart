import 'dart:async';
import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/screens/home_screen.dart';
import 'package:evidence_vault/services/capture/capture_session_manager.dart';
import 'package:evidence_vault/services/persistence/local_capture_session_store.dart';
import 'package:evidence_vault/services/storage/file_attach_flow.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/sync/evidence_sync_manager.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/home/quick_capture_button.dart';
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
    tempRoot = await Directory.systemTemp.createTemp('ev_32_capture_now_lock_');
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
      userId: 'user-32',
    );
    HomeScreen.resetCaptureNowLaunchForTests();
  }

  Future<void> cleanupEnv() async {
    HomeScreen.resetCaptureNowLaunchForTests();
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

  Future<void> seedExisting({String title = 'Existing incident'}) async {
    final session = WorkspaceSession.instance;
    final incidentId = session.controller.currentIncident.id;
    await manager.getOrCreateActiveSession(
      incidentId: incidentId,
      userId: 'user-32',
    );
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: incidentId, title: title),
    );
  }

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext navContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            navContext = context;
            return const Scaffold(
              body: SizedBox.expand(child: Text('host')),
            );
          },
        ),
      ),
    );
    await tester.pump();
    return navContext;
  }

  void stubCockpitHandoff() {
    HomeScreen.debugCockpitOpenOverride = ({
      required context,
      required mode,
      required onOpened,
    }) async {
      onOpened();
    };
  }

  void stubNoteCancel() {
    HomeScreen.debugOpenNoteForTests = (_) async => null;
  }

  setUp(() async {
    await prepareEnv();
  });

  tearDown(() async {
    await cleanupEnv();
  });

  group('single Capture Now mints exactly one incident', () {
    for (final type in [
      QuickCaptureType.photo,
      QuickCaptureType.video,
      QuickCaptureType.voice,
    ]) {
      testWidgets('single ${type.name} Capture Now creates exactly one incident',
          (tester) async {
        await tester.runAsync(seedExisting);
        final priorId =
            WorkspaceSession.instance.controller.currentIncident.id;
        final context = await pumpHost(tester);
        stubCockpitHandoff();

        await tester.runAsync(() {
          return HomeScreen.handleCaptureNowTap(context, type);
        });

        expect(HomeScreen.debugBeginNewCaptureIncidentCount, 1);
        expect(
          WorkspaceSession.instance.controller.currentIncident.id,
          isNot(priorId),
        );
        expect(HomeScreen.captureNowLaunchInFlight, isFalse);
      });
    }

    testWidgets('single Note Capture Now creates exactly one incident',
        (tester) async {
      await tester.runAsync(seedExisting);
      final priorId =
          WorkspaceSession.instance.controller.currentIncident.id;
      final context = await pumpHost(tester);
      stubNoteCancel();

      await tester.runAsync(() {
        return HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.note,
        );
      });

      expect(HomeScreen.debugBeginNewCaptureIncidentCount, 1);
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        isNot(priorId),
      );
      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
    });
  });

  group('rapid second Capture Now tap is rejected by the launch lock', () {
    Future<void> proveDoubleTapRejected({
      required WidgetTester tester,
      required BuildContext context,
      required QuickCaptureType type,
    }) async {
      await tester.runAsync(() async {
        final hold = Completer<void>();
        HomeScreen.debugAfterCaptureNowLockAcquired = () => hold.future;
        final first = HomeScreen.handleCaptureNowTap(context, type);
        expect(HomeScreen.captureNowLaunchInFlight, isTrue);
        expect(HomeScreen.debugBeginNewCaptureIncidentCount, 0);

        await HomeScreen.handleCaptureNowTap(context, type);
        expect(HomeScreen.debugBeginNewCaptureIncidentCount, 0);

        hold.complete();
        await first;
      });

      expect(HomeScreen.debugBeginNewCaptureIncidentCount, 1);
      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
    }

    for (final type in [
      QuickCaptureType.photo,
      QuickCaptureType.video,
      QuickCaptureType.voice,
    ]) {
      testWidgets(
          'rapid double ${type.name} tap creates only one incident',
          (tester) async {
        await tester.runAsync(seedExisting);
        final context = await pumpHost(tester);
        stubCockpitHandoff();
        await proveDoubleTapRejected(
          tester: tester,
          context: context,
          type: type,
        );
      });
    }

    testWidgets('rapid double Note tap creates only one incident',
        (tester) async {
      await tester.runAsync(seedExisting);
      final context = await pumpHost(tester);
      stubNoteCancel();
      await proveDoubleTapRejected(
        tester: tester,
        context: context,
        type: QuickCaptureType.note,
      );
    });

    testWidgets(
        'second tap does not call beginNewCaptureIncident and first stays bound',
        (tester) async {
      await tester.runAsync(seedExisting);
      final context = await pumpHost(tester);

      await tester.runAsync(() async {
        final entered = Completer<void>();
        final release = Completer<void>();
        HomeScreen.debugCockpitOpenOverride = ({
          required context,
          required mode,
          required onOpened,
        }) async {
          entered.complete();
          await release.future;
          onOpened();
        };
        final first = HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.photo,
        );
        await entered.future;
        final incidentA =
            WorkspaceSession.instance.controller.currentIncident.id;
        expect(HomeScreen.debugBeginNewCaptureIncidentCount, 1);

        await HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.video,
        );
        await HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.note,
        );

        expect(HomeScreen.debugBeginNewCaptureIncidentCount, 1);
        expect(
          WorkspaceSession.instance.controller.currentIncident.id,
          incidentA,
        );

        release.complete();
        await first;
        expect(
          WorkspaceSession.instance.controller.currentIncident.id,
          incidentA,
        );
      });
    });
  });

  group('guard release', () {
    testWidgets('guard releases after successful Cockpit launch',
        (tester) async {
      await tester.runAsync(seedExisting);
      final context = await pumpHost(tester);
      stubCockpitHandoff();

      await tester.runAsync(() {
        return HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.photo,
        );
      });

      expect(HomeScreen.captureNowLaunchInFlight, isFalse);

      final firstId =
          WorkspaceSession.instance.controller.currentIncident.id;
      await tester.runAsync(() {
        return HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.video,
        );
      });
      expect(HomeScreen.debugBeginNewCaptureIncidentCount, 2);
      expect(
        WorkspaceSession.instance.controller.currentIncident.id,
        isNot(firstId),
      );
    });

    testWidgets('guard releases after cancelled Cockpit launch',
        (tester) async {
      await tester.runAsync(seedExisting);
      final context = await pumpHost(tester);
      HomeScreen.debugCockpitOpenOverride = ({
        required context,
        required mode,
        required onOpened,
      }) async {
        // Cancelled before the route is handed off.
      };

      await tester.runAsync(() {
        return HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.photo,
        );
      });

      expect(HomeScreen.captureNowLaunchInFlight, isFalse);

      stubCockpitHandoff();
      await tester.runAsync(() {
        return HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.photo,
        );
      });
      expect(HomeScreen.debugBeginNewCaptureIncidentCount, 2);
    });

    testWidgets('guard releases after Note cancellation', (tester) async {
      await tester.runAsync(seedExisting);
      final context = await pumpHost(tester);
      stubNoteCancel();

      await tester.runAsync(() {
        return HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.note,
        );
      });

      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
      await tester.runAsync(() {
        return HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.note,
        );
      });
      expect(HomeScreen.debugBeginNewCaptureIncidentCount, 2);
    });

    testWidgets('guard releases after launch exception', (tester) async {
      await tester.runAsync(seedExisting);
      final context = await pumpHost(tester);
      HomeScreen.debugAfterCaptureNowLockAcquired = () async {
        throw StateError('launch failed');
      };

      await expectLater(
        HomeScreen.handleCaptureNowTap(context, QuickCaptureType.photo),
        throwsA(isA<StateError>()),
      );
      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
      expect(HomeScreen.debugBeginNewCaptureIncidentCount, 0);

      HomeScreen.debugAfterCaptureNowLockAcquired = null;
      stubCockpitHandoff();
      await tester.runAsync(() {
        return HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.photo,
        );
      });
      expect(HomeScreen.debugBeginNewCaptureIncidentCount, 1);
      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
    });

    testWidgets('widget disposal cannot leave a persistent logical lock',
        (tester) async {
      await tester.runAsync(seedExisting);
      stubCockpitHandoff();
      final context = await pumpHost(tester);

      await tester.runAsync(() async {
        final hold = Completer<void>();
        HomeScreen.debugAfterCaptureNowLockAcquired = () => hold.future;
        final launched = HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.photo,
        );
        expect(HomeScreen.captureNowLaunchInFlight, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        hold.complete();
        await launched;
      });

      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
    });
  });

  group('adjacent paths stay unchanged', () {
    test('File Capture Now lock remains FileAttachFlow, independent of Home',
        () {
      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
      expect(FileAttachFlow.attachInProgress, isFalse);

      FileAttachFlow.attachInProgress = true;
      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
      expect(FileAttachFlow.attachInProgress, isTrue);
      FileAttachFlow.endAttach();
      expect(FileAttachFlow.attachInProgress, isFalse);
    });

    testWidgets(
        'Continue Preserving is not gated by the Capture Now launch lock',
        (tester) async {
      await tester.runAsync(seedExisting);
      final existingId =
          WorkspaceSession.instance.controller.currentIncident.id;
      stubCockpitHandoff();
      final context = await pumpHost(tester);

      await tester.runAsync(() async {
        final hold = Completer<void>();
        HomeScreen.debugAfterCaptureNowLockAcquired = () => hold.future;
        final launch = HomeScreen.handleCaptureNowTap(
          context,
          QuickCaptureType.photo,
        );
        expect(HomeScreen.captureNowLaunchInFlight, isTrue);
        expect(HomeScreen.debugBeginNewCaptureIncidentCount, 0);

        final opened =
            await WorkspaceSession.instance.openIncident(existingId);
        expect(opened, isTrue);
        expect(
          WorkspaceSession.instance.controller.currentIncident.id,
          existingId,
        );
        expect(HomeScreen.debugBeginNewCaptureIncidentCount, 0);

        hold.complete();
        await launch;
      });
      expect(HomeScreen.captureNowLaunchInFlight, isFalse);
    });
  });
}
