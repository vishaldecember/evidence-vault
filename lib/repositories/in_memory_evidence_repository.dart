import '../domain/evidence/captured_evidence.dart';
import '../domain/evidence/captured_evidence_type.dart';
import '../domain/evidence/evidence_lifecycle.dart';
import '../domain/evidence/evidence_provenance_event.dart';
import '../domain/evidence/evidence_record.dart';
import '../domain/evidence/evidence_record_mapper.dart';
import '../domain/evidence/evidence_record_type.dart';
import '../domain/evidence/evidence_sync_status.dart';
import '../domain/evidence/evidence_temporal_intent.dart';
import '../domain/evidence/supporting_evidence.dart';
import '../domain/evidence/supporting_evidence_type.dart';
import '../domain/participant/related_person_link.dart';
import '../domain/participant/related_person_metadata.dart';
import '../models/relationship_type.dart';
import '../models/verification_factory.dart';
import '../models/workspace_capture_mode.dart';
import '../models/workspace_evidence_factory.dart';
import '../services/storage/cached_evidence_entry.dart';
import '../services/storage/evidence_status_bridge.dart';
import '../services/storage/evidence_upload_models.dart';
import 'evidence_repository.dart';
import 'incident_store.dart';
import 'timeline_repository.dart';

/// In-memory [EvidenceRepository] — capture → persist within [IncidentStore].
class InMemoryEvidenceRepository implements EvidenceRepository {
  InMemoryEvidenceRepository(
    this._store,
    this._timelineRepository,
  );

  final IncidentStore _store;
  final TimelineRepository _timelineRepository;
  DateTime? _lastCaptureAt;

  @override
  List<CapturedEvidence> get capturedEvidence =>
      List<CapturedEvidence>.unmodifiable(_store.capturedEvidence);

  @override
  List<SupportingEvidence> get supportingEvidence =>
      List<SupportingEvidence>.unmodifiable(_store.supportingEvidence);

  @override
  List<EvidenceRecord> get evidenceRecords {
    return [
      for (final item in _store.capturedEvidence)
        EvidenceRecordMapper.fromCaptured(item),
      for (final item in _store.supportingEvidence)
        EvidenceRecordMapper.fromSupporting(item),
    ];
  }

  @override
  EvidenceRecord? recordById(String evidenceId) {
    final captured = capturedById(evidenceId);
    if (captured != null) {
      return EvidenceRecordMapper.fromCaptured(captured);
    }
    final supporting = supportingById(evidenceId);
    if (supporting != null) {
      return EvidenceRecordMapper.fromSupporting(supporting);
    }
    return null;
  }

  /// Monotonic capture clock so rapid captures keep sequence order.
  ///
  /// Returns a UTC instant. Display converts to local timezone once.
  DateTime _captureTimestamp() {
    final now = DateTime.now().toUtc();
    if (_lastCaptureAt != null && !now.isAfter(_lastCaptureAt!)) {
      _lastCaptureAt = _lastCaptureAt!.add(const Duration(microseconds: 1));
    } else {
      _lastCaptureAt = now;
    }
    return _lastCaptureAt!;
  }

  @override
  CapturedEvidence addCapturedFromCaptureMode(
    WorkspaceCaptureMode mode, {
    String? participantId,
    String? captureSessionId,
    bool createTimelineAnchor = true,
  }) {
    final now = _captureTimestamp();
    final type = _capturedTypeForMode(mode);
    final id = WorkspaceEvidenceFactory.nextEvidenceId();
    if (containsEvidenceId(id)) {
      // Extremely unlikely with UUIDs; never insert a duplicate key.
      throw StateError('Duplicate evidence id generated: $id');
    }
    final anchor = _timelineRepository.createAnchor(
      capturedEvidenceId: id,
      anchoredAt: now,
    );

    final captured = CapturedEvidence(
      id: id,
      incidentId: _store.incident.id,
      type: type,
      capturedAt: now,
      title: _titleForCaptured(type, contextual: false),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      timelineAnchorId: anchor.id,
      notePreview:
          type == CapturedEvidenceType.voice ? _defaultVoicePreview() : null,
      participantId: participantId,
      captureSessionId: captureSessionId,
      // Chronology captures default to Primary; Investigation may refine.
      isPrimaryEvidence: true,
    );

    _store.capturedEvidence.insert(0, captured);
    _touchIncident(now);
    return captured;
  }

