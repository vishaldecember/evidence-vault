import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/vault/incident_collection.dart';
import '../../repositories/firebase/firestore_paths.dart';
import '../../repositories/firebase/firestore_serializers.dart';
import '../auth/firebase_bootstrap.dart';

/// User-scoped Incident Collections. Membership is incident IDs only.
///
/// Does not write Incident documents, evidence, chronology, status, or
/// archive state. Stale member IDs (deleted later) are left in place.
class IncidentCollectionStore {
  IncidentCollectionStore({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  static final IncidentCollectionStore instance = IncidentCollectionStore();

  static const _uuid = Uuid();

  final FirebaseFirestore? _firestoreOverride;
  final Map<String, Map<String, IncidentCollection>> _byUser = {};

  /// Creates a collection. Empty membership is allowed internally.
  Future<IncidentCollection> create({
    required String userId,
    required String title,
    List<String> memberIncidentIds = const [],
  }) async {
    final uid = _requireUserId(userId);
    final now = _now();
    final collection = IncidentCollection(
      id: 'collection-${_uuid.v4()}',
      title: title.trim(),
      createdAt: now,
      updatedAt: now,
      memberIncidentIds: memberIncidentIds,
    );
    _put(uid, collection);
    await _persist(uid, collection);
    return collection;
  }

  Future<IncidentCollection?> get({
    required String userId,
    required String collectionId,
  }) async {
    final uid = _requireUserId(userId);
    final id = collectionId.trim();
    if (id.isEmpty) {
      return null;
    }
    final cached = _byUser[uid]?[id];
    if (cached != null) {
      return cached;
    }
    return _loadRemote(uid, id);
  }

  /// User collections, most recently updated first, then id.
  Future<List<IncidentCollection>> list({required String userId}) async {
    final uid = _requireUserId(userId);
    await _hydrateUser(uid);
    final collections = [...?_byUser[uid]?.values];
    collections.sort((a, b) {
      final byUpdated = b.updatedAt.compareTo(a.updatedAt);
      if (byUpdated != 0) {
        return byUpdated;
      }
      return a.id.compareTo(b.id);
    });
    return List.unmodifiable(collections);
  }

  Future<IncidentCollection?> updateTitle({
    required String userId,
    required String collectionId,
    required String title,
  }) async {
    final existing = await get(userId: userId, collectionId: collectionId);
    if (existing == null) {
      return null;
    }
    final next = existing.copyWith(
      title: title.trim(),
      updatedAt: _now(),
    );
    return _commit(userId, next);
  }

  /// Idempotent. Duplicate membership does not rewrite the collection.
  Future<IncidentCollection?> addMember({
    required String userId,
    required String collectionId,
    required String incidentId,
  }) async {
    final existing = await get(userId: userId, collectionId: collectionId);
    if (existing == null) {
      return null;
    }
    final next = existing.withMember(incidentId, updatedAt: _now());
    if (identical(next, existing)) {
      return existing;
    }
    return _commit(userId, next);
  }

  /// Idempotent. Removing a non-member does not rewrite the collection.
  Future<IncidentCollection?> removeMember({
    required String userId,
    required String collectionId,
    required String incidentId,
  }) async {
    final existing = await get(userId: userId, collectionId: collectionId);
    if (existing == null) {
      return null;
    }
    final next = existing.withoutMember(incidentId, updatedAt: _now());
    if (identical(next, existing)) {
      return existing;
    }
    return _commit(userId, next);
  }

  /// Removes [incidentId] from every collection for [userId].
  ///
  /// Does not delete collection documents or other members.
  Future<void> removeIncidentFromAll({
    required String userId,
    required String incidentId,
  }) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    final collections = await list(userId: userId);
    for (final collection in collections) {
      await removeMember(
        userId: userId,
        collectionId: collection.id,
        incidentId: id,
      );
    }
  }

  /// Deletes the collection document only. Member incidents are untouched.
  Future<void> delete({
    required String userId,
    required String collectionId,
  }) async {
    final uid = _requireUserId(userId);
    final id = collectionId.trim();
    if (id.isEmpty) {
      return;
    }
    _byUser[uid]?.remove(id);
    if (!_canPersist) {
      return;
    }
    try {
      await _db.doc(FirestorePaths.incidentCollection(uid, id)).delete();
    } catch (error) {
      debugPrint('[IncidentCollection] delete skipped: $error');
    }
  }

  Future<IncidentCollection> _commit(
    String userId,
    IncidentCollection collection,
  ) async {
    final uid = _requireUserId(userId);
    _put(uid, collection);
    await _persist(uid, collection);
    return collection;
  }

  void _put(String userId, IncidentCollection collection) {
    _byUser.putIfAbsent(userId, () => {});
    _byUser[userId]![collection.id] = collection;
  }

  Future<void> _persist(String userId, IncidentCollection collection) async {
    if (!_canPersist) {
      return;
    }
    try {
      await _db.doc(FirestorePaths.incidentCollection(userId, collection.id)).set(
            FirestoreSerializers.incidentCollectionToMap(collection),
            SetOptions(merge: true),
          );
    } catch (error) {
      // Keep the in-memory membership. Firestore permission/network failures
      // must not roll back a successful local grouping.
      debugPrint('[IncidentCollection] persist skipped: $error');
    }
  }

  Future<IncidentCollection?> _loadRemote(
    String userId,
    String collectionId,
  ) async {
    if (!_canPersist) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db
          .doc(FirestorePaths.incidentCollection(userId, collectionId))
          .get();
    } catch (error) {
      debugPrint('[IncidentCollection] load skipped: $error');
      return _byUser[userId]?[collectionId];
    }
    if (!snap.exists || snap.data() == null) {
      return null;
    }
    final collection = FirestoreSerializers.incidentCollectionFromMap(
      snap.data()!,
      snap.id,
    );
    _put(userId, collection);
    return collection;
  }

  Future<void> _hydrateUser(String userId) async {
    if (!_canPersist) {
      return;
    }
    final QuerySnapshot<Map<String, dynamic>> query;
    try {
      query = await _db
          .collection(FirestorePaths.incidentCollections(userId))
          .get();
    } catch (error) {
      debugPrint('[IncidentCollection] hydrate skipped: $error');
      return;
    }
    final remote = <String, IncidentCollection>{};
    for (final doc in query.docs) {
      remote[doc.id] = FirestoreSerializers.incidentCollectionFromMap(
        doc.data(),
        doc.id,
      );
    }
    final local = _byUser[userId];
    if (local != null) {
      for (final entry in local.entries) {
        remote.putIfAbsent(entry.key, () => entry.value);
      }
    }
    _byUser[userId] = remote;
  }

  bool get _canPersist {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    if (_firestoreOverride != null) {
      return true;
    }
    return FirebaseBootstrap.isAvailable;
  }

  FirebaseFirestore get _db =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static String _requireUserId(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User id is required');
    }
    return uid;
  }

  static DateTime _now() => DateTime.now().toUtc();

  /// Test seam — clears the in-memory working set. Does not write incidents.
  @visibleForTesting
  void debugReset() {
    _byUser.clear();
  }
}
