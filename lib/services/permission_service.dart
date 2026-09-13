import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/evidence_type.dart';
import '../widgets/evidence/permission_dialog.dart';

/// Runtime permissions that may gate a capture flow.
///
/// Location is intentionally not a hard gate: [MetadataService] collects it
/// soft-fail. Broad storage / media-library access is never requested — media
/// is written to app-private paths and documents use the system picker (SAF).
enum EvidencePermission {
  camera,
  microphone,
  location,
}

abstract final class PermissionService {
  /// Permissions that must be granted before starting a capture flow.
  ///
  /// Mapping (Android 13–15 and iOS):
  /// - Photo → camera
  /// - Video → camera + microphone
  /// - Voice → microphone
  /// - Document → none (Android Storage Access Framework / iOS UIDocumentPicker
  ///   via `file_picker`)
  static List<EvidencePermission> requiredFor(EvidenceType type) {
    return switch (type) {
      EvidenceType.photo => const [
          EvidencePermission.camera,
        ],
      EvidenceType.video => const [
          EvidencePermission.camera,
          EvidencePermission.microphone,
        ],
      EvidenceType.audio => const [
          EvidencePermission.microphone,
        ],
      EvidenceType.document => const [],
    };
  }

  static Future<bool> ensureAll(
    BuildContext context,
    List<EvidencePermission> permissions,
  ) async {
    if (permissions.isEmpty) {
      return true;
    }

    for (final permission in permissions) {
      final granted = await _ensure(context, permission);
      if (!granted) return false;
    }
    return true;
  }

  static Future<bool> _ensure(
    BuildContext context,
    EvidencePermission permission,
  ) async {
    final status = await _request(permission);

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (!context.mounted) return false;

    await PermissionDialog.show(
      context,
      title: _titleFor(permission),
      message: _messageFor(permission),
      permanentlyDenied: status.isPermanentlyDenied,
    );

    return false;
  }

  static Future<PermissionStatus> _request(
    EvidencePermission permission,
  ) async {
    final handler = switch (permission) {
      EvidencePermission.camera => Permission.camera,
      EvidencePermission.microphone => Permission.microphone,
      EvidencePermission.location => Permission.locationWhenInUse,
    };

    final current = await handler.status;
    if (current.isGranted || current.isLimited) {
      return current;
    }

    return handler.request();
  }

  static String _titleFor(EvidencePermission permission) {
    return switch (permission) {
      EvidencePermission.camera => 'Camera access needed',
      EvidencePermission.microphone => 'Microphone access needed',
      EvidencePermission.location => 'Location access needed',
    };
  }

  static String _messageFor(EvidencePermission permission) {
    return switch (permission) {
      EvidencePermission.camera =>
        'My Truth needs camera access to capture photos and videos. '
            'You can enable this in your device settings.',
      EvidencePermission.microphone =>
        'My Truth needs microphone access to record audio evidence. '
            'You can enable this in your device settings.',
      EvidencePermission.location =>
        'My Truth captures location metadata with each evidence item. '
            'Location access helps verify when and where evidence was collected.',
    };
  }
}
