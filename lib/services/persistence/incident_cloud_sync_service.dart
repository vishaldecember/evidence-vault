import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../domain/evidence/evidence_sync_status.dart';
import '../../domain/incident/incident.dart';
import '../../domain/incident/incident_aggregate.dart';
import '../../domain/timeline/timeline_anchor.dart';
import '../../engines/investigation_health_engine.dart';
import '../../repositories/firebase/firebase_evidence_repository.dart';
import '../../repositories/firebase/firebase_incident_repository.dart';
import '../../repositories/firebase/firebase_investigation_repository.dart';
import '../../repositories/incident_store.dart';
import '../../repositories/storage_repository.dart';
import '../auth/firebase_bootstrap.dart';
import '../storage/evidence_upload_models.dart';
import '../storage/local_evidence_cache.dart';
import '../user_session_service.dart';

/// Write-through + hydrate between [IncidentStore] and Firestore (Sprint 4D).
///
/// Working-set mutations stay on in-memory repositories; this service persists
/// and restores so evidence and the investigation graph survive app restart.
/// UI never imports Firestore.
class IncidentCloudSyncService {
  IncidentCloudSyncService({
    FirebaseIncidentRepository? incidents,
    FirebaseEvidenceRepository? evidence,
    FirebaseInvestigationRepository? investigation,
    StorageRepository? storage,
  })  : _incidentsOverride = incidents,
        _evidenceOverride = evidence,
        _investigationOverride = investigation,
        _storageOverride = storage;

  static final IncidentCloudSyncService instance = IncidentCloudSyncService();

  FirebaseIncidentRepository? _incidentsOverride;
  FirebaseEvidenceRepository? _evidenceOverride;
  FirebaseInvestigationRepository? _investigationOverride;
  StorageRepository? _storageOverride;

  /// Lazy — constructing Firestore before Firebase.initializeApp() crashes tests.
  FirebaseIncidentRepository get _incidents =>
      _incidentsOverride ??= FirebaseIncidentRepository();

  FirebaseEvidenceRepository get _evidence =>
      _evidenceOverride ??= FirebaseEvidenceRepository();

  FirebaseInvestigationRepository get _investigation =>
      _investigationOverride ??= FirebaseInvestigationRepository();

  StorageRepository get _storage =>
      _storageOverride ??= FirebaseStorageRepository();

  bool get _enabled {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    return FirebaseBootstrap.isAvailable && UserSessionService.isSignedIn;
  }

  String? get _userId => UserSessionService.account?.userId;

