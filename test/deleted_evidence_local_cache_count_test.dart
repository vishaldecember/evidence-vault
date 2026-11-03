import 'dart:io';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/services/persistence/incident_cloud_sync_service.dart';
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

LibraryIncidentSummary _summary({
  required String id,
  required int evidenceCount,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: 'Cache Delete Fixture',
    evidenceCount: evidenceCount,
    contextEnrichedCount: 0,
    integrityVerified: false,
    lastPreserved: 'Today',
    isInProgress: true,
    createdAt: DateTime(2026, 9, 9),
    updatedAt: DateTime(2026, 9, 9),
  );
}

LibraryIncidentSummary? _card(String id) {
  for (final summary in IncidentLibraryService.instance.summaries) {
    if (summary.id == id) {
      return summary;
    }
  }
  return null;
}

CapturedEvidence _captured({
  required String id,
  required String incidentId,
}) {
  final now = DateTime(2026, 9, 9);
  return CapturedEvidence(
    id: id,
    incidentId: incidentId,
    type: CapturedEvidenceType.photo,
    capturedAt: now,
    title: id,
    integrityVerified: false,
    verification: VerificationFactory.initial(),
    timelineAnchorId: 'anchor-$id',
  );
}

IncidentStore _store({
  required String incidentId,
  required List<String> evidenceIds,
}) {
  return IncidentStore(
    incident: Incident(
      id: incidentId,
      title: 'Cache Delete Fixture',
      status: IncidentStatus.active,
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9),
    ),
    capturedEvidence: [
      for (final id in evidenceIds)
        _captured(id: id, incidentId: incidentId),
    ],
  );
}

