import 'evidence_device.dart';
import 'evidence_location.dart';

/// Automatic capture metadata stored separately from UI presentation.
class EvidenceMetadata {
  const EvidenceMetadata({
    required this.evidenceId,
    required this.capturedAt,
    required this.timezone,
    required this.device,
    required this.location,
  });

  final String evidenceId;
  final DateTime capturedAt;
  final String timezone;
  final EvidenceDevice device;
  final EvidenceLocation location;

  Map<String, dynamic> toJson() => {
        'evidenceId': evidenceId,
        'capturedAt': capturedAt.toIso8601String(),
        'timezone': timezone,
        'device': device.toJson(),
        'location': location.toJson(),
      };

  factory EvidenceMetadata.fromJson(Map<String, dynamic> json) {
    return EvidenceMetadata(
      evidenceId: json['evidenceId'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      timezone: json['timezone'] as String? ?? 'UTC',
      device: EvidenceDevice.fromJson(
        Map<String, dynamic>.from(json['device'] as Map),
      ),
      location: EvidenceLocation.fromJson(
        Map<String, dynamic>.from(json['location'] as Map),
      ),
    );
  }
}
