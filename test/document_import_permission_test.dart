import 'package:evidence_vault/models/evidence_type.dart';
import 'package:evidence_vault/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionService.requiredFor', () {
    test('photo requires only camera', () {
      final permissions = PermissionService.requiredFor(EvidenceType.photo);

      expect(permissions, [EvidencePermission.camera]);
    });

    test('video requires camera and microphone', () {
      final permissions = PermissionService.requiredFor(EvidenceType.video);

      expect(
        permissions,
        [EvidencePermission.camera, EvidencePermission.microphone],
      );
    });

    test('voice / audio requires only microphone', () {
      final permissions = PermissionService.requiredFor(EvidenceType.audio);

      expect(permissions, [EvidencePermission.microphone]);
    });

    test('document import requires no runtime permissions (SAF)', () {
      final permissions = PermissionService.requiredFor(EvidenceType.document);

      expect(permissions, isEmpty);
    });

    test('no capture type hard-gates on location', () {
      for (final type in EvidenceType.values) {
        expect(
          PermissionService.requiredFor(type),
          isNot(contains(EvidencePermission.location)),
          reason: '$type must not block capture on location',
        );
      }
    });
  });
}
