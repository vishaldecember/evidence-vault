import 'package:flutter_test/flutter_test.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:evidence_vault/services/storage/evidence_upload_models.dart';

void main() {
  group('FirestoreSerializers', () {
    test('round-trips incident fields required by Sprint 4B', () {
      final now = DateTime.utc(2026, 8, 5, 12);
      final incident = Incident(
        id: 'inc-1',
        title: 'Travel case',
        status: IncidentStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final map = FirestoreSerializers.incidentToMap(
        incident: incident,
        ownerId: 'uid-1',
        timelineCount: 3,
        relationshipCount: 1,
        narrativeCount: 2,
        reconstructionHealth: 64,
      );

      expect(map['incidentId'], 'inc-1');
      expect(map['timelineCount'], 3);
      expect(map['reconstructionHealth'], 64);

      final restored = FirestoreSerializers.incidentFromMap(map, 'inc-1');
      expect(restored.id, 'inc-1');
      expect(restored.title, 'Travel case');
      expect(restored.status, IncidentStatus.active);
    });

    test('serializes evidence metadata for coaching reload', () {
      final evidence = CapturedEvidence(
        id: 'ev-1',
        incidentId: 'inc-1',
        type: CapturedEvidenceType.photo,
        capturedAt: DateTime.utc(2026, 8, 5, 12),
        title: 'Photo',
        integrityVerified: true,
        verification: VerificationFactory.initial(),
        timelineAnchorId: 'anchor-1',
        downloadUrl: 'https://example.com/a.jpg',
        thumbnailUrl: 'https://example.com/a_thumb.jpg',
        fileName: 'a.jpg',
        uploadStatus: EvidenceUploadStatus.uploaded,
        deviceModel: 'Pixel',
        latitude: 1.2,
        longitude: 3.4,
        notePreview: 'gate photo',
      );

      final map = FirestoreSerializers.capturedToMap(
        evidence,
        userId: 'uid-1',
        timelineOrder: 0,
        supportingEvidenceIds: const ['note-1'],
      );

      expect(map['timelineOrder'], 0);
      expect(map['downloadUrl'], startsWith('https://'));
      expect(map['supportingEvidenceIds'], ['note-1']);
      expect(map['device'], 'Pixel');

      final restored = FirestoreSerializers.capturedFromMap(map)!;
      expect(restored.id, 'ev-1');
      expect(restored.downloadUrl, evidence.downloadUrl);
      expect(restored.thumbnailUrl, evidence.thumbnailUrl);
      expect(restored.timelineOrder, 0);
      expect(restored.deviceModel, 'Pixel');
    });
  });
}