  /// Hydrates an [IncidentAggregate] from Firestore for the signed-in user's
  /// active incident.
  ///
  /// Load-only: never mints an incident. Missing active/latest → `null`.
  Future<IncidentAggregate?> restoreActiveIncident() async {
    if (!_enabled) {
      return null;
    }
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final incident = await resolveExistingActiveIncident(
        userId: userId,
        readActiveIncidentId: _incidents.readActiveIncidentId,
        loadIncident: _incidents.loadIncident,
        loadLatestIncident: _incidents.loadLatestIncident,
        setActiveIncidentId: _incidents.setActiveIncidentId,
      );
      if (incident == null) {
        return null;
      }
      return await _restoreIncidentDocument(userId: userId, incident: incident);
    } catch (error, stack) {
      debugPrint('[Sync] restore failed: $error');
      debugPrint('$stack');
      return null;
    }
  }

  /// Active or latest existing incident. Never creates a cloud document.
  @visibleForTesting
  static Future<Incident?> resolveExistingActiveIncident({
    required String userId,
    required Future<String?> Function(String userId) readActiveIncidentId,
    required Future<Incident?> Function(String userId, String incidentId)
        loadIncident,
    required Future<Incident?> Function(String userId) loadLatestIncident,
    required Future<void> Function(String userId, String incidentId)
        setActiveIncidentId,
  }) async {
    final activeId = await readActiveIncidentId(userId);
    if (activeId != null && activeId.trim().isNotEmpty) {
      final existing = await loadIncident(userId, activeId.trim());
      if (existing != null) {
        return existing;
      }
    }

    final latest = await loadLatestIncident(userId);
    if (latest != null) {
      await setActiveIncidentId(userId, latest.id);
      return latest;
    }

    return null;
  }

  /// Hydrates a specific incident (Library / incident switcher) and marks it
  /// active for the signed-in user.
  Future<IncidentAggregate?> restoreIncident(String incidentId) async {
    if (!_enabled) {
      return null;
    }
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final incident = await _incidents.loadIncident(userId, incidentId);
      if (incident == null) {
        return null;
      }
      await _incidents.setActiveIncidentId(userId, incidentId);
      return await _restoreIncidentDocument(userId: userId, incident: incident);
    } catch (error, stack) {
      debugPrint('[Sync] restore incident failed: $error');
      debugPrint('$stack');
      return null;
    }
  }

  Future<IncidentAggregate> _restoreIncidentDocument({
    required String userId,
    required Incident incident,
  }) async {
    final bundle = await _evidence.loadEvidence(
      userId: userId,
      incidentId: incident.id,
    );

    final store = IncidentStore(
      incident: incident,
      capturedEvidence: bundle.captured,
      supportingEvidence: bundle.supporting,
    );

    await _investigation.loadGraphInto(
      userId: userId,
      incidentId: incident.id,
      store: store,
    );

    // Backfill anchors for legacy documents written before the investigation
    // graph subcollections existed.
    if (store.timelineAnchors.isEmpty && bundle.captured.isNotEmpty) {
      store.timelineAnchors.addAll([
        for (var i = 0; i < bundle.captured.length; i++)
          TimelineAnchor(
            id: bundle.captured[i].timelineAnchorId,
            incidentId: incident.id,
            capturedEvidenceId: bundle.captured[i].id,
            anchoredAt: bundle.captured[i].capturedAt,
            sequenceOrder: bundle.captured[i].timelineOrder ?? i,
          ),
      ]);
    }

    debugPrint(
      '[Sync] restored incident=${incident.id} '
      'evidence=${bundle.captured.length + bundle.supporting.length} '
      'anchors=${store.timelineAnchors.length}',
    );
    return IncidentAggregate.fromStore(store);
  }

  /// Persists incident counters, every evidence document, and the full
  /// investigation graph (async, non-blocking).
  Future<void> persistAggregate(IncidentAggregate aggregate) async {
    if (!_enabled) {
      return;
    }
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final store = aggregate.store;
      final health =
          InvestigationHealthEngine.evaluate(aggregate).overallScore;

      await _incidents.upsertIncident(
        userId: userId,
        incident: store.incident,
        timelineCount: store.timelineAnchors.length,
        relationshipCount: store.relationshipGroups.length,
        narrativeCount: store.narrativeEvents.length,
        reconstructionHealth: health,
        evidenceCount: store.capturedEvidence.length +
            store.supportingEvidence.length,
      );

      final ordered = _timelineOrderedIds(store);
      final supportingByParent = <String, List<String>>{};
      for (final item in store.supportingEvidence) {
        final parent = item.resolvedParentEvidenceId;
        if (parent == null) {
          continue;
        }
        supportingByParent.putIfAbsent(parent, () => []).add(item.id);
      }

      for (var i = 0; i < ordered.length; i++) {
        final id = ordered[i];
        final capturedIndex =
            store.capturedEvidence.indexWhere((item) => item.id == id);
        if (capturedIndex != -1) {
          final withSync = store.capturedEvidence[capturedIndex].copyWith(
            timelineOrder: i,
            syncStatus: _syncStatusFor(
              uploadStatus: store.capturedEvidence[capturedIndex].uploadStatus,
              hasFile: store.capturedEvidence[capturedIndex].filePath != null ||
                  store.capturedEvidence[capturedIndex].storagePath != null,
            ),
          );
          store.capturedEvidence[capturedIndex] = withSync;
          await _evidence.upsertCaptured(
            userId: userId,
            evidence: withSync,
            timelineOrder: i,
            supportingEvidenceIds: supportingByParent[id] ?? const [],
          );
          continue;
        }
        final supportingIndex =
            store.supportingEvidence.indexWhere((item) => item.id == id);
        if (supportingIndex != -1) {
          final withSync = store.supportingEvidence[supportingIndex].copyWith(
            timelineOrder: i,
            syncStatus: _syncStatusFor(
              uploadStatus:
                  store.supportingEvidence[supportingIndex].uploadStatus,
              hasFile: store.supportingEvidence[supportingIndex].filePath !=
                      null ||
                  store.supportingEvidence[supportingIndex].storagePath !=
                      null,
            ),
          );
          store.supportingEvidence[supportingIndex] = withSync;
          await _evidence.upsertSupporting(
            userId: userId,
            evidence: withSync,
            timelineOrder: i,
            supportingEvidenceIds: const [],
          );
        }
      }

      await _investigation.persistGraph(userId: userId, store: store);

      debugPrint('[Sync] persisted incident=${store.incident.id}');
    } catch (error, stack) {
      debugPrint('[Sync] persist failed: $error');
      debugPrint('$stack');
    }
  }

  /// Writes incident identity fields (title/status) without zeroing counters.
  ///
  /// Used for rename — must not block capture and must not clobber evidenceCount.
  Future<void> persistIncidentOnly(Incident incident) async {
    if (!_enabled) {
      return;
    }
    final userId = _userId;
    if (userId == null) {
      return;
    }
    try {
      await _incidents.patchIncidentIdentity(
        userId: userId,
        incident: incident,
      );
    } catch (error) {
      debugPrint('[Sync] incident-only persist failed: $error');
    }
  }

  /// Deletes one evidence item's Firestore doc + Storage files and removes
  /// every trace of it from the in-memory [store] (relationship groups,
  /// relationships, captured/supporting lists) and [LocalEvidenceCache] index.
  Future<void> deleteEvidenceCascade({
    required String incidentId,
    required String evidenceId,
    required IncidentStore store,
  }) async {
    if (!_enabled) {
      await _removeEvidenceFromStoreAndCache(
        store: store,
        evidenceId: evidenceId,
      );
      return;
    }
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      await _removeEvidenceFromStoreAndCache(
        store: store,
        evidenceId: evidenceId,
      );
      return;
    }

    try {
      await _evidence.deleteEvidence(
        userId: userId,
        incidentId: incidentId,
        evidenceId: evidenceId,
      );
      await _removeEvidenceFromStoreAndCache(
        store: store,
        evidenceId: evidenceId,
      );

      try {
        await _storage.deleteEvidenceFiles(
          userId: userId,
          incidentId: incidentId,
          evidenceId: evidenceId,
        );
      } catch (error) {
        debugPrint('[Sync] storage cleanup skipped for $evidenceId: $error');
      }

      await _investigation.persistGraph(userId: userId, store: store);
      debugPrint('[Sync] deleted evidence cascade → $evidenceId');
    } catch (error, stack) {
      debugPrint('[Sync] delete cascade failed: $error');
      debugPrint('$stack');
    }
  }

  /// Drops the working-set row and the durable cache index used for library counts.
  static Future<void> _removeEvidenceFromStoreAndCache({
    required IncidentStore store,
    required String evidenceId,
  }) async {
    _removeEvidenceFromStore(store: store, evidenceId: evidenceId);
    final id = evidenceId.trim();
    if (id.isEmpty) {
      return;
    }
    try {
      await LocalEvidenceCache.remove(id);
    } catch (error) {
      debugPrint('[Sync] local cache remove skipped for $id: $error');
    }
  }

  static void _removeEvidenceFromStore({
    required IncidentStore store,
    required String evidenceId,
  }) {
    for (var i = 0; i < store.relationshipGroups.length; i++) {
      final group = store.relationshipGroups[i];
      if (group.memberEvidenceIds.contains(evidenceId)) {
        final members =
            group.memberEvidenceIds.where((id) => id != evidenceId).toList();
        store.relationshipGroups[i] = group.copyWithMembers(members);
      }
    }
    store.relationshipGroups.removeWhere(
      (group) => group.memberEvidenceIds.isEmpty,
    );
    store.relationships.removeWhere(
      (relationship) =>
          relationship.sourceEvidenceId == evidenceId ||
          relationship.targetEvidenceId == evidenceId,
    );
    store.timelineAnchors.removeWhere(
      (anchor) => anchor.capturedEvidenceId == evidenceId,
    );
    store.capturedEvidence.removeWhere((item) => item.id == evidenceId);
    store.supportingEvidence.removeWhere((item) => item.id == evidenceId);
    store.organizeCreatedEvidenceIds.remove(evidenceId);
    store.organizeContextAnchors.removeWhere(
      (anchor) =>
          anchor.contextEvidenceId == evidenceId ||
          anchor.capturedEvidenceId == evidenceId,
    );
  }

  static EvidenceSyncStatus _syncStatusFor({
    required EvidenceUploadStatus uploadStatus,
    required bool hasFile,
  }) {
    if (!hasFile && uploadStatus == EvidenceUploadStatus.pending) {
      // Text-only / metadata-only — treat as locally captured until cloud write.
      return EvidenceSyncStatus.localCaptured;
    }
    return switch (uploadStatus) {
      EvidenceUploadStatus.uploaded => EvidenceSyncStatus.ready,
      EvidenceUploadStatus.uploading => EvidenceSyncStatus.uploading,
      EvidenceUploadStatus.processing => EvidenceSyncStatus.processing,
      EvidenceUploadStatus.failed => EvidenceSyncStatus.failed,
      EvidenceUploadStatus.pending => EvidenceSyncStatus.queuedForUpload,
    };
  }

  /// Capture order: prefer timelineOrder, else chronological merge.
  static List<String> _timelineOrderedIds(IncidentStore store) {
    final entries = <({String id, int order, DateTime at})>[
      for (final item in store.capturedEvidence)
        (
          id: item.id,
          order: item.timelineOrder ?? item.capturedAt.millisecondsSinceEpoch,
          at: item.capturedAt,
        ),
      for (final item in store.supportingEvidence)
        (
          id: item.id,
          order: item.timelineOrder ?? item.createdAt.millisecondsSinceEpoch,
          at: item.createdAt,
        ),
    ]..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        if (byOrder != 0) {
          return byOrder;
        }
        return a.at.compareTo(b.at);
      });
    return [for (final entry in entries) entry.id];
  }
}
