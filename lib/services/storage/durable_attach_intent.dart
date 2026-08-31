/// Metadata-only File attach record. Never stores document bytes or URIs.
///
/// One pending operation per authenticated user. The record is incident-
/// specific ([sourceIncidentId]); it is not a global "current incident" pointer.
class DurableAttachIntent {
  const DurableAttachIntent({
    required this.userId,
    required this.sourceIncidentId,
    required this.origin,
    required this.operationId,
    required this.createdAtMs,
    this.version = schemaVersion,
    this.modality = modalityFile,
    this.status = awaitingPicker,
  });

  static const schemaVersion = 1;
  static const awaitingPicker = 'awaitingPicker';
  static const reselectRequired = 'reselectRequired';
  static const originHomeCaptureNow = 'homeCaptureNow';
  static const originWorkspaceSticky = 'workspaceSticky';
  static const modalityFile = 'file';
  static const modalityOrganizeFile = 'organizeFile';

  final int version;
  final String userId;
  final String sourceIncidentId;

  /// [FileAttachOrigin] name: [originHomeCaptureNow] or [originWorkspaceSticky].
  final String origin;
  final String modality;
  final String operationId;
  final int createdAtMs;
  final String status;

  bool get isHomeCaptureNow => origin == originHomeCaptureNow;

  Map<String, Object?> toJson() => {
    'version': version,
    'userId': userId,
    'sourceIncidentId': sourceIncidentId,
    'origin': origin,
    'modality': modality,
    'operationId': operationId,
    'createdAtMs': createdAtMs,
    'status': status,
  };

  static DurableAttachIntent? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final userId = (map['userId'] as String?)?.trim() ?? '';
    final incidentId = (map['sourceIncidentId'] as String?)?.trim() ?? '';
    final operationId = (map['operationId'] as String?)?.trim() ?? '';
    final origin = (map['origin'] as String?)?.trim() ?? '';
    final createdAtMs = map['createdAtMs'];
    if (userId.isEmpty ||
        incidentId.isEmpty ||
        operationId.isEmpty ||
        createdAtMs is! int) {
      return null;
    }
    if (origin != originHomeCaptureNow && origin != originWorkspaceSticky) {
      return null;
    }
    final version = map['version'];
    return DurableAttachIntent(
      version: version is int ? version : schemaVersion,
      userId: userId,
      sourceIncidentId: incidentId,
      origin: origin,
      modality: (map['modality'] as String?)?.trim().isNotEmpty == true
          ? (map['modality'] as String).trim()
          : modalityFile,
      operationId: operationId,
      createdAtMs: createdAtMs,
      status: (map['status'] as String?)?.trim().isNotEmpty == true
          ? (map['status'] as String).trim()
          : awaitingPicker,
    );
  }

  DurableAttachIntent copyWith({String? status}) {
    return DurableAttachIntent(
      version: version,
      userId: userId,
      sourceIncidentId: sourceIncidentId,
      origin: origin,
      modality: modality,
      operationId: operationId,
      createdAtMs: createdAtMs,
      status: status ?? this.status,
    );
  }
}
