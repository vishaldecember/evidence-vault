import '../models/library_incident_record.dart';
import '../models/library_incident_summary.dart';
import '../models/trust_package_archive_record.dart';
import '../models/trust_package_share_link.dart';
import '../controllers/workspace_evidence_controller.dart';
import '../controllers/workspace_session.dart';
import '../domain/incident/incident_aggregate.dart';
import '../repositories/firebase/firebase_incident_repository.dart';
import '../repositories/incident_store.dart';
import '../repositories/trust_package_archive_store.dart';
import '../repositories/trust_package_share_store.dart';
import 'package:flutter/foundation.dart';

import 'auth/firebase_bootstrap.dart';
import 'capture/capture_session_manager.dart';
import 'evidence_storage_service.dart';
import 'persistence/incident_library_service.dart';
import 'persistence/local_capture_session_store.dart';
import 'persistence/local_incident_pointer.dart';
import 'persistence/organize_context_persistence.dart';
import 'persistence/vault_wipe_pending.dart';
import 'storage/durable_attach_intent_store.dart';
import 'storage/evidence_storage_service.dart' as firebase_object_storage;
import 'storage/local_evidence_cache.dart';
import 'storage/saf_staging_bridge.dart';
import 'sync/evidence_sync_manager.dart';
import 'user_session_service.dart';
import 'persistence/incident_cloud_sync_service.dart';

/// Snapshot for transactional rollback during investigation data deletion.
class InvestigationDataDeletionSnapshot {
  InvestigationDataDeletionSnapshot({
    required this.workspaceController,
    required this.workspaceAggregate,
    required this.archives,
    required this.shareLinks,
    required this.librarySummaries,
    required this.libraryRecords,
  });

  final WorkspaceEvidenceController workspaceController;
  final IncidentAggregate workspaceAggregate;
  final List<TrustPackageArchiveRecord> archives;
  final List<TrustPackageShareLink> shareLinks;
  final List<LibraryIncidentSummary> librarySummaries;
  final List<LibraryIncidentRecord> libraryRecords;

  static InvestigationDataDeletionSnapshot capture() {
    final controller = WorkspaceSession.instance.controller;
    return InvestigationDataDeletionSnapshot(
      workspaceController: controller,
      workspaceAggregate: IncidentAggregate.fromStore(
        controller.aggregate.store.copy(),
      ),
      archives: List<TrustPackageArchiveRecord>.from(
        TrustPackageArchiveStore.all,
      ),
      shareLinks: List<TrustPackageShareLink>.from(
        TrustPackageShareStore.all,
      ),
      librarySummaries: List<LibraryIncidentSummary>.from(
        IncidentLibraryService.instance.summaries,
      ),
      libraryRecords: List<LibraryIncidentRecord>.from(
        IncidentLibraryService.instance.records,
      ),
    );
  }

  void restore() {
    workspaceController.replaceAggregate(workspaceAggregate);
    WorkspaceSession.instance.controller = workspaceController;
    TrustPackageArchiveStore.replaceAll(archives);
    TrustPackageShareStore.replaceAll(shareLinks);
    IncidentLibraryService.instance.restoreSnapshot(
      summaries: librarySummaries,
      records: libraryRecords,
    );
  }
}

/// Shared transactional deletion pipeline for investigation artifacts.
class InvestigationDataDeletionService {
  const InvestigationDataDeletionService({
    this.deletePersistedMedia,
    this.removeCloudBackups,
    this.removeSearchIndexes,
  });

  final Future<void> Function()? deletePersistedMedia;
  final Future<void> Function()? removeCloudBackups;
  final Future<void> Function()? removeSearchIndexes;

