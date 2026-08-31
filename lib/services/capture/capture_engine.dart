import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/evidence/evidence_integrity.dart';
import '../../domain/evidence/evidence_provenance_event.dart';
import '../../domain/evidence/evidence_record_type.dart';
import '../../domain/evidence/evidence_sync_status.dart';
import '../../models/workspace_capture_mode.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../../models/verification_factory.dart';
import '../../models/workspace_evidence_item.dart';
import '../storage/capture_media_service.dart';
import '../storage/evidence_upload_coordinator.dart';
import '../storage/evidence_upload_models.dart';
import '../storage/local_evidence_cache.dart';
import '../sync/evidence_sync_manager.dart';
import '../persistence/local_incident_pointer.dart';
import '../user_session_service.dart';
import '../../diagnostics/file_p0_trace.dart';
import 'capture_job.dart';
import 'capture_session_manager.dart';
import 'firestore_job.dart';
import 'thumbnail_job.dart';
import '../../services/metadata_service.dart';

/// Thrown when an async capture started for one incident would write to another.
class StaleCaptureIncidentException implements Exception {
  const StaleCaptureIncidentException({
    required this.startedForIncidentId,
    required this.currentIncidentId,
  });

  final String startedForIncidentId;
  final String currentIncidentId;

  @override
  String toString() =>
      'StaleCaptureIncidentException: started=$startedForIncidentId '
      'current=$currentIncidentId';
}

/// Capture Pipeline 2.0 — local-first, non-blocking cloud sync.
///
/// **Local commit completes before this method returns.**
/// Firebase upload / workers continue in the background.
class CaptureEngine {
  CaptureEngine._();

  static final CaptureEngine instance = CaptureEngine._();

  bool _sessionMatchesStart(CapturePipelineHost host, String incidentIdAtStart) {
    return incidentIdAtStart.isNotEmpty &&
        host.captureIncidentId == incidentIdAtStart;
  }

