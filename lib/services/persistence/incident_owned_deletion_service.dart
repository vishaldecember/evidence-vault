import 'package:flutter/foundation.dart';

import '../../controllers/workspace_session.dart';
import '../../repositories/firebase/firebase_incident_repository.dart';
import '../../repositories/trust_package_archive_store.dart';
import '../../repositories/trust_package_share_store.dart';
import '../auth/firebase_bootstrap.dart';
import '../investigation/reconstruction_location_label_store.dart';
import '../investigation/user_connection_overlay_store.dart';
import '../storage/evidence_storage_service.dart';
import '../storage/local_evidence_cache.dart';
import '../user_session_service.dart';
import '../vault/incident_collection_store.dart';
import 'local_capture_session_store.dart';
import 'local_incident_pointer.dart';
import 'organize_context_persistence.dart';

/// Ownership-safe permanent deletion for one incident.
///
/// Deletes only data that is addressed by [incidentId] (or whose originating
/// incident is that id). Does not wipe the vault, other incidents, or
/// user-scoped collection documents.
class IncidentOwnedDeletionService {
  const IncidentOwnedDeletionService({
    this.deleteCloudTree,
    this.deleteCloudStorage,
  });

  final Future<void> Function({
    required String userId,
    required String incidentId,
  })? deleteCloudTree;

  final Future<void> Function({
    required String userId,
    required String incidentId,
  })? deleteCloudStorage;

  Future<IncidentOwnedDeletionResult> deleteOwnedData({
    required String incidentId,
    String? userId,
  }) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return const IncidentOwnedDeletionResult.empty();
    }
    final owner = userId ?? UserSessionService.account?.userId ?? '';

    final localEvidenceIds = [
      for (final entry in await LocalEvidenceCache.all())
        if (entry.incidentId == id) entry.evidenceId,
    ];
    await LocalEvidenceCache.removeForIncident(id);
    await OrganizeContextPersistence.clearForIncident(id);
    await LocalCaptureSessionStore.removeForIncident(id);
    await UserConnectionOverlayStore.instance.removeForIncident(id);
    await ReconstructionLocationLabelStore.instance.removeForIncident(id);

    final removedArchiveIds = [
      for (final record in TrustPackageArchiveStore.forIncident(id))
        record.archiveId,
    ];
    TrustPackageArchiveStore.removeForIncident(id);
    if (removedArchiveIds.isNotEmpty) {
      final remaining = [
        for (final link in TrustPackageShareStore.all)
          if (!removedArchiveIds.contains(link.packageId) &&
              !removedArchiveIds.contains(link.trustPackageId))
            link,
      ];
      TrustPackageShareStore.replaceAll(remaining);
    }

    if (owner.isNotEmpty) {
      await LocalIncidentPointer.clearTitleForIncident(
        userId: owner,
        incidentId: id,
      );
      await LocalIncidentPointer.clearPointerIfIncident(
        userId: owner,
        incidentId: id,
      );
      await IncidentCollectionStore.instance.removeIncidentFromAll(
        userId: owner,
        incidentId: id,
      );
    }

    try {
      final session = WorkspaceSession.instance;
      if (session.controller.currentIncident.id == id) {
        session.clearInvestigation();
      }
    } catch (error) {
      debugPrint('[Deletion] session clear skipped: $error');
    }

    if (owner.isNotEmpty && FirebaseBootstrap.isAvailable) {
      try {
        await (deleteCloudTree ?? _defaultDeleteCloudTree)(
          userId: owner,
          incidentId: id,
        );
      } catch (error) {
        debugPrint('[Deletion] cloud tree skipped: $error');
      }
      try {
        await (deleteCloudStorage ?? _defaultDeleteCloudStorage)(
          userId: owner,
          incidentId: id,
        );
      } catch (error) {
        debugPrint('[Deletion] cloud storage skipped: $error');
      }
    }

    return IncidentOwnedDeletionResult(
      incidentId: id,
      localEvidenceIds: localEvidenceIds,
      removedArchiveIds: removedArchiveIds,
    );
  }

  static Future<void> _defaultDeleteCloudTree({
    required String userId,
    required String incidentId,
  }) {
    return FirebaseIncidentRepository().deleteOwnedIncidentTree(
      userId: userId,
      incidentId: incidentId,
    );
  }

  static Future<void> _defaultDeleteCloudStorage({
    required String userId,
    required String incidentId,
  }) {
    return EvidenceStorageService().deleteIncidentOwnedPrefix(
      userId: userId,
      incidentId: incidentId,
    );
  }
}

class IncidentOwnedDeletionResult {
  const IncidentOwnedDeletionResult({
    required this.incidentId,
    required this.localEvidenceIds,
    required this.removedArchiveIds,
  });

  const IncidentOwnedDeletionResult.empty()
      : incidentId = '',
        localEvidenceIds = const [],
        removedArchiveIds = const [];

  final String incidentId;
  final List<String> localEvidenceIds;
  final List<String> removedArchiveIds;
}
