import 'dart:io';

import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/services/persistence/incident_cloud_sync_service.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Incident _incident(String id, {String title = 'Existing'}) {
  final now = DateTime(2026, 9, 9);
  return Incident(
    id: id,
    title: title,
    status: IncidentStatus.draft,
    createdAt: now,
    updatedAt: now,
  );
}

/// In-memory stand-in for the Firestore incident collection used by restore.
class _RecordingIncidentCloud {
  _RecordingIncidentCloud({
    this.activeId,
    Map<String, Incident>? documents,
  }) : documents = documents ?? {};

  String? activeId;
  final Map<String, Incident> documents;
  final createdIds = <String>[];
  var upsertCount = 0;
  var setActiveCount = 0;

  Future<String?> readActiveIncidentId(String userId) async {
    expect(userId, isNotEmpty);
    return activeId;
  }

  Future<Incident?> loadIncident(String userId, String incidentId) async {
    expect(userId, isNotEmpty);
    return documents[incidentId];
  }

  Future<Incident?> loadLatestIncident(String userId) async {
    expect(userId, isNotEmpty);
    if (documents.isEmpty) {
      return null;
    }
    final values = documents.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values.first;
  }

  Future<void> setActiveIncidentId(String userId, String incidentId) async {
    expect(userId, isNotEmpty);
    setActiveCount++;
    activeId = incidentId;
  }
}

Future<Incident?> _restoreActive(String userId, _RecordingIncidentCloud cloud) {
  return IncidentCloudSyncService.resolveExistingActiveIncident(
    userId: userId,
    readActiveIncidentId: cloud.readActiveIncidentId,
    loadIncident: cloud.loadIncident,
    loadLatestIncident: cloud.loadLatestIncident,
    setActiveIncidentId: cloud.setActiveIncidentId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const userId = 'user-restore';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
  });

  tearDown(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
  });

  group('A. Existing incident restore', () {
    test('active incident is restored with the same id and no second create',
        () async {
      final existing = _incident('incident-active');
      final cloud = _RecordingIncidentCloud(
        activeId: existing.id,
        documents: {existing.id: existing},
      );

      final restored = await _restoreActive(userId, cloud);

      expect(restored, isNotNull);
      expect(restored!.id, existing.id);
      expect(cloud.documents.keys, [existing.id]);
      expect(cloud.createdIds, isEmpty);
      expect(cloud.upsertCount, 0);
      expect(cloud.setActiveCount, 0);
    });

    test('stale active pointer falls back to latest without minting', () async {
      final latest = _incident('incident-latest');
      final cloud = _RecordingIncidentCloud(
        activeId: 'incident-deleted',
        documents: {latest.id: latest},
      );

      final restored = await _restoreActive(userId, cloud);

      expect(restored!.id, latest.id);
      expect(cloud.activeId, latest.id);
      expect(cloud.setActiveCount, 1);
      expect(cloud.createdIds, isEmpty);
      expect(cloud.documents.length, 1);
    });
  });

  group('B. Missing incident restore', () {
    test('empty collection does not create, mint, or enter the library',
        () async {
      final cloud = _RecordingIncidentCloud();
      final beforeIds = [
        for (final summary in IncidentLibraryService.instance.summaries)
          summary.id,
      ];

      final restored = await _restoreActive(userId, cloud);

      expect(restored, isNull);
      expect(cloud.documents, isEmpty);
      expect(cloud.createdIds, isEmpty);
      expect(cloud.upsertCount, 0);
      expect(cloud.activeId, isNull);
      expect(cloud.setActiveCount, 0);
      expect(
        [
          for (final summary in IncidentLibraryService.instance.summaries)
            summary.id,
        ],
        beforeIds,
      );
      expect(IncidentLibraryService.instance.summaries, isEmpty);
    });

    test('requested missing id is load-only — no cloud or library insert',
        () async {
      final cloud = _RecordingIncidentCloud(
        documents: {_incident('incident-known').id: _incident('incident-known')},
      );
      IncidentLibraryService.instance.restoreSnapshot(
        summaries: [
          LibraryIncidentSummary(
            id: 'incident-known',
            title: 'Known',
            evidenceCount: 2,
            contextEnrichedCount: 0,
            integrityVerified: false,
            lastPreserved: 'Today',
          ),
        ],
        records: const [],
      );

      final loaded = await cloud.loadIncident(userId, 'incident-missing');

      expect(loaded, isNull);
      expect(cloud.createdIds, isEmpty);
      expect(cloud.documents.keys, ['incident-known']);
      expect(
        [
          for (final summary in IncidentLibraryService.instance.summaries)
            summary.id,
        ],
        ['incident-known'],
      );
    });
  });

  group('C. Capture Now identity regression', () {
    test('beginNewCaptureIncident mints exactly one id; captures share it',
        () async {
      final session = WorkspaceSession.instance;
      final priorId = session.controller.currentIncident.id;

      await session.beginNewCaptureIncident();
      final created = session.controller.currentIncident.id;

      expect(created, isNotEmpty);
      expect(created, isNot(priorId));
      session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
      session.controller.preserveEvidence(WorkspaceCaptureMode.note);
      expect(session.controller.currentIncident.id, created);
      expect(session.controller.currentIncident.evidenceCount, 2);
    });
  });

  group('D. Continue Preserving identity regression', () {
    test('openIncident keeps the existing id and does not mint another',
        () async {
      const existingId = 'incident-continue';
      final session = WorkspaceSession.instance;
      final opened = await session.openIncident(existingId);

      expect(opened, isTrue);
      expect(session.controller.currentIncident.id, existingId);
    });
  });

  group('Restore caller contract', () {
    test('restoreActiveIncident no longer calls ensureIncident', () {
      final source = File(
        'lib/services/persistence/incident_cloud_sync_service.dart',
      ).readAsStringSync();
      expect(source.contains('ensureIncident'), isFalse);
      expect(source.contains('resolveExistingActiveIncident'), isTrue);
      expect(source.contains('loadIncident'), isTrue);
      expect(source.contains('loadLatestIncident'), isTrue);
    });

    test('disabled test restore path returns null without minting', () async {
      final cloud = _RecordingIncidentCloud();
      // Production restoreActiveIncident is disabled under FLUTTER_TEST.
      final aggregate =
          await IncidentCloudSyncService.instance.restoreActiveIncident();
      expect(aggregate, isNull);
      expect(cloud.createdIds, isEmpty);
    });
  });
}