  /// Creates local evidence, durable-commits to cache, then returns.
  ///
  /// The UI must never await Firebase — only the local commit barrier.
  ///
  /// [createLocalEvidence] receives the active [CaptureSession] id (Sprint 6C)
  /// so RAM rows carry [captureSessionId] at insert time.
  Future<String> receive({
    required CapturePipelineHost host,
    required WorkspaceCaptureMode mode,
    required String Function(String? captureSessionId) createLocalEvidence,
    CapturedMediaFile? media,
    EvidenceUploadCoordinator? uploadCoordinator,
    String? noteText,
    String? mimeType,
  }) async {
    final incidentIdAtStart = host.captureIncidentId;
    final incidentId = incidentIdAtStart;
    final userId = UserSessionService.account?.userId ?? '';
    final isFile = mode == WorkspaceCaptureMode.file;
    final requiresDurableMedia = mode != WorkspaceCaptureMode.note;
    if (isFile) {
      FileP0Trace.step(
        'CAPTURE_ENGINE_RECEIVE',
        incidentId: incidentId,
        fileName: media?.fileName,
        fileSize: media?.fileSizeBytes,
        path: media?.localPath,
        extra: 'userIdEmpty=${userId.isEmpty}',
      );
    }

    String? captureSessionId;
    try {
      final session =
          await CaptureSessionManager.instance.getOrCreateActiveSession(
        incidentId: incidentId,
        userId: userId,
      );
      captureSessionId = session.id;
    } catch (error, stack) {
      if (isFile) {
        FileP0Trace.failure(
          'CAPTURE_SESSION_ENSURE',
          error: error,
          stackTrace: stack,
          incidentId: incidentId,
        );
      } else {
        debugPrint('[CaptureEngine] capture session ensure failed: $error');
      }
    }

    if (!_sessionMatchesStart(host, incidentIdAtStart)) {
      throw StaleCaptureIncidentException(
        startedForIncidentId: incidentIdAtStart,
        currentIncidentId: host.captureIncidentId,
      );
    }

    final provenanceFuture = MetadataService.collectAtCapture();
    final evidenceId = createLocalEvidence(captureSessionId);
    final provenance = await provenanceFuture;
    final deviceName = provenance.device.name.trim();
    final provenanceMetadata = <String, String>{
      if (deviceName.isNotEmpty) 'deviceModel': deviceName,
      if (provenance.location.latitude != null)
        'latitude': '${provenance.location.latitude}',
      if (provenance.location.longitude != null)
        'longitude': '${provenance.location.longitude}',
    };
    host.rememberCaptureProvenance(provenance);
    host.applyCaptureProvenance(
      evidenceId: evidenceId,
      deviceModel: deviceName.isEmpty ? null : deviceName,
      latitude: provenance.location.latitude,
      longitude: provenance.location.longitude,
    );
    final capturedAt = DateTime.now().toUtc();
    host.appendEvidenceProvenance(
      EvidenceProvenanceEvent(
        type: EvidenceProvenanceType.captured,
        evidenceId: evidenceId,
        at: capturedAt,
        captureModality: _modalityFor(mode),
        source: deviceName.isEmpty ? null : deviceName,
      ),
    );
    if (isFile) {
      FileP0Trace.step(
        'EVIDENCE_CREATED',
        incidentId: incidentId,
        extra: 'evidenceId=$evidenceId captureSessionId=$captureSessionId',
      );
    }

    if (!_sessionMatchesStart(host, incidentIdAtStart)) {
      host.abandonFailedLocalCapture(evidenceId);
      throw StaleCaptureIncidentException(
        startedForIncidentId: incidentIdAtStart,
        currentIncidentId: host.captureIncidentId,
      );
    }

    if (captureSessionId != null) {
      await CaptureSessionManager.instance.attachEvidenceToSession(
        sessionId: captureSessionId,
        evidenceId: evidenceId,
      );
    }

    if (!_sessionMatchesStart(host, incidentIdAtStart)) {
      host.abandonFailedLocalCapture(evidenceId);
      throw StaleCaptureIncidentException(
        startedForIncidentId: incidentIdAtStart,
        currentIncidentId: host.captureIncidentId,
      );
    }

    if (requiresDurableMedia) {
      if (media == null) {
        host.abandonFailedLocalCapture(evidenceId);
        throw const MediaDurabilityException(
          'Media is required to preserve this evidence.',
        );
      }

      final coordinator =
          uploadCoordinator ?? EvidenceUploadCoordinator.instance;

      // LOCAL COMMIT BARRIER — durableize must succeed before metadata success.
      late final CapturedMediaFile committed;
      try {
        if (isFile) {
          FileP0Trace.step(
            'DURABLEIZE_START',
            incidentId: incidentId,
            fileName: media.fileName,
            fileSize: media.fileSizeBytes,
            path: media.localPath,
            extra: 'evidenceId=$evidenceId',
          );
        }
        committed = await LocalEvidenceCache.durableize(
          incidentId: incidentId,
          evidenceId: evidenceId,
          media: media,
        );
        if (isFile) {
          FileP0Trace.step(
            'DURABLEIZE_SUCCESS',
            incidentId: incidentId,
            fileName: committed.fileName,
            fileSize: committed.fileSizeBytes,
            path: committed.localPath,
            extra: 'evidenceId=$evidenceId pathChanged='
                '${committed.localPath != media.localPath}',
          );
        }
      } catch (error, stack) {
        if (isFile) {
          FileP0Trace.failure(
            'DURABLEIZE',
            error: error,
            stackTrace: stack,
            incidentId: incidentId,
            fileName: media.fileName,
            fileSize: media.fileSizeBytes,
            path: media.localPath,
            extra: 'evidenceId=$evidenceId abandoned=true',
          );
        } else {
          debugPrint(
            '[CaptureEngine] durableize failed → $evidenceId: $error',
          );
        }
        host.abandonFailedLocalCapture(evidenceId);
        if (error is MediaDurabilityException) {
          rethrow;
        }
        throw const MediaDurabilityException(
          'Local media could not be durably stored.',
        );
      }

      if (!_sessionMatchesStart(host, incidentIdAtStart)) {
        host.abandonFailedLocalCapture(evidenceId);
        throw StaleCaptureIncidentException(
          startedForIncidentId: incidentIdAtStart,
          currentIncidentId: host.captureIncidentId,
        );
      }

      host.attachCaptureThumbnail(
        evidenceId: evidenceId,
        filePath: committed.localPath,
        fileName: committed.fileName,
        thumbnailPath: committed.thumbnailPath,
        fileSizeBytes: committed.fileSizeBytes,
      );
      String? contentHash;
      try {
        contentHash = await EvidenceIntegrity.sha256OfFile(committed.localPath);
        host.recordContentHash(evidenceId: evidenceId, hash: contentHash);
      } catch (error) {
        debugPrint(
          '[Integrity] Evidence $evidenceId SHA-256 failed: $error',
        );
      }
      final preservedAt = DateTime.now().toUtc();
      host.appendEvidenceProvenance(
        EvidenceProvenanceEvent(
          type: EvidenceProvenanceType.preserved,
          evidenceId: evidenceId,
          at: preservedAt,
          captureModality: _modalityFor(mode),
          source: deviceName.isEmpty ? null : deviceName,
          contentHash: contentHash,
          storageReference: committed.localPath,
        ),
      );
      host.scheduleCaptureMetadataPersist();
      if (isFile) {
        FileP0Trace.step(
          'EVIDENCE_ASSIGNED',
          incidentId: incidentId,
          extra: 'evidenceId=$evidenceId pathAttached=true',
        );
      }

      coordinator.announceStatus(
        evidenceId,
        EvidenceUploadStatus.pending,
      );
      host.updateLifecycleStatus(
        evidenceId: evidenceId,
        status: EvidenceSyncStatus.queuedForUpload,
      );

      await EvidenceSyncManager.instance.registerLocalCapture(
        evidenceId: evidenceId,
        incidentId: incidentId,
        evidenceType: EvidenceRecordType.fromCaptureMode(mode),
        capturedAt: DateTime.now().toUtc(),
        mode: mode,
        media: committed,
        hash: contentHash,
        metadata: {
          if (mimeType != null && mimeType.isNotEmpty) 'mimeType': mimeType,
          if (captureSessionId != null && captureSessionId.isNotEmpty)
            'captureSessionId': captureSessionId,
          ...provenanceMetadata,
          ...EvidenceProvenanceEvent.toMetadata(
            [
              EvidenceProvenanceEvent(
                type: EvidenceProvenanceType.captured,
                evidenceId: evidenceId,
                at: capturedAt,
                captureModality: _modalityFor(mode),
                source: deviceName.isEmpty ? null : deviceName,
              ),
              EvidenceProvenanceEvent(
                type: EvidenceProvenanceType.preserved,
                evidenceId: evidenceId,
                at: preservedAt,
                captureModality: _modalityFor(mode),
                source: deviceName.isEmpty ? null : deviceName,
                contentHash: contentHash,
                storageReference: committed.localPath,
              ),
            ],
          ),
        },
        captureSessionId: captureSessionId,
        kickDrain: true,
      );
      if (isFile) {
        FileP0Trace.step(
          'CLOUD_QUEUE',
          incidentId: incidentId,
          extra: 'evidenceId=$evidenceId async=true',
        );
        FileP0Trace.step(
          'CONTROLLER_UPDATED',
          incidentId: incidentId,
          extra: 'evidenceId=$evidenceId',
        );
      }

      // Background only — never blocks capture return.
      unawaited(
        _runBackgroundJobs(
          CaptureJobContext(
            evidenceId: evidenceId,
            incidentId: incidentId,
            mode: mode,
            media: committed,
            controller: host,
            uploadCoordinator: coordinator,
          ),
        ),
      );
    } else {
      if (!_sessionMatchesStart(host, incidentIdAtStart)) {
        host.abandonFailedLocalCapture(evidenceId);
        throw StaleCaptureIncidentException(
          startedForIncidentId: incidentIdAtStart,
          currentIncidentId: host.captureIncidentId,
        );
      }
      host.scheduleCaptureMetadataPersist();
      final text = noteText?.trim() ?? '';
      final contentHash =
          text.isEmpty ? null : EvidenceIntegrity.sha256OfUtf8(text);
      if (contentHash != null) {
        host.recordContentHash(evidenceId: evidenceId, hash: contentHash);
      }
      final preservedAt = DateTime.now().toUtc();
      host.appendEvidenceProvenance(
        EvidenceProvenanceEvent(
          type: EvidenceProvenanceType.preserved,
          evidenceId: evidenceId,
          at: preservedAt,
          captureModality: _modalityFor(mode),
          source: deviceName.isEmpty ? null : deviceName,
          contentHash: contentHash,
        ),
      );
      await EvidenceSyncManager.instance.registerLocalCapture(
        evidenceId: evidenceId,
        incidentId: incidentId,
        evidenceType: EvidenceRecordType.fromCaptureMode(mode),
        capturedAt: DateTime.now().toUtc(),
        mode: mode,
        noteText: noteText,
        mimeType: mimeType,
        hash: contentHash,
        metadata: {
          ...provenanceMetadata,
          ...EvidenceProvenanceEvent.toMetadata(
            [
              EvidenceProvenanceEvent(
                type: EvidenceProvenanceType.captured,
                evidenceId: evidenceId,
                at: capturedAt,
                captureModality: _modalityFor(mode),
                source: deviceName.isEmpty ? null : deviceName,
              ),
              EvidenceProvenanceEvent(
                type: EvidenceProvenanceType.preserved,
                evidenceId: evidenceId,
                at: preservedAt,
                captureModality: _modalityFor(mode),
                source: deviceName.isEmpty ? null : deviceName,
                contentHash: contentHash,
              ),
            ],
          ),
        },
        captureSessionId: captureSessionId,
        kickDrain: true,
      );
    }

    if (userId.isNotEmpty && incidentId.isNotEmpty) {
      final title = host.captureIncidentTitle.trim();
      unawaited(
        LocalIncidentPointer.remember(
          userId: userId,
          incidentId: incidentId,
          // Preserve any prior durable title; blank capture must not wipe it.
          title: title.isEmpty ? null : title,
          captureSessionId: captureSessionId,
        ),
      );
    }

    return evidenceId;
  }

  static String _modalityFor(WorkspaceCaptureMode mode) {
    return EvidenceInspectorSemantics.captureModality(
      WorkspaceEvidenceItem(
        id: 'modality',
        kind: WorkspaceEvidenceKind.fromCaptureMode(mode),
        title: mode.label,
        lastPreservedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        integrityVerified: false,
        verification: VerificationFactory.initial(),
      ),
    );
  }

  Future<void> _runBackgroundJobs(CaptureJobContext context) async {
    final jobs = <CaptureJob>[
      ThumbnailJob(),
      FirestoreJob(),
    ];

    for (final job in jobs) {
      try {
        debugPrint('[CaptureEngine] ${job.name} → ${context.evidenceId}');
        await job.run(context);
      } catch (error, stack) {
        debugPrint(
          '[CaptureEngine] ${job.name} failed → ${context.evidenceId}: $error\n$stack',
        );
      }
    }
  }
}
