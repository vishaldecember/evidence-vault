import '../../models/evidence_record_model.dart';
import '../../models/workspace_evidence_item.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../../utils/evidence_formatters.dart';
import '../evidence/evidence_integrity.dart';
import '../evidence/evidence_provenance_event.dart';
import 'trust_package_integrity_provenance.dart';

/// Projects Stage 1 integrity and provenance into the Trust Pack section.
///
/// Reads existing evidence fields and provenance events only.
/// Does not hash new payloads into storage, geocode, or invent events.
abstract final class TrustPackageIntegrityProvenanceBuilder {
  static TrustPackageIntegrityProvenanceSection fromItems(
    List<WorkspaceEvidenceItem> items,
  ) {
    final sorted = List<WorkspaceEvidenceItem>.from(items)
      ..sort((a, b) {
        final byTime = a.lastPreservedAt.compareTo(b.lastPreservedAt);
        if (byTime != 0) {
          return byTime;
        }
        return a.id.compareTo(b.id);
      });

    return TrustPackageIntegrityProvenanceSection(
      entries: [
        for (final item in sorted) fromItem(item),
      ],
    );
  }

  static TrustPackageIntegrityProvenanceEntry fromItem(
    WorkspaceEvidenceItem item, {
    EvidenceIntegrityCheck? check,
  }) {
    final recordedHash = EvidenceInspectorSemantics.contentHash(item);
    final classified = check ??
        EvidenceIntegrity.classifyAvailable(
          recordedHash: recordedHash,
          originalFilePath: item.filePath,
          thumbnailPath: item.thumbnailPath,
          noteText: item.notePreview,
        );
    final state = _stateFor(classified);
    final capturedEvent = _firstEvent(item, EvidenceProvenanceType.captured);
    final preservedEvent = _firstEvent(item, EvidenceProvenanceType.preserved);
    final capturedAt = capturedEvent?.at ?? item.capturedAt;
    final preservedAt = preservedEvent?.at ?? item.recordedAt;
    final source = _sourceOf(item, capturedEvent, preservedEvent);
    final modality = _modalityOf(item, capturedEvent, preservedEvent);

    return TrustPackageIntegrityProvenanceEntry(
      evidenceId: item.id,
      title: item.title,
      state: state,
      originalPreserved: state == TrustPackIntegrityState.verified,
      capturedAt: capturedAt,
      preservedAt: preservedAt,
      source: source,
      captureModality: modality,
      location: _locationOf(item),
      locationUncertain: false,
      history: _historyOf(item),
      contentHash: recordedHash,
      independentVerification:
          TrustPackIntegrityLabels.independentNotPerformed,
    );
  }

  static TrustPackIntegrityState _stateFor(EvidenceIntegrityCheck check) {
    return switch (check) {
      EvidenceIntegrityCheck.match => TrustPackIntegrityState.verified,
      EvidenceIntegrityCheck.payloadUnavailable =>
        TrustPackIntegrityState.recorded,
      EvidenceIntegrityCheck.mismatch => TrustPackIntegrityState.mismatch,
      EvidenceIntegrityCheck.hashNotRecorded =>
        TrustPackIntegrityState.fingerprintUnavailable,
    };
  }

  static EvidenceProvenanceEvent? _firstEvent(
    WorkspaceEvidenceItem item,
    EvidenceProvenanceType type,
  ) {
    for (final event in item.provenanceEvents) {
      if (event.type == type) {
        return event;
      }
    }
    return null;
  }

  static String? _sourceOf(
    WorkspaceEvidenceItem item,
    EvidenceProvenanceEvent? captured,
    EvidenceProvenanceEvent? preserved,
  ) {
    for (final candidate in [
      captured?.source,
      preserved?.source,
      item.deviceModel,
    ]) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _modalityOf(
    WorkspaceEvidenceItem item,
    EvidenceProvenanceEvent? captured,
    EvidenceProvenanceEvent? preserved,
  ) {
    for (final candidate in [captured?.captureModality, preserved?.captureModality]) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return EvidenceInspectorSemantics.captureModality(item);
  }

  static String _locationOf(WorkspaceEvidenceItem item) {
    final metadata = EvidenceRecordMetadata.forItem(item);
    final recorded = metadata.location?.trim() ?? '';
    if (recorded.isNotEmpty) {
      return recorded;
    }
    if (item.latitude != null && item.longitude != null) {
      return EvidenceFormatters.coordinates(item.latitude, item.longitude);
    }
    return TrustPackIntegrityLabels.locationUnavailable;
  }

  static List<TrustPackageIntegrityHistoryEvent> _historyOf(
    WorkspaceEvidenceItem item,
  ) {
    final events = List<EvidenceProvenanceEvent>.from(item.provenanceEvents)
      ..sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        if (byTime != 0) {
          return byTime;
        }
        return a.type.index.compareTo(b.type.index);
      });

    return [
      for (final event in events)
        TrustPackageIntegrityHistoryEvent(
          at: event.at,
          label: switch (event.type) {
            EvidenceProvenanceType.captured =>
              TrustPackIntegrityLabels.eventCaptured,
            EvidenceProvenanceType.preserved =>
              TrustPackIntegrityLabels.eventPreserved,
            EvidenceProvenanceType.contextAdded =>
              TrustPackIntegrityLabels.eventContextAdded,
          },
        ),
    ];
  }
}
