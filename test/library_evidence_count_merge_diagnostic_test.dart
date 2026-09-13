import 'dart:io';

import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diagnostic coverage for [IncidentLibraryService] count merge.
///
/// These tests document **current** `max(cloudOrMemory, localCache)` behavior.
/// They do not assert a product-desired contract.
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
    title: 'Count Merge Fixture',
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

  const userId = 'user-count-merge';
  const incidentId = 'incident-count-merge';
  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('ev_count_merge_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: userId,
    );
    IncidentLibraryService.instance.clear();
  });

  tearDown(() async {
    IncidentLibraryService.instance.clear();
    UserSessionService.resetForTests();
    LocalEvidenceCache.resetForTests();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('CURRENT refresh merge = max(in-memory/cloud snapshot, cache rows)', () {
    test('1. equal local/cloud counts stay equal', () async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [_summary(id: incidentId, evidenceCount: 5)],
        records: const [],
      );
      for (var i = 0; i < 5; i++) {
        await _seedCacheRow(
          evidenceId: 'ev-$i',
          incidentId: incidentId,
          userId: userId,
        );
      }

      await IncidentLibraryService.instance.refresh();

      expect(_card(incidentId)?.evidenceCount, 5);
    });

    test('2. local cache > cloud/memory snapshot → library uses local (max)',
        () async {
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

      // CURRENT: high-watermark. Unresolved whether this is desired after delete.
      expect(_card(incidentId)?.evidenceCount, 6);
    });

    test('3. cloud/memory snapshot > local cache → library uses snapshot (max)',
        () async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [_summary(id: incidentId, evidenceCount: 10)],
        records: const [],
      );
      for (var i = 0; i < 5; i++) {
        await _seedCacheRow(
          evidenceId: 'ev-$i',
          incidentId: incidentId,
          userId: userId,
        );
      }

      await IncidentLibraryService.instance.refresh();

      expect(_card(incidentId)?.evidenceCount, 10);
    });

    test(
      '4. deletion-shaped stale cache: snapshot 9, cache 10 → refresh shows 10',
      () async {
        IncidentLibraryService.instance.restoreSnapshot(
          summaries: [_summary(id: incidentId, evidenceCount: 9)],
          records: const [],
        );
        for (var i = 0; i < 10; i++) {
          await _seedCacheRow(
            evidenceId: 'ev-$i',
            incidentId: incidentId,
            userId: userId,
          );
        }

        await IncidentLibraryService.instance.refresh();

        // CURRENT: stale cache wins. No timestamp/version compared.
        expect(_card(incidentId)?.evidenceCount, 10);
      },
    );

    test('5. failed-sync analog: cache 10, snapshot 8 → library 10', () async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [_summary(id: incidentId, evidenceCount: 8)],
        records: const [],
      );
      for (var i = 0; i < 10; i++) {
        await _seedCacheRow(
          evidenceId: 'ev-$i',
          incidentId: incidentId,
          userId: userId,
        );
      }

      await IncidentLibraryService.instance.refresh();

      expect(_card(incidentId)?.evidenceCount, 10);
    });

    test('6. successful convergence: both 6 → library 6', () async {
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [_summary(id: incidentId, evidenceCount: 6)],
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
  });

  group('CURRENT related paths (not max, but affect visible count)', () {
    test('upsertFromLocal(0) does not lower a known positive count', () {
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: incidentId,
        evidenceCount: 5,
        title: 'Count Merge Fixture',
      );
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: incidentId,
        evidenceCount: 0,
        title: 'Count Merge Fixture',
      );
      expect(_card(incidentId)?.evidenceCount, 5);
    });

    test('upsertFromLocal(4) does lower 5 → 4 (non-zero downgrade allowed)', () {
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: incidentId,
        evidenceCount: 5,
        title: 'Count Merge Fixture',
      );
      IncidentLibraryService.instance.upsertFromLocal(
        incidentId: incidentId,
        evidenceCount: 4,
        title: 'Count Merge Fixture',
      );
      expect(_card(incidentId)?.evidenceCount, 4);
    });

    test(
      'deleteEvidenceCascade removes the LocalEvidenceCache index row',
      () {
        final controller = File(
          'lib/controllers/workspace_evidence_controller.dart',
        ).readAsStringSync();
        final cascade = File(
          'lib/services/persistence/incident_cloud_sync_service.dart',
        ).readAsStringSync();
        expect(
          controller.contains('Future<void> deleteEvidence(String evidenceId)'),
          isTrue,
        );
        expect(
          cascade.contains('LocalEvidenceCache.remove'),
          isTrue,
          reason: 'Cascade must drop the cache index row used for library counts',
        );
        expect(
          cascade.contains('math.max'),
          isFalse,
          reason: 'Cascade must not replace library max() merge',
        );
        final deleteFn = controller.split('Future<void> deleteEvidence(').last;
        final body = deleteFn.split('String _captureFromMode').first;
        expect(
          body.contains('deleteEvidenceCascade'),
          isTrue,
        );
      },
    );
  });
}