  @override
  SupportingEvidence addSupportingFromCaptureMode(
    WorkspaceCaptureMode mode, {
    required String parentCapturedEvidenceId,
    String? participantId,
    String? captureSessionId,
    bool createTimelineAnchor = true,
  }) {
    final now = _captureTimestamp();
    final type = _supportingTypeForMode(mode);
    final supporting = SupportingEvidence(
      id: WorkspaceEvidenceFactory.nextEvidenceId(),
      incidentId: _store.incident.id,
      type: type,
      createdAt: now,
      title: _titleForSupporting(type, contextual: true),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      notePreview: type == SupportingEvidenceType.note
          ? _defaultNotePreview()
          : null,
      fileName: type == SupportingEvidenceType.attachment
          ? 'incident_report_draft.pdf'
          : null,
      parentEvidenceId: parentCapturedEvidenceId,
      relationshipType: RelationshipType.supports,
      linkedCapturedEvidenceIds: {parentCapturedEvidenceId},
      participantId: participantId,
      captureSessionId: captureSessionId,
    );

    _store.supportingEvidence.insert(0, supporting);
    if (createTimelineAnchor) {
      _timelineRepository.createAnchor(
        capturedEvidenceId: supporting.id,
        anchoredAt: now,
      );
    }
    _touchIncident(now);
    return supporting;
  }

  @override
  SupportingEvidence addSupportingTextNote({
    required String parentCapturedEvidenceId,
    required String text,
    String? participantId,
    String? captureSessionId,
    bool createTimelineAnchor = false,
  }) {
    final now = _captureTimestamp();
    final supporting = SupportingEvidence(
      id: WorkspaceEvidenceFactory.nextEvidenceId(),
      incidentId: _store.incident.id,
      type: SupportingEvidenceType.note,
      createdAt: now,
      title: 'Context — Written Note',
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      notePreview: text.trim(),
      parentEvidenceId: parentCapturedEvidenceId,
      relationshipType: RelationshipType.supports,
      linkedCapturedEvidenceIds: {parentCapturedEvidenceId},
      participantId: participantId,
      captureSessionId: captureSessionId,
    );

    _store.supportingEvidence.insert(0, supporting);
    if (createTimelineAnchor) {
      _timelineRepository.createAnchor(
        capturedEvidenceId: supporting.id,
        anchoredAt: now,
      );
    }
    _touchIncident(now);
    return supporting;
  }

  /// Supporting capture from the workspace capture bar.
  ///
  /// Standalone notes/files do **not** auto-attach to the latest voice/photo —
  /// that caused false "text on voice" indicators. Pass [parentEvidenceId] only
  /// for explicit context enrichment.
  SupportingEvidence addStandaloneSupportingFromCaptureMode(
    WorkspaceCaptureMode mode, {
    String? parentEvidenceId,
    String? participantId,
    String? noteText,
    String? fileName,
    String? mimeType,
    String? captureSessionId,
    bool createTimelineAnchor = true,
  }) {
    final now = _captureTimestamp();
    final type = _supportingTypeForMode(mode);
    final linkedParents = parentEvidenceId == null
        ? const <String>{}
        : {parentEvidenceId};
    final supporting = SupportingEvidence(
      id: WorkspaceEvidenceFactory.nextEvidenceId(),
      incidentId: _store.incident.id,
      type: type,
      createdAt: now,
      title: _titleForSupporting(type, contextual: false),
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      notePreview: type == SupportingEvidenceType.note
          ? (noteText?.trim().isNotEmpty == true
              ? noteText!.trim()
              : null)
          : null,
      fileName: type == SupportingEvidenceType.attachment
          ? (fileName ?? 'attachment')
          : null,
      mimeType: mimeType,
      captureSessionId: captureSessionId,
      parentEvidenceId: parentEvidenceId,
      relationshipType: RelationshipType.supports,
      linkedCapturedEvidenceIds: linkedParents,
      participantId: participantId,
    );

    _store.supportingEvidence.insert(0, supporting);
    if (createTimelineAnchor) {
      _timelineRepository.createAnchor(
        capturedEvidenceId: supporting.id,
        anchoredAt: now,
      );
    }
    _touchIncident(now);
    return supporting;
  }

  @override
  SupportingEvidence? updateSupportingNoteText({
    required String evidenceId,
    required String text,
  }) {
    final index = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (index == -1) {
      return null;
    }

    final current = _store.supportingEvidence[index];
    var updatedAt = DateTime.now().toUtc();
    if (!updatedAt.isAfter(current.createdAt)) {
      updatedAt = current.createdAt.add(const Duration(milliseconds: 1));
    }
    final updated = current.copyWith(
      notePreview: text.trim(),
      updatedAt: updatedAt,
    );
    _store.supportingEvidence[index] = updated;
    _touchIncident(updated.updatedAt ?? DateTime.now().toUtc());
    return updated;
  }

