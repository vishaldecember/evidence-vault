import '../../domain/collection/evidence_collection.dart';
import '../../domain/evidence/captured_evidence.dart';
import '../../domain/evidence/captured_evidence_type.dart';
import '../../domain/evidence/evidence_provenance_event.dart';
import '../../domain/evidence/evidence_sync_status.dart';
import '../../domain/evidence/evidence_temporal_intent.dart';
import '../../domain/evidence/supporting_evidence.dart';
import '../../domain/evidence/supporting_evidence_type.dart';
import '../../domain/incident/incident.dart';
import '../../domain/incident/incident_status.dart';
import '../../domain/participant/participant.dart';
import '../../domain/participant/participant_role.dart';
import '../../domain/reconstruction/narrative_event.dart';
import '../../domain/reconstruction/reconstruction_note.dart';
import '../../domain/relationship/relationship_group.dart';
import '../../domain/timeline/timeline_anchor.dart';
import '../../domain/vault/incident_collection.dart';
import '../../models/evidence_relationship.dart';
import '../../models/relationship_type.dart';
import '../../models/verification_factory.dart';
import '../../services/storage/evidence_upload_models.dart';
import '../../utils/instant_codec.dart';

/// Serializes domain objects to / from Firestore maps (Sprint 4D).
abstract final class FirestoreSerializers {
  static Map<String, dynamic> incidentToMap({
    required Incident incident,
    required String ownerId,
    required int timelineCount,
    required int relationshipCount,
    required int narrativeCount,
    required int reconstructionHealth,
    int? evidenceCount,
  }) {
    return {
      'incidentId': incident.id,
      'ownerId': ownerId,
      'title': incident.title,
      'status': incident.status.name,
      'manuallyComplete': incident.manuallyComplete,
      'createdAt': incident.createdAt.toIso8601String(),
      'updatedAt': incident.updatedAt.toIso8601String(),
      'timelineCount': timelineCount,
      'relationshipCount': relationshipCount,
      'narrativeCount': narrativeCount,
      'reconstructionHealth': reconstructionHealth,
      'evidenceCount': evidenceCount ?? timelineCount,
      'activeIncident': true,
      'coverEvidenceId': incident.coverEvidenceId,
      'deletedAt': incident.deletedAt?.toIso8601String(),
    };
  }

  static Incident incidentFromMap(Map<String, dynamic> data, String docId) {
    // Empty-string incidentId must NOT win over the Firestore document id.
    // Untitled drafts have historically been written with incidentId:'' which
    // made every Untitled Library card share id="" and fail to open.
    final rawId = data['incidentId'] as String?;
    final id = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : docId;
    return Incident(
      id: id,
      title: (data['title'] as String?) ?? '',
      status: _statusFrom((data['status'] as String?) ?? 'draft'),
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      updatedAt: _date(data['updatedAt']) ?? DateTime.now(),
      manuallyComplete: data['manuallyComplete'] as bool? ?? false,
      coverEvidenceId: Incident.normalizeCoverEvidenceId(
        data['coverEvidenceId'] as String?,
      ),
      deletedAt: _date(data['deletedAt']),
    );
  }

  static Map<String, dynamic> incidentCollectionToMap(
    IncidentCollection collection,
  ) {
    return {
      'collectionId': collection.id,
      'title': collection.title,
      'memberIncidentIds': collection.memberIncidentIds,
      'createdAt': InstantCodec.encode(collection.createdAt),
      'updatedAt': InstantCodec.encode(collection.updatedAt),
    };
  }

