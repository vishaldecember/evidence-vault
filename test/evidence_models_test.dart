import 'package:evidence_vault/models/evidence_category.dart';
import 'package:evidence_vault/models/evidence_device.dart';
import 'package:evidence_vault/models/evidence_location.dart';
import 'package:evidence_vault/models/evidence_metadata.dart';
import 'package:evidence_vault/models/evidence_record.dart';
import 'package:evidence_vault/models/evidence_status.dart';
import 'package:evidence_vault/models/evidence_type.dart';
import 'package:evidence_vault/utils/evidence_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidenceRecord serialization', () {
    test('round trips through JSON', () {
      final metadata = EvidenceMetadata(
        evidenceId: 'abc-123',
        capturedAt: DateTime.parse('2026-07-23T10:15:00.000'),
        timezone: 'NPT',
        device: const EvidenceDevice(name: 'Pixel 8', platform: 'android'),
        location: const EvidenceLocation(
          latitude: 27.7172,
          longitude: 85.3240,
          accuracyMeters: 12.5,
        ),
      );

      final record = EvidenceRecord(
        id: metadata.evidenceId,
        title: 'Accident scene',
        description: 'Front bumper damage',
        category: EvidenceCategory.legal,
        type: EvidenceType.photo,
        createdAt: metadata.capturedAt,
        location: metadata.location,
        device: metadata.device,
        filePath: '/tmp/photo.jpg',
        thumbnail: '/tmp/photo.jpg',
        status: EvidenceStatus.saved,
        metadata: metadata,
      );

      final restored = EvidenceRecord.fromJson(record.toJson());

      expect(restored.id, record.id);
      expect(restored.title, record.title);
      expect(restored.type, EvidenceType.photo);
      expect(restored.category, EvidenceCategory.legal);
      expect(restored.status, EvidenceStatus.saved);
      expect(restored.metadata.evidenceId, 'abc-123');
      expect(restored.location.latitude, 27.7172);
    });
  });

  group('EvidenceFormatters', () {
    test('formats file sizes', () {
      expect(EvidenceFormatters.fileSize(0), '0 B');
      expect(EvidenceFormatters.fileSize(2048), '2.0 KB');
    });

    test('formats coordinates fallback', () {
      expect(
        EvidenceFormatters.coordinates(null, null),
        'Location unavailable',
      );
    });
  });
}
