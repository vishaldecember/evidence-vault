import '../../domain/vault/incident_collection.dart';
import 'incident_collection_store.dart';

/// Incident → Incident drop. Creates a user collection of IDs only.
///
/// Does not write Incident or Evidence documents.
class VaultIncidentGrouping {
  const VaultIncidentGrouping({this._store});

  final IncidentCollectionStore? _store;

  IncidentCollectionStore get store =>
      _store ?? IncidentCollectionStore.instance;

  static const defaultTitle = 'Collection';

  /// Returns null when the drop is invalid. Membership is
  /// `[sourceIncidentId, targetIncidentId]` in that order.
  Future<IncidentCollection?> groupIncidents({
    required String userId,
    required String sourceIncidentId,
    required String targetIncidentId,
  }) async {
    final source = sourceIncidentId.trim();
    final target = targetIncidentId.trim();
    if (userId.trim().isEmpty || source.isEmpty || target.isEmpty) {
      return null;
    }
    if (source == target) {
      return null;
    }
    return store.create(
      userId: userId,
      title: defaultTitle,
      memberIncidentIds: [source, target],
    );
  }

  /// Adds [incidentId] to an existing collection. Duplicate membership is
  /// a no-op. Does not write Incident or Evidence documents.
  Future<IncidentCollection?> addIncidentToCollection({
    required String userId,
    required String collectionId,
    required String incidentId,
  }) async {
    final uid = userId.trim();
    final collection = collectionId.trim();
    final incident = incidentId.trim();
    if (uid.isEmpty || collection.isEmpty || incident.isEmpty) {
      return null;
    }
    return store.addMember(
      userId: uid,
      collectionId: collection,
      incidentId: incident,
    );
  }
}
