import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/participant/participant.dart';
import '../../domain/reconstruction/narrative_event.dart';
import '../../domain/reconstruction/reconstruction_note.dart';
import '../../domain/relationship/relationship_group.dart';
import '../../domain/timeline/timeline_anchor.dart';
import '../../models/evidence_relationship.dart';
import '../incident_store.dart';
import 'firestore_paths.dart';
import 'firestore_serializers.dart';

/// Firestore persistence for the investigation graph (Sprint 4D).
///
/// Owns replace-all sync for an incident's timeline anchors, relationship
/// groups, evidence relationships, narrative events, and reconstruction
/// notes. UI never calls Firestore directly — this repository is used only
/// by [IncidentCloudSyncService].
class FirebaseInvestigationRepository {
  FirebaseInvestigationRepository({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _timelineAnchors(
    String uid,
    String incidentId,
  ) =>
      _db.collection(FirestorePaths.timelineAnchors(uid, incidentId));

  CollectionReference<Map<String, dynamic>> _relationshipGroups(
    String uid,
    String incidentId,
  ) =>
      _db.collection(FirestorePaths.relationshipGroups(uid, incidentId));

  CollectionReference<Map<String, dynamic>> _evidenceCollections(
    String uid,
    String incidentId,
  ) =>
      _db.collection(FirestorePaths.evidenceCollections(uid, incidentId));

  CollectionReference<Map<String, dynamic>> _relationships(
    String uid,
    String incidentId,
  ) =>
      _db.collection(FirestorePaths.relationships(uid, incidentId));

  CollectionReference<Map<String, dynamic>> _narrativeEvents(
    String uid,
    String incidentId,
  ) =>
      _db.collection(FirestorePaths.narrativeEvents(uid, incidentId));

  CollectionReference<Map<String, dynamic>> _reconstructionNotes(
    String uid,
    String incidentId,
  ) =>
      _db.collection(FirestorePaths.reconstructionNotes(uid, incidentId));

  CollectionReference<Map<String, dynamic>> _participants(
    String uid,
    String incidentId,
  ) =>
      _db.collection(FirestorePaths.participants(uid, incidentId));

  /// Replace-all sync of the full investigation graph for [store.incident].
  Future<void> persistGraph({
    required String userId,
    required IncidentStore store,
  }) async {
    final incidentId = store.incident.id;
    final batch = _db.batch();

    await _replaceCollection<TimelineAnchor>(
      batch: batch,
      collection: _timelineAnchors(userId, incidentId),
      items: store.timelineAnchors,
      idOf: (item) => item.id,
      toMap: FirestoreSerializers.timelineAnchorToMap,
    );
    await _replaceCollection<RelationshipGroup>(
      batch: batch,
      collection: _relationshipGroups(userId, incidentId),
      items: store.relationshipGroups,
      idOf: (item) => item.id,
      toMap: FirestoreSerializers.relationshipGroupToMap,
    );
    await _replaceCollection<EvidenceCollection>(
      batch: batch,
      collection: _evidenceCollections(userId, incidentId),
      items: store.evidenceCollections,
      idOf: (item) => item.id,
      toMap: FirestoreSerializers.evidenceCollectionToMap,
    );
    await _replaceCollection<EvidenceRelationship>(
      batch: batch,
      collection: _relationships(userId, incidentId),
      items: store.relationships,
      idOf: (item) => item.id,
      toMap: FirestoreSerializers.relationshipToMap,
    );
    await _replaceCollection<NarrativeEvent>(
      batch: batch,
      collection: _narrativeEvents(userId, incidentId),
      items: store.narrativeEvents,
      idOf: (item) => item.id,
      toMap: FirestoreSerializers.narrativeEventToMap,
    );
    await _replaceCollection<ReconstructionNote>(
      batch: batch,
      collection: _reconstructionNotes(userId, incidentId),
      items: store.reconstructionNotes,
      idOf: (item) => item.id,
      toMap: FirestoreSerializers.reconstructionNoteToMap,
    );
    await _replaceCollection<Participant>(
      batch: batch,
      collection: _participants(userId, incidentId),
      items: store.participants,
      idOf: (item) => item.id,
      toMap: FirestoreSerializers.participantToMap,
    );

    await batch.commit();
    debugPrint('[Firestore] investigation graph persisted → $incidentId');
  }

  /// Loads the full investigation graph into [store] (clear then fill).
  Future<void> loadGraphInto({
    required String userId,
    required String incidentId,
    required IncidentStore store,
  }) async {
    final anchorsSnap = await _timelineAnchors(userId, incidentId)
        .orderBy('sequenceOrder')
        .get();
    final groupsSnap = await _relationshipGroups(userId, incidentId).get();
    final collectionsSnap =
        await _evidenceCollections(userId, incidentId).get();
    final relationshipsSnap = await _relationships(userId, incidentId).get();
    final narrativeSnap = await _narrativeEvents(userId, incidentId)
        .orderBy('sortOrder')
        .get();
    final notesSnap = await _reconstructionNotes(userId, incidentId).get();
    final participantsSnap = await _participants(userId, incidentId).get();

    final anchors = [
      for (final doc in anchorsSnap.docs)
        FirestoreSerializers.timelineAnchorFromMap(doc.data(), doc.id),
    ];
    final groups = [
      for (final doc in groupsSnap.docs)
        FirestoreSerializers.relationshipGroupFromMap(doc.data(), doc.id),
    ];
    final collections = [
      for (final doc in collectionsSnap.docs)
        FirestoreSerializers.evidenceCollectionFromMap(doc.data(), doc.id),
    ]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final relationships = [
      for (final doc in relationshipsSnap.docs)
        FirestoreSerializers.relationshipFromMap(doc.data(), doc.id),
    ];
    final narrativeEvents = [
      for (final doc in narrativeSnap.docs)
        FirestoreSerializers.narrativeEventFromMap(doc.data(), doc.id),
    ];
    final notes = [
      for (final doc in notesSnap.docs)
        FirestoreSerializers.reconstructionNoteFromMap(doc.data(), doc.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final participants = [
      for (final doc in participantsSnap.docs)
        FirestoreSerializers.participantFromMap(doc.data(), doc.id),
    ];

    store.timelineAnchors
      ..clear()
      ..addAll(anchors);
    store.relationshipGroups
      ..clear()
      ..addAll(groups);
    store.evidenceCollections
      ..clear()
      ..addAll(collections);
    store.relationships
      ..clear()
      ..addAll(relationships);
    store.narrativeEvents
      ..clear()
      ..addAll(narrativeEvents);
    store.reconstructionNotes
      ..clear()
      ..addAll(notes);
    store.participants
      ..clear()
      ..addAll(participants);

    debugPrint(
      '[Firestore] investigation graph loaded → anchors=${anchors.length} '
      'groups=${groups.length} collections=${collections.length} '
      'relationships=${relationships.length} '
      'narrative=${narrativeEvents.length} notes=${notes.length} '
      'participants=${participants.length}',
    );
  }

  /// Diffs [items] against the existing docs in [collection] and stages
  /// set/delete operations on [batch] so removed entries are cleaned up.
  Future<void> _replaceCollection<T>({
    required WriteBatch batch,
    required CollectionReference<Map<String, dynamic>> collection,
    required List<T> items,
    required String Function(T item) idOf,
    required Map<String, dynamic> Function(T item) toMap,
  }) async {
    final existing = await collection.get();
    final currentIds = items.map(idOf).toSet();

    for (final doc in existing.docs) {
      if (!currentIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final item in items) {
      batch.set(
        collection.doc(idOf(item)),
        toMap(item),
        SetOptions(merge: true),
      );
    }
  }
}