  @override
  bool updateTemporalIntent({
    required String evidenceId,
    required EvidenceTemporalIntent intent,
  }) {
    final capturedIndex = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (capturedIndex != -1) {
      final current = _store.capturedEvidence[capturedIndex];
      if (current.temporalIntent == intent) {
        return true;
      }
      _store.capturedEvidence[capturedIndex] = current.copyWith(
        temporalIntent: intent,
      );
      return true;
    }

    final supportingIndex = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (supportingIndex == -1) {
      return false;
    }
    final current = _store.supportingEvidence[supportingIndex];
    if (current.temporalIntent == intent) {
      return true;
    }
    _store.supportingEvidence[supportingIndex] = current.copyWith(
      temporalIntent: intent,
    );
    return true;
  }

  @override
  void attachLocalMedia({
    required String evidenceId,
    required String filePath,
    String? fileName,
    String? thumbnailPath,
    int? fileSizeBytes,
  }) {
    final capturedIndex = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (capturedIndex != -1) {
      _store.capturedEvidence[capturedIndex] =
          _store.capturedEvidence[capturedIndex].copyWith(
        filePath: filePath,
        fileName: fileName,
        thumbnailPath: thumbnailPath,
        fileSizeBytes: fileSizeBytes,
        uploadStatus: EvidenceUploadStatus.pending,
        syncStatus: EvidenceSyncStatus.queuedForUpload,
      );
      _touchIncident(DateTime.now());
      return;
    }

    final supportingIndex = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (supportingIndex == -1) {
      return;
    }
    _store.supportingEvidence[supportingIndex] =
        _store.supportingEvidence[supportingIndex].copyWith(
      filePath: filePath,
      fileName: fileName,
      thumbnailPath: thumbnailPath,
      fileSizeBytes: fileSizeBytes,
      uploadStatus: EvidenceUploadStatus.pending,
      syncStatus: EvidenceSyncStatus.queuedForUpload,
    );
    _touchIncident(DateTime.now());
  }