  static IncidentCollection incidentCollectionFromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    final rawId = data['collectionId'] as String? ?? data['id'] as String?;
    final id = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : docId;
    return IncidentCollection(
      id: id,
      title: (data['title'] as String?) ?? '',
      createdAt: _date(data['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _date(data['updatedAt']) ?? DateTime.now().toUtc(),
      memberIncidentIds: ((data['memberIncidentIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  // ---------------------------------------------------------------------
  // Evidence (captured + supporting)
  // ---------------------------------------------------------------------

  /// Throws [StateError] when a Firestore evidence write would be incomplete.
  static void validateEvidenceMap(Map<String, dynamic> data) {
    final evidenceId = data['evidenceId'] as String?;
    final incidentId = data['incidentId'] as String?;
    final userId = data['userId'] as String?;
    final type = data['type'] as String?;
    if (evidenceId == null || evidenceId.isEmpty) {
      throw StateError('Evidence write rejected: evidenceId missing.');
    }
    if (incidentId == null || incidentId.isEmpty) {
      throw StateError('Evidence write rejected: incidentId missing.');
    }
    if (userId == null || userId.isEmpty) {
      throw StateError('Evidence write rejected: userId missing.');
    }
    if (type == null || type.isEmpty) {
      throw StateError('Evidence write rejected: type missing.');
    }
  }

  static Map<String, dynamic> capturedToMap(
    CapturedEvidence item, {
    required String userId,
    required int timelineOrder,
    required List<String> supportingEvidenceIds,
    String? deviceModel,
    double? latitude,
    double? longitude,
    String? thumbnailStoragePath,
  }) {
    final now = DateTime.now();
    final map = <String, dynamic>{
      'userId': userId,
      'evidenceId': item.id,
      'incidentId': item.incidentId,
      'kind': 'captured',
      'type': item.type.name,
      'downloadUrl': item.downloadUrl,
      'thumbnailUrl': item.thumbnailUrl,
      'thumbnailStoragePath': thumbnailStoragePath,
      'storagePath': item.storagePath,
      'filename': item.fileName,
      'mimeType': item.mimeType,
      'fileSize': item.fileSizeBytes,
      'fileSizeBytes': item.fileSizeBytes,
      'context': item.resolvedContext,
      'notes': item.resolvedContext,
      'captureTimestamp': InstantCodec.encode(item.capturedAt),
      'capturedAt': InstantCodec.encode(item.capturedAt),
      'createdAt': InstantCodec.encode(item.createdAt ?? item.capturedAt),
      'updatedAt': InstantCodec.encode(item.updatedAt ?? now),
      'location': _locationMap(
        latitude ?? item.latitude,
        longitude ?? item.longitude,
      ),
      'device': deviceModel ?? item.deviceModel,
      'timelineOrder': timelineOrder,
      'timelineAnchorId': item.timelineAnchorId,
      'parentEvidenceId': null,
      'supportingEvidenceIds': supportingEvidenceIds,
      'title': item.title,
      'participantId': item.participantId,
      'uploadStatus': item.uploadStatus.name,
      'syncStatus': item.syncStatus.wireName,
      'uploadProgress': item.uploadProgress,
      'retryCount': item.retryCount,
      if (item.contentHash != null) 'contentHash': item.contentHash,
      if (item.temporalIntent != null)
        'temporalIntent': item.temporalIntent!.wireName,
      if (item.metadata.isNotEmpty) 'metadata': item.metadata,
      if (item.provenanceEvents.isNotEmpty)
        'provenanceEvents': [
          for (final event in item.provenanceEvents) event.toJson(),
        ],
      if (item.collectionId != null) 'collectionId': item.collectionId,
      if (item.captureSessionId != null)
        'captureSessionId': item.captureSessionId,
      'isPrimaryEvidence': item.isPrimaryEvidence,
    };
    validateEvidenceMap(map);
    return map;
  }

  static Map<String, dynamic> supportingToMap(
    SupportingEvidence item, {
    required String userId,
    required int timelineOrder,
    required List<String> supportingEvidenceIds,
    String? deviceModel,
    double? latitude,
    double? longitude,
    String? thumbnailStoragePath,
  }) {
    final map = <String, dynamic>{
      'userId': userId,
      'evidenceId': item.id,
      'incidentId': item.incidentId,
      'kind': 'supporting',
      'type': item.type.name,
      'downloadUrl': item.downloadUrl,
      'thumbnailUrl': item.thumbnailUrl,
      'thumbnailStoragePath': thumbnailStoragePath,
      'storagePath': item.storagePath,
      'filename': item.fileName,
      'mimeType': item.mimeType,
      'fileSize': item.fileSizeBytes,
      'fileSizeBytes': item.fileSizeBytes,
      'context': item.resolvedContext,
      'notes': item.resolvedContext,
      'captureTimestamp': InstantCodec.encode(item.createdAt),
      'capturedAt': InstantCodec.encode(item.createdAt),
      'createdAt': InstantCodec.encode(item.createdAt),
      'updatedAt': InstantCodec.encode(item.updatedAt ?? item.createdAt),
      'location': _locationMap(
        latitude ?? item.latitude,
        longitude ?? item.longitude,
      ),
      'device': deviceModel ?? item.deviceModel,
      'timelineOrder': timelineOrder,
      'parentEvidenceId': item.resolvedParentEvidenceId,
      'relationshipType': item.relationshipType.name,
      'supportingEvidenceIds': supportingEvidenceIds,
      'linkedCapturedEvidenceIds': item.linkedCapturedEvidenceIds.toList(),
      'title': item.title,
      'participantId': item.participantId,
      'uploadStatus': item.uploadStatus.name,
      'syncStatus': item.syncStatus.wireName,
      'uploadProgress': item.uploadProgress,
      'retryCount': item.retryCount,
      if (item.contentHash != null) 'contentHash': item.contentHash,
      if (item.temporalIntent != null)
        'temporalIntent': item.temporalIntent!.wireName,
      if (item.metadata.isNotEmpty) 'metadata': item.metadata,
      if (item.provenanceEvents.isNotEmpty)
        'provenanceEvents': [
          for (final event in item.provenanceEvents) event.toJson(),
        ],
      if (item.collectionId != null) 'collectionId': item.collectionId,
      if (item.captureSessionId != null)
        'captureSessionId': item.captureSessionId,
    };
    validateEvidenceMap(map);
    return map;
  }

  static CapturedEvidence? capturedFromMap(Map<String, dynamic> data) {
    if ((data['kind'] as String?) == 'supporting') {
      return null;
    }
    final typeName = data['type'] as String? ?? 'photo';
    final type = CapturedEvidenceType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => CapturedEvidenceType.photo,
    );
    final location = data['location'];
    final capturedAt =
        _date(data['captureTimestamp']) ??
        _date(data['capturedAt']) ??
        DateTime.now();
    return CapturedEvidence(
      id: data['evidenceId'] as String? ?? '',
      incidentId: data['incidentId'] as String? ?? '',
      type: type,
      capturedAt: capturedAt,
      title: data['title'] as String? ?? type.label,
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      timelineAnchorId:
          data['timelineAnchorId'] as String? ?? 'anchor-${data['evidenceId']}',
      notePreview: (data['context'] ?? data['notes']) as String?,
      context: data['context'] as String?,
      fileName: data['filename'] as String?,
      participantId: data['participantId'] as String?,
      storagePath: data['storagePath'] as String?,
      downloadUrl: data['downloadUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      mimeType: data['mimeType'] as String?,
      fileSizeBytes:
          (data['fileSizeBytes'] as num?)?.toInt() ??
          (data['fileSize'] as num?)?.toInt(),
      uploadStatus: _uploadStatus(data['uploadStatus'] as String?),
      syncStatus: _syncStatus(data['syncStatus'] as String?),
      deviceModel: data['device'] as String?,
      latitude: _coord(location, 'latitude'),
      longitude: _coord(location, 'longitude'),
      timelineOrder: (data['timelineOrder'] as num?)?.toInt(),
      createdAt: _date(data['createdAt']) ?? capturedAt,
      updatedAt: _date(data['updatedAt']),
      collectionId: data['collectionId'] as String?,
      captureSessionId: data['captureSessionId'] as String?,
      isPrimaryEvidence:
          data['isPrimaryEvidence'] as bool? ??
          ((data['type'] as String?) == 'photo' ||
              (data['type'] as String?) == 'video' ||
              (data['type'] as String?) == 'voice'),
      uploadProgress: (data['uploadProgress'] as num?)?.toDouble() ?? 0,
      retryCount: (data['retryCount'] as num?)?.toInt() ?? 0,
      contentHash: data['contentHash'] as String?,
      temporalIntent: EvidenceTemporalIntent.fromWire(data['temporalIntent']),
      metadata: _stringMap(data['metadata']),
      provenanceEvents: EvidenceProvenanceEvent.fromJsonList(
        data['provenanceEvents'],
      ),
    );
  }

  static SupportingEvidence? supportingFromMap(Map<String, dynamic> data) {
    if ((data['kind'] as String?) != 'supporting') {
      // Notes/files without kind still map if type is supporting.
      final typeName = data['type'] as String? ?? '';
      final isSupporting = SupportingEvidenceType.values.any(
        (value) => value.name == typeName,
      );
      if (!isSupporting) {
        return null;
      }
    }
    final typeName = data['type'] as String? ?? 'note';
    final type = SupportingEvidenceType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => SupportingEvidenceType.note,
    );
    final location = data['location'];
    final linked = ((data['linkedCapturedEvidenceIds'] as List?) ?? const [])
        .whereType<String>()
        .toSet();
    final parentId = data['parentEvidenceId'] as String?;
    final createdAt =
        _date(data['captureTimestamp']) ??
        _date(data['capturedAt']) ??
        DateTime.now();
    return SupportingEvidence(
      id: data['evidenceId'] as String? ?? '',
      incidentId: data['incidentId'] as String? ?? '',
      type: type,
      createdAt: _date(data['createdAt']) ?? createdAt,
      title: data['title'] as String? ?? type.label,
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      notePreview: (data['context'] ?? data['notes']) as String?,
      context: data['context'] as String?,
      fileName: data['filename'] as String?,
      parentEvidenceId: parentId,
      relationshipType: _relationship(data['relationshipType'] as String?),
      linkedCapturedEvidenceIds: {?parentId, ...linked},
      participantId: data['participantId'] as String?,
      storagePath: data['storagePath'] as String?,
      downloadUrl: data['downloadUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      mimeType: data['mimeType'] as String?,
      fileSizeBytes:
          (data['fileSizeBytes'] as num?)?.toInt() ??
          (data['fileSize'] as num?)?.toInt(),
      uploadStatus: _uploadStatus(data['uploadStatus'] as String?),
      syncStatus: _syncStatus(data['syncStatus'] as String?),
      deviceModel: data['device'] as String?,
      latitude: _coord(location, 'latitude'),
      longitude: _coord(location, 'longitude'),
      timelineOrder: (data['timelineOrder'] as num?)?.toInt(),
      updatedAt: _date(data['updatedAt']),
      collectionId: data['collectionId'] as String?,
      captureSessionId: data['captureSessionId'] as String?,
      uploadProgress: (data['uploadProgress'] as num?)?.toDouble() ?? 0,
      retryCount: (data['retryCount'] as num?)?.toInt() ?? 0,
      contentHash: data['contentHash'] as String?,
      temporalIntent: EvidenceTemporalIntent.fromWire(data['temporalIntent']),
      metadata: _stringMap(data['metadata']),
      provenanceEvents: EvidenceProvenanceEvent.fromJsonList(
        data['provenanceEvents'],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Investigation graph (Sprint 4D)
  // ---------------------------------------------------------------------

  static Map<String, dynamic> timelineAnchorToMap(TimelineAnchor anchor) {
    return {
      'id': anchor.id,
      'incidentId': anchor.incidentId,
      'capturedEvidenceId': anchor.capturedEvidenceId,
      'anchoredAt': anchor.anchoredAt.toIso8601String(),
      'sequenceOrder': anchor.sequenceOrder,
    };
  }

  static TimelineAnchor timelineAnchorFromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    return TimelineAnchor(
      id: data['id'] as String? ?? docId,
      incidentId: data['incidentId'] as String? ?? '',
      capturedEvidenceId: data['capturedEvidenceId'] as String? ?? '',
      anchoredAt: _date(data['anchoredAt']) ?? DateTime.now(),
      sequenceOrder: (data['sequenceOrder'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, dynamic> relationshipGroupToMap(RelationshipGroup group) {
    return {
      'id': group.id,
      'incidentId': group.incidentId,
      'memberEvidenceIds': group.memberEvidenceIds,
      'type': group.type.name,
      'createdAt': group.createdAt.toIso8601String(),
      'colorIndex': group.colorIndex,
      'displayName': group.displayName,
      'description': group.description,
    };
  }

  static RelationshipGroup relationshipGroupFromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    return RelationshipGroup(
      id: data['id'] as String? ?? docId,
      incidentId: data['incidentId'] as String? ?? '',
      memberEvidenceIds: ((data['memberEvidenceIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      type: _relationship(data['type'] as String?),
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      colorIndex: (data['colorIndex'] as num?)?.toInt() ?? 0,
      displayName: data['displayName'] as String?,
      description: data['description'] as String?,
    );
  }

  static Map<String, dynamic> evidenceCollectionToMap(
    EvidenceCollection collection,
  ) {
    return {
      'id': collection.id,
      'incidentId': collection.incidentId,
      'name': collection.name,
      'systemGenerated': collection.systemGenerated,
      'pending': collection.pending,
      'displayOrder': collection.displayOrder,
      'createdAt': collection.createdAt.toIso8601String(),
      'updatedAt': collection.updatedAt.toIso8601String(),
      'memberEvidenceIds': collection.memberEvidenceIds,
      if (collection.category != null && collection.category!.isNotEmpty)
        'category': collection.category,
    };
  }

  static EvidenceCollection evidenceCollectionFromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    return EvidenceCollection(
      id: data['id'] as String? ?? docId,
      incidentId: data['incidentId'] as String? ?? '',
      name: data['name'] as String? ?? 'Collection',
      systemGenerated: data['systemGenerated'] as bool? ?? true,
      pending:
          data['pending'] as bool? ??
          (data['systemGenerated'] as bool? ?? true),
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 0,
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      updatedAt: _date(data['updatedAt']) ?? DateTime.now(),
      memberEvidenceIds: ((data['memberEvidenceIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? (data['category'] as String).trim()
          : null,
    );
  }

  static Map<String, dynamic> relationshipToMap(
    EvidenceRelationship relationship,
  ) {
    return {
      'id': relationship.id,
      'sourceEvidenceId': relationship.sourceEvidenceId,
      'targetEvidenceId': relationship.targetEvidenceId,
      'type': relationship.type.name,
      'createdAt': relationship.createdAt.toIso8601String(),
      if (relationship.reason != null) 'reason': relationship.reason,
      if (relationship.source != null) 'source': relationship.source,
    };
  }

  static EvidenceRelationship relationshipFromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    return EvidenceRelationship(
      id: data['id'] as String? ?? docId,
      sourceEvidenceId: data['sourceEvidenceId'] as String? ?? '',
      targetEvidenceId: data['targetEvidenceId'] as String? ?? '',
      type: _relationship(data['type'] as String?),
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      reason: data['reason'] as String?,
      source: data['source'] as String?,
    );
  }

  static Map<String, dynamic> narrativeEventToMap(NarrativeEvent event) {
    return {
      'id': event.id,
      'incidentId': event.incidentId,
      'sortOrder': event.sortOrder,
      'title': event.title,
      'summary': event.summary,
      'timelineAnchorEvidenceId': event.timelineAnchorEvidenceId,
      'relationshipGroupIds': event.relationshipGroupIds,
      'reconstructionNoteIds': event.reconstructionNoteIds,
      'supportingEvidenceIds': event.supportingEvidenceIds,
      'titleCustomized': event.titleCustomized,
      'summaryCustomized': event.summaryCustomized,
    };
  }

  static NarrativeEvent narrativeEventFromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    return NarrativeEvent(
      id: data['id'] as String? ?? docId,
      incidentId: data['incidentId'] as String? ?? '',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      title: data['title'] as String? ?? '',
      summary: data['summary'] as String?,
      timelineAnchorEvidenceId:
          data['timelineAnchorEvidenceId'] as String? ?? '',
      relationshipGroupIds:
          ((data['relationshipGroupIds'] as List?) ?? const [])
              .whereType<String>()
              .toList(),
      reconstructionNoteIds:
          ((data['reconstructionNoteIds'] as List?) ?? const [])
              .whereType<String>()
              .toList(),
      supportingEvidenceIds:
          ((data['supportingEvidenceIds'] as List?) ?? const [])
              .whereType<String>()
              .toList(),
      titleCustomized: data['titleCustomized'] as bool? ?? false,
      summaryCustomized: data['summaryCustomized'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> reconstructionNoteToMap(ReconstructionNote note) {
    return {
      'id': note.id,
      'incidentId': note.incidentId,
      'title': note.title,
      'body': note.body,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    };
  }

  static ReconstructionNote reconstructionNoteFromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    return ReconstructionNote(
      id: data['id'] as String? ?? docId,
      incidentId: data['incidentId'] as String? ?? '',
      title: data['title'] as String?,
      body: data['body'] as String? ?? '',
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      updatedAt: _date(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> participantToMap(Participant participant) {
    return {
      'id': participant.id,
      'incidentId': participant.incidentId,
      'displayName': participant.displayName,
      'role': participant.role.name,
      'contactInformation': participant.contactInformation,
      'organisation': participant.organisation,
      'notes': participant.notes,
      'createdAt': InstantCodec.encode(participant.createdAt),
      'updatedAt': InstantCodec.encode(participant.updatedAt),
    };
  }

  static Participant participantFromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    final roleName = data['role'] as String? ?? ParticipantRole.other.name;
    return Participant(
      id: data['id'] as String? ?? docId,
      incidentId: data['incidentId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: ParticipantRole.values.firstWhere(
        (value) => value.name == roleName,
        orElse: () => ParticipantRole.other,
      ),
      contactInformation: data['contactInformation'] as String?,
      organisation: data['organisation'] as String?,
      notes: data['notes'] as String? ?? '',
      createdAt: _date(data['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _date(data['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static Map<String, dynamic>? _locationMap(double? lat, double? lng) {
    if (lat == null && lng == null) {
      return null;
    }
    return {'latitude': ?lat, 'longitude': ?lng};
  }

  static double? _coord(Object? location, String key) {
    if (location is! Map) {
      return null;
    }
    return (location[key] as num?)?.toDouble();
  }

  static DateTime? _date(Object? value) => InstantCodec.decode(value);

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) {
      return const {};
    }
    final out = <String, String>{};
    value.forEach((key, entry) {
      if (key != null && entry != null) {
        out['$key'] = '$entry';
      }
    });
    return out;
  }

  static IncidentStatus _statusFrom(String name) {
    return IncidentStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => IncidentStatus.draft,
    );
  }

  static EvidenceUploadStatus _uploadStatus(String? name) {
    return EvidenceUploadStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => EvidenceUploadStatus.pending,
    );
  }

  static EvidenceSyncStatus _syncStatus(String? name) {
    return EvidenceSyncStatus.fromWire(name);
  }

  static RelationshipType _relationship(String? name) {
    return RelationshipType.values.firstWhere(
      (value) => value.name == name,
      orElse: () => RelationshipType.supports,
    );
  }
}
