import 'capture_session_status.dart';

/// One period of active evidence collection within an [Incident].
///
/// An incident is the event; a capture session groups evidence captured during
/// a continuous collection period (e.g. "Session started 10:30 AM").
class CaptureSession {
  CaptureSession({
    required this.id,
    required this.incidentId,
    required this.userId,
    required this.startedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.endedAt,
    List<String>? evidenceIds,
  }) : evidenceIds = List<String>.unmodifiable(evidenceIds ?? const []);

  final String id;
  final String incidentId;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final CaptureSessionStatus status;
  final List<String> evidenceIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == CaptureSessionStatus.active;

  CaptureSession copyWith({
    DateTime? endedAt,
    bool clearEndedAt = false,
    CaptureSessionStatus? status,
    List<String>? evidenceIds,
    DateTime? updatedAt,
  }) {
    return CaptureSession(
      id: id,
      incidentId: incidentId,
      userId: userId,
      startedAt: startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      status: status ?? this.status,
      evidenceIds: evidenceIds ?? this.evidenceIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'incidentId': incidentId,
        'userId': userId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'status': status.wireName,
        'evidenceIds': evidenceIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CaptureSession.fromJson(Map<String, dynamic> json) {
    final started =
        DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now();
    final created =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? started;
    final updated =
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created;
    final endedRaw = json['endedAt'] as String?;
    final evidenceRaw = json['evidenceIds'];
    final ids = <String>[];
    if (evidenceRaw is List) {
      for (final item in evidenceRaw) {
        if (item == null) continue;
        final id = '$item'.trim();
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
    return CaptureSession(
      id: json['id'] as String? ?? '',
      incidentId: json['incidentId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      startedAt: started,
      endedAt: endedRaw == null ? null : DateTime.tryParse(endedRaw),
      status: CaptureSessionStatus.fromWire(json['status'] as String?),
      evidenceIds: ids,
      createdAt: created,
      updatedAt: updated,
    );
  }
}