  @override
  void applyCaptureProvenance({
    required String evidenceId,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {
    final capturedIndex = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (capturedIndex != -1) {
      final current = _store.capturedEvidence[capturedIndex];
      _store.capturedEvidence[capturedIndex] = current.copyWith(
        deviceModel: deviceModel ?? current.deviceModel,
        latitude: latitude ?? current.latitude,
        longitude: longitude ?? current.longitude,
      );
      _touchIncident(DateTime.now());
      return;
    }

    final supportingIndex = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (supportingIndex == -1) {
      return;
    }
    final current = _store.supportingEvidence[supportingIndex];
    _store.supportingEvidence[supportingIndex] = current.copyWith(
      deviceModel: deviceModel ?? current.deviceModel,
      latitude: latitude ?? current.latitude,
      longitude: longitude ?? current.longitude,
    );
    _touchIncident(DateTime.now());
  }

  @override
  bool recordContentHash({
    required String evidenceId,
    required String hash,
  }) {
    final value = hash.trim();
    if (value.isEmpty) {
      return false;
    }
    final capturedIndex = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (capturedIndex != -1) {
      final current = _store.capturedEvidence[capturedIndex];
      final existing = current.contentHash?.trim() ?? '';
      if (existing.isNotEmpty) {
        return false;
      }
      _store.capturedEvidence[capturedIndex] = current.copyWith(
        contentHash: value,
        metadata: EvidenceProvenanceEvent.toMetadata(
          current.provenanceEvents,
          existing: current.metadata,
        ),
      );
      return true;
    }
    final supportingIndex = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (supportingIndex == -1) {
      return false;
    }
    final current = _store.supportingEvidence[supportingIndex];
    final existing = current.contentHash?.trim() ?? '';
    if (existing.isNotEmpty) {
      return false;
    }
    _store.supportingEvidence[supportingIndex] = current.copyWith(
      contentHash: value,
      metadata: EvidenceProvenanceEvent.toMetadata(
        current.provenanceEvents,
        existing: current.metadata,
      ),
    );
    return true;
  }

  @override
  bool appendProvenanceEvent(EvidenceProvenanceEvent event) {
    final id = event.evidenceId.trim();
    if (id.isEmpty) {
      return false;
    }
    final capturedIndex = _store.capturedEvidence.indexWhere(
      (item) => item.id == id,
    );
    if (capturedIndex != -1) {
      final current = _store.capturedEvidence[capturedIndex];
      final next = EvidenceProvenanceEvent.append(
        existing: current.provenanceEvents,
        next: event,
      );
      if (identical(next, current.provenanceEvents) ||
          next.length == current.provenanceEvents.length) {
        return false;
      }
      _store.capturedEvidence[capturedIndex] = current.copyWith(
        provenanceEvents: next,
        metadata: EvidenceProvenanceEvent.toMetadata(
          next,
          existing: current.metadata,
        ),
      );
      return true;
    }
    final supportingIndex = _store.supportingEvidence.indexWhere(
      (item) => item.id == id,
    );
    if (supportingIndex == -1) {
      return false;
    }
    final current = _store.supportingEvidence[supportingIndex];
    final next = EvidenceProvenanceEvent.append(
      existing: current.provenanceEvents,
      next: event,
    );
    if (next.length == current.provenanceEvents.length) {
      return false;
    }
    _store.supportingEvidence[supportingIndex] = current.copyWith(
      provenanceEvents: next,
      metadata: EvidenceProvenanceEvent.toMetadata(
        next,
        existing: current.metadata,
      ),
    );
    return true;
  }

  @override
  List<EvidenceProvenanceEvent> provenanceEventsFor(String evidenceId) {
    final id = evidenceId.trim();
    for (final item in _store.capturedEvidence) {
      if (item.id == id) {
        return List<EvidenceProvenanceEvent>.from(item.provenanceEvents);
      }
    }
    for (final item in _store.supportingEvidence) {
      if (item.id == id) {
        return List<EvidenceProvenanceEvent>.from(item.provenanceEvents);
      }
    }
    return const [];
  }

  @override
  void applyStorageUpload({
    required String evidenceId,
    required String storagePath,
    required String downloadUrl,
    required String mimeType,
    required int fileSizeBytes,
    String? thumbnailUrl,
    String? thumbnailStoragePath,
    String? deviceModel,
    double? latitude,
    double? longitude,
  }) {
    final capturedIndex = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (capturedIndex != -1) {
      _store.capturedEvidence[capturedIndex] =
          _store.capturedEvidence[capturedIndex].copyWith(
        storagePath: storagePath,
        downloadUrl: downloadUrl,
        thumbnailUrl: thumbnailUrl,
        mimeType: mimeType,
        fileSizeBytes: fileSizeBytes,
        uploadStatus: EvidenceUploadStatus.uploaded,
        syncStatus: EvidenceSyncStatus.ready,
        uploadProgress: 1,
        deviceModel: deviceModel,
        latitude: latitude,
        longitude: longitude,
        updatedAt: DateTime.now(),
      );
      _touchIncident(DateTime.now());
      return;
    }

    final supportingIndex = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (supportingIndex == -1) {
      return;
    }
    _store.supportingEvidence[supportingIndex] =
        _store.supportingEvidence[supportingIndex].copyWith(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      uploadStatus: EvidenceUploadStatus.uploaded,
      syncStatus: EvidenceSyncStatus.ready,
      uploadProgress: 1,
      deviceModel: deviceModel,
      latitude: latitude,
      longitude: longitude,
      updatedAt: DateTime.now(),
    );
    _touchIncident(DateTime.now());
  }

  @override
  void markUploadFailed({required String evidenceId}) {
    final capturedIndex = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (capturedIndex != -1) {
      _store.capturedEvidence[capturedIndex] =
          _store.capturedEvidence[capturedIndex].copyWith(
        uploadStatus: EvidenceUploadStatus.failed,
        syncStatus: EvidenceSyncStatus.failed,
        updatedAt: DateTime.now(),
      );
      _touchIncident(DateTime.now());
      return;
    }

    final supportingIndex = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (supportingIndex == -1) {
      return;
    }
    _store.supportingEvidence[supportingIndex] =
        _store.supportingEvidence[supportingIndex].copyWith(
      uploadStatus: EvidenceUploadStatus.failed,
      syncStatus: EvidenceSyncStatus.failed,
      updatedAt: DateTime.now(),
    );
    _touchIncident(DateTime.now());
  }

  @override
  bool updateLifecycleStatus({
    required String evidenceId,
    required EvidenceSyncStatus status,
    double? uploadProgress,
    int? retryCount,
    bool force = false,
  }) {
    final capturedIndex = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (capturedIndex != -1) {
      final current = _store.capturedEvidence[capturedIndex];
      final next = force
          ? status
          : EvidenceLifecycle.transitionOrKeep(
              from: current.syncStatus,
              to: status,
            );
      if (!force && next != status && current.syncStatus != status) {
        return false;
      }
      _store.capturedEvidence[capturedIndex] = current.copyWith(
        syncStatus: next,
        uploadStatus: EvidenceStatusBridge.toUploadStatus(next),
        uploadProgress: uploadProgress,
        retryCount: retryCount ??
            (next == EvidenceSyncStatus.failed
                ? current.retryCount + 1
                : current.retryCount),
        updatedAt: DateTime.now(),
      );
      _touchIncident(DateTime.now());
      return true;
    }

    final supportingIndex = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (supportingIndex == -1) {
      return false;
    }
    final current = _store.supportingEvidence[supportingIndex];
    final next = force
        ? status
        : EvidenceLifecycle.transitionOrKeep(
            from: current.syncStatus,
            to: status,
          );
    if (!force && next != status && current.syncStatus != status) {
      return false;
    }
    _store.supportingEvidence[supportingIndex] = current.copyWith(
      syncStatus: next,
      uploadStatus: EvidenceStatusBridge.toUploadStatus(next),
      uploadProgress: uploadProgress,
      retryCount: retryCount ??
          (next == EvidenceSyncStatus.failed
              ? current.retryCount + 1
              : current.retryCount),
      updatedAt: DateTime.now(),
    );
    _touchIncident(DateTime.now());
    return true;
  }

  @override
  void removeEvidence({required String evidenceId}) {
    _store.capturedEvidence.removeWhere((item) => item.id == evidenceId);
    _store.supportingEvidence.removeWhere((item) => item.id == evidenceId);
    _store.timelineAnchors.removeWhere(
      (item) => item.capturedEvidenceId == evidenceId,
    );
    _store.relationships.removeWhere(
      (item) =>
          item.sourceEvidenceId == evidenceId ||
          item.targetEvidenceId == evidenceId,
    );
    for (var i = 0; i < _store.relationshipGroups.length; i++) {
      final group = _store.relationshipGroups[i];
      if (!group.memberEvidenceIds.contains(evidenceId)) {
        continue;
      }
      _store.relationshipGroups[i] = group.copyWithMembers(
        group.memberEvidenceIds.where((id) => id != evidenceId).toList(),
      );
    }
    _store.relationshipGroups.removeWhere(
      (group) => group.memberEvidenceIds.isEmpty,
    );
    _touchIncident(DateTime.now());
  }

  @override
  bool upsertFromLocalCache(CachedEvidenceEntry entry) {
    if (containsEvidenceId(entry.evidenceId)) {
      // Refresh local paths / lifecycle if the working set is sparse.
      final capturedIndex = _store.capturedEvidence.indexWhere(
        (item) => item.id == entry.evidenceId,
      );
      if (capturedIndex != -1) {
        final current = _store.capturedEvidence[capturedIndex];
        _store.capturedEvidence[capturedIndex] = current.copyWith(
          filePath: entry.localFilePath ?? current.filePath,
          thumbnailPath: entry.thumbnailPath ?? current.thumbnailPath,
          fileName: entry.fileName ?? current.fileName,
          fileSizeBytes: entry.fileSizeBytes ?? current.fileSizeBytes,
          syncStatus: entry.syncStatus,
          uploadStatus:
              EvidenceStatusBridge.toUploadStatus(entry.syncStatus),
          uploadProgress: entry.uploadProgress,
          retryCount: entry.retryCount,
          contentHash: current.contentHash ?? entry.hash,
          storagePath: entry.cloudPath ?? current.storagePath,
          downloadUrl: entry.downloadUrl ?? current.downloadUrl,
          participantId:
              RelatedPersonMetadata.idOf(entry.metadata) ?? current.participantId,
          metadata: entry.metadata.isEmpty ? current.metadata : entry.metadata,
          provenanceEvents: current.provenanceEvents.isNotEmpty
              ? current.provenanceEvents
              : EvidenceProvenanceEvent.fromMetadata(entry.metadata),
          deviceModel: current.deviceModel ??
              _deviceFromMetadata(entry.metadata),
          latitude: current.latitude ??
              _coordFromMetadata(entry.metadata, 'latitude'),
          longitude: current.longitude ??
              _coordFromMetadata(entry.metadata, 'longitude'),
        );
        return false;
      }
      final supportingIndex = _store.supportingEvidence.indexWhere(
        (item) => item.id == entry.evidenceId,
      );
      if (supportingIndex != -1) {
        final current = _store.supportingEvidence[supportingIndex];
        _store.supportingEvidence[supportingIndex] = current.copyWith(
          filePath: entry.localFilePath ?? current.filePath,
          thumbnailPath: entry.thumbnailPath ?? current.thumbnailPath,
          fileName: entry.fileName ?? current.fileName,
          fileSizeBytes: entry.fileSizeBytes ?? current.fileSizeBytes,
          notePreview: entry.noteText ?? current.notePreview,
          mimeType: entry.mimeType ?? current.mimeType,
          syncStatus: entry.syncStatus,
          uploadStatus:
              EvidenceStatusBridge.toUploadStatus(entry.syncStatus),
          uploadProgress: entry.uploadProgress,
          retryCount: entry.retryCount,
          contentHash: current.contentHash ?? entry.hash,
          storagePath: entry.cloudPath ?? current.storagePath,
          downloadUrl: entry.downloadUrl ?? current.downloadUrl,
          participantId:
              RelatedPersonMetadata.idOf(entry.metadata) ?? current.participantId,
          metadata: entry.metadata.isEmpty ? current.metadata : entry.metadata,
          provenanceEvents: current.provenanceEvents.isNotEmpty
              ? current.provenanceEvents
              : EvidenceProvenanceEvent.fromMetadata(entry.metadata),
          deviceModel: current.deviceModel ??
              _deviceFromMetadata(entry.metadata),
          latitude: current.latitude ??
              _coordFromMetadata(entry.metadata, 'latitude'),
          longitude: current.longitude ??
              _coordFromMetadata(entry.metadata, 'longitude'),
        );
      }
      return false;
    }

    final entryIncidentId = entry.incidentId.trim();
    final storeIncidentId = _store.incident.id.trim();
    if (entryIncidentId.isEmpty ||
        storeIncidentId.isEmpty ||
        entryIncidentId != storeIncidentId) {
      return false;
    }

    final isCaptured = entry.evidenceType == EvidenceRecordType.photo ||
        entry.evidenceType == EvidenceRecordType.video ||
        entry.evidenceType == EvidenceRecordType.voice;

    if (isCaptured) {
      final type = switch (entry.evidenceType) {
        EvidenceRecordType.video => CapturedEvidenceType.video,
        EvidenceRecordType.voice => CapturedEvidenceType.voice,
        _ => CapturedEvidenceType.photo,
      };
      final anchor = _timelineRepository.createAnchor(
        capturedEvidenceId: entry.evidenceId,
        anchoredAt: entry.capturedAt,
      );
      _store.capturedEvidence.insert(
        0,
        CapturedEvidence(
          id: entry.evidenceId,
          incidentId: entryIncidentId,
          type: type,
          capturedAt: entry.capturedAt,
          title: _titleForCaptured(type, contextual: false),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
          timelineAnchorId: anchor.id,
          fileName: entry.fileName,
          filePath: entry.localFilePath,
          thumbnailPath: entry.thumbnailPath,
          fileSizeBytes: entry.fileSizeBytes,
          storagePath: entry.cloudPath,
          downloadUrl: entry.downloadUrl,
          syncStatus: entry.syncStatus,
          uploadStatus:
              EvidenceStatusBridge.toUploadStatus(entry.syncStatus),
          uploadProgress: entry.uploadProgress,
          retryCount: entry.retryCount,
          contentHash: entry.hash,
          metadata: entry.metadata,
          provenanceEvents: EvidenceProvenanceEvent.fromMetadata(entry.metadata),
          createdAt: entry.createdAt,
          captureSessionId: entry.captureSessionId,
          isPrimaryEvidence: true,
          participantId: RelatedPersonMetadata.idOf(entry.metadata),
          deviceModel: _deviceFromMetadata(entry.metadata),
          latitude: _coordFromMetadata(entry.metadata, 'latitude'),
          longitude: _coordFromMetadata(entry.metadata, 'longitude'),
        ),
      );
      _touchIncident(DateTime.now());
      return true;
    }

    final supportingType = switch (entry.evidenceType) {
      EvidenceRecordType.note => SupportingEvidenceType.note,
      EvidenceRecordType.witness => SupportingEvidenceType.witnessStatement,
      _ => SupportingEvidenceType.attachment,
    };
    final parentId = entry.parentEvidenceId;
    _store.supportingEvidence.insert(
      0,
      SupportingEvidence(
        id: entry.evidenceId,
        incidentId: entryIncidentId,
        type: supportingType,
        createdAt: entry.createdAt,
        title: _titleForSupporting(supportingType, contextual: false),
        integrityVerified: true,
        verification: VerificationFactory.initial(),
        notePreview: entry.noteText,
        fileName: entry.fileName,
        filePath: entry.localFilePath,
        thumbnailPath: entry.thumbnailPath,
        fileSizeBytes: entry.fileSizeBytes,
        mimeType: entry.mimeType,
        storagePath: entry.cloudPath,
        downloadUrl: entry.downloadUrl,
        syncStatus: entry.syncStatus,
        uploadStatus: EvidenceStatusBridge.toUploadStatus(entry.syncStatus),
        uploadProgress: entry.uploadProgress,
        retryCount: entry.retryCount,
        contentHash: entry.hash,
        metadata: entry.metadata,
        provenanceEvents: EvidenceProvenanceEvent.fromMetadata(entry.metadata),
        captureSessionId: entry.captureSessionId,
        parentEvidenceId: parentId,
        relationshipType: RelationshipType.supports,
        linkedCapturedEvidenceIds:
            parentId == null ? const {} : {parentId},
        participantId: RelatedPersonMetadata.idOf(entry.metadata),
        deviceModel: _deviceFromMetadata(entry.metadata),
        latitude: _coordFromMetadata(entry.metadata, 'latitude'),
        longitude: _coordFromMetadata(entry.metadata, 'longitude'),
      ),
    );
    _touchIncident(DateTime.now());
    return true;
  }

  @override
  CapturedEvidence? assignParticipantToCaptured({
    required String evidenceId,
    String? participantId,
    String? relatedPersonName,
    String? relatedPersonRole,
  }) {
    final index = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (index == -1) {
      return null;
    }

    final current = _store.capturedEvidence[index];
    final updated = current.copyWith(
      participantId: participantId,
      clearParticipantId: participantId == null,
      metadata: RelatedPersonMetadata.merge(
        current: current.metadata,
        participantId: participantId,
        displayName: relatedPersonName,
        roleName: relatedPersonRole,
      ),
    );
    _store.capturedEvidence[index] = updated;
    _touchIncident(DateTime.now().toUtc());
    return updated;
  }

  @override
  CapturedEvidence? addParticipantToCaptured({
    required String evidenceId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  }) {
    return _writeCapturedPeople(
      evidenceId,
      RelatedPersonMetadata.addPerson(
        current: _capturedMetadata(evidenceId) ?? const {},
        participantId: participantId,
        displayName: relatedPersonName,
        roleName: relatedPersonRole,
      ),
    );
  }

  @override
  CapturedEvidence? replaceParticipantOnCaptured({
    required String evidenceId,
    required String previousParticipantId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  }) {
    return _writeCapturedPeople(
      evidenceId,
      RelatedPersonMetadata.replacePerson(
        current: _capturedMetadata(evidenceId) ?? const {},
        previousParticipantId: previousParticipantId,
        participantId: participantId,
        displayName: relatedPersonName,
        roleName: relatedPersonRole,
      ),
    );
  }

  @override
  CapturedEvidence? removeParticipantFromCaptured({
    required String evidenceId,
    required String participantId,
  }) {
    return _writeCapturedPeople(
      evidenceId,
      RelatedPersonMetadata.removePerson(
        current: _capturedMetadata(evidenceId) ?? const {},
        participantId: participantId,
      ),
    );
  }

  @override
  SupportingEvidence? assignParticipantToSupporting({
    required String evidenceId,
    String? participantId,
    String? relatedPersonName,
    String? relatedPersonRole,
  }) {
    final index = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (index == -1) {
      return null;
    }

    final current = _store.supportingEvidence[index];
    final updated = current.copyWith(
      participantId: participantId,
      clearParticipantId: participantId == null,
      metadata: RelatedPersonMetadata.merge(
        current: current.metadata,
        participantId: participantId,
        displayName: relatedPersonName,
        roleName: relatedPersonRole,
      ),
    );
    _store.supportingEvidence[index] = updated;
    _touchIncident(DateTime.now().toUtc());
    return updated;
  }

  @override
  SupportingEvidence? addParticipantToSupporting({
    required String evidenceId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  }) {
    return _writeSupportingPeople(
      evidenceId,
      RelatedPersonMetadata.addPerson(
        current: _supportingMetadata(evidenceId) ?? const {},
        participantId: participantId,
        displayName: relatedPersonName,
        roleName: relatedPersonRole,
      ),
    );
  }

  @override
  SupportingEvidence? replaceParticipantOnSupporting({
    required String evidenceId,
    required String previousParticipantId,
    required String participantId,
    required String relatedPersonName,
    String? relatedPersonRole,
  }) {
    return _writeSupportingPeople(
      evidenceId,
      RelatedPersonMetadata.replacePerson(
        current: _supportingMetadata(evidenceId) ?? const {},
        previousParticipantId: previousParticipantId,
        participantId: participantId,
        displayName: relatedPersonName,
        roleName: relatedPersonRole,
      ),
    );
  }

  @override
  SupportingEvidence? removeParticipantFromSupporting({
    required String evidenceId,
    required String participantId,
  }) {
    return _writeSupportingPeople(
      evidenceId,
      RelatedPersonMetadata.removePerson(
        current: _supportingMetadata(evidenceId) ?? const {},
        participantId: participantId,
      ),
    );
  }

  @override
  CapturedEvidence? writeRelatedPeopleOnCaptured({
    required String evidenceId,
    required List<RelatedPersonLink> people,
  }) {
    final current = _capturedMetadata(evidenceId);
    if (current == null) {
      return null;
    }
    return _writeCapturedPeople(
      evidenceId,
      RelatedPersonMetadata.writePeople(current, people),
    );
  }

  @override
  SupportingEvidence? writeRelatedPeopleOnSupporting({
    required String evidenceId,
    required List<RelatedPersonLink> people,
  }) {
    final current = _supportingMetadata(evidenceId);
    if (current == null) {
      return null;
    }
    return _writeSupportingPeople(
      evidenceId,
      RelatedPersonMetadata.writePeople(current, people),
    );
  }

  Map<String, String>? _capturedMetadata(String evidenceId) {
    return capturedById(evidenceId)?.metadata;
  }

  Map<String, String>? _supportingMetadata(String evidenceId) {
    return supportingById(evidenceId)?.metadata;
  }

  CapturedEvidence? _writeCapturedPeople(
    String evidenceId,
    Map<String, String> metadata,
  ) {
    final index = _store.capturedEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (index == -1) {
      return null;
    }
    final people = RelatedPersonMetadata.peopleOf(metadata);
    final primary = people.isEmpty ? null : people.first;
    final updated = _store.capturedEvidence[index].copyWith(
      participantId: primary?.participantId,
      clearParticipantId: primary == null,
      metadata: metadata,
    );
    _store.capturedEvidence[index] = updated;
    _touchIncident(DateTime.now().toUtc());
    return updated;
  }

  SupportingEvidence? _writeSupportingPeople(
    String evidenceId,
    Map<String, String> metadata,
  ) {
    final index = _store.supportingEvidence.indexWhere(
      (item) => item.id == evidenceId,
    );
    if (index == -1) {
      return null;
    }
    final people = RelatedPersonMetadata.peopleOf(metadata);
    final primary = people.isEmpty ? null : people.first;
    final updated = _store.supportingEvidence[index].copyWith(
      participantId: primary?.participantId,
      clearParticipantId: primary == null,
      metadata: metadata,
    );
    _store.supportingEvidence[index] = updated;
    _touchIncident(DateTime.now().toUtc());
    return updated;
  }

  @override
  CapturedEvidence? capturedById(String id) {
    for (final item in _store.capturedEvidence) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  SupportingEvidence? supportingById(String id) {
    for (final item in _store.supportingEvidence) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  bool containsEvidenceId(String id) =>
      capturedById(id) != null || supportingById(id) != null;

  void _touchIncident(DateTime updatedAt) {
    _store.incident = _store.incident.copyWith(updatedAt: updatedAt);
  }

  static String? _deviceFromMetadata(Map<String, String> metadata) {
    final value = metadata['deviceModel']?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static double? _coordFromMetadata(Map<String, String> metadata, String key) {
    final raw = metadata[key]?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return double.tryParse(raw);
  }

  static CapturedEvidenceType _capturedTypeForMode(WorkspaceCaptureMode mode) =>
      switch (mode) {
        WorkspaceCaptureMode.photo => CapturedEvidenceType.photo,
        WorkspaceCaptureMode.video => CapturedEvidenceType.video,
        WorkspaceCaptureMode.voice => CapturedEvidenceType.voice,
        _ => CapturedEvidenceType.photo,
      };

  static SupportingEvidenceType _supportingTypeForMode(
    WorkspaceCaptureMode mode,
  ) =>
      switch (mode) {
        WorkspaceCaptureMode.note => SupportingEvidenceType.note,
        WorkspaceCaptureMode.file => SupportingEvidenceType.attachment,
        WorkspaceCaptureMode.photo => SupportingEvidenceType.document,
        WorkspaceCaptureMode.video => SupportingEvidenceType.document,
        WorkspaceCaptureMode.voice => SupportingEvidenceType.note,
      };

  static String _titleForCaptured(
    CapturedEvidenceType type, {
    required bool contextual,
  }) {
    final prefix = contextual ? 'Context — ' : '';
    return switch (type) {
      CapturedEvidenceType.photo => '${prefix}Photo Evidence',
      CapturedEvidenceType.video => '${prefix}Video Evidence',
      CapturedEvidenceType.voice => '${prefix}Voice Note',
    };
  }

  static String _titleForSupporting(
    SupportingEvidenceType type, {
    required bool contextual,
  }) {
    final prefix = contextual ? 'Context — ' : '';
    return switch (type) {
      SupportingEvidenceType.note => '${prefix}Written Note',
      SupportingEvidenceType.pdf => '${prefix}PDF Document',
      SupportingEvidenceType.document => '${prefix}Document',
      SupportingEvidenceType.attachment => '${prefix}Attachment',
      SupportingEvidenceType.witnessStatement => '${prefix}Witness Record',
    };
  }

  static String _defaultVoicePreview() =>
      'Observed the interaction at the entrance.\n'
      'Timestamp aligns with prior evidence.';

  static String _defaultNotePreview() =>
      'Observed the interaction at the entrance.\n'
      'Timestamp aligns with prior evidence.';
}