Future<void> _seedCacheRow({
  required String evidenceId,
  required String incidentId,
  required String userId,
}) async {
  final now = DateTime(2026, 9, 9);
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

  const userId = 'user-cache-delete';
  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_cache_delete_');
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

  group('Phase 2(B)-3B deleted evidence leaves local cache', () {
    test('A. deleting one of 10 drops local cache count to 9', () async {
      const incidentId = 'incident-delete-ten';
      final ids = [for (var i = 0; i < 10; i++) 'ev-$i'];
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [_summary(id: incidentId, evidenceCount: 10)],
        records: const [],
      );
      for (final id in ids) {
        await _seedCacheRow(
          evidenceId: id,
          incidentId: incidentId,
          userId: userId,
        );
      }
      final store = _store(incidentId: incidentId, evidenceIds: ids);
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.fromStore(store),
      );
      expect(await LocalEvidenceCache.forIncident(incidentId), hasLength(10));
      expect(_card(incidentId)?.evidenceCount, 10);

      const deletedId = 'ev-9';
      await controller.deleteEvidence(deletedId);

      final remaining = await LocalEvidenceCache.forIncident(incidentId);
      expect(remaining, hasLength(9));
      expect(
        remaining.any((entry) => entry.evidenceId == deletedId),
        isFalse,
      );
      expect(await LocalEvidenceCache.byId(deletedId), isNull);
      expect(store.capturedEvidence, hasLength(9));
      expect(_card(incidentId)?.evidenceCount, 9);

      await IncidentLibraryService.instance.refresh();
      expect(_card(incidentId)?.evidenceCount, 9);
    });

    test(
      'B. stale cache of 10 converges to 9 after deleting the extra row',
      () async {
        const incidentId = 'incident-stale-cache';
        IncidentLibraryService.instance.restoreSnapshot(
          summaries: [_summary(id: incidentId, evidenceCount: 9)],
          records: const [],
        );
        for (var i = 0; i < 9; i++) {
          await _seedCacheRow(
            evidenceId: 'ev-$i',
            incidentId: incidentId,
            userId: userId,
          );
        }
        await _seedCacheRow(
          evidenceId: 'ev-stale',
          incidentId: incidentId,
          userId: userId,
        );

        await IncidentLibraryService.instance.refresh();
        expect(_card(incidentId)?.evidenceCount, 10);

        final store = _store(
          incidentId: incidentId,
          evidenceIds: [for (var i = 0; i < 9; i++) 'ev-$i', 'ev-stale'],
        );
        await IncidentCloudSyncService.instance.deleteEvidenceCascade(
          incidentId: incidentId,
          evidenceId: 'ev-stale',
          store: store,
        );

        IncidentLibraryService.instance.upsertFromLocal(
          incidentId: incidentId,
          title: 'Cache Delete Fixture',
          evidenceCount: store.capturedEvidence.length,
        );

        final remaining = await LocalEvidenceCache.forIncident(incidentId);
        expect(remaining, hasLength(9));
        expect(
          remaining.any((entry) => entry.evidenceId == 'ev-stale'),
          isFalse,
        );
        expect(store.capturedEvidence, hasLength(9));
        expect(_card(incidentId)?.evidenceCount, 9);

        await IncidentLibraryService.instance.refresh();
        expect(_card(incidentId)?.evidenceCount, 9);
      },
    );

    test('C. max() still prefers optimistic unsynced local capture', () async {
      const incidentId = 'incident-optimistic';
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [_summary(id: incidentId, evidenceCount: 5)],
        records: const [],
      );
      for (var i = 0; i < 6; i++) {
        await _seedCacheRow(
          evidenceId: 'ev-$i',
          incidentId: incidentId,
          userId: userId,
        );
      }

      await IncidentLibraryService.instance.refresh();

      expect(_card(incidentId)?.evidenceCount, 6);
    });

    test('D. delete removes only the requested evidence', () async {
      const incidentId = 'incident-abc';
      for (final id in ['ev-a', 'ev-b', 'ev-c']) {
        await _seedCacheRow(
          evidenceId: id,
          incidentId: incidentId,
          userId: userId,
        );
      }
      final store = _store(
        incidentId: incidentId,
        evidenceIds: const ['ev-a', 'ev-b', 'ev-c'],
      );

      await IncidentCloudSyncService.instance.deleteEvidenceCascade(
        incidentId: incidentId,
        evidenceId: 'ev-b',
        store: store,
      );

      final remaining = await LocalEvidenceCache.forIncident(incidentId);
      final remainingIds = remaining.map((entry) => entry.evidenceId).toSet();
      expect(remainingIds, {'ev-a', 'ev-c'});
      expect(await LocalEvidenceCache.byId('ev-b'), isNull);
      expect(
        store.capturedEvidence.map((item) => item.id).toSet(),
        {'ev-a', 'ev-c'},
      );
      expect(remaining, hasLength(2));
    });

    test('E. deleting from incident A does not change incident B', () async {
      const incidentA = 'incident-a';
      const incidentB = 'incident-b';
      await _seedCacheRow(
        evidenceId: 'ev-a1',
        incidentId: incidentA,
        userId: userId,
      );
      await _seedCacheRow(
        evidenceId: 'ev-a2',
        incidentId: incidentA,
        userId: userId,
      );
      await _seedCacheRow(
        evidenceId: 'ev-b1',
        incidentId: incidentB,
        userId: userId,
      );
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [
          _summary(id: incidentA, evidenceCount: 2),
          _summary(id: incidentB, evidenceCount: 1),
        ],
        records: const [],
      );
      final storeA = _store(
        incidentId: incidentA,
        evidenceIds: const ['ev-a1', 'ev-a2'],
      );

      await IncidentCloudSyncService.instance.deleteEvidenceCascade(
        incidentId: incidentA,
        evidenceId: 'ev-a2',
        store: storeA,
      );

      expect(await LocalEvidenceCache.forIncident(incidentA), hasLength(1));
      expect(
        (await LocalEvidenceCache.forIncident(incidentB))
            .map((entry) => entry.evidenceId),
        ['ev-b1'],
      );
      expect(await LocalEvidenceCache.byId('ev-b1'), isNotNull);

      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: incidentA,
        title: 'Cache Delete Fixture',
        evidenceCount: storeA.capturedEvidence.length,
      );
      await IncidentLibraryService.instance.refresh();
      expect(_card(incidentA)?.evidenceCount, 1);
      expect(_card(incidentB)?.evidenceCount, 1);
    });

    test('library merge still uses max(local, cloud)', () {
      final source = File(
        'lib/services/persistence/incident_library_service.dart',
      ).readAsStringSync();
      expect(
        source.contains('math.max(existing.evidenceCount, localEvidence)'),
        isTrue,
      );
    });
  });
}


