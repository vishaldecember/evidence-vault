import 'incident_status.dart';

/// Aggregate root for one truth record.
///
/// Owns evidence, timeline anchors, relationship groups, reconstruction notes,
/// and derived coaching state (computed — not stored).
class Incident {
  const Incident({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.manuallyComplete = false,
    this.coverEvidenceId,
    this.deletedAt,
  });

  final String id;
  final String title;
  final IncidentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool manuallyComplete;

  /// Set when the incident entered Recently Deleted. Null otherwise.
  ///
  /// Does not replace [createdAt], [updatedAt], or any evidence timestamps.
  final DateTime? deletedAt;

  /// Optional pointer to one existing Evidence record. Presentation only.
  ///
  /// Not a media object, thumbnail, or copied file. Null when unset.
  final String? coverEvidenceId;

  /// Blank / whitespace IDs become null. No fabricated default.
  static String? normalizeCoverEvidenceId(String? raw) {
    final id = raw?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  /// True when [evidenceIncidentId] is this incident's id.
  static bool coverBelongsToIncident({
    required String incidentId,
    required String? coverEvidenceId,
    required String? evidenceIncidentId,
  }) {
    final cover = normalizeCoverEvidenceId(coverEvidenceId);
    final owner = incidentId.trim();
    final evidenceOwner = evidenceIncidentId?.trim() ?? '';
    if (cover == null || owner.isEmpty || evidenceOwner.isEmpty) {
      return false;
    }
    return evidenceOwner == owner;
  }

  Incident copyWith({
    String? title,
    IncidentStatus? status,
    DateTime? updatedAt,
    bool? manuallyComplete,
    String? coverEvidenceId,
    bool clearCoverEvidenceId = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Incident(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      manuallyComplete: manuallyComplete ?? this.manuallyComplete,
      coverEvidenceId: clearCoverEvidenceId
          ? null
          : (normalizeCoverEvidenceId(coverEvidenceId) ?? this.coverEvidenceId),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
