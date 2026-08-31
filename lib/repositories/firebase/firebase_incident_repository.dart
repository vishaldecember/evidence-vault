import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/incident/incident.dart';
import '../../domain/incident/incident_status.dart';
import 'firestore_paths.dart';
import 'firestore_serializers.dart';

/// Firestore persistence for incidents — UI never calls Firestore directly.
class FirebaseIncidentRepository {
  FirebaseIncidentRepository({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  static const _uuid = Uuid();

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _incidents(String uid) =>
      _db.collection(FirestorePaths.incidents(uid));

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.doc(FirestorePaths.user(uid));

  /// Patches title/status/updatedAt only — never zeroes derived counters.
  Future<void> patchIncidentIdentity({
    required String userId,
    required Incident incident,
  }) async {
    await _incidents(userId).doc(incident.id).set(
      {
        'incidentId': incident.id,
        'ownerId': userId,
        'title': incident.title,
        'status': incident.status.name,
        'manuallyComplete': incident.manuallyComplete,
        'updatedAt': incident.updatedAt.toIso8601String(),
        'deletedAt': incident.deletedAt == null
            ? FieldValue.delete()
            : incident.deletedAt!.toIso8601String(),
      },
      SetOptions(merge: true),
    );
    debugPrint('[Firestore] incident identity patched → ${incident.id}');
  }

  /// Creates or updates the incident document and marks it active on the user.
  Future<void> upsertIncident({
    required String userId,
    required Incident incident,
    required int timelineCount,
    required int relationshipCount,
    required int narrativeCount,
    required int reconstructionHealth,
    int? evidenceCount,
  }) async {
    final data = FirestoreSerializers.incidentToMap(
      incident: incident,
      ownerId: userId,
      timelineCount: timelineCount,
      relationshipCount: relationshipCount,
      narrativeCount: narrativeCount,
      reconstructionHealth: reconstructionHealth,
      evidenceCount: evidenceCount,
    );

    final batch = _db.batch();
    batch.set(
      _incidents(userId).doc(incident.id),
      data,
      SetOptions(merge: true),
    );
    batch.set(
      _userDoc(userId),
      {
        'activeIncidentId': incident.id,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    debugPrint('[Firestore] incident upserted → ${incident.id}');
  }

  Future<String?> readActiveIncidentId(String userId) async {
    final snap = await _userDoc(userId).get();
    if (!snap.exists) {
      return null;
    }
    return snap.data()?['activeIncidentId'] as String?;
  }

  Future<Incident?> loadIncident(String userId, String incidentId) async {
    final snap = await _incidents(userId).doc(incidentId).get();
    if (!snap.exists || snap.data() == null) {
      return null;
    }
    return FirestoreSerializers.incidentFromMap(snap.data()!, snap.id);
  }

  /// Most recently updated incident for the user, if any.
  Future<Incident?> loadLatestIncident(String userId) async {
    final query = await _incidents(userId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return null;
    }
    final doc = query.docs.first;
    return FirestoreSerializers.incidentFromMap(doc.data(), doc.id);
  }

  /// All incidents for the user, most recently updated first.
  Future<List<Incident>> listIncidents(String userId) async {
    final query =
        await _incidents(userId).orderBy('updatedAt', descending: true).get();
    return [
      for (final doc in query.docs)
        FirestoreSerializers.incidentFromMap(doc.data(), doc.id),
    ];
  }

  /// Every incident preserved by the user with its derived counters —
  /// powers Home / Vault library surfaces without a second query per incident
  /// (Sprint 4D).
  Future<List<IncidentSummaryRecord>> listIncidentSummaries(
    String userId,
  ) async {
    final query =
        await _incidents(userId).orderBy('updatedAt', descending: true).get();
    return [
      for (final doc in query.docs)
        IncidentSummaryRecord(
          incident: FirestoreSerializers.incidentFromMap(doc.data(), doc.id),
          timelineCount: (doc.data()['timelineCount'] as num?)?.toInt() ?? 0,
          evidenceCount: (doc.data()['evidenceCount'] as num?)?.toInt() ??
              (doc.data()['timelineCount'] as num?)?.toInt() ??
              0,
          relationshipCount:
              (doc.data()['relationshipCount'] as num?)?.toInt() ?? 0,
          narrativeCount:
              (doc.data()['narrativeCount'] as num?)?.toInt() ?? 0,
          reconstructionHealth:
              (doc.data()['reconstructionHealth'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  /// Marks [incidentId] as the active incident for the user.
  Future<void> setActiveIncidentId(String userId, String incidentId) async {
    await _userDoc(userId).set(
      {
        'activeIncidentId': incidentId,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
    debugPrint('[Firestore] active incident set → $incidentId');
  }

  Future<Incident> ensureIncident({
    required String userId,
    Incident? seed,
  }) async {
    final activeId = await readActiveIncidentId(userId);
    if (activeId != null) {
      final existing = await loadIncident(userId, activeId);
      if (existing != null) {
        return existing;
      }
    }

    final latest = await loadLatestIncident(userId);
    if (latest != null) {
      await _userDoc(userId).set(
        {'activeIncidentId': latest.id},
        SetOptions(merge: true),
      );
      return latest;
    }

    final now = DateTime.now();
    final incident = seed ??
        Incident(
          id: 'incident-${_uuid.v4()}',
          title: '',
          status: IncidentStatus.draft,
          createdAt: now,
          updatedAt: now,
        );

    await upsertIncident(
      userId: userId,
      incident: incident,
      timelineCount: 0,
      relationshipCount: 0,
      narrativeCount: 0,
      reconstructionHealth: 0,
    );
    return incident;
  }

  /// Deletes one incident document and its known incident-owned subcollections.
  ///
  /// Does **not** delete user-scoped [incidentCollections] or other incidents.
  /// Clears [activeIncidentId] only when it points at [incidentId].
  Future<void> deleteOwnedIncidentTree({
    required String userId,
    required String incidentId,
  }) async {
    final id = incidentId.trim();
    if (userId.isEmpty || id.isEmpty) {
      return;
    }
    final subcollections = [
      FirestorePaths.evidenceCollection(userId, id),
      FirestorePaths.timelineAnchors(userId, id),
      FirestorePaths.relationshipGroups(userId, id),
      FirestorePaths.evidenceCollections(userId, id),
      FirestorePaths.relationships(userId, id),
      FirestorePaths.narrativeEvents(userId, id),
      FirestorePaths.reconstructionNotes(userId, id),
      FirestorePaths.participants(userId, id),
    ];
    for (final path in subcollections) {
      await _deleteCollectionDocs(path);
    }
    await _incidents(userId).doc(id).delete();

    final activeId = await readActiveIncidentId(userId);
    if (activeId == id) {
      await _userDoc(userId).set(
        {
          'activeIncidentId': FieldValue.delete(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    }
    debugPrint('[Firestore] deleted owned incident tree → $id');
  }

  Future<void> _deleteCollectionDocs(String path) async {
    final query = await _db.collection(path).get();
    if (query.docs.isEmpty) {
      return;
    }
    const chunk = 400;
    for (var i = 0; i < query.docs.length; i += chunk) {
      final batch = _db.batch();
      final end = i + chunk > query.docs.length ? query.docs.length : i + chunk;
      for (final doc in query.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Deletes every incident document for [userId] and clears activeIncidentId.
  ///
  /// Used by Clear Vault so Library/refresh cannot resurrect old titles.
  Future<void> deleteAllIncidentsForUser(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    final query = await _incidents(userId).get();
    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    batch.set(
      _userDoc(userId),
      {
        'activeIncidentId': FieldValue.delete(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    debugPrint(
      '[Firestore] deleted ${query.docs.length} incidents for user=$userId',
    );
  }
}

/// Incident plus the derived counters stored alongside it in Firestore —
/// enough to render Library summaries without a second query per incident.
class IncidentSummaryRecord {
  const IncidentSummaryRecord({
    required this.incident,
    required this.timelineCount,
    required this.evidenceCount,
    required this.relationshipCount,
    required this.narrativeCount,
    required this.reconstructionHealth,
  });

  final Incident incident;
  final int timelineCount;
  final int evidenceCount;
  final int relationshipCount;
  final int narrativeCount;
  final int reconstructionHealth;
}
