import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/persistence/local_incident_pointer.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

LibraryIncidentSummary? _card(String incidentId) {
  for (final s in IncidentLibraryService.instance.summaries) {
    if (s.id == incidentId) {
      return s;
    }
  }
  return null;
}

Future<void> _seedLocalEvidence({
  required String evidenceId,
  required String incidentId,
  required String userId,
}) async {
  final now = DateTime.now();
  await LocalEvidenceCache.upsert(
    CachedEvidenceEntry(
      evidenceId: evidenceId,
      incidentId: incidentId,
      userId: userId,
      evidenceType: EvidenceRecordType.photo,
      createdAt: now,
      capturedAt: now,
      syncStatus: EvidenceSyncStatus.localCaptured,
      captureMode: WorkspaceCaptureMode.photo,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-library-count';
  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_lib_count_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: userId,
    );
    await LocalIncidentPointer.clearForTests(userId);
    IncidentLibraryService.instance.clear();
  });

  tearDown(() async {
    await LocalIncidentPointer.clearForTests(userId);
    IncidentLibraryService.instance.clear();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    LocalEvidenceCache.resetForTests();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('Library evidence count (local-first)', () {
    test('A. first incident with one evidence → Library count = 1', () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      final firstId = session.controller.currentIncident.id;
      expect(firstId, isNotEmpty);

      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      expect(session.controller.currentIncident.evidenceCount, 1);
      final store = session.controller.aggregate.store;
      expect(
        store.capturedEvidence.every((e) => e.incidentId == firstId),
        isTrue,
      );

      final card = _card(firstId);
      expect(card, isNotNull);
      expect(card!.evidenceCount, 1);
    });

    test('B. first incident with multiple evidence → exact count', () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      final firstId = session.controller.currentIncident.id;
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      session.controller.preserveEvidence(WorkspaceCaptureMode.video);
      session.controller.preserveEvidence(WorkspaceCaptureMode.voice);
      expect(session.controller.currentIncident.evidenceCount, 3);
      expect(_card(firstId)?.evidenceCount, 3);
    });

    test('C/D. second incident counts stay isolated', () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      final firstId = session.controller.currentIncident.id;
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      session.controller.preserveEvidence(WorkspaceCaptureMode.note);
      expect(_card(firstId)?.evidenceCount, 2);

      await session.beginNewCaptureIncident();
      final secondId = session.controller.currentIncident.id;
      expect(secondId, isNot(firstId));
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      expect(_card(secondId)?.evidenceCount, 1);
      expect(_card(firstId)?.evidenceCount, 2);

      // Incident B capture must never inflate Incident A.
      session.controller.preserveEvidence(WorkspaceCaptureMode.video);
      expect(_card(secondId)?.evidenceCount, 2);
      expect(_card(firstId)?.evidenceCount, 2);
    });

    test('E. untitled incident evidence count works', () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      final id = session.controller.currentIncident.id;
      expect(session.controller.currentIncident.title, isEmpty);
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      final card = _card(id);
      expect(card, isNotNull);
      expect(card!.title, 'Untitled Incident');
      expect(card.evidenceCount, 1);
    });

    test('F/G. count survives persistence reload + local merge (offline)',
        () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      final firstId = session.controller.currentIncident.id;
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      await _seedLocalEvidence(
        evidenceId: 'persist-ev-1',
        incidentId: firstId,
        userId: userId,
      );
      await _seedLocalEvidence(
        evidenceId: 'persist-ev-2',
        incidentId: firstId,
        userId: userId,
      );

      // Simulate Library memory wipe (restart) — counts come from local cache.
      IncidentLibraryService.instance.clear();
      expect(IncidentLibraryService.instance.summaries, isEmpty);

      await IncidentLibraryService.instance.refresh();
      final card = _card(firstId);
      expect(card, isNotNull);
      expect(card!.evidenceCount, greaterThanOrEqualTo(2));
    });

    test('H. capture → leave Workspace → Library shows count', () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      final firstId = session.controller.currentIncident.id;
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      session.controller.preserveEvidence(WorkspaceCaptureMode.video);

      // Leave Workspace to a different empty draft (Library view).
      await session.beginNewCaptureIncident();
      expect(session.controller.currentIncident.id, isNot(firstId));

      expect(_card(firstId)?.evidenceCount, 2);
    });

    test('I. restart path: LocalEvidenceCache drives Library count', () async {
      const incidentId = 'incident-restart-first';
      await _seedLocalEvidence(
        evidenceId: 'r1',
        incidentId: incidentId,
        userId: userId,
      );
      await _seedLocalEvidence(
        evidenceId: 'r2',
        incidentId: incidentId,
        userId: userId,
      );
      await _seedLocalEvidence(
        evidenceId: 'r3',
        incidentId: incidentId,
        userId: userId,
      );

      LocalEvidenceCache.resetForTests();
      IncidentLibraryService.instance.clear();
      await IncidentLibraryService.instance.refresh();

      expect(_card(incidentId)?.evidenceCount, 3);
    });

    test('J. first and later incidents use same count mechanism', () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      final firstId = session.controller.currentIncident.id;
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);

      await session.beginNewCaptureIncident();
      final laterId = session.controller.currentIncident.id;
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      session.controller.preserveEvidence(WorkspaceCaptureMode.note);

      final firstCard = _card(firstId)!;
      final laterCard = _card(laterId)!;
      expect(firstCard.evidenceCount, 1);
      expect(laterCard.evidenceCount, 2);
      // Same source: upsertFromLocal by incidentId (not a special first path).
      expect(firstCard.id, firstId);
      expect(laterCard.id, laterId);
    });

    test('identity: every evidence.incidentId matches first incident.id',
        () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      final firstId = session.controller.currentIncident.id;
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      session.controller.preserveEvidence(WorkspaceCaptureMode.video);
      final store = session.controller.aggregate.store;
      for (final e in store.capturedEvidence) {
        expect(e.incidentId, firstId);
      }
      for (final e in store.supportingEvidence) {
        expect(e.incidentId, firstId);
      }
      expect(_card(firstId)?.evidenceCount, 2);
    });
  });

  group('Library → Workspace open performance (local-first)', () {
    test(
      'card tap resolves by incidentId and returns without awaiting cloud',
      () async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        final activeId = session.controller.currentIncident.id;

        const targetId = 'library-card-target';
        IncidentLibraryService.instance.upsertFromLocal(
          incidentId: targetId,
          evidenceCount: 0,
          title: '',
        );

        final stopwatch = Stopwatch()..start();
        final opened = await session.openIncident(targetId);
        stopwatch.stop();

        expect(opened, isTrue);
        expect(session.controller.currentIncident.id, targetId);
        expect(session.controller.currentIncident.id, isNot(activeId));
        // Local shell + prefs title only — must not wait on cloud/hydrate.
        expect(stopwatch.elapsedMilliseconds, lessThan(500));

        // Hydrate may still be in flight; identity must already be authoritative.
        await session.waitForPendingOpenWork();
        expect(session.controller.currentIncident.id, targetId);
      },
    );

    test('open does not use active incident as placeholder', () async {
      final session = WorkspaceSession.instance;
      session.controller.replaceAggregate(
        IncidentAggregate.shell(id: 'incident-active', title: 'Street Fight'),
      );
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);

      final opened = await session.openIncident('incident-library');
      expect(opened, isTrue);
      expect(session.controller.currentIncident.id, 'incident-library');
      expect(session.controller.currentIncident.title, isNot('Street Fight'));
    });
  });

  group('Library card count — no transient zero on tap', () {
    test('1. incident with 0 evidence displays 0', () {
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'inc-zero',
        evidenceCount: 0,
        title: 'Empty',
      );
      expect(_card('inc-zero')?.evidenceCount, 0);
    });

    test('2. incident with 1 evidence displays 1', () {
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'inc-one',
        evidenceCount: 1,
        title: 'One',
      );
      expect(_card('inc-one')?.evidenceCount, 1);
    });

    test('3. incident with multiple evidence displays exact count', () {
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'inc-many',
        evidenceCount: 5,
        title: 'Many',
      );
      expect(_card('inc-many')?.evidenceCount, 5);
    });

    test(
      '4/5/6. openIncident empty shell must not emit transient Library zero',
      () async {
        final session = WorkspaceSession.instance;
        await session.beginNewCaptureIncident();
        // Leave current on a different draft so open uses shell replace.
        final draftId = session.controller.currentIncident.id;

        const targetId = 'library-flicker-target';
        const title = 'Policy Dispute';
        IncidentLibraryService.instance.upsertFromLocal(
          incidentId: targetId,
          evidenceCount: 5,
          title: title,
        );
        expect(_card(targetId)?.evidenceCount, 5);

        final observedCounts = <int>[];
        void watch() {
          final c = _card(targetId)?.evidenceCount;
          if (c != null) {
            observedCounts.add(c);
          }
        }

        final library = IncidentLibraryService.instance;
        library.addListener(watch);
        addTearDown(() => library.removeListener(watch));
        watch();

        final opened = await session.openIncident(targetId);
        expect(opened, isTrue);
        // Shell replace publishes immediately via replaceAggregate.
        expect(session.controller.currentIncident.id, targetId);
        expect(
          session.controller.currentIncident.evidenceCount,
          0,
          reason: 'Workspace shell is empty before hydrate — expected',
        );
        // Library card must NOT follow that transient zero.
        expect(_card(targetId)?.evidenceCount, 5);
        expect(
          observedCounts.every((c) => c != 0 || c == 5),
          isTrue,
        );
        expect(
          observedCounts.contains(0),
          isFalse,
          reason: 'Library must never emit evidenceCount=0 after knowing 5',
        );
        expect(_card(targetId)?.title, title);
        expect(_card(targetId)?.id, targetId);
        expect(draftId, isNot(targetId));
      },
    );

    test('7/8. title and id unchanged across empty-shell upsert', () {
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'stable-id',
        evidenceCount: 3,
        title: 'Stable Title',
      );
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'stable-id',
        evidenceCount: 0,
        title: 'Stable Title',
      );
      final card = _card('stable-id')!;
      expect(card.id, 'stable-id');
      expect(card.title, 'Stable Title');
      expect(card.evidenceCount, 3);
    });

    test('9. count remains after open returns to Library state', () async {
      final session = WorkspaceSession.instance;
      await session.beginNewCaptureIncident();
      const targetId = 'library-return-count';
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: targetId,
        evidenceCount: 4,
        title: 'Return',
      );
      await session.openIncident(targetId);
      expect(_card(targetId)?.evidenceCount, 4);
      // Switch away (as if leaving Workspace back toward Library draft).
      await session.beginNewCaptureIncident();
      expect(_card(targetId)?.evidenceCount, 4);
    });

    test('10. multiple cards keep independent counts (no bleed)', () {
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'A',
        evidenceCount: 1,
        title: 'A',
      );
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'B',
        evidenceCount: 3,
        title: 'B',
      );
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'C',
        evidenceCount: 5,
        title: 'C',
      );
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'D',
        evidenceCount: 0,
        title: 'D',
      );

      // Simulate shell opens publishing zeros for B and C.
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'B',
        evidenceCount: 0,
        title: 'B',
      );
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'C',
        evidenceCount: 0,
        title: 'C',
      );

      expect(_card('A')?.evidenceCount, 1);
      expect(_card('B')?.evidenceCount, 3);
      expect(_card('C')?.evidenceCount, 5);
      expect(_card('D')?.evidenceCount, 0);
    });

    test('non-zero downgrade still allowed (5 → 3)', () {
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'downgrade',
        evidenceCount: 5,
        title: 'D',
      );
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: 'downgrade',
        evidenceCount: 3,
        title: 'D',
      );
      expect(_card('downgrade')?.evidenceCount, 3);
    });
  });
}
