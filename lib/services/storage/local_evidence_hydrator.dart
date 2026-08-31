import 'package:flutter/foundation.dart';

import '../../repositories/evidence_repository.dart';
import '../user_session_service.dart';
import 'local_evidence_cache.dart';

/// Merges durable local cache rows into [EvidenceRepository] (Sprint 6B).
///
/// Workspace reads evidence through the repository — never Firebase directly.
/// Local cache is the temporary source of truth for unsynced / offline captures.
abstract final class LocalEvidenceHydrator {
  /// Inserts missing cache rows for [incidentId] into [repository].
  ///
  /// Returns the number of newly inserted evidence items.
  static Future<int> hydrateIncident({
    required String incidentId,
    required EvidenceRepository repository,
    String? userId,
  }) async {
    if (incidentId.isEmpty) {
      return 0;
    }
    try {
      final scopedUserId =
          userId ?? UserSessionService.account?.userId;
      final cached = await LocalEvidenceCache.forIncident(
        incidentId,
        userId: scopedUserId,
      );
      var inserted = 0;
      for (final entry in cached) {
        if (repository.upsertFromLocalCache(entry)) {
          inserted++;
        }
      }
      if (inserted > 0) {
        debugPrint(
          '[LocalEvidenceHydrator] restored $inserted local evidence '
          'for $incidentId',
        );
      }
      return inserted;
    } catch (error) {
      debugPrint('[LocalEvidenceHydrator] hydrate failed: $error');
      return 0;
    }
  }
}