  Future<void> deleteAllInvestigationData() async {
    final snapshot = InvestigationDataDeletionSnapshot.capture();
    final sync = IncidentCloudSyncService.instance;
    sync.beginDestructiveWipe();
    try {
      final store = WorkspaceSession.instance.controller.aggregate.store;
      _deleteTrustPackages();
      _deleteRelationshipGroups(store);
      _deleteTimelineAnchors(store);
      _deleteNarrativeEvents(store);
      _deleteEvidence(store);
      await _recordPendingCloudWipe();
      await (removeCloudBackups ?? _defaultRemoveCloudBackups)();
      await _deleteIncidentsAndLocalIdentity();
      IncidentLibraryService.instance.clear();
      await (removeSearchIndexes ?? _defaultRemoveSearchIndexes)();
      await (deletePersistedMedia ?? _defaultDeletePersistedMedia)();
    } catch (error) {
      snapshot.restore();
      rethrow;
    } finally {
      sync.endDestructiveWipe();
    }
  }

  static void _deleteTrustPackages() {
    TrustPackageArchiveStore.clearAll();
    TrustPackageShareStore.clearAll();
  }

  static void _deleteRelationshipGroups(IncidentStore store) {
    store.relationshipGroups.clear();
    store.relationships.clear();
  }

  static void _deleteTimelineAnchors(IncidentStore store) {
    store.timelineAnchors.clear();
  }

  static void _deleteNarrativeEvents(IncidentStore store) {
    store.narrativeEvents.clear();
    store.reconstructionNotes.clear();
  }

  static void _deleteEvidence(IncidentStore store) {
    store.capturedEvidence.clear();
    store.supportingEvidence.clear();
  }

  /// Resets Workspace + durable local identity so a post-clear Capture Now
  /// cannot inherit titles / pointers / cache from deleted incidents.
  static Future<void> _deleteIncidentsAndLocalIdentity() async {
    final userId = UserSessionService.account?.userId ?? '';
    WorkspaceSession.instance.clearInvestigation();
    CaptureSessionManager.instance.clearMemory();
    await EvidenceSyncManager.instance.clearLocalSyncState();
    if (userId.isNotEmpty) {
      await LocalIncidentPointer.clearAllForUser(userId);
    }
    await LocalEvidenceCache.clearAll();
    await OrganizeContextPersistence.clearAll();
    await LocalCaptureSessionStore.clearAll();
    if (userId.isNotEmpty) {
      await DurableAttachIntentStore.clearPendingIntent(
        userId: userId,
        reason: 'clear_vault',
      );
    }
    await SafStagingBridge.discardAll();
  }

  static Future<void> _defaultDeletePersistedMedia() async {
    await EvidenceStorageService.clearAll();
    await EvidenceStorageService.clearTrustPackageExports();
  }

  static Future<void> _recordPendingCloudWipe() async {
    final userId = UserSessionService.account?.userId ?? '';
    if (userId.isEmpty || !FirebaseBootstrap.isAvailable) {
      return;
    }
    try {
      final ids = await FirebaseIncidentRepository().listIncidentIds(userId);
      await VaultWipePending.mark(userId: userId, incidentIds: ids);
    } catch (error) {
      debugPrint('[Vault] pending wipe mark skipped: $error');
    }
  }

  static Future<void> _defaultRemoveCloudBackups() async {
    final userId = UserSessionService.account?.userId ?? '';
    if (userId.isEmpty || !FirebaseBootstrap.isAvailable) {
      return;
    }
    try {
      final repo = FirebaseIncidentRepository();
      final incidentIds = await repo.listIncidentIds(userId);
      await VaultWipePending.mark(userId: userId, incidentIds: incidentIds);
      final storage = firebase_object_storage.EvidenceStorageService();
      for (final incidentId in incidentIds) {
        try {
          await storage.deleteIncidentOwnedPrefix(
            userId: userId,
            incidentId: incidentId,
          );
        } catch (error) {
          debugPrint('[Vault] cloud storage wipe skipped: $error');
        }
      }
      await repo.deleteAllIncidentsForUser(userId);
      await VaultWipePending.clear();
    } catch (error) {
      // Local identity still proceeds; pending ids keep Library empty until
      // a later refresh finishes the cloud delete.
      debugPrint('[Vault] cloud incident wipe failed: $error');
    }
  }

  static Future<void> _defaultRemoveSearchIndexes() async {
    // Search index removal will integrate with backend search in a later sprint.
  }
}
