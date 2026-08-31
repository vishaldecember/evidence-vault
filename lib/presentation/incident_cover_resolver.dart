import '../domain/evidence/evidence_record_type.dart';
import '../domain/incident/incident.dart';
import '../services/storage/cached_evidence_entry.dart';
import '../services/storage/local_evidence_cache.dart';

/// Resolved cover visual. Null path means use the existing Incident fallback.
class IncidentCoverResolution {
  const IncidentCoverResolution._({this.thumbnailPath, this.evidenceType});

  static const fallback = IncidentCoverResolution._();

  factory IncidentCoverResolution.resolved(
    String thumbnailPath, {
    EvidenceRecordType? evidenceType,
  }) {
    return IncidentCoverResolution._(
      thumbnailPath: thumbnailPath,
      evidenceType: evidenceType,
    );
  }

  final String? thumbnailPath;
  final EvidenceRecordType? evidenceType;

  bool get hasThumbnail {
    final path = thumbnailPath?.trim() ?? '';
    return path.isNotEmpty;
  }
}

/// Resolves [Incident.coverEvidenceId] through [LocalEvidenceCache].
///
/// Does not copy bytes, generate thumbnails, or fetch all evidence.
abstract final class IncidentCoverResolver {
  static Future<IncidentCoverResolution> resolve({
    required String incidentId,
    String? coverEvidenceId,
    CachedEvidenceEntry? cachedEntry,
    Future<CachedEvidenceEntry?> Function(String evidenceId)? lookup,
  }) async {
    final cover = Incident.normalizeCoverEvidenceId(coverEvidenceId);
    final owner = incidentId.trim();
    if (cover == null || owner.isEmpty) {
      return IncidentCoverResolution.fallback;
    }

    final entry = cachedEntry ??
        await (lookup ?? LocalEvidenceCache.byId)(cover);
    if (entry == null || entry.evidenceId.trim() != cover) {
      return IncidentCoverResolution.fallback;
    }
    if (!Incident.coverBelongsToIncident(
      incidentId: owner,
      coverEvidenceId: cover,
      evidenceIncidentId: entry.incidentId,
    )) {
      return IncidentCoverResolution.fallback;
    }

    final thumb = entry.thumbnailPath?.trim() ?? '';
    if (thumb.isEmpty) {
      return IncidentCoverResolution._(evidenceType: entry.evidenceType);
    }
    final original = entry.localFilePath?.trim() ?? '';
    if (original.isNotEmpty && thumb == original) {
      return IncidentCoverResolution._(evidenceType: entry.evidenceType);
    }
    return IncidentCoverResolution._(
      thumbnailPath: thumb,
      evidenceType: entry.evidenceType,
    );
  }
}
