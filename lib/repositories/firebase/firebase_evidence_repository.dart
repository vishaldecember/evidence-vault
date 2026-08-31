import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/evidence/captured_evidence.dart';
import '../../domain/evidence/supporting_evidence.dart';
import 'firestore_paths.dart';
import 'firestore_serializers.dart';

/// One evidence document loaded from Firestore, sorted by [timelineOrder].
class PersistedEvidenceBundle {
  const PersistedEvidenceBundle({
    required this.captured,
    required this.supporting,
  });

  final List<CapturedEvidence> captured;
  final List<SupportingEvidence> supporting;
}

/// Firestore persistence for evidence metadata — UI never calls Firestore.
class FirebaseEvidenceRepository {
  FirebaseEvidenceRepository({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _evidence(
    String uid,
    String incidentId,
  ) =>
      _db.collection(FirestorePaths.evidenceCollection(uid, incidentId));

  Future<void> upsertEvidenceDoc({
    required String userId,
    required String incidentId,
    required String evidenceId,
    required Map<String, dynamic> data,
  }) async {
    FirestoreSerializers.validateEvidenceMap(data);
    await _evidence(userId, incidentId).doc(evidenceId).set(
          data,
          SetOptions(merge: true),
        );
    debugPrint('[Firestore] evidence upserted → $evidenceId');
  }

  Future<void> upsertCaptured({
    required String userId,
    required CapturedEvidence evidence,
    required int timelineOrder,
    required List<String> supportingEvidenceIds,
    String? deviceModel,
    double? latitude,
    double? longitude,
    String? thumbnailStoragePath,
  }) {
    return upsertEvidenceDoc(
      userId: userId,
      incidentId: evidence.incidentId,
      evidenceId: evidence.id,
      data: FirestoreSerializers.capturedToMap(
        evidence,
        userId: userId,
        timelineOrder: timelineOrder,
        supportingEvidenceIds: supportingEvidenceIds,
        deviceModel: deviceModel,
        latitude: latitude,
        longitude: longitude,
        thumbnailStoragePath: thumbnailStoragePath,
      ),
    );
  }

  Future<void> upsertSupporting({
    required String userId,
    required SupportingEvidence evidence,
    required int timelineOrder,
    required List<String> supportingEvidenceIds,
    String? deviceModel,
    double? latitude,
    double? longitude,
    String? thumbnailStoragePath,
  }) {
    return upsertEvidenceDoc(
      userId: userId,
      incidentId: evidence.incidentId,
      evidenceId: evidence.id,
      data: FirestoreSerializers.supportingToMap(
        evidence,
        userId: userId,
        timelineOrder: timelineOrder,
        supportingEvidenceIds: supportingEvidenceIds,
        deviceModel: deviceModel,
        latitude: latitude,
        longitude: longitude,
        thumbnailStoragePath: thumbnailStoragePath,
      ),
    );
  }

  /// Deletes one evidence document. Storage cleanup happens separately via
  /// [IncidentCloudSyncService.deleteEvidenceCascade].
  Future<void> deleteEvidence({
    required String userId,
    required String incidentId,
    required String evidenceId,
  }) async {
    await _evidence(userId, incidentId).doc(evidenceId).delete();
    debugPrint('[Firestore] evidence deleted → $evidenceId');
  }

  /// Loads all evidence for an incident, sorted by timelineOrder ascending.
  Future<PersistedEvidenceBundle> loadEvidence({
    required String userId,
    required String incidentId,
  }) async {
    final snap = await _evidence(userId, incidentId)
        .orderBy('timelineOrder')
        .get();

    final captured = <CapturedEvidence>[];
    final supporting = <SupportingEvidence>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final kind = data['kind'] as String?;
      if (kind == 'supporting') {
        final item = FirestoreSerializers.supportingFromMap(data);
        if (item != null) {
          supporting.add(item);
        }
      } else {
        final item = FirestoreSerializers.capturedFromMap(data);
        if (item != null) {
          captured.add(item);
        } else {
          final asSupporting = FirestoreSerializers.supportingFromMap(data);
          if (asSupporting != null) {
            supporting.add(asSupporting);
          }
        }
      }
    }

    // Fallback sort if some docs lack timelineOrder.
    captured.sort((a, b) {
      final ao = a.timelineOrder ?? a.capturedAt.millisecondsSinceEpoch;
      final bo = b.timelineOrder ?? b.capturedAt.millisecondsSinceEpoch;
      return ao.compareTo(bo);
    });
    supporting.sort((a, b) {
      final ao = a.timelineOrder ?? a.createdAt.millisecondsSinceEpoch;
      final bo = b.timelineOrder ?? b.createdAt.millisecondsSinceEpoch;
      return ao.compareTo(bo);
    });

    debugPrint(
      '[Firestore] loaded evidence → captured=${captured.length} '
      'supporting=${supporting.length}',
    );
    return PersistedEvidenceBundle(
      captured: captured,
      supporting: supporting,
    );
  }
}
