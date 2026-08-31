import 'evidence_category.dart';
import 'evidence_device.dart';
import 'evidence_location.dart';
import 'evidence_metadata.dart';
import 'evidence_status.dart';
import 'evidence_type.dart';

class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.createdAt,
    required this.location,
    required this.device,
    required this.filePath,
    this.thumbnail,
    required this.status,
    required this.metadata,
  });

  final String id;
  final String title;
  final String description;
  final EvidenceCategory category;
  final EvidenceType type;
  final DateTime createdAt;
  final EvidenceLocation location;
  final EvidenceDevice device;
  final String filePath;
  final String? thumbnail;
  final EvidenceStatus status;
  final EvidenceMetadata metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'location': location.toJson(),
        'device': device.toJson(),
        'filePath': filePath,
        'thumbnail': thumbnail,
        'status': status.name,
        'metadata': metadata.toJson(),
      };

  factory EvidenceRecord.fromJson(Map<String, dynamic> json) {
    return EvidenceRecord(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: EvidenceCategory.values.byName(json['category'] as String),
      type: EvidenceType.values.byName(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      location: EvidenceLocation.fromJson(
        Map<String, dynamic>.from(json['location'] as Map),
      ),
      device: EvidenceDevice.fromJson(
        Map<String, dynamic>.from(json['device'] as Map),
      ),
      filePath: json['filePath'] as String,
      thumbnail: json['thumbnail'] as String?,
      status: EvidenceStatus.values.byName(json['status'] as String),
      metadata: EvidenceMetadata.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map),
      ),
    );
  }
}
